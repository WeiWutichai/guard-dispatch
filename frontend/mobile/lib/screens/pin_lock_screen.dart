import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/pin_storage_service.dart';
import '../widgets/pin_dots_indicator.dart';
import '../widgets/pin_keypad.dart';
import 'phone_input_screen.dart';
import 'role_selection_screen.dart';

import '../services/language_service.dart';
import '../l10n/app_strings.dart';

class PinLockScreen extends StatefulWidget {
  final PinStorageService pinService;

  const PinLockScreen({super.key, required this.pinService});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  bool _hasError = false;

  // Phase 3: rate-limiting / lockout state.
  PinLockedOut? _lockoutState;
  Timer? _countdownTimer;
  Duration _remainingLockout = Duration.zero;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    final lock = await widget.pinService.getCurrentLockoutState();
    if (!mounted) return;
    if (lock != null) {
      setState(() => _lockoutState = lock);
      _startCountdown(lock.remaining);
      // Skip biometric auto-trigger — UI is locked.
      return;
    }
    // Existing biometric auto-trigger logic. context is not safe in initState
    // path, so derive language from platformDispatcher (matches prior behavior).
    if (widget.pinService.isBiometricEnabled) {
      final isThai =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'th';
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _lockoutState == null) {
          _onBiometricTap(PinLockStrings(isThai: isThai));
        }
      });
    }
  }

  void _startCountdown(Duration initial) {
    _countdownTimer?.cancel();
    _remainingLockout = initial;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingLockout -= const Duration(seconds: 1);
        if (_remainingLockout <= Duration.zero) {
          timer.cancel();
          _lockoutState = null;
          _remainingLockout = Duration.zero;
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _onDigit(String digit) {
    if (_lockoutState != null || _isValidating) return;
    if (_enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
      _hasError = false;
    });
    if (_enteredPin.length == 6) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _validatePin();
      });
    }
  }

  void _onBackspace() {
    if (_lockoutState != null || _isValidating) return;
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _validatePin() async {
    if (_isValidating) return;
    setState(() => _isValidating = true);

    final result = await widget.pinService.validatePin(_enteredPin);
    if (!mounted) return;

    // Reset entered PIN regardless of outcome.
    setState(() {
      _enteredPin = '';
      _isValidating = false;
    });

    switch (result) {
      case PinValid():
        _navigateToApp();
      case PinInvalid():
        setState(() => _hasError = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _hasError = false);
        });
      case PinLockedOut():
        setState(() {
          _lockoutState = result;
          _hasError = false;
        });
        _startCountdown(result.remaining);
      case PinWiped():
        await _handleWipe();
    }
  }

  Future<void> _handleWipe() async {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = PinLockStrings(isThai: isThai);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          strings.wipedDialogTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          strings.wipedDialogBody,
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              strings.wipedDialogConfirm,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;

    // Tear down auth state (server-side revoke + clear tokens + clear pending).
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
      (route) => false,
    );
  }

  Future<void> _onBiometricTap(PinLockStrings strings) async {
    if (_lockoutState != null) return;
    final localAuth = LocalAuthentication();

    // Check if biometrics are available on this device
    final canCheck = await localAuth.canCheckBiometrics;
    final isSupported = await localAuth.isDeviceSupported();
    if (!canCheck || !isSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.biometricNotAvailable),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final authenticated = await localAuth.authenticate(
        localizedReason: strings.biometricReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!mounted) return;
      if (authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(strings.biometricSuccess, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _navigateToApp();
        });
      }
    } catch (_) {
      // Biometric auth failed or was cancelled — user can still use PIN
    }
  }

  Future<void> _navigateToApp() async {
    final auth = context.read<AuthProvider>();
    final phone = auth.phone ?? await AuthService.getStoredPhone();
    if (!mounted) return;

    // For authenticated users: await fetchProfile so customerApprovalStatus
    // is available before RoleSelectionScreen checks it.
    // Always verify session is still valid on server before navigating
    if (auth.status == AuthStatus.authenticated) {
      await auth.fetchProfile().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      if (!mounted) return;
    }

    // Always go to RoleSelectionScreen — it handles all routing:
    // authenticated → dashboard, pending no role → registration,
    // pending with role → pending screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => RoleSelectionScreen(phone: phone)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = PinLockStrings(isThai: isThai);

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
                  const SizedBox(height: 48),
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 28),
                  // Title — swap to lockout title while locked.
                  Text(
                    _lockoutState != null
                        ? strings.lockedOutTitle
                        : strings.enterPin,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _lockoutState != null
                          ? AppColors.warning
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lockoutState != null
                        ? strings.lockedOutSubtitle(
                            _formatRemaining(_remainingLockout),
                          )
                        : strings.enterPinSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // PIN dots
                  PinDotsIndicator(
                    enteredCount: _enteredPin.length,
                    hasError: _hasError,
                  ),
                  const SizedBox(height: 12),
                  // Lockout banner OR error text
                  if (_lockoutState != null)
                    _buildLockoutBanner(strings)
                  else
                    AnimatedOpacity(
                      opacity: _hasError ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        strings.pinIncorrect,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Keypad
                  PinKeypad(
                    onDigitPressed: _onDigit,
                    onBackspace: _onBackspace,
                    biometricEnabled:
                        widget.pinService.isBiometricEnabled &&
                        _lockoutState == null,
                    onBiometricPressed: () => _onBiometricTap(strings),
                    enabled: _lockoutState == null && !_isValidating,
                  ),
                  const SizedBox(height: 20),
                  // Footer
                  Text(
                    'P-GUARD MOBILE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockoutBanner(PinLockStrings strings) {
    final remaining =
        PinStorageService.wipeThreshold - _lockoutState!.totalAttempts;
    final showWarning = _lockoutState!.totalAttempts >= 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                strings.lockedOutSubtitle(_formatRemaining(_remainingLockout)),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          if (showWarning) ...[
            const SizedBox(height: 6),
            Text(
              strings.attemptsRemaining(remaining),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.warning,
              ),
            ),
          ],
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
}
