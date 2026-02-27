import 'package:flutter/material.dart';
import '../theme/colors.dart';

class PinDotsIndicator extends StatelessWidget {
  final int enteredCount;
  final int totalDigits;
  final bool hasError;

  const PinDotsIndicator({
    super.key,
    required this.enteredCount,
    this.totalDigits = 6,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalDigits, (index) {
        final isFilled = index < enteredCount;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isFilled ? 18 : 16,
            height: isFilled ? 18 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasError
                  ? AppColors.danger
                  : isFilled
                      ? AppColors.primary
                      : Colors.transparent,
              border: Border.all(
                color: hasError
                    ? AppColors.danger
                    : isFilled
                        ? AppColors.primary
                        : AppColors.border,
                width: 2,
              ),
              boxShadow: isFilled && !hasError
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
