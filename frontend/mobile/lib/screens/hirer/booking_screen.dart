import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../notification_screen.dart';
import 'guard_selection_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _selectedDuration = 'กำหนดเอง';
  int _guardCount = 1;
  final List<String> _durations = ['12 ชั่วโมง', '8 ชั่วโมง', 'กำหนดเอง'];
  final List<String> _equipment = [
    'ไฟฉาย',
    'กุญแจมือถือ',
    'กระบอง, กระบองไฟจราจร',
    'ชุดยูนิฟอร์ม รปภ.',
    'ชุดเครื่องแบบ รปภ.+เสื้อโปโล',
    'อื่นๆ',
  ];
  final Set<String> _selectedEquipment = {'ไฟฉาย', 'กุญแจมือถือ'};

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(isThai),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    isThai
                        ? 'จองเจ้าหน้าที่รักษาความปลอดภัย'
                        : 'Book Security Guard',
                    isThai ? 'กรอกข้อมูลการจอง' : 'Fill booking info',
                  ),
                  const SizedBox(height: 24),
                  _buildLabel(
                    isThai ? 'เวลาให้บริการ' : 'Service Time',
                    Icons.access_time_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildDurationSelection(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimePicker(
                          isThai ? 'วันที่เริ่ม' : 'Start Date',
                          'dd/mm/yyyy',
                          Icons.calendar_today_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateTimePicker(
                          isThai ? 'เวลาเริ่ม' : 'Start Time',
                          '--:--',
                          Icons.access_time_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimePicker(
                          isThai ? 'วันที่สิ้นสุด' : 'End Date',
                          'dd/mm/yyyy',
                          Icons.calendar_today_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateTimePicker(
                          isThai ? 'เวลาสิ้นสุด' : 'End Time',
                          '--:--',
                          Icons.access_time_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThai
                              ? 'ระยะเวลาบริการ: 6 ชั่วโมง'
                              : 'Duration: 6 Hours',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isThai
                              ? 'อัตรา ฿100/ชม. • ค่าบริการโดยประมาณ ฿600'
                              : 'Rate ฿100/hr • Est. Total ฿600',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel(
                    isThai ? 'สถานที่' : 'Location',
                    Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationInput(isThai),
                  const SizedBox(height: 12),
                  _buildLocationButtons(isThai),
                  const SizedBox(height: 32),
                  _buildLabel(
                    isThai ? 'รายละเอียดงาน' : 'Job Details',
                    Icons.description_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildTextArea(
                    isThai
                        ? 'อธิบายรายละเอียดงานหรือความต้องการพิเศษ'
                        : 'Describe job details or special requirements',
                  ),
                  const SizedBox(height: 32),
                  _buildLabel(
                    isThai ? 'อุปกรณ์รักษาความปลอดภัย' : 'Security Equipment',
                    Icons.shield_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildEquipmentList(),
                  const SizedBox(height: 32),
                  _buildLabel(
                    isThai ? 'บริการเพิ่มเติม' : 'Additional Services',
                    Icons.add_box_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildAdditionalServices(isThai),
                  const SizedBox(height: 32),
                  _buildPriceSummary(isThai),
                  const SizedBox(height: 32),
                  _buildSearchButton(isThai),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isThai) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
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
          const Icon(Icons.person_outline_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
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
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelection() {
    return Row(
      children: _durations.map((d) {
        final isSelected = _selectedDuration == d;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedDuration = d),
            child: Container(
              margin: EdgeInsets.only(right: d == _durations.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimePicker(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInput(bool isThai) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: isThai
              ? 'ใส่ที่อยู่หรือใช้ GPS ปัจจุบัน'
              : 'Enter address or use current GPS',
          border: InputBorder.none,
          hintStyle: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButtons(bool isThai) {
    return Row(
      children: [
        _buildSmallButton(
          Icons.map_outlined,
          isThai ? 'ปักหมุดจากแผนที่' : 'Pin on map',
        ),
        const SizedBox(width: 8),
        _buildSmallButton(
          Icons.my_location_rounded,
          isThai ? 'ใช้ตำแหน่งปัจจุบัน' : 'Use Current Location',
        ),
      ],
    );
  }

  Widget _buildSmallButton(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextArea(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        maxLines: 4,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentList() {
    return Column(
      children: _equipment.map((e) {
        final isSelected = _selectedEquipment.contains(e);
        return GestureDetector(
          onTap: () => setState(() {
            if (isSelected)
              _selectedEquipment.remove(e);
            else
              _selectedEquipment.add(e);
          }),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  e,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdditionalServices(bool isThai) {
    final services = [
      {'label': isThai ? 'มีสัตว์เลี้ยง' : 'Has Pets'},
      {'label': isThai ? 'ดูแลต้นไม้' : 'Water Plants'},
      {'label': isThai ? 'ปิด/เปิดน้ำ-ไฟฟ้า' : 'Utility Check'},
    ];
    return Column(
      children: services
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_box_outline_blank_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s['label']!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPriceSummary(bool isThai) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            isThai ? 'ค่าบริการแนะนำ (6 ชั่วโมง)' : 'Service Est. (6 Hours)',
            '฿600',
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThai ? 'จำนวนเจ้าหน้าที่' : 'Number of guards',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _buildStepButton(
                      Icons.remove,
                      () => setState(() {
                        if (_guardCount > 1) _guardCount--;
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_guardCount',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStepButton(
                      Icons.add,
                      () => setState(() => _guardCount++),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThai ? 'ทิปหรือโบนัสพิเศษ (ต่อคน)' : 'Tip/Bonus (per person)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('0', style: GoogleFonts.inter(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isThai ? 'บาท' : 'THB',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThai ? 'รวมทั้งหมด' : 'Grand Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '฿${600 * _guardCount}',
                style: GoogleFonts.inter(
                  fontSize: 20,
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

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
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
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
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

  Widget _buildSearchButton(bool isThai) {
    return ElevatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GuardSelectionScreen()),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        isThai ? 'ค้นหาเจ้าหน้าที่' : 'Find Guard',
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
