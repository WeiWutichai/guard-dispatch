import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import 'customer_tracking_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String guardName;
  final double totalAmount;
  final int bookedHours;
  final String requestId;
  final String guardId;
  final double customerLat;
  final double customerLng;

  const PaymentSuccessScreen({
    super.key,
    required this.guardName,
    required this.totalAmount,
    required this.bookedHours,
    required this.requestId,
    required this.guardId,
    required this.customerLat,
    required this.customerLng,
  });

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final trackingStrings = CustomerTrackingStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Success icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                isThai ? 'ชำระเงินสำเร็จ!' : 'Payment Successful!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isThai
                    ? 'เจ้าหน้าที่กำลังเดินทางมาหาคุณ'
                    : 'Your guard is on the way',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 40),

              // Booking summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.person_rounded,
                      isThai ? 'เจ้าหน้าที่' : 'Guard',
                      guardName,
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      Icons.access_time_rounded,
                      isThai ? 'ระยะเวลา' : 'Duration',
                      '$bookedHours ${isThai ? "ชั่วโมง" : "hours"}',
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(
                      Icons.payments_rounded,
                      isThai ? 'ยอดชำระ' : 'Amount Paid',
                      '฿${totalAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Track Guard button (primary)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerTrackingScreen(
                          requestId: requestId,
                          guardId: guardId,
                          guardName: guardName,
                          customerLat: customerLat,
                          customerLng: customerLng,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 22),
                  label: Text(
                    trackingStrings.trackGuard,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Back to home button (secondary)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isThai ? 'กลับหน้าหลัก' : 'Back to Home',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
