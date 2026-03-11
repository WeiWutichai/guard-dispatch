import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/pin_storage_service.dart';
import '../widgets/pin_dots_indicator.dart';
import '../widgets/pin_keypad.dart';
import 'role_selection_screen.dart';
import 'pin_login_screen.dart';

import '../services/language_service.dart';
import '../l10n/app_strings.dart';

enum _PinSetupStep { create, confirm, biometricOpt }

class PinSetupScreen extends StatefulWidget {
  final PinStorageService pinService;
  /// If set, PIN setup is part of the registration flow.
  /// After PIN + biometric → go to RoleSelectionScreen.
  final String? phone;
  /// phone_verified_token from OTP step — passed through to RoleSelectionScreen
  /// → GuardRegistrationScreen which calls registerWithOtp() at the end.
  final String? phoneVerifiedToken;

  const PinSetupScreen({
    super.key,
    required this.pinService,
    this.phone,
    this.phoneVerifiedToken,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  _PinSetupStep _step = _PinSetupStep.create;
  String _enteredPin = '';
  String _firstPin = '';
  bool _hasError = false;

  void _onDigit(String digit) {
    if (_enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
      _hasError = false;
    });
    if (_enteredPin.length == 6) {
      Future.delayed(const Duration(milliseconds: 200), _onPinComplete);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  void _onPinComplete() {
    if (_step == _PinSetupStep.create) {
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _step = _PinSetupStep.confirm;
      });
    } else if (_step == _PinSetupStep.confirm) {
      if (_enteredPin == _firstPin) {
        setState(() {
          _step = _PinSetupStep.biometricOpt;
          _enteredPin = '';
        });
      } else {
        setState(() => _hasError = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _enteredPin = '';
              _hasError = false;
            });
          }
        });
      }
    }
  }

  Future<void> _finishSetup({required bool enableBiometric}) async {
    await widget.pinService.savePin(_firstPin);
    await widget.pinService.setBiometricEnabled(enableBiometric);
    if (!mounted) return;

    // Step 1 of 3-step registration: register user with no role right after PIN.
    // This creates the user in backend (approval_status=pending, role=null).
    // Admin sees the applicant immediately with "ยังไม่ได้ระบุ" (no type).
    // Send the PIN's SHA-256 hash as the password so the user can login after approval.
    if (widget.phoneVerifiedToken != null) {
      try {
        final authProvider = context.read<AuthProvider>();
        final pinHash = PinStorageService.hashPin(_firstPin);
        await authProvider.registerWithOtp(
          phoneVerifiedToken: widget.phoneVerifiedToken!,
          password: pinHash,
        );
        // Store phone for post-approval login (loginWithPhone needs it).
        if (widget.phone != null) {
          await AuthService.storePhone(widget.phone!);
        }
      } on DioException catch (e) {
        if (!mounted) return;
        final message = e.response?.data?['error']?['message'] as String?;

        // Account already approved → try auto-login with the PIN just entered
        if (message != null &&
            message.contains('log in instead') &&
            widget.phone != null) {
          final pinHash = PinStorageService.hashPin(_firstPin);
          try {
            await context
                .read<AuthProvider>()
                .loginWithPhone(widget.phone!, pinHash);
            if (!mounted) return;
            // Auto-login succeeded → dashboard via RoleSelection
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => RoleSelectionScreen(phone: widget.phone),
              ),
              (route) => false,
            );
            return;
          } catch (_) {
            // PIN doesn't match backend → let user enter original PIN
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => PinLoginScreen(phone: widget.phone!),
              ),
              (route) => false,
            );
            return;
          }
        }

        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          return; // Don't navigate on unexpected errors
        }
      }
    }

    if (!mounted) return;

    // phoneVerifiedToken was consumed — only pass phone going forward.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(phone: widget.phone),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = PinSetupStrings(isThai: isThai);

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
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildIcon(),
                  const SizedBox(height: 20),
                  _buildStepHeader(strings),
                  const SizedBox(height: 36),
                  if (_step != _PinSetupStep.biometricOpt) ...[
                    PinDotsIndicator(
                      enteredCount: _enteredPin.length,
                      hasError: _hasError,
                    ),
                    const SizedBox(height: 12),
                    _buildErrorText(strings),
                    const Spacer(),
                    PinKeypad(
                      onDigitPressed: _onDigit,
                      onBackspace: _onBackspace,
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    _buildBiometricOption(strings),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    final IconData icon = _step == _PinSetupStep.biometricOpt
        ? Icons.fingerprint_rounded
        : Icons.lock_outline_rounded;

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
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(PinSetupStrings strings) {
    String title;
    String subtitle;

    switch (_step) {
      case _PinSetupStep.create:
        title = strings.createTitle;
        subtitle = strings.createSubtitle;
      case _PinSetupStep.confirm:
        title = strings.confirmTitle;
        subtitle = strings.confirmSubtitle;
      case _PinSetupStep.biometricOpt:
        title = strings.biometricTitle;
        subtitle = strings.biometricSubtitle;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(_step),
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorText(PinSetupStrings strings) {
    return AnimatedOpacity(
      opacity: _hasError ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        strings.pinMismatch,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.danger,
        ),
      ),
    );
  }

  Widget _buildBiometricOption(PinSetupStrings strings) {
    return Expanded(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Fingerprint icon in glassmorphism card
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 36,
              horizontal: 32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 52,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.touchSensor,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
          ),
          const Spacer(),
          // Buttons
          Row(
              children: [
                // Skip
                Expanded(
                  child: GestureDetector(
                    onTap: () => _finishSetup(enableBiometric: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          strings.skip,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Enable
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => _finishSetup(enableBiometric: true),
                    child: Container(
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
                      child: Center(
                        child: Text(
                          strings.enable,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
