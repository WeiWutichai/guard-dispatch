import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_strings.dart';
import '../widgets/language_toggle.dart';
import 'guard/guard_dashboard_screen.dart';
import 'hirer/hirer_dashboard_screen.dart';
import 'phone_input_screen.dart';
import 'registration_form_screen.dart';
import 'registration_pending_screen.dart';
import 'guard_registration_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  /// If set, this is a new registration flow.
  /// [profileToken] is the short-lived JWT returned by registerWithOtp()
  /// (already called in PinSetupScreen) for submitting guard profile data.
  final String? phone;
  final String? profileToken;

  const RoleSelectionScreen({
    super.key,
    this.phone,
    this.profileToken,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  Future<void> _onRoleTap(String role, Widget dashboard) async {
    if (role == 'guard') {
      // Parallel reads: isPendingApproval + isRegistered (both are SharedPreferences).
      final results = await Future.wait([
        AuthService.isPendingApproval(),
        AuthService.isRegistered(role),
      ]);
      if (!mounted) return;

      final isPending = results[0];
      final isRegistered = results[1];

      if (isPending) {
        // Guard is pending approval — check if profile was already submitted.
        final profile = await AuthService.getPendingProfile();
        if (!mounted) return;
        if (profile != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegistrationPendingScreen()),
          );
          return;
        }
        // Profile not yet submitted → go directly to guard form (skip
        // RegistrationFormScreen which would trigger OTP again).
        String? phone = widget.phone;
        if (phone == null) {
          final stored = await AuthService.getPhoneVerifiedData();
          if (!mounted) return;
          phone = stored.$1;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuardRegistrationScreen(
              phone: phone ?? '',
              profileToken: widget.profileToken,
              dashboard: dashboard,
            ),
          ),
        );
        return;
      }

      if (isRegistered) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => dashboard));
        return;
      }

      // Not registered — get phone from widget props or storage fallback.
      String? phone = widget.phone;
      final profileToken = widget.profileToken;
      if (phone == null) {
        final stored = await AuthService.getPhoneVerifiedData();
        if (!mounted) return;
        phone = stored.$1;
      }
      if (phone != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationFormScreen(
              role: role,
              dashboard: dashboard,
              phone: phone ?? '',
              profileToken: profileToken,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
        );
      }
      return;
    }

    // Non-guard roles: isRegistered + getPhoneVerifiedData in parallel when
    // phone is not already in widget props (avoids a second sequential read).
    final (isRegistered, storedPhone) = await (
      AuthService.isRegistered(role),
      widget.phone == null
          ? AuthService.getPhoneVerifiedData().then((r) => r.$1)
          : Future.value(widget.phone),
    ).wait;
    if (!mounted) return;

    if (isRegistered) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => dashboard));
      return;
    }

    final String? phone = widget.phone ?? storedPhone;
    final profileToken = widget.profileToken;

    if (phone != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationFormScreen(
            role: role,
            dashboard: dashboard,
            phone: phone!,
            profileToken: profileToken,
          ),
        ),
      );
    } else {
      // Truly no phone at all (should not happen) — go through full OTP flow
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = RoleSelectionStrings(isThai: isThai);

    return Scaffold(
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
                  // Language toggle
                  const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: LanguageToggle(),
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
          'SecureGuard',
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.guardCta,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.login_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
