import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../phone_input_screen.dart';

class GuardRegistrationScreen extends StatefulWidget {
  final String? phone;
  final String? phoneVerifiedToken;

  const GuardRegistrationScreen({
    super.key,
    this.phone,
    this.phoneVerifiedToken,
  });

  @override
  State<GuardRegistrationScreen> createState() =>
      _GuardRegistrationScreenState();
}

class _GuardRegistrationScreenState extends State<GuardRegistrationScreen> {
  int _currentStep = 0;
  bool _submitted = false;
  DateTime? _submittedAt;

  // Step 1 controllers
  final _nameController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  final _yearsExpController = TextEditingController(text: '0');
  final _workplaceController = TextEditingController();

  // Step 2 document files (real image_picker files)
  final Map<String, File?> _documents = {
    'id_card': null,
    'security_license': null,
    'training_cert': null,
    'criminal_check': null,
    'driver_license': null,
  };
  // Document expiry dates
  final Map<String, DateTime?> _documentExpiry = {
    'id_card': null,
    'security_license': null,
    'training_cert': null,
    'criminal_check': null,
    'driver_license': null,
  };
  // Step 3 passbook photo
  File? _passbookPhoto;

  // Step 3 controllers
  String? _selectedBank;
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _yearsExpController.dispose();
    _workplaceController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;
  String? _errorMessage;
  final _imagePicker = ImagePicker();

  int get _uploadedDocCount => _documents.values.where((v) => v != null).length;

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submitApplication();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickImage(String key, {bool isPassbook = false}) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        if (isPassbook) {
          _passbookPhoto = File(picked.path);
        } else {
          _documents[key] = File(picked.path);
        }
      });
    }
  }

  Future<void> _takePhoto(String key, {bool isPassbook = false}) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        if (isPassbook) {
          _passbookPhoto = File(picked.path);
        } else {
          _documents[key] = File(picked.path);
        }
      });
    }
  }

  void _removeFile(String key, {bool isPassbook = false}) {
    setState(() {
      if (isPassbook) {
        _passbookPhoto = null;
      } else {
        _documents[key] = null;
      }
    });
  }

  Future<void> _pickExpiryDate(String key) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _documentExpiry[key] ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 20)),
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
    if (picked != null) {
      setState(() => _documentExpiry[key] = picked);
    }
  }


  Future<void> _submitApplication() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      String? profileToken;

      // Step ①: Get profile_token
      if (widget.phoneVerifiedToken != null) {
        // First-time submission — register with OTP token
        profileToken = await authProvider.registerWithOtp(
          phoneVerifiedToken: widget.phoneVerifiedToken!,
          fullName: _nameController.text,
          role: 'guard',
          phone: widget.phone,
        );
      } else {
        // Token expired — user needs to re-verify phone via OTP
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageProvider.of(context).isThai
                ? 'เซสชันหมดอายุ กรุณายืนยันเบอร์โทรอีกครั้ง'
                : 'Session expired. Please verify your phone again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
          (route) => false,
        );
        return;
      }

      if (profileToken == null) {
        throw Exception('Failed to get profile token');
      }

      // Step ②: Submit guard profile with documents
      final files = <String, File>{};
      for (final entry in _documents.entries) {
        if (entry.value != null) {
          files[entry.key] = entry.value!;
        }
      }
      if (_passbookPhoto != null) {
        files['passbook_photo'] = _passbookPhoto!;
      }

      await authProvider.submitGuardProfile(
        profileToken: profileToken,
        fullName: _nameController.text,
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth != null
            ? '${_selectedDateOfBirth!.year}-${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}-${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}'
            : null,
        yearsOfExperience: int.tryParse(_yearsExpController.text),
        previousWorkplace: _workplaceController.text.isNotEmpty
            ? _workplaceController.text
            : null,
        bankName: _selectedBank,
        accountNumber: _accountNumberController.text.isNotEmpty
            ? _accountNumberController.text
            : null,
        accountName: _accountNameController.text.isNotEmpty
            ? _accountNameController.text
            : null,
        files: files,
      );

      await AuthService.markRegistered('guard', _nameController.text);

      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submittedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        if (data['error']?['message'] != null) {
          msg = data['error']['message'].toString();
        }
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardRegistrationStrings(isThai: isThai);
    final List<String> steps = [
      strings.stepPersonal,
      strings.stepDocuments,
      strings.stepBank,
    ];

    if (_submitted) {
      return _buildSubmittedScreen(strings);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.deepBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            if (_currentStep > 0) {
              _prevStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          strings.appBarTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(strings, steps),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.fillInfo,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_currentStep == 0) _buildPersonalInfoStep(strings),
                  if (_currentStep == 1) _buildDocumentsStep(strings),
                  if (_currentStep == 2) _buildBankStep(strings),
                ],
              ),
            ),
          ),
          _buildBottomButtons(strings),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
    GuardRegistrationStrings strings,
    List<String> steps,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          bool isCompleted = index < _currentStep;
          bool isActive = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive || isCompleted
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive || isCompleted
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    steps[index],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Colors.white : Colors.white60,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isCompleted
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Step 1: Personal Info ───────────────────

  Widget _buildPersonalInfoStep(GuardRegistrationStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(strings.personalDetails),
        const SizedBox(height: 20),
        _buildLabel(strings.fullName),
        _buildTextField(strings.fullNameHint, controller: _nameController),
        const SizedBox(height: 20),
        _buildLabel(strings.gender),
        _buildDropdownField(
          strings.selectGender,
          strings.genderOptions,
          value: _selectedGender,
          onChanged: (val) => setState(() => _selectedGender = val),
        ),
        const SizedBox(height: 20),
        _buildLabel(strings.dateOfBirth),
        _buildDateField(strings),

        const SizedBox(height: 32),
        _buildSectionHeader(strings.workExperience),
        const SizedBox(height: 20),
        _buildLabel(strings.yearsOfExp),
        _buildTextField(
          '0',
          controller: _yearsExpController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        _buildLabel(strings.previousWorkplace),
        _buildTextField(strings.companyHint, controller: _workplaceController),
      ],
    );
  }

  // ─── Step 2: Documents ───────────────────

  Widget _buildDocumentsStep(GuardRegistrationStrings strings) {
    final docItems = [
      {'key': 'id_card', 'label': strings.idCard},
      {'key': 'security_license', 'label': strings.securityLicense},
      {'key': 'training_cert', 'label': strings.trainingCert},
      {'key': 'criminal_check', 'label': strings.criminalCheck},
      {'key': 'driver_license', 'label': strings.driverLicense},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(strings.uploadDocuments),
        const SizedBox(height: 8),
        Text(
          strings.uploadDocumentsDesc,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ...docItems.expand(
          (item) => [
            _buildDocumentUploadItem(item['label']!, item['key']!, strings),
            _buildExpiryField(item['key']!, strings),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentUploadItem(
    String label,
    String key,
    GuardRegistrationStrings strings, {
    bool isPassbook = false,
  }) {
    final file = isPassbook ? _passbookPhoto : _documents[key];
    final isUploaded = file != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUploaded
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUploaded
                      ? Icons.check_circle_rounded
                      : Icons.description_outlined,
                  color: isUploaded ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUploaded
                          ? file.path.split('/').last
                          : strings.notAttached,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isUploaded
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isUploaded)
                IconButton(
                  onPressed: () => _removeFile(key, isPassbook: isPassbook),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.danger,
                ),
            ],
          ),
          if (isUploaded) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file, height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(key, isPassbook: isPassbook),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(strings.uploadFile, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _takePhoto(key, isPassbook: isPassbook),
                icon: const Icon(Icons.camera_alt, size: 22),
                color: AppColors.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryField(String key, GuardRegistrationStrings strings) {
    final expiry = _documentExpiry[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _pickExpiryDate(key),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: expiry != null ? AppColors.primary.withValues(alpha: 0.06) : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: expiry != null ? AppColors.primary : Colors.orange.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                expiry != null ? Icons.event_available_rounded : Icons.calendar_month_rounded,
                size: 24,
                color: expiry != null ? AppColors.primary : Colors.orange.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  expiry != null
                      ? '${strings.expiryDate}: ${_formatDate(expiry)}'
                      : '📅 ${strings.selectExpiryDate}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: expiry != null ? AppColors.primary : Colors.orange.shade800,
                  ),
                ),
              ),
              if (expiry != null)
                GestureDetector(
                  onTap: () => setState(() => _documentExpiry[key] = null),
                  child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                )
              else
                Icon(Icons.arrow_drop_down_rounded, size: 28, color: Colors.orange.shade600),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 3: Bank Account ───────────────────

  Widget _buildBankStep(GuardRegistrationStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(strings.bankDetails),
        const SizedBox(height: 20),
        _buildLabel(strings.bankName),
        _buildDropdownField(
          strings.selectBank,
          strings.bankOptions,
          value: _selectedBank,
          onChanged: (val) => setState(() => _selectedBank = val),
        ),
        const SizedBox(height: 20),
        _buildLabel(strings.accountNumber),
        _buildSecureAccountField(strings.accountNumberHint),
        const SizedBox(height: 20),
        _buildLabel(strings.accountName),
        _buildTextField(
          strings.accountNameHint,
          controller: _accountNameController,
        ),
        const SizedBox(height: 20),
        _buildLabel(strings.passbookPhoto),
        _buildDocumentUploadItem(strings.passbookPhoto, 'passbook_photo', strings, isPassbook: true),
      ],
    );
  }

  // ─── Step 4: Submitted / Review Screen ───────

  Widget _buildSubmittedScreen(GuardRegistrationStrings strings) {
    final isThai = LanguageProvider.of(context).isThai;
    final dateStr = _submittedAt != null
        ? _formatDateTime(_submittedAt!, isThai)
        : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.deepBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          strings.appBarTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.info,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              strings.applicationReview,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Submitted timestamp
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${strings.submittedOn} $dateStr${isThai ? " น." : ""}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submitted data summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.submittedData,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    strings.nameLabel,
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : '-',
                  ),
                  _buildSummaryRow(
                    strings.experienceLabel,
                    '${_yearsExpController.text} ${strings.yearsUnit}',
                  ),
                  _buildSummaryRow(
                    strings.documentsLabel,
                    '$_uploadedDocCount/5 ${strings.documentsCount}',
                  ),
                  _buildSummaryRow(
                    strings.bankLabel,
                    _selectedBank ?? '-',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
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
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt, bool isThai) {
    final months = isThai
        ? [
            'มกราคม',
            'กุมภาพันธ์',
            'มีนาคม',
            'เมษายน',
            'พฤษภาคม',
            'มิถุนายน',
            'กรกฎาคม',
            'สิงหาคม',
            'กันยายน',
            'ตุลาคม',
            'พฤศจิกายน',
            'ธันวาคม',
          ]
        : [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
    final year = isThai ? dt.year + 543 : dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} $year, $hour:$minute';
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day/$month/$year';
  }

  // ─── Shared UI Components ───────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint, {
    IconData? icon,
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        suffixIcon: icon != null
            ? Icon(icon, size: 18, color: AppColors.textSecondary)
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSecureAccountField(String hint) {
    return TextField(
      controller: _accountNumberController,
      keyboardType: TextInputType.number,
      maxLength: 15,
      enableInteractiveSelection: false,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: GoogleFonts.inter(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: const Icon(Icons.account_balance_outlined, size: 18),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildDateField(GuardRegistrationStrings strings) {
    final displayText = _selectedDateOfBirth != null
        ? _formatDate(_selectedDateOfBirth!)
        : 'dd/mm/yyyy';

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDateOfBirth ?? DateTime(2000, 1, 1),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _selectedDateOfBirth = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _selectedDateOfBirth != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String hint,
    List<String> items, {
    String? value,
    ValueChanged<String?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val, style: GoogleFonts.inter(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBottomButtons(GuardRegistrationStrings strings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentStep > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    strings.back,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
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
                      _currentStep == 2 ? strings.submitApplication : strings.next,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
