import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/auth_provider.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_strings.dart';
import 'guard/guard_dashboard_screen.dart';
import 'hirer/hirer_dashboard_screen.dart';
import 'app_settings_screen.dart';
import 'phone_input_screen.dart';
import 'registration_pending_screen.dart';
import 'guard_registration_screen.dart';
import 'customer_registration_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  /// Phone number from OTP flow. Used to call updateRole API.
  final String? phone;

  const RoleSelectionScreen({
    super.key,
    this.phone,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Guard against double-tap / rapid re-taps while an updateRole call is
  // in flight. phone_verified_token is single-use — every retry would
  // fail with "Verification token expired or already used".
  bool _isNavigating = false;

  Future<void> _onRoleTap(String role, Widget dashboard) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      await _onRoleTapInner(role, dashboard);
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  Future<void> _onRoleTapInner(String role, Widget dashboard) async {
    final auth = context.read<AuthProvider>();

    // Resolve phone FIRST — needed for all subsequent operations.
    String? phone = widget.phone;
    phone ??= auth.phone;
    phone ??= await AuthService.getStoredPhone();
    if (phone == null) {
      final verified = await AuthService.getPhoneVerifiedData();
      phone = verified.$1;
    }
    if (!mounted) return;

    // If user is already authenticated (approved), go directly to dashboard.
    if (auth.status == AuthStatus.authenticated) {
      // Retry fetchProfile if never succeeded (e.g. startup timed out).
      // /auth/me always returns phone — null means no successful fetch yet.
      if (auth.phone == null) {
        await auth.fetchProfile();
        if (!mounted) return;
      }
      // For customer role: check customer profile approval status.
      // - approved → dashboard
      // - pending → pending screen
      // - null (no profile) → registration form
      if (role == 'customer') {
        final cas = auth.customerApprovalStatus;
        if (cas == 'approved') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => dashboard),
          );
        } else if (cas == 'pending') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RegistrationPendingScreen(role: 'customer')),
          );
        } else {
          // No customer profile yet → show registration form
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerRegistrationScreen(
                phone: auth.phone ?? '',
                profileToken: null,
              ),
            ),
          );
        }
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
      return;
    }

    // NOTE: removed `AuthService.isRegistered(role)` check — `markRegistered`
    // is never called in the current 3-step OTP registration flow, so the
    // check always returned false and the path was dead. Approved users are
    // routed to the dashboard via the `auth.status == authenticated` branch
    // above. (security-reviewer LOW #2)

    // If pending AND this specific role's profile was already submitted → pending screen.
    final hasSubmitted = await AuthService.hasSubmittedRole(role);
    if (!mounted) return;
    if (hasSubmitted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => RegistrationPendingScreen(role: role)),
        (route) => false,
      );
      return;
    }

    // Phone already resolved above — redirect to OTP if still null
    if (phone == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
      );
      return;
    }

    // Read pending role for reissue logic
    final pendingRole = await AuthService.getPendingRole();

    if (role == 'guard') {
      // Step 2: Set role via API → get profile_token for guard form
      String? profileToken;
      if (!mounted) return;

      try {
        final authProvider = context.read<AuthProvider>();
        if (pendingRole == 'guard') {
          // Role already set but token expired — re-verify via OTP.
          // pushReplacement so RoleSelection isn't left dangling on the
          // stack after the user completes the new OTP cycle.
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PhoneInputScreen(),
            ),
          );
          return;
        } else {
          // Set role for the first time
          profileToken = await authProvider.updateRole(phone, 'guard');
        }
      } on DioException catch (e) {
        if (!mounted) return;
        final message = e.response?.data?['error']?['message'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Failed to set role')),
        );
        return;
      } catch (e) {
        // Non-Dio exceptions — typically "กรุณายืนยันเบอร์โทรศัพท์อีกครั้ง"
        // when the phone_verified_token has expired or been consumed.
        // Redirect to OTP verification so the user can get a fresh token.
        if (!mounted) return;
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
        );
        return;
      }

      if (!mounted) return;
      // pushReplacement so the back gesture doesn't return to RoleSelection.
      // phone_verified_token has been consumed — coming back here would
      // always fail with "Missing phone verification token".
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GuardRegistrationScreen(
            phone: phone!,
            profileToken: profileToken,
            dashboard: dashboard,
          ),
        ),
      );
      return;
    }

    // Customer path: set role → get profile_token → customer registration form
    String? profileToken;
    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();
      if (pendingRole == 'customer') {
        // Role already set but token expired — re-verify via OTP.
        // pushReplacement so RoleSelection isn't left dangling on the
        // stack after the user completes the new OTP cycle.
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PhoneInputScreen(),
          ),
        );
        return;
      } else {
        // Set role for the first time
        profileToken = await authProvider.updateRole(phone, 'customer');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?['error']?['message'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Failed to set role')),
      );
      return;
    } catch (e) {
      // Non-Dio exceptions — typically "Missing phone verification token".
      // Redirect to OTP flow automatically. (security-reviewer MEDIUM M3)
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      if (msg.toLowerCase().contains('phone verification token') ||
          msg.toLowerCase().contains('verify your phone')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerRegistrationScreen(
          phone: phone!,
          profileToken: profileToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = RoleSelectionStrings(isThai: isThai);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Settings gear (top-right)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AppSettingsScreen()),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.settings_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLogo(),
                  const SizedBox(height: 10),
                  _buildTitle(),
                  const SizedBox(height: 16),
                  _buildRoleTitle(isThai, strings),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    _buildHireCard(context, isThai, strings),
                                    const SizedBox(height: 14),
                                    _buildGuardCard(context, isThai, strings),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 8,
                                  ),
                                  child: _buildFooter(isThai, strings),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'P-Guard',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTitle(bool isThai, RoleSelectionStrings strings) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(isThai),
        children: [
          Text(
            strings.roleTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            strings.roleSubtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHireCard(
    BuildContext context,
    bool isThai,
    RoleSelectionStrings strings,
  ) {
    return GestureDetector(
      onTap: () => _onRoleTap('customer', const HirerDashboardScreen()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey('hire_$isThai'),
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.hireTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.hireDesc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      strings.hireCta,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuardCard(
    BuildContext context,
    bool isThai,
    RoleSelectionStrings strings,
  ) {
    return GestureDetector(
      onTap: () => _onRoleTap('guard', const GuardDashboardScreen()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey('guard_$isThai'),
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.guardTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.guardDesc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      strings.guardCta,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.login_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isThai, RoleSelectionStrings strings) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey('footer_$isThai'),
        children: [
          Text(
            strings.footerTitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              letterSpacing: isThai ? 0 : 1.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            strings.footerTerms,
            style: GoogleFonts.inter(fontSize: 9, color: AppColors.border),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
