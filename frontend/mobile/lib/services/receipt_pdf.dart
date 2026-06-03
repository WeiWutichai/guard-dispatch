import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/thai_baht_text.dart';

/// Seller / company details printed on the tax-invoice header + bank-transfer
/// note.
///
/// Name / tax ID / address are the registered company values. Phone / email /
/// bank are still PLACEHOLDERS — update them here (one-file edit) once provided.
class ReceiptCompany {
  static const String name = 'บริษัท ซีเคียว คอนเนคติ้ง จำกัด';
  static const String nameEn = 'Secure Connecting Co., Ltd.';
  static const String address =
      '52 ซอยรามคำแหง 164 ถนนรามคำแหง แขวงมีนบุรี เขตมีนบุรี กรุงเทพมหานคร 10510';
  static const String taxId = '0105569044883';
  static const String phone = '02-000-0000';
  static const String email = 'billing@pguard.example';
  static const String bankName = 'ธนาคารกสิกรไทย';
  static const String bankAccountName = 'บริษัท ซีเคียว คอนเนคติ้ง จำกัด';
  static const String bankAccountNo = '000-0-00000-0';
}

/// VAT rate applied on top of the booking subtotal. The system stores prices
/// VAT-exclusive (base_fee × hours × guards + tip), so the invoice ADDS 7%.
const double _kVatRate = 0.07;

/// In-memory PDF builder for the customer tax-invoice / receipt.
///
/// Kept client-side intentionally: every booking number comes from
/// `booking.payments` as served by `GET /booking/customer/receipts` — the
/// backend stays the source of truth. VAT + Thai-baht text are *presentation*
/// derived here. No fonts/images bundled to keep the binary small;
/// `PdfGoogleFonts` fetches NotoSansThai at first use and caches it.
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
    final invRef = _invoiceRef(receipt['request_id']);
    final issued = _parseDate(receipt['paid_at']) ??
        _parseDate(receipt['completed_at']);
    final guardName = (receipt['guard_name'] ?? '-').toString();
    final address = (receipt['service_address'] ?? '-').toString();
    final bookedHours = _asNum(receipt['booked_hours']);
    final actualHours = _asNum(receipt['actual_hours_worked']);
    final original = _asNum(receipt['original_amount']) ?? 0;
    final finalAmt = _asNum(receipt['final_amount']);
    final refund = _asNum(receipt['refund_amount']);
    final tip = _asNum(receipt['tip_amount']) ?? 0;
    final net =
        _asNum(receipt['net_amount']) ?? (finalAmt ?? original) + tip;
    final paymentMethod = (receipt['payment_method'] ?? '-').toString();

    // The amount actually charged for the guard service (prorated if partial).
    final serviceAmount = finalAmt ?? original;
    final qty = actualHours ?? bookedHours;

    // VAT-exclusive subtotal == backend net (service + tip); add 7% on top.
    final subtotal = net;
    final vat = _round2(subtotal * _kVatRate);
    final grandTotal = _round2(subtotal + vat);

    final items = <_LineItem>[
      _LineItem(
        description: isThai
            ? 'ค่าบริการรักษาความปลอดภัย${guardName == '-' ? '' : ' — $guardName'}'
            : 'Security guard service${guardName == '-' ? '' : ' — $guardName'}',
        qtyLabel: _hoursLabel(qty, isThai),
        unitPrice: (qty != null && qty > 0) ? serviceAmount / qty : null,
        amount: serviceAmount,
      ),
      if (tip > 0)
        _LineItem(
          description: isThai ? 'ค่าตอบแทนพิเศษ (ทิป)' : 'Gratuity (tip)',
          qtyLabel: '1',
          unitPrice: tip,
          amount: tip,
        ),
    ];

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(
              isThai: isThai,
              receiptNo: receiptNo,
              invRef: invRef,
              issued: issued,
            ),
            pw.SizedBox(height: 14),
            pw.Divider(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            _customerBlock(
              isThai: isThai,
              customerName: customerName,
              customerPhone: customerPhone,
              address: address,
            ),
            pw.SizedBox(height: 16),
            _itemsTable(isThai: isThai, items: items),
            pw.SizedBox(height: 12),
            _totals(
              isThai: isThai,
              subtotal: subtotal,
              vat: vat,
              grandTotal: grandTotal,
            ),
            pw.SizedBox(height: 6),
            _amountInWords(grandTotal, isThai),
            pw.SizedBox(height: 16),
            _paymentAndBank(isThai: isThai, paymentMethod: paymentMethod),
            if (refund != null && refund > 0) ...[
              pw.SizedBox(height: 8),
              _refundNote(refund, isThai),
            ],
            pw.SizedBox(height: 28),
            _signatures(isThai),
            pw.SizedBox(height: 14),
            pw.Center(
              child: pw.Text(
                isThai
                    ? 'ขอบคุณที่ใช้บริการ P-Guard'
                    : 'Thank you for using P-Guard',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
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

  static pw.Widget _header({
    required bool isThai,
    required String receiptNo,
    required String invRef,
    required DateTime? issued,
  }) {
    final companyName = isThai ? ReceiptCompany.name : ReceiptCompany.nameEn;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Seller / company block
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'P-Guard',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                companyName,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(ReceiptCompany.address,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(
                '${isThai ? 'เลขประจำตัวผู้เสียภาษี' : 'Tax ID'}: ${ReceiptCompany.taxId}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                '${isThai ? 'โทร' : 'Tel'}: ${ReceiptCompany.phone}   ${ReceiptCompany.email}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Document info block
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isThai ? 'ใบเสร็จรับเงิน / ใบกำกับภาษี' : 'Receipt / Tax Invoice',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(isThai ? '(ต้นฉบับ)' : '(Original)',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 6),
              _docInfoRow(isThai ? 'เลขที่' : 'No.', receiptNo),
              _docInfoRow(isThai ? 'อ้างอิง' : 'Ref.', invRef),
              _docInfoRow(
                isThai ? 'วันที่' : 'Date',
                issued == null ? '-' : _formatInvoiceDate(issued, isThai),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _docInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label: ',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _customerBlock({
    required bool isThai,
    required String customerName,
    required String? customerPhone,
    required String address,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(isThai ? 'ลูกค้า / ผู้ว่าจ้าง' : 'Bill to',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(
            customerPhone == null
                ? customerName
                : '$customerName  ($customerPhone)',
            style:
                pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${isThai ? 'สถานที่ปฏิบัติงาน' : 'Service location'}: $address',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable({
    required bool isThai,
    required List<_LineItem> items,
  }) {
    pw.Widget cell(String text,
        {bool header = false,
        pw.TextAlign align = pw.TextAlign.left,
        bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: header ? 10 : 10,
            fontWeight:
                (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? PdfColors.white : PdfColors.grey900,
          ),
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.green700),
        children: [
          cell('#', header: true, align: pw.TextAlign.center),
          cell(isThai ? 'รายการ' : 'Description', header: true),
          cell(isThai ? 'จำนวน' : 'Qty',
              header: true, align: pw.TextAlign.center),
          cell(isThai ? 'ราคา/หน่วย' : 'Unit price',
              header: true, align: pw.TextAlign.right),
          cell(isThai ? 'จำนวนเงิน' : 'Amount',
              header: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      rows.add(
        pw.TableRow(
          children: [
            cell('${i + 1}', align: pw.TextAlign.center),
            cell(it.description),
            cell(it.qtyLabel, align: pw.TextAlign.center),
            cell(it.unitPrice == null ? '-' : _money(it.unitPrice!),
                align: pw.TextAlign.right),
            cell(_money(it.amount), align: pw.TextAlign.right, bold: true),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(26),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.8),
      },
      children: rows,
    );
  }

  static pw.Widget _totals({
    required bool isThai,
    required num subtotal,
    required num vat,
    required num grandTotal,
  }) {
    pw.Widget line(String label, num value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.SizedBox(width: 16),
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                '฿${_money(value)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        line(isThai ? 'รวมเป็นเงิน' : 'Subtotal', subtotal),
        line(isThai ? 'ภาษีมูลค่าเพิ่ม 7%' : 'VAT 7%', vat),
        pw.SizedBox(height: 2),
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey500, width: 0.8)),
          ),
          child: line(
              isThai ? 'จำนวนเงินรวมทั้งสิ้น' : 'Grand total', grandTotal,
              bold: true),
        ),
      ],
    );
  }

  static pw.Widget _amountInWords(num grandTotal, bool isThai) {
    final words = isThai
        ? '(${bahtText(grandTotal)})'
        : '(${NumberFormat("#,##0.00").format(grandTotal)} THB)';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        words,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green900),
      ),
    );
  }

  static pw.Widget _paymentAndBank({
    required bool isThai,
    required String paymentMethod,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text('${isThai ? 'วิธีการชำระเงิน' : 'Payment method'}: ',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(paymentMethod,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          isThai
              ? 'ชำระผ่านบัญชี ${ReceiptCompany.bankName} เลขที่ ${ReceiptCompany.bankAccountNo} (${ReceiptCompany.bankAccountName})'
              : 'Bank: ${ReceiptCompany.bankName} A/C ${ReceiptCompany.bankAccountNo} (${ReceiptCompany.bankAccountName})',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _refundNote(num refund, bool isThai) {
    final txt = isThai
        ? 'หมายเหตุ: มียอดคืนเงิน ฿${_money(refund)} ซึ่งจะถูกดำเนินการโดยทีมแอดมินภายหลัง'
        : 'Note: a refund of ฿${_money(refund)} will be processed by admin separately.';
    return pw.Text(txt,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange700));
  }

  static pw.Widget _signatures(bool isThai) {
    pw.Widget block(String label) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 150,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom:
                      pw.BorderSide(color: PdfColors.grey600, width: 0.6)),
            ),
            child: pw.SizedBox(height: 28),
          ),
          pw.SizedBox(height: 4),
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        block(isThai ? 'ผู้รับเงิน' : 'Received by'),
        block(isThai ? 'ผู้มีอำนาจลงนาม' : 'Authorized signature'),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Value helpers
  // -------------------------------------------------------------------------

  static String _money(num v) => NumberFormat('#,##0.00').format(v);

  static num _round2(num v) => (v * 100).round() / 100;

  static String _hoursLabel(num? v, bool isThai) =>
      v == null ? '-' : '${NumberFormat('#,##0.##').format(v)} ${isThai ? 'ชม.' : 'hrs'}';

  static String _invoiceRef(dynamic requestId) {
    final s = requestId?.toString();
    if (s == null || s.isEmpty) return '-';
    final hex = s.replaceAll('-', '');
    final short = hex.length >= 8 ? hex.substring(0, 8) : hex;
    return 'INV-${short.toUpperCase()}';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  /// Thai invoices conventionally use the Buddhist Era year (+543).
  static String _formatInvoiceDate(DateTime d, bool isThai) {
    final local = d.toLocal();
    if (isThai) {
      final be = local.year + 543;
      return '${DateFormat('dd/MM').format(local)}/$be';
    }
    return DateFormat('dd/MM/yyyy').format(local);
  }
}

/// One row in the itemized invoice table.
class _LineItem {
  const _LineItem({
    required this.description,
    required this.qtyLabel,
    required this.unitPrice,
    required this.amount,
  });

  final String description;
  final String qtyLabel;
  final num? unitPrice;
  final num amount;
}
