import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometricPressed;
  final bool biometricEnabled;

  /// When false, all keys (digits, backspace, biometric) are non-interactive
  /// and dimmed to communicate a disabled state (e.g. PIN lockout window).
  final bool enabled;

  const PinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    this.onBiometricPressed,
    this.biometricEnabled = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final keypad = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        _buildBottomRow(),
      ],
    );
    if (enabled) return keypad;
    // Disabled: block input + dim visually.
    return IgnorePointer(
      ignoring: true,
      child: Opacity(opacity: 0.4, child: keypad),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitKey(d)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Fingerprint or empty
        if (biometricEnabled)
          _buildActionKey(
            child: Icon(
              Icons.fingerprint_rounded,
              size: 28,
              color: AppColors.primary,
            ),
            onTap: enabled ? onBiometricPressed : null,
          )
        else
          const SizedBox(width: 72, height: 72),
        // Zero
        _buildDigitKey('0'),
        // Backspace
        _buildActionKey(
          child: Icon(
            Icons.backspace_outlined,
            size: 24,
            color: AppColors.textSecondary,
          ),
          onTap: enabled ? onBackspace : null,
        ),
      ],
    );
  }

  Widget _buildDigitKey(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onDigitPressed(digit) : null,
        borderRadius: BorderRadius.circular(36),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              digit,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(child: child),
        ),
      ),
    );
  }
}
