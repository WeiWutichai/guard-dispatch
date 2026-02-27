import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import 'booking_screen.dart';
import '../notification_screen.dart';

class ServiceSelectionScreen extends StatelessWidget {
  const ServiceSelectionScreen({super.key});

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
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildTitleSection(isThai),
                    const SizedBox(height: 24),
                    _buildServiceCard(
                      context: context,
                      isThai: isThai,
                      title: isThai
                          ? 'เจ้าหน้าที่รักษาความปลอดภัย'
                          : 'Security Guard',
                      subtitle: isThai
                          ? 'สำหรับรักษาความปลอดภัยบ้าน สำนักงาน หรือสถานที่ต่างๆ'
                          : 'For home, office, or various locations',
                      price: '600-1200',
                      rating: '4.8/5',
                      details: [
                        isThai ? 'ขั้นต่ำ 6 ชั่วโมง' : 'Min 6 hours',
                        isThai
                            ? 'บริการในกรุงเทพฯ และปริมณฑล'
                            : 'Bangkok & vicinity',
                        isThai ? 'คะแนนเฉลี่ย 4.8/5' : 'Avg Rating 4.8/5',
                      ],
                      icon: Icons.security_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    _buildServiceCard(
                      context: context,
                      isThai: isThai,
                      title: isThai ? 'บอดี้การ์ด' : 'Bodyguard',
                      subtitle: isThai
                          ? 'สำหรับคุ้มครองส่วนตัว ติดตาม หรือป้องกันภัยส่วนบุคคล'
                          : 'For personal protection or escort',
                      price: '800-1600',
                      rating: '4.9/5',
                      details: [
                        isThai ? 'ขั้นต่ำ 4 ชั่วโมง' : 'Min 4 hours',
                        isThai ? 'บริการทั่วประเทศ' : 'Nationwide service',
                        isThai ? 'คะแนนเฉลี่ย 4.9/5' : 'Avg Rating 4.9/5',
                      ],
                      icon: Icons.person_search_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 32),
                    _buildStatsSection(isThai),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isThai) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SecureGuard',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isThai ? 'บริการรักษาความปลอดภัย' : 'Security Services',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationScreen(isGuard: false),
                  ),
                ),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            isThai
                ? 'สวัสดี! เลือกบริการรักษาความปลอดภัยที่คุณต้องการ'
                : 'Hello! Choose the security service you need',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(bool isThai) {
    return Column(
      children: [
        Text(
          isThai ? 'เลือกบริการ' : 'Select Service',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isThai
              ? 'บริการรักษาความปลอดภัยที่คุณต้องการ'
              : 'The security service you require',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required bool isThai,
    required String title,
    required String subtitle,
    required String price,
    required String rating,
    required List<String> details,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    detail.contains('ชั่วโมง') || detail.contains('hours')
                        ? Icons.access_time_rounded
                        : detail.contains('กรุงเทพ') ||
                              detail.contains('Bangkok') ||
                              detail.contains('ทั่วประเทศ') ||
                              detail.contains('Nationwide')
                        ? Icons.location_on_outlined
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    detail,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '฿$price',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: '/${isThai ? 'วัน' : 'day'}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isThai ? 'เลือกบริการ' : 'Select',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isThai) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('500+', isThai ? 'เจ้าหน้าที่' : 'Guards'),
        _buildStatItem('24/7', isThai ? 'ให้บริการ' : 'Support'),
        _buildStatItem('5K+', isThai ? 'ลูกค้า' : 'Customers'),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
