import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/language_service.dart';
import '../../services/receipt_pdf.dart';
import '../../theme/colors.dart';

/// Full invoice layout + PDF share button for a single completed receipt.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key, required this.receipt});

  final Map<String, dynamic> receipt;

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  bool _sharing = false;

  Future<void> _sharePdf(ReceiptsStrings s, bool isThai) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = context.read<AuthProvider>();
      final bytes = await ReceiptPdf.build(
        receipt: widget.receipt,
        customerName: auth.customerFullName ?? auth.fullName ?? '-',
        customerPhone: auth.phone,
        isThai: isThai,
      );
      final receiptNo =
          (widget.receipt['receipt_no'] ?? 'receipt').toString();
      await ReceiptPdf.share(bytes: bytes, receiptNo: receiptNo);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${s.pdfError}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = ReceiptsStrings(isThai: isThai);

    final r = widget.receipt;
    final receiptNo = (r['receipt_no'] ?? '-').toString();
    final paidAt = _date(r['paid_at']) ?? _date(r['completed_at']);
    final guard = (r['guard_name'] ?? '-').toString();
    final address = (r['service_address'] ?? '-').toString();
    final bookedHours = _num(r['booked_hours']);
    final actualHours = _num(r['actual_hours_worked']);
    final original = _num(r['original_amount']) ?? 0;
    final finalAmt = _num(r['final_amount']);
    final refund = _num(r['refund_amount']);
    final tip = _num(r['tip_amount']) ?? 0;
    final net = _num(r['net_amount']) ?? (finalAmt ?? original) + tip;
    final paymentMethod = (r['payment_method'] ?? '-').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          _header(context, s),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _meta(s, receiptNo, paidAt),
                const SizedBox(height: 16),
                _parties(s, guard, address),
                const SizedBox(height: 16),
                _amounts(
                  s: s,
                  isThai: isThai,
                  bookedHours: bookedHours,
                  actualHours: actualHours,
                  original: original,
                  finalAmt: finalAmt,
                  refund: refund,
                  tip: tip,
                  net: net,
                  paymentMethod: paymentMethod,
                ),
                if (refund != null && refund > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    s.refundNote,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _downloadButton(s, isThai),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ReceiptsStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'P-Guard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  s.detailTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _meta(ReceiptsStrings s, String receiptNo, DateTime? issued) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(s.receiptNo, receiptNo, highlight: true),
          const SizedBox(height: 8),
          _kv(
            s.issuedOn,
            issued == null
                ? '-'
                : DateFormat('dd MMM yyyy HH:mm').format(issued.toLocal()),
          ),
        ],
      ),
    );
  }

  Widget _parties(ReceiptsStrings s, String guard, String address) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(s.guard, guard),
          const SizedBox(height: 8),
          _kv(s.serviceAddress, address),
        ],
      ),
    );
  }

  Widget _amounts({
    required ReceiptsStrings s,
    required bool isThai,
    required num? bookedHours,
    required num? actualHours,
    required num original,
    required num? finalAmt,
    required num? refund,
    required num tip,
    required num net,
    required String paymentMethod,
  }) {
    String money(num v) => '฿${NumberFormat("#,##0.00").format(v)}';
    String hours(num? v) => v == null
        ? '-'
        : '${NumberFormat("#,##0.##").format(v)} ${s.hoursUnit}';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv(s.bookedHours, hours(bookedHours)),
          const SizedBox(height: 8),
          _kv(s.actualHours, hours(actualHours)),
          const Divider(height: 24),
          _money(s.originalAmount, money(original)),
          if (finalAmt != null && finalAmt != original) ...[
            const SizedBox(height: 8),
            _money(s.finalAmount, money(finalAmt)),
          ],
          if (refund != null && refund > 0) ...[
            const SizedBox(height: 8),
            _money(
              s.refundAmount,
              money(refund),
              color: const Color(0xFFFF9500),
            ),
          ],
          if (tip > 0) ...[
            const SizedBox(height: 8),
            _money(s.tipAmount, money(tip)),
          ],
          const Divider(height: 24),
          _money(
            s.netAmount,
            money(net),
            bold: true,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _kv(s.paymentMethod, paymentMethod),
        ],
      ),
    );
  }

  Widget _downloadButton(ReceiptsStrings s, bool isThai) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sharing ? null : () => _sharePdf(s, isThai),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _sharing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded),
        label: Text(
          _sharing ? s.sharingPdf : s.downloadPdf,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 15 : 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF1C1C1E),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _money(String label, String value,
      {bool bold = false, Color? color}) {
    final baseColor = color ?? const Color(0xFF1C1C1E);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? baseColor : const Color(0xFF6B6B70),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: baseColor,
          ),
        ),
      ],
    );
  }

  static num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static DateTime? _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
