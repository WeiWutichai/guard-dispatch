import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../l10n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'otp_verification_screen.dart';
import 'registration_pending_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  final String? role;
  final Widget? destination;

  const PhoneInputScreen({super.key, this.role, this.destination});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isValid = false;
  bool _isLoading = false;
  // Synchronous guard against double-tap. setState is async (schedules
  // rebuild on next frame), so two taps within the same frame both see
  // _isLoading=false. This flag flips synchronously before any await.
  bool _otpInFlight = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text.replaceAll('-', '').replaceAll(' ', '');
      setState(() => _isValid = text.length == 10);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getRoleLabel(PhoneInputStrings strings) => widget.role == 'customer'
      ? strings.customerLabel
      : (widget.role == 'guard' ? strings.guardLabel : '');
  IconData? get _roleIcon => widget.role == 'customer'
      ? Icons.home_work_rounded
      : (widget.role == 'guard' ? Icons.badge_rounded : null);
  Color get _roleColor => AppColors.primary;

  Future<void> _onNext() async {
    if (!_isValid || _isLoading || _otpInFlight) return;
    _otpInFlight = true;

    // Pending users should see their status screen, not go through OTP again.
    final auth = context.read<AuthProvider>();
    if (auth.isPendingApproval) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => RegistrationPendingScreen(role: auth.role)),
        (route) => false,
      );
      return;
    }

    final phone = _controller.text.replaceAll('-', '').replaceAll(' ', '');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      // B3 — solve math captcha before the backend will issue an OTP.
      final captchaAnswer = await _askCaptcha(authProvider);
      if (captchaAnswer == null) {
        // User cancelled the challenge.
        return;
      }

      await authProvider.requestOtp(
        phone,
        challengeId: captchaAnswer.challengeId,
        answer: captchaAnswer.answer,
      );

      // Persist phone early so it's always available after this point
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verified_phone', phone);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            role: widget.role,
            phone: phone,
            destination: widget.destination,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?['error']?['message'] as String?;
      setState(() => _errorMessage = message ?? e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      _otpInFlight = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fetch a captcha from the backend and ask the user to solve it.
  /// Returns null if the user cancels; on submit returns the challenge id
  /// and the user's answer.
  Future<_CaptchaAnswer?> _askCaptcha(AuthProvider auth) async {
    final isThai = LanguageProvider.of(context).isThai;
    Map<String, dynamic> challenge;
    try {
      challenge = await auth.getOtpChallenge();
    } catch (_) {
      if (!mounted) return null;
      setState(() => _errorMessage =
          isThai ? 'โหลดรหัสยืนยันไม่สำเร็จ' : 'Failed to load verification');
      return null;
    }

    final challengeId = challenge['challenge_id'] as String? ?? '';
    final question = challenge['question'] as String? ?? '';
    if (challengeId.isEmpty || !mounted) return null;

    final answerCtrl = TextEditingController();
    final answer = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          isThai ? 'ยืนยันว่าไม่ใช่บอท' : 'Verify you are not a robot',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isThai ? 'กรุณาตอบคำถาม:' : 'Please solve:',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              question,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: isThai ? 'ใส่คำตอบ' : 'Your answer',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, answerCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isThai ? 'ยืนยัน' : 'Submit'),
          ),
        ],
      ),
    );
    if (answer == null || answer.isEmpty) return null;
    return _CaptchaAnswer(challengeId: challengeId, answer: answer);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = PhoneInputStrings(isThai: isThai);

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
                  const SizedBox(height: 36),
                  if (widget.role != null) ...[
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_roleIcon != null) ...[
                            Icon(_roleIcon, size: 16, color: _roleColor),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _getRoleLabel(strings),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Title
                  Text(
                    strings.registerTitle,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.registerSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Phone input card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _roleColor.withValues(alpha: 0.2),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.phoneLabel,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // Country code
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '\u{1F1F9}\u{1F1ED}',
                                        style: GoogleFonts.inter(fontSize: 18),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+66',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Phone field
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 1.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0XX XXX XXXX',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.border,
                                        letterSpacing: 1.5,
                                      ),
                                      counterText: '',
                                      filled: true,
                                      fillColor: AppColors.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: _roleColor,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 14),
                  // Info text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          strings.otpInfo,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
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
                  const Spacer(),
                  // Submit button
                  GestureDetector(
                    onTap: (_isValid && !_isLoading && !_otpInFlight) ? _onNext : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? _roleColor.withValues(alpha: 0.5)
                            : (_isValid ? _roleColor : AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isValid
                            ? [
                                BoxShadow(
                                  color: _roleColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            strings.requestOtp,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: (_isValid || _isLoading)
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: _isValid
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ],
                        ],
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
    );
  }
}

class _CaptchaAnswer {
  final String challengeId;
  final String answer;
  _CaptchaAnswer({required this.challengeId, required this.answer});
}
