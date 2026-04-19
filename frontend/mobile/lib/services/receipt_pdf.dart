import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// In-memory PDF builder for the customer receipt.
///
/// Kept client-side intentionally: nothing about the receipt is computed on
/// the fly here — every number comes from `booking.payments` as served by
/// `GET /booking/customer/receipts`. The backend stays the source of truth;
/// this file is a pure rendering layer. No fonts or images bundled to keep
/// the mobile app binary small — `PdfGoogleFonts` fetches NotoSansThai at
/// first use and caches it.
class ReceiptPdf {
  /// Build the PDF document bytes from a `ReceiptItem`-shaped map (the same
  /// JSON object the list/detail screens already receive).
  static Future<Uint8List> build({
    required Map<String, dynamic> receipt,
    required String customerName,
    required String? customerPhone,
    required bool isThai,
  }) async {
    final doc = pw.Document();
    final regular = await PdfGoogleFonts.notoSansThaiRegular();
    final bold = await PdfGoogleFonts.notoSansThaiBold();
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final receiptNo = (receipt['receipt_no'] ?? '-').toString();
    final paidAt = _parseDate(receipt['paid_at']);
    final completedAt = _parseDate(receipt['completed_at']);
    final guardName = (receipt['guard_name'] ?? '-').toString();
    final address = (receipt['service_address'] ?? '-').toString();
    final bookedHours = _asNum(receipt['booked_hours']);
    final actualHours = _asNum(receipt['actual_hours_worked']);
    final original = _asNum(receipt['original_amount']) ?? 0;
    final finalAmt = _asNum(receipt['final_amount']);
    final refund = _asNum(receipt['refund_amount']);
    final tip = _asNum(receipt['tip_amount']) ?? 0;
    final net = _asNum(receipt['net_amount']) ?? (finalAmt ?? original) + tip;
    final paymentMethod = (receipt['payment_method'] ?? '-').toString();

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(receiptNo, paidAt ?? completedAt, isThai),
            pw.SizedBox(height: 24),
            _partiesTable(
              isThai: isThai,
              customerName: customerName,
              customerPhone: customerPhone,
              guardName: guardName,
              address: address,
            ),
            pw.SizedBox(height: 24),
            _lineItems(
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
            pw.Spacer(),
            _footer(isThai),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Present the native share sheet so the user can save / email / AirDrop
  /// the generated PDF.
  static Future<void> share({
    required Uint8List bytes,
    required String receiptNo,
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: '$receiptNo.pdf');
  }

  // -------------------------------------------------------------------------
  // Layout helpers
  // -------------------------------------------------------------------------

  static pw.Widget _header(String receiptNo, DateTime? issued, bool isThai) {
    final issuedLabel = isThai ? 'ออกให้เมื่อ' : 'Issued on';
    final numberLabel = isThai ? 'เลขที่' : 'No.';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'P-Guard',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.Text(
              isThai ? 'ใบเสร็จรับเงิน' : 'Payment Receipt',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('$numberLabel $receiptNo',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (issued != null)
              pw.Text('$issuedLabel: ${_formatDate(issued)}',
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _partiesTable({
    required bool isThai,
    required String customerName,
    required String? customerPhone,
    required String guardName,
    required String address,
  }) {
    final customer = isThai ? 'ลูกค้า' : 'Customer';
    final guard = isThai ? 'เจ้าหน้าที่' : 'Guard';
    final loc = isThai ? 'สถานที่ปฏิบัติงาน' : 'Service location';
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        _row(customer,
            customerPhone == null ? customerName : '$customerName ($customerPhone)'),
        _row(guard, guardName),
        _row(loc, address),
      ],
    );
  }

  static pw.TableRow _row(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.Widget _lineItems({
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
    String fmtMoney(num v) => '฿${NumberFormat("#,##0.00").format(v)}';
    String fmtHours(num? v) =>
        v == null ? '-' : '${NumberFormat("#,##0.##").format(v)} ${isThai ? 'ชม.' : 'hrs'}';

    pw.Widget money(String label, num? value, {bool bold = false, PdfColor? color}) {
      final style = pw.TextStyle(
        fontSize: bold ? 13 : 11,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: style),
            pw.Text(value == null ? '-' : fmtMoney(value), style: style),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(isThai ? 'ชั่วโมงที่จอง' : 'Booked hours',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.Text(fmtHours(bookedHours),
                  style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(isThai ? 'ชั่วโมงที่ปฏิบัติจริง' : 'Actual hours',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.Text(fmtHours(actualHours),
                  style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          money(isThai ? 'ราคาเดิม' : 'Original price', original),
          if (finalAmt != null && finalAmt != original)
            money(isThai ? 'ราคาสุดท้าย (prorated)' : 'Final price (prorated)', finalAmt),
          if (refund != null && refund > 0)
            money(isThai ? 'ยอดคืน' : 'Refund', refund, color: PdfColors.orange700),
          if (tip > 0) money(isThai ? 'ทิป' : 'Tip', tip),
          pw.SizedBox(height: 8),
          pw.Divider(height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          money(isThai ? 'รวมสุทธิ' : 'Net total', net, bold: true),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(isThai ? 'วิธีการชำระเงิน' : 'Payment method',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.Text(paymentMethod,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(bool isThai) {
    final thanks = isThai
        ? 'ขอบคุณที่ใช้บริการ P-Guard'
        : 'Thank you for using P-Guard';
    final refundNote = isThai
        ? 'ยอดคืนเงินจะถูกดำเนินการโดยทีมแอดมินภายหลัง'
        : 'Refunds are processed by admin separately.';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(refundNote,
            style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600)),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Text(thanks,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Parsing helpers
  // -------------------------------------------------------------------------

  static DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static String _formatDate(DateTime d) =>
      DateFormat('yyyy-MM-dd HH:mm').format(d.toLocal());
}
