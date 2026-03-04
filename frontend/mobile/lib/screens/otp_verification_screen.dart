import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'pin_setup_screen.dart';
import '../services/pin_storage_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String? role;
  final String phone;
  final Widget? destination;

  /// When true, pop with the phone_verified_token instead of navigating
  /// to PinSetupScreen. Used by RegistrationFormScreen to re-verify.
  final bool returnTokenOnly;

  const OtpVerificationScreen({
    super.key,
    this.role,
    required this.phone,
    this.destination,
    this.returnTokenOnly = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _hasError = false;
  bool _isVerifying = false;
  String? _errorMessage;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  Color get _roleColor => AppColors.primary;

  String get _maskedPhone {
    if (widget.phone.length >= 4) {
      return '${widget.phone.substring(0, 3)}-XXX-${widget.phone.substring(widget.phone.length - 4)}';
    }
    return widget.phone;
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_enteredOtp.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final phoneVerifiedToken = await authProvider.verifyOtp(
        widget.phone,
        _enteredOtp,
      );

      // Persist phone + token so RoleSelectionScreen can retrieve them
      // even if not passed directly (e.g. arriving from PinLockScreen).
      await AuthService.storePhoneVerifiedData(widget.phone, phoneVerifiedToken);

      if (!mounted) return;

      if (widget.returnTokenOnly) {
        // Pop back with the token (used by RegistrationFormScreen)
        Navigator.pop(context, phoneVerifiedToken);
        return;
      }

      // Navigate directly to PIN setup — name/email collected later in the
      // registration form. registerWithOtp is called at the end of that flow.
      final pinService = context.read<PinStorageService>();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            pinService: pinService,
            phone: widget.phone,
            phoneVerifiedToken: phoneVerifiedToken,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?['error']?['message'] as String?;
      setState(() {
        _hasError = true;
        _isVerifying = false;
        _errorMessage = message;
      });
      _clearFieldsAfterDelay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isVerifying = false;
        _errorMessage = e.toString();
      });
      _clearFieldsAfterDelay();
    }
  }

  void _clearFieldsAfterDelay() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        setState(() => _hasError = false);
      }
    });
  }

  Future<void> _resendOtp() async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.requestOtp(widget.phone);
      _startResendTimer();
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?['error']?['message'] as String?;
      setState(() => _errorMessage = message ?? e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = OtpStrings(isThai: isThai);

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Back button
                  GestureDetector(
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
                  const SizedBox(height: 28),
                  // Lock icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.sms_rounded, color: _roleColor, size: 28),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    strings.verifyTitle,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(text: strings.codeSentTo),
                        TextSpan(
                          text: _maskedPhone,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  // OTP input boxes
                  _buildOtpFields(),
                  const SizedBox(height: 14),
                  // Error message
                  AnimatedOpacity(
                    opacity: (_hasError || _errorMessage != null) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: Text(
                        _errorMessage ?? strings.otpIncorrect,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Verifying indicator
                  if (_isVerifying)
                    Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _roleColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Resend
                  Center(
                    child: _resendSeconds > 0
                        ? Text(
                            '${strings.resendIn} $_resendSeconds ${strings.seconds}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : GestureDetector(
                            onTap: _resendOtp,
                            child: Text(
                              strings.resendOtp,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _roleColor,
                              ),
                            ),
                          ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = _controllers[index].text.isNotEmpty;
        return Container(
          width: 48,
          height: 56,
          margin: EdgeInsets.only(
            left: index == 0 ? 0 : (index == 3 ? 12 : 6),
            right: index == 2 ? 6 : 0,
          ),
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) => _onKeyDown(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => _onOtpChanged(index, value),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _hasError ? AppColors.danger : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: _hasError
                    ? AppColors.danger.withValues(alpha: 0.05)
                    : isFilled
                    ? _roleColor.withValues(alpha: 0.05)
                    : AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _hasError
                        ? AppColors.danger
                        : isFilled
                        ? _roleColor
                        : AppColors.border,
                    width: isFilled ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _roleColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        );
      }),
    );
  }
}
