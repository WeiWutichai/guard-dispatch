import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

class ReviewRatingScreen extends StatefulWidget {
  final String assignmentId;
  final String guardName;
  /// When true (default), success/skip pops to first route (home).
  /// When false, just pops this screen (returns to previous screen).
  final bool popToHome;

  const ReviewRatingScreen({
    super.key,
    required this.assignmentId,
    required this.guardName,
    this.popToHome = true,
  });

  @override
  State<ReviewRatingScreen> createState() => _ReviewRatingScreenState();
}

class _ReviewRatingScreenState extends State<ReviewRatingScreen> {
  double _overallRating = 0;
  double _punctuality = 0;
  double _professionalism = 0;
  double _communication = 0;
  double _appearance = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_overallRating == 0) return;

    setState(() => _isSubmitting = true);

    try {
      await context.read<BookingProvider>().submitReview(
        widget.assignmentId,
        overallRating: _overallRating,
        punctuality: _punctuality > 0 ? _punctuality : null,
        professionalism: _professionalism > 0 ? _professionalism : null,
        communication: _communication > 0 ? _communication : null,
        appearance: _appearance > 0 ? _appearance : null,
        reviewText: _reviewController.text.trim().isNotEmpty
            ? _reviewController.text.trim()
            : null,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showSuccessDialog() {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = ReviewRatingStrings(isThai: isThai);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              strings.thankYou,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.reviewSubmittedMsg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (widget.popToHome) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  strings.reviewSubmitted,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _skip() {
    if (widget.popToHome) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = ReviewRatingStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Green header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.title,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        strings.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guard name
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              size: 36, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.guardName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          strings.guard,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Overall rating (required)
                  _buildRatingSection(
                    strings.overallRating,
                    _overallRating,
                    (val) => setState(() => _overallRating = val),
                    isLarge: true,
                    isRequired: true,
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Container(
                    height: 1,
                    color: AppColors.border,
                  ),

                  const SizedBox(height: 20),

                  // Category ratings (optional)
                  _buildRatingSection(
                    strings.punctuality,
                    _punctuality,
                    (val) => setState(() => _punctuality = val),
                  ),
                  const SizedBox(height: 14),
                  _buildRatingSection(
                    strings.professionalism,
                    _professionalism,
                    (val) => setState(() => _professionalism = val),
                  ),
                  const SizedBox(height: 14),
                  _buildRatingSection(
                    strings.communication,
                    _communication,
                    (val) => setState(() => _communication = val),
                  ),
                  const SizedBox(height: 14),
                  _buildRatingSection(
                    strings.appearance,
                    _appearance,
                    (val) => setState(() => _appearance = val),
                  ),

                  const SizedBox(height: 24),

                  // Review text
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: strings.reviewPlaceholder,
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.disabled,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          _overallRating > 0 && !_isSubmitting
                              ? _submitReview
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.disabled.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              strings.submitReview,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Skip button
                  Center(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _skip,
                      child: Text(
                        strings.skip,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
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

  Widget _buildRatingSection(
    String label,
    double currentRating,
    ValueChanged<double> onChanged, {
    bool isLarge = false,
    bool isRequired = false,
  }) {
    final starSize = isLarge ? 40.0 : 28.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isLarge ? 16 : 14,
                fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: isLarge
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: List.generate(5, (index) {
            final starValue = (index + 1).toDouble();
            return GestureDetector(
              onTap: () => onChanged(starValue),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isLarge ? 4.0 : 2.0),
                child: Icon(
                  starValue <= currentRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: starSize,
                  color: starValue <= currentRating
                      ? Colors.amber
                      : AppColors.disabled,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
