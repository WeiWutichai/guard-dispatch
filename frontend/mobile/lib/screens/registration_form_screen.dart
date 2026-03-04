import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../providers/auth_provider.dart';
import 'otp_verification_screen.dart';
import 'guard_registration_screen.dart';

/// Shows "ยังไม่ได้สมัคร" status page.
/// Tapping "สมัครเลย" navigates to SetPasswordScreen (full registration form).
class RegistrationFormScreen extends StatefulWidget {
  final String role;
  final Widget dashboard;
  final String phone;
  /// Short-lived profile_token returned by registerWithOtp() in PinSetupScreen.
  /// Used to authenticate the guard profile submission without a full JWT.
  final String? profileToken;

  const RegistrationFormScreen({
    super.key,
    required this.role,
    required this.dashboard,
    required this.phone,
    this.profileToken,
  });

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  bool _isRequestingOtp = false;
  String? _errorMessage;

  Color get _roleColor => AppColors.primary;

  Future<void> _onRegisterNow() async {
    // profile_token was obtained in PinSetupScreen — navigate directly.
    if (widget.profileToken != null) {
      _navigateToRegistration(widget.profileToken!);
      return;
    }

    // Fallback: no token — need to re-verify OTP (edge case: token expired).
    setState(() {
      _isRequestingOtp = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.requestOtp(widget.phone);
      if (!mounted) return;

      // Navigate to OTP screen in returnTokenOnly mode
      final token = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phone: widget.phone,
            returnTokenOnly: true,
          ),
        ),
      );

      if (!mounted) return;
      setState(() => _isRequestingOtp = false);

      if (token != null) {
        _navigateToRegistration(token);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?['error']?['message'] as String?;
      setState(() {
        _isRequestingOtp = false;
        _errorMessage = message ?? e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRequestingOtp = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _navigateToRegistration(String profileToken) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuardRegistrationScreen(
          phone: widget.phone,
          profileToken: profileToken,
          dashboard: widget.dashboard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _roleColor.withValues(alpha: 0.06),
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
          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, top: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // Clock icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 36,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // "ยังไม่ได้สมัคร"
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isThai ? 'ยังไม่ได้สมัคร' : 'Not Registered',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Subtitle
                        Text(
                          isThai
                              ? 'กรุณาสมัครเพื่อเริ่มรับงาน'
                              : 'Please register to start receiving jobs',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Warning icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.priority_high_rounded,
                            size: 24,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(flex: 2),
                        // "สมัครเลย" button
                        GestureDetector(
                          onTap: _isRequestingOtp ? null : _onRegisterNow,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isRequestingOtp
                                  ? _roleColor.withValues(alpha: 0.5)
                                  : _roleColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _roleColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isRequestingOtp
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isThai
                                              ? 'กำลังส่ง OTP...'
                                              : 'Sending OTP...',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      isThai ? 'สมัครเลย' : 'Register Now',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
