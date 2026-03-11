import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String requestId;
  final double totalAmount;
  final double subtotal;
  final double baseFee;
  final double tip;
  final int bookedHours;
  final int guardCount;
  final String guardName;

  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.totalAmount,
    required this.subtotal,
    required this.baseFee,
    required this.tip,
    required this.bookedHours,
    required this.guardCount,
    required this.guardName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'promptpay';
  bool _isPaying = false;

  Future<void> _pay() async {
    final isThai = LanguageProvider.of(context).isThai;
    setState(() => _isPaying = true);
    try {
      await context.read<BookingProvider>().makePayment(
            requestId: widget.requestId,
            amount: widget.totalAmount,
            paymentMethod: _selectedMethod,
          );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            guardName: widget.guardName,
            totalAmount: widget.totalAmount,
            bookedHours: widget.bookedHours,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'เกิดข้อผิดพลาด: $e' : 'Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context, isThai),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isThai ? 'ชำระเงิน' : 'Payment',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryCard(isThai),
                  const SizedBox(height: 32),
                  _buildSecurityBanner(isThai),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    isThai ? 'เลือกวิธีการชำระเงิน' : 'Select Payment Method',
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentOption(
                    'promptpay',
                    Icons.qr_code_rounded,
                    'PromptPay',
                    isThai
                        ? 'สแกน QR Code เพื่อชำระเงิน'
                        : 'Scan QR for payment',
                  ),
                  _buildPaymentOption(
                    'credit_card',
                    Icons.credit_card_rounded,
                    isThai ? 'บัตรเครดิต' : 'Credit Card',
                    'Visa, MasterCard, JCB',
                  ),
                  _buildPaymentOption(
                    'debit_card',
                    Icons.account_balance_wallet_outlined,
                    isThai ? 'บัตรเดบิต' : 'Debit Card',
                    isThai ? 'บัตรเดบิตทุกธนาคาร' : 'All local banks',
                  ),
                  _buildPaymentOption(
                    'mobile_banking',
                    Icons.smartphone_rounded,
                    'Mobile Banking',
                    isThai ? 'แอปธนาคารบนมือถือ' : 'Mobile Banking App',
                  ),
                  const SizedBox(height: 48),
                  _buildPayButton(isThai),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isThai) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SecureGuard',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isThai ? 'บริการรักษาความปลอดภัย' : 'Security Services',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isThai) {
    final hoursLabel = isThai
        ? '${widget.bookedHours} ชม. × ${widget.guardCount} คน'
        : '${widget.bookedHours} hrs × ${widget.guardCount}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isThai ? 'สรุปการชำระเงิน' : 'Payment Summary',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            '${isThai ? "ค่าบริการ" : "Service"} ($hoursLabel)',
            '฿${widget.subtotal.toStringAsFixed(0)}',
          ),
          if (widget.baseFee > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              isThai ? 'ค่าดำเนินการ' : 'Service Fee',
              '฿${widget.baseFee.toStringAsFixed(0)}',
            ),
          ],
          if (widget.tip > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              isThai ? 'ทิปหรือโบนัสพิเศษ' : 'Tip/Bonus',
              '฿${widget.tip.toStringAsFixed(0)}',
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThai ? 'ยอดรวมทั้งสิ้น' : 'Grand Total',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '฿${widget.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityBanner(bool isThai) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThai ? 'ชำระเงินปลอดภัย' : 'Secure Payment',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isThai
                      ? 'จ่ายผ่าน Platform ปลอดภัยกว่า โดยเงินจะถูกจ่ายให้เจ้าหน้าที่เมื่องานเสร็จสิ้นเท่านั้น และขอคืนเงินได้หากงานไม่สำเร็จ'
                      : 'Pay via platform for security. Funds are released only upon completion. Refundable if service fails.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPaymentOption(
      String method, IconData icon, String title, String subtitle) {
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 24,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton(bool isThai) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isPaying ? null : _pay,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isPaying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                '${isThai ? "ชำระเงิน" : "Pay"} ฿${widget.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
