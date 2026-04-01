import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import 'guard_searching_screen.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> serviceRate;

  const BookingScreen({super.key, required this.serviceRate});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _addressController = TextEditingController();
  final _jobDetailsController = TextEditingController();
  final _notesController = TextEditingController();
  final _tipController = TextEditingController();

  // Service time
  late int _selectedHours;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  // Location
  double? _lat;
  double? _lng;

  // Equipment
  final Map<String, bool> _equipment = {
    'flashlight': false,
    'handcuffs': false,
    'baton': false,
    'uniform': false,
    'uniform_polo': false,
    'other': false,
  };
  final _otherEquipmentController = TextEditingController();

  // Job type
  String? _selectedJobType;
  final _otherJobTypeController = TextEditingController();

  // Additional services
  final Map<String, bool> _services = {
    'has_pets': false,
    'plant_care': false,
    'utilities': false,
    'other': false,
  };
  final _otherServiceController = TextEditingController();

  // Pricing
  int _guardCount = 1;
  bool _isSubmitting = false;

  // Parsed from service rate
  late String _serviceName;
  late int _minHours;
  late double _minPrice;
  late double _maxPrice;
  late double _baseFee;

  @override
  void initState() {
    super.initState();
    final rate = widget.serviceRate;
    _serviceName = rate['name'] as String? ?? '';
    _minHours = rate['min_hours'] as int? ?? 4;
    _minPrice = (rate['min_price'] as num?)?.toDouble() ?? 0;
    _maxPrice = (rate['max_price'] as num?)?.toDouble() ?? 0;
    _baseFee = (rate['base_fee'] as num?)?.toDouble() ?? 0;

    _selectedHours = _minHours;
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _addressController.dispose();
    _jobDetailsController.dispose();
    _notesController.dispose();
    _tipController.dispose();
    _otherJobTypeController.dispose();
    _otherEquipmentController.dispose();
    _otherServiceController.dispose();
    super.dispose();
  }

  // Duration preset options derived from min_hours
  List<int> get _durationPresets {
    final presets = <int>[];
    for (final h in [4, 6, 8, 12, 24]) {
      if (h >= _minHours) presets.add(h);
    }
    if (presets.isEmpty || presets.first != _minHours) {
      presets.insert(0, _minHours);
    }
    return presets;
  }

  DateTime get _endDateTime {
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return start.add(Duration(hours: _selectedHours));
  }

  double get _hourlyRate => (_minPrice + _maxPrice) / 2;
  double get _subtotal => _hourlyRate * _selectedHours * _guardCount;
  double get _tip {
    final t = double.tryParse(_tipController.text.trim());
    return (t != null && t > 0) ? t : 0;
  }

  double get _total => _subtotal + _baseFee + _tip;

  static final Dio _nominatimDio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {'User-Agent': 'P-GuardMobile/1.0'},
  ));

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final response = await _nominatimDio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
        'zoom': '16',
        'accept-language': 'th,en',
      });
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is Map<String, dynamic>) {
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        return addr['road'] ??
            addr['suburb'] ??
            addr['city_district'] ??
            addr['subdistrict'] ??
            addr['town'] ??
            addr['city'] ??
            (data['display_name'] as String?)?.split(',').first;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setLocationWithGeocode(double lat, double lng, {String? displayName}) async {
    setState(() {
      _lat = lat;
      _lng = lng;
      _addressController.text = displayName ??
          '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    });
    if (displayName == null) {
      final name = await _reverseGeocode(lat, lng);
      if (name != null && mounted) {
        setState(() {
          _addressController.text = name;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _setLocationWithGeocode(position.latitude, position.longitude);
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isThai ? 'ได้ตำแหน่ง GPS แล้ว' : 'GPS location acquired'),
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

  Future<void> _openMapPicker() async {
    // Default to current GPS or Bangkok center
    final initialLat = _lat ?? 13.7563;
    final initialLng = _lng ?? 100.5018;

    final result = await showModalBottomSheet<({LatLng latLng, String? displayName})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MapPickerSheet(
        initialLat: initialLat,
        initialLng: initialLng,
      ),
    );

    if (result != null && mounted) {
      await _setLocationWithGeocode(
        result.latLng.latitude,
        result.latLng.longitude,
        displayName: result.displayName,
      );
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'ปักหมุดสำเร็จ' : 'Location pinned'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _deriveUrgency() {
    final now = DateTime.now();
    final diff = _selectedDate.difference(now).inDays;
    if (diff <= 0) return 'high';
    if (diff <= 3) return 'medium';
    return 'low';
  }

  String _buildDescription(bool isThai) {
    final parts = <String>[];
    parts.add(isThai
        ? 'บริการ: $_serviceName'
        : 'Service: $_serviceName');
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    parts.add(isThai
        ? 'วันที่: $dateStr เวลา: $timeStr'
        : 'Date: $dateStr Time: $timeStr');
    parts.add(isThai
        ? 'ระยะเวลา: $_selectedHours ชม.'
        : 'Duration: $_selectedHours hrs');
    parts.add(isThai
        ? 'จำนวน รปภ.: $_guardCount คน'
        : 'Guards: $_guardCount');

    if (_selectedJobType != null) {
      String jtLabel;
      if (_selectedJobType == 'other') {
        final custom = _otherJobTypeController.text.trim();
        jtLabel = custom.isNotEmpty
            ? custom
            : (isThai ? 'อื่นๆ' : 'Other');
      } else {
        final jt = _jobTypes.firstWhere((t) => t['key'] == _selectedJobType);
        jtLabel = (isThai ? jt['th'] : jt['en']) as String;
      }
      parts.add(isThai
          ? 'ประเภทงาน: $jtLabel'
          : 'Job Type: $jtLabel');
    }

    final selectedServices = _services.entries
        .where((e) => e.value)
        .map((e) => _serviceLabel(e.key, isThai))
        .toList();
    if (selectedServices.isNotEmpty) {
      parts.add(isThai
          ? 'บริการเพิ่มเติม: ${selectedServices.join(', ')}'
          : 'Additional: ${selectedServices.join(', ')}');
    }

    final selectedEquipment = _equipment.entries
        .where((e) => e.value)
        .map((e) => _equipmentLabel(e.key, isThai))
        .toList();
    if (selectedEquipment.isNotEmpty) {
      parts.add(isThai
          ? 'อุปกรณ์: ${selectedEquipment.join(', ')}'
          : 'Equipment: ${selectedEquipment.join(', ')}');
    }

    final jobDetails = _jobDetailsController.text.trim();
    if (jobDetails.isNotEmpty) {
      parts.add(isThai
          ? 'รายละเอียดงาน: $jobDetails'
          : 'Job Details: $jobDetails');
    }

    return parts.join('\n');
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

    final lat = _lat ?? 13.7563;
    final lng = _lng ?? 100.5018;
    final notes = _notesController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final result = await context.read<BookingProvider>().createRequest(
            locationLat: lat,
            locationLng: lng,
            address: address,
            description: _buildDescription(isThai),
            offeredPrice: _total,
            specialInstructions: notes.isNotEmpty ? notes : null,
            urgency: _deriveUrgency(),
            bookedHours: _selectedHours,
          );
      if (!mounted) return;
      final requestId = result['id']?.toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GuardSearchingScreen(
            requestId: requestId,
            lat: lat,
            lng: lng,
            totalAmount: _total,
            subtotal: _subtotal,
            baseFee: _baseFee,
            tip: _tip,
            bookedHours: _selectedHours,
            guardCount: _guardCount,
          ),
        ),
      );
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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(isThai),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceTimeSection(isThai),
                  const SizedBox(height: 20),
                  _buildLocationSection(isThai),
                  const SizedBox(height: 20),
                  _buildJobTypeSection(isThai),
                  const SizedBox(height: 20),
                  _buildEquipmentSection(isThai),
                  const SizedBox(height: 20),
                  _buildAdditionalServicesSection(isThai),
                  const SizedBox(height: 20),
                  _buildPricingSection(isThai),
                  const SizedBox(height: 24),
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

  // ===========================================================================
  // Header
  // ===========================================================================

  Widget _buildHeader(bool isThai) {
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '฿${_minPrice.toInt()}-${_maxPrice.toInt()}/${isThai ? 'ชม.' : 'hr'}',
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
          const SizedBox(height: 16),
          Text(
            isThai
                ? 'กรอกรายละเอียดการจองบริการ'
                : 'Fill in your booking details',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 1: Service Time
  // ===========================================================================

  Widget _buildServiceTimeSection(bool isThai) {
    return _buildSectionCard(
      icon: Icons.access_time_rounded,
      title: isThai ? 'ระยะเวลาบริการ' : 'Service Duration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration presets
          Text(
            isThai ? 'เลือกระยะเวลา' : 'Select Duration',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _durationPresets.map((h) {
              final isSelected = _selectedHours == h;
              return GestureDetector(
                onTap: () => setState(() => _selectedHours = h),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '$h ${isThai ? 'ชม.' : 'hrs'}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Custom hours stepper
          Row(
            children: [
              Text(
                isThai ? 'หรือกำหนดเอง:' : 'Or custom:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _buildStepper(
                value: _selectedHours,
                min: _minHours,
                onChanged: (v) => setState(() => _selectedHours = v),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.border),

          // Date picker
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                isThai ? 'วันที่เริ่มบริการ' : 'Start Date',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down_rounded,
                          size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Time picker
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                isThai ? 'เวลาเริ่ม' : 'Start Time',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down_rounded,
                          size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.border),

          // End date/time (auto-calculated)
          _buildEndDateTimeRow(isThai),
        ],
      ),
    );
  }

  Widget _buildEndDateTimeRow(bool isThai) {
    final end = _endDateTime;
    final endDateStr = DateFormat('dd MMM yyyy').format(end);
    final endTimeStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            isThai ? 'สิ้นสุดบริการ' : 'Service End',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '$endDateStr  $endTimeStr',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Location
  // ===========================================================================

  Widget _buildLocationSection(bool isThai) {
    return _buildSectionCard(
      icon: Icons.location_on_rounded,
      title: isThai ? 'สถานที่' : 'Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address sub-label
          Text(
            isThai ? 'ที่อยู่' : 'Address',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _addressController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: isThai
                    ? 'ใส่ที่อยู่หรือใช้ GPS ปัจจุบัน'
                    : 'Enter address or use current GPS',
                border: InputBorder.none,
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Pin from map button
          GestureDetector(
            onTap: _openMapPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _lat != null
                    ? AppColors.success.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _lat != null
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _lat != null
                        ? Icons.check_circle_rounded
                        : Icons.map_rounded,
                    size: 18,
                    color: _lat != null ? AppColors.success : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: _lat != null
                        ? AppColors.success
                        : Colors.red.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _lat != null
                        ? (isThai ? 'ปักหมุดแล้ว' : 'Location pinned')
                        : (isThai
                            ? 'ปักหมุดจากแผนที่'
                            : 'Pin from Map'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color:
                          _lat != null ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Use current location button
          GestureDetector(
            onTap: _getCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.my_location_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    isThai ? 'ใช้ตำแหน่งปัจจุบัน' : 'Use Current Location',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 28, color: AppColors.border),

          // Job details sub-label
          Text(
            isThai ? 'รายละเอียดงาน' : 'Job Details',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _jobDetailsController,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: isThai
                    ? 'อธิบายรายละเอียดงานหรือความต้องการพิเศษ'
                    : 'Describe job details or special requirements',
                border: InputBorder.none,
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Job Type
  // ===========================================================================

  static const _jobTypes = [
    {'key': 'village', 'th': 'งานหมู่บ้าน', 'en': 'Village', 'icon': Icons.holiday_village_rounded},
    {'key': 'condo', 'th': 'คอนโด', 'en': 'Condo', 'icon': Icons.apartment_rounded},
    {'key': 'factory', 'th': 'โรงงาน', 'en': 'Factory', 'icon': Icons.factory_rounded},
    {'key': 'other', 'th': 'อื่นๆ', 'en': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  Widget _buildJobTypeSection(bool isThai) {
    return _buildSectionCard(
      icon: Icons.work_rounded,
      title: isThai ? 'ประเภทงาน' : 'Job Type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _jobTypes.map((type) {
              final key = type['key'] as String;
              final label = (isThai ? type['th'] : type['en']) as String;
              final icon = type['icon'] as IconData;
              final isSelected = _selectedJobType == key;
              return GestureDetector(
                onTap: () => setState(() => _selectedJobType = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18,
                          color: isSelected ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedJobType == 'other')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _otherJobTypeController,
                  decoration: InputDecoration(
                    hintText: isThai ? 'โปรดระบุประเภทงาน' : 'Please specify job type',
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Security Equipment
  // ===========================================================================

  Widget _buildEquipmentSection(bool isThai) {
    return _buildSectionCard(
      icon: Icons.build_circle_rounded,
      title: isThai ? 'อุปกรณ์รักษาความปลอดภัย' : 'Security Equipment',
      child: Column(
        children: [
          _buildSimpleCheckbox('flashlight', _equipment,
              isThai ? 'ไฟฉาย' : 'Flashlight'),
          _buildSimpleCheckbox('handcuffs', _equipment,
              isThai ? 'กุญแจมือถือ' : 'Handcuffs'),
          _buildSimpleCheckbox('baton', _equipment,
              isThai ? 'กระบอง, กระบองไฟจราจร' : 'Baton, Traffic Baton'),
          _buildSimpleCheckbox('uniform', _equipment,
              isThai ? 'ชุดยูนิฟอร์ม รปภ.' : 'Guard Uniform'),
          _buildSimpleCheckbox('uniform_polo', _equipment,
              isThai ? 'ชุดเครื่องแบบ รปภ.+เสื้อโปโล' : 'Guard Uniform + Polo'),
          _buildSimpleCheckbox('other', _equipment,
              isThai ? 'อื่นๆ' : 'Other'),
          if (_equipment['other'] == true)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
              child: TextField(
                controller: _otherEquipmentController,
                decoration: InputDecoration(
                  hintText: 'Other (${isThai ? "โปรดระบุ" : "please specify"})',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Additional Services
  // ===========================================================================

  Widget _buildAdditionalServicesSection(bool isThai) {
    return _buildSectionCard(
      icon: Icons.add_circle_outline_rounded,
      title: isThai ? 'บริการเพิ่มเติม' : 'Additional Services',
      child: Column(
        children: [
          _buildSimpleCheckbox('has_pets', _services,
              isThai ? 'มีสัตว์เลี้ยง' : 'Has Pets'),
          _buildSimpleCheckbox('plant_care', _services,
              isThai ? 'ดูแลต้นไม้' : 'Plant Care'),
          _buildSimpleCheckbox('utilities', _services,
              isThai ? 'ปิด/เปิดน้ำ-ไฟฟ้า' : 'Turn On/Off Utilities'),
          _buildSimpleCheckbox('other', _services,
              isThai ? 'อื่นๆ' : 'Other'),
          if (_services['other'] == true)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
              child: TextField(
                controller: _otherServiceController,
                decoration: InputDecoration(
                  hintText: 'Other (${isThai ? "โปรดระบุ" : "please specify"})',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: Pricing
  // ===========================================================================

  Widget _buildPricingSection(bool isThai) {
    return _buildSectionCard(
      icon: Icons.receipt_long_rounded,
      title: isThai ? 'สรุปราคา' : 'Price Summary',
      child: Column(
        children: [
          // Guard count
          Row(
            children: [
              const Icon(Icons.people_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                isThai ? 'จำนวนเจ้าหน้าที่' : 'Number of Guards',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildStepper(
                value: _guardCount,
                min: 1,
                onChanged: (v) => setState(() => _guardCount = v),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.border),

          // Breakdown
          _buildPriceRow(
            isThai ? 'ค่าบริการรายชั่วโมง' : 'Hourly Rate',
            '฿${_hourlyRate.toStringAsFixed(0)}/${isThai ? 'ชม.' : 'hr'}',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            isThai
                ? '$_selectedHours ชม. × $_guardCount คน'
                : '$_selectedHours hrs × $_guardCount guard${_guardCount > 1 ? 's' : ''}',
            '฿${_subtotal.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            isThai ? 'ค่าพื้นฐาน' : 'Base Fee',
            '฿${_baseFee.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),

          // Tip input
          Row(
            children: [
              Text(
                isThai ? 'ค่าตอบแทนพิเศษ' : 'Tip / Bonus',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 100,
                height: 38,
                child: TextField(
                  controller: _tipController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.disabled),
                    prefixText: '฿',
                    prefixStyle: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThai ? 'ราคารวมทั้งหมด' : 'Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '฿${_total.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          // Notes
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isThai
                    ? 'หมายเหตุเพิ่มเติม (ไม่บังคับ)'
                    : 'Additional notes (optional)',
                border: InputBorder.none,
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Submit
  // ===========================================================================

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
                  color: Colors.white, strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  isThai ? 'ยืนยันการจอง' : 'Confirm Booking',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // Shared widgets
  // ===========================================================================

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildSimpleCheckbox(
      String key, Map<String, bool> map, String label) {
    final isChecked = map[key] ?? false;
    return GestureDetector(
      onTap: () => setState(() => map[key] = !isChecked),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper({
    required int value,
    required int min,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepButton(
            Icons.remove,
            value > min ? () => onChanged(value - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$value',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          _buildStepButton(
            Icons.add,
            () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? AppColors.textPrimary : AppColors.disabled),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary),
        ),
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

  // ===========================================================================
  // i18n helpers for checkbox labels
  // ===========================================================================

  String _equipmentLabel(String key, bool isThai) {
    switch (key) {
      case 'flashlight':
        return isThai ? 'ไฟฉาย' : 'Flashlight';
      case 'handcuffs':
        return isThai ? 'กุญแจมือถือ' : 'Handcuffs';
      case 'baton':
        return isThai ? 'กระบอง' : 'Baton';
      case 'uniform':
        return isThai ? 'ชุดยูนิฟอร์ม รปภ.' : 'Guard Uniform';
      case 'uniform_polo':
        return isThai ? 'ชุดเครื่องแบบ+โปโล' : 'Uniform + Polo';
      case 'other':
        final text = _otherEquipmentController.text.trim();
        return text.isNotEmpty
            ? text
            : (isThai ? 'อื่นๆ' : 'Other');
      default:
        return key;
    }
  }

  String _serviceLabel(String key, bool isThai) {
    switch (key) {
      case 'has_pets':
        return isThai ? 'มีสัตว์เลี้ยง' : 'Has Pets';
      case 'plant_care':
        return isThai ? 'ดูแลต้นไม้' : 'Plant Care';
      case 'utilities':
        return isThai ? 'ปิด/เปิดน้ำ-ไฟฟ้า' : 'Utilities';
      case 'other':
        final text = _otherServiceController.text.trim();
        return text.isNotEmpty
            ? text
            : (isThai ? 'อื่นๆ' : 'Other');
      default:
        return key;
    }
  }
}

// =============================================================================
// Map Picker Bottom Sheet
// =============================================================================

class _MapPickerSheet extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const _MapPickerSheet({
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  late LatLng _pinLocation;
  String? _selectedDisplayName;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  static final Dio _nominatimDio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {'User-Agent': 'P-GuardMobile/1.0'},
  ));

  @override
  void initState() {
    super.initState();
    _pinLocation = LatLng(widget.initialLat, widget.initialLng);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _isReverseGeocoding = false;

  Future<void> _reverseGeocodePin(double lat, double lng) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final response = await _nominatimDio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
        'zoom': '16',
        'accept-language': 'th,en',
      });
      if (!mounted) return;
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is Map<String, dynamic>) {
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final name = addr['road'] ??
            addr['suburb'] ??
            addr['city_district'] ??
            addr['subdistrict'] ??
            addr['town'] ??
            addr['city'] ??
            (data['display_name'] as String?)?.split(',').first;
        if (name != null && mounted) {
          setState(() => _selectedDisplayName = name as String);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isReverseGeocoding = false);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      final response = await _nominatimDio.get('/search', queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'th',
        'accept-language': 'th,en',
      });
      final List<dynamic> data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      setState(() {
        _searchResults = data.cast<Map<String, dynamic>>();
        _showResults = _searchResults.isNotEmpty;
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;

    final displayName = result['display_name'] as String? ?? '';
    final point = LatLng(lat, lng);
    setState(() {
      _pinLocation = point;
      _selectedDisplayName = displayName.split(',').first.trim();
      _showResults = false;
      _searchController.text = displayName;
    });
    _searchFocus.unfocus();
    _mapController.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  isThai ? 'ปักหมุดจากแผนที่' : 'Pin Location on Map',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: isThai ? 'ค้นหาสถานที่...' : 'Search places...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showResults = false;
                          });
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textSecondary),
                      )
                    : _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : null,
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Coordinate display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pin_drop_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${_pinLocation.latitude.toStringAsFixed(6)}, ${_pinLocation.longitude.toStringAsFixed(6)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_isReverseGeocoding)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_selectedDisplayName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _selectedDisplayName!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Map + search results overlay
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pinLocation,
                    initialZoom: 15,
                    onTap: (_, point) {
                      setState(() {
                        _pinLocation = point;
                        _selectedDisplayName = null;
                        _showResults = false;
                      });
                      _searchFocus.unfocus();
                      _reverseGeocodePin(point.latitude, point.longitude);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.p-guard.mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pinLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Zoom controls
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ZoomButton(
                        icon: Icons.add,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                        isTop: true,
                      ),
                      _ZoomButton(
                        icon: Icons.remove,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                        isTop: false,
                      ),
                    ],
                  ),
                ),
                // Search results dropdown
                if (_showResults)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final r = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_rounded,
                                  size: 20, color: AppColors.primary),
                              title: Text(
                                r['display_name'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                              onTap: () => _selectSearchResult(r),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, (latLng: _pinLocation, displayName: _selectedDisplayName)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isThai ? 'ยืนยันตำแหน่ง' : 'Confirm Location',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTop;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isTop ? 8 : 0),
            bottom: Radius.circular(isTop ? 0 : 8),
          ),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: isTop
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
