import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import '../notification_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  String _selectedUrgency = 'medium';
  int _guardCount = 1;
  bool _isSubmitting = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _addressController.text = auth.customerAddress ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'ได้ตำแหน่ง GPS แล้ว' : 'GPS location acquired'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitBooking() async {
    final isThai = LanguageProvider.of(context).isThai;
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'กรุณากรอกที่อยู่' : 'Please enter address'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Use GPS coords or default to Bangkok center
    final lat = _lat ?? 13.7563;
    final lng = _lng ?? 100.5018;

    final priceText = _priceController.text.trim();
    final offeredPrice = priceText.isNotEmpty ? double.tryParse(priceText) : null;

    // Combine special instructions with guard count
    final specialParts = <String>[];
    if (_guardCount > 1) {
      specialParts.add(isThai
          ? 'จำนวนเจ้าหน้าที่: $_guardCount คน'
          : 'Guards needed: $_guardCount');
    }
    final extraInstructions = _specialInstructionsController.text.trim();
    if (extraInstructions.isNotEmpty) specialParts.add(extraInstructions);
    final specialInstructions =
        specialParts.isNotEmpty ? specialParts.join('\n') : null;

    setState(() => _isSubmitting = true);
    try {
      await context.read<BookingProvider>().createRequest(
            locationLat: lat,
            locationLng: lng,
            address: address,
            description: _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
            offeredPrice: offeredPrice,
            specialInstructions: specialInstructions,
            urgency: _selectedUrgency,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai
              ? 'สร้างคำขอสำเร็จ! รอ Admin จัดสรร รปภ.'
              : 'Request created! Waiting for admin to assign guard.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isThai ? 'เกิดข้อผิดพลาด: $e' : 'Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    final urgencies = [
      {'key': 'low', 'label': isThai ? 'ต่ำ' : 'Low'},
      {'key': 'medium', 'label': isThai ? 'ปกติ' : 'Normal'},
      {'key': 'high', 'label': isThai ? 'เร่งด่วน' : 'Urgent'},
      {'key': 'critical', 'label': isThai ? 'ฉุกเฉิน' : 'Critical'},
    ];

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

                  // Urgency selector
                  _buildLabel(
                    isThai ? 'ระดับความเร่งด่วน' : 'Urgency Level',
                    Icons.priority_high_rounded,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: urgencies.map((u) {
                      final isSelected = _selectedUrgency == u['key'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedUrgency = u['key']!),
                          child: Container(
                            margin: EdgeInsets.only(
                              right: u == urgencies.last ? 0 : 8,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                u['label']!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Location / Address
                  _buildLabel(
                    isThai ? 'สถานที่' : 'Location',
                    Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(_addressController, isThai
                      ? 'ใส่ที่อยู่'
                      : 'Enter address'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _getCurrentLocation,
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
                                Icon(
                                  _lat != null
                                      ? Icons.check_circle_rounded
                                      : Icons.my_location_rounded,
                                  size: 16,
                                  color: _lat != null
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _lat != null
                                      ? (isThai ? 'ได้ตำแหน่งแล้ว' : 'Location set')
                                      : (isThai
                                          ? 'ใช้ตำแหน่งปัจจุบัน'
                                          : 'Use Current Location'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _lat != null
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Job description
                  _buildLabel(
                    isThai ? 'รายละเอียดงาน' : 'Job Details',
                    Icons.description_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildTextArea(
                    _descriptionController,
                    isThai
                        ? 'อธิบายรายละเอียดงาน'
                        : 'Describe job details',
                  ),

                  const SizedBox(height: 32),

                  // Special instructions
                  _buildLabel(
                    isThai ? 'คำแนะนำพิเศษ' : 'Special Instructions',
                    Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildTextArea(
                    _specialInstructionsController,
                    isThai
                        ? 'อุปกรณ์ที่ต้องการ, ข้อกำหนดพิเศษ ฯลฯ'
                        : 'Equipment needed, special requirements, etc.',
                  ),

                  const SizedBox(height: 32),

                  // Price & Guard count
                  _buildPriceSummary(isThai),
                  const SizedBox(height: 32),
                  _buildSubmitButton(isThai),
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

  Widget _buildInputField(TextEditingController controller, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
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

  Widget _buildTextArea(TextEditingController controller, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
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
          // Offered price input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThai ? 'ราคาที่เสนอ' : 'Offered Price',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: GoogleFonts.inter(fontSize: 13),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
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
          const SizedBox(height: 12),
          // Guard count
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

  Widget _buildSubmitButton(bool isThai) {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitBooking,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              isThai ? 'ส่งคำขอจอง' : 'Submit Request',
              style:
                  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
