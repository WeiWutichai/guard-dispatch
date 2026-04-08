import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import '../../theme/colors.dart';
import 'review_rating_screen.dart';

/// Shown right after the customer approves a guard's completion request.
/// Loads `GET /booking/assignments/{id}/cost-summary` and renders a
/// breakdown of: booked hours vs actual hours, original price vs prorated
/// final price, refund (if any), and an optional tip input.
///
/// Continue button → ReviewRatingScreen (existing star rating flow).
class JobCompletionSummaryScreen extends StatefulWidget {
  final String assignmentId;
  final String guardName;

  const JobCompletionSummaryScreen({
    super.key,
    required this.assignmentId,
    required this.guardName,
  });

  @override
  State<JobCompletionSummaryScreen> createState() =>
      _JobCompletionSummaryScreenState();
}

class _JobCompletionSummaryScreenState
    extends State<JobCompletionSummaryScreen> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _error;

  final TextEditingController _tipController = TextEditingController();
  bool _isSubmittingTip = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _tipController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final summary = await context
        .read<BookingProvider>()
        .fetchCostSummary(widget.assignmentId);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _summary = summary;
      if (summary == null) {
        _error = 'unable_to_load';
      }
    });
  }

  Future<void> _submitTip() async {
    final raw = _tipController.text.trim();
    if (raw.isEmpty) return;

    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid tip amount')),
      );
      return;
    }

    setState(() => _isSubmittingTip = true);

    final updated = await context
        .read<BookingProvider>()
        .addTip(widget.assignmentId, amount);

    if (!mounted) return;
    setState(() {
      _isSubmittingTip = false;
      if (updated != null) {
        _summary = updated;
        _tipController.clear();
      }
    });

    final isThai = LanguageProvider.of(context).isThai;
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai ? 'ส่งทิปสำเร็จ' : 'Tip sent successfully',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      // BookingProvider sets _error on failure but the screen has no
      // visible error surface for this — show a SnackBar so the user
      // knows the tip didn't go through and the button re-enabling
      // wasn't a silent success. (code-reviewer MEDIUM fix)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai
                ? 'ส่งทิปไม่สำเร็จ กรุณาลองใหม่'
                : 'Failed to send tip. Please try again.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _continueToReview() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewRatingScreen(
          assignmentId: widget.assignmentId,
          guardName: widget.guardName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = JobCompletionSummaryStrings(isThai: isThai);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError(strings)
                  : _buildContent(strings, isThai),
        ),
      ),
    );
  }

  Widget _buildError(JobCompletionSummaryStrings strings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(
            strings.loadError,
            style: GoogleFonts.inter(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSummary,
            child: Text(strings.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(JobCompletionSummaryStrings strings, bool isThai) {
    final s = _summary!;
    final bookedHours = (s['booked_hours'] as num?)?.toInt() ?? 0;
    final actualHoursWorked = _toDouble(s['actual_hours_worked']);
    final originalAmount = _toDouble(s['original_amount']) ?? 0;
    final finalAmount = _toDouble(s['final_amount']);
    final refundAmount = _toDouble(s['refund_amount']);
    final tipAmount = _toDouble(s['tip_amount']) ?? 0;
    final netAmount = _toDouble(s['net_amount']);
    final hourlyRate = _toDouble(s['hourly_rate']);

    final displayFinal = finalAmount ?? originalAmount;
    final isPartial = (actualHoursWorked ?? 0) < bookedHours.toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Header — completion icon + title
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Hours breakdown card
          _card(
            title: strings.hoursWorked,
            child: Column(
              children: [
                _row(
                  strings.bookedHours,
                  '$bookedHours ${strings.hoursUnit}',
                ),
                const SizedBox(height: 10),
                _row(
                  strings.actualHours,
                  actualHoursWorked != null
                      ? '${_fmtHours(actualHoursWorked)} ${strings.hoursUnit}'
                      : '—',
                  emphasized: true,
                  color: isPartial ? AppColors.warning : AppColors.primary,
                ),
                if (hourlyRate != null) ...[
                  const Divider(height: 24),
                  _row(
                    strings.hourlyRate,
                    '฿${_fmtMoney(hourlyRate)} / ${strings.hoursUnit}',
                    muted: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cost breakdown card
          _card(
            title: strings.costBreakdown,
            child: Column(
              children: [
                _row(
                  strings.originalPrice,
                  '฿${_fmtMoney(originalAmount)}',
                ),
                if (isPartial && finalAmount != null) ...[
                  const SizedBox(height: 10),
                  _row(
                    strings.proratedPrice,
                    '฿${_fmtMoney(finalAmount)}',
                    emphasized: true,
                    color: AppColors.primary,
                  ),
                ],
                if (refundAmount != null && refundAmount > 0) ...[
                  const SizedBox(height: 10),
                  _row(
                    strings.refundAmount,
                    '฿${_fmtMoney(refundAmount)}',
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      strings.refundNote,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (tipAmount > 0) ...[
                  const SizedBox(height: 10),
                  _row(
                    strings.tipPaid,
                    '฿${_fmtMoney(tipAmount)}',
                    color: AppColors.primary,
                  ),
                ],
                const Divider(height: 24),
                _row(
                  strings.totalToPay,
                  '฿${_fmtMoney(netAmount ?? displayFinal)}',
                  emphasized: true,
                  large: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tip input card
          _card(
            title: strings.tipTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.tipDescription,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tipController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          prefixText: '฿ ',
                          hintText: strings.tipHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmittingTip ? null : _submitTip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: _isSubmittingTip
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                strings.tipButton,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Continue → review rating
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _continueToReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                strings.continueButton,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---- helpers ----

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _fmtMoney(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _fmtHours(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool emphasized = false,
    bool large = false,
    bool muted = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: large ? 15 : 14,
            color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: large ? 22 : (emphasized ? 16 : 14),
            color: color ??
                (muted ? AppColors.textSecondary : AppColors.textPrimary),
            fontWeight:
                emphasized || large ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
