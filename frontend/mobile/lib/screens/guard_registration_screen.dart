import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_strings.dart';
import 'registration_pending_screen.dart';

class GuardRegistrationScreen extends StatefulWidget {
  final String phone;
  /// profile_token returned by registerWithOtp() in PinSetupScreen.
  /// Used to authenticate the guard profile submission.
  final String? profileToken;
  final Widget dashboard;

  const GuardRegistrationScreen({
    super.key,
    required this.phone,
    this.profileToken,
    required this.dashboard,
  });

  @override
  State<GuardRegistrationScreen> createState() =>
      _GuardRegistrationScreenState();
}

class _GuardRegistrationScreenState extends State<GuardRegistrationScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;
  // Profile token received from PinSetupScreen via widget.profileToken.
  late final String? _profileToken = widget.profileToken;

  // Step 1 — Personal info
  final _fullNameController = TextEditingController();
  String? _selectedGender;
  DateTime? _dateOfBirth;
  final _yearsExpController = TextEditingController();
  final _previousWorkplaceController = TextEditingController();

  // Step 2 — Documents (store picked File objects)
  final Map<String, File?> _documents = {
    'idCard': null,
    'securityLicense': null,
    'trainingCert': null,
    'criminalCheck': null,
    'driverLicense': null,
  };

  // Step 3 — Bank account
  String? _selectedBank;
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  File? _passbookFile;

  final _picker = ImagePicker();

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _yearsExpController.dispose();
    _previousWorkplaceController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  static String _maskAccountNumber(String acc) {
    if (acc.length <= 4) return acc.replaceAll(RegExp(r'.'), '•');
    return '•••• ${acc.substring(acc.length - 4)}';
  }

  Future<void> _pickFile(String key, ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFile == null) return;
      final file = File(xFile.path);
      setState(() {
        if (_documents.containsKey(key)) {
          _documents[key] = file;
        } else if (key == 'passbook') {
          _passbookFile = file;
        }
      });
    } catch (_) {
      // User denied permission or camera unavailable — ignore silently.
    }
  }

  Future<void> _onSubmit() async {
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      // profile_token was obtained in PinSetupScreen (passed via widget.profileToken).
      final profileToken = _profileToken;

      // Save profile summary locally (masked account number for security).
      await AuthService.savePendingProfile({
        'full_name': _fullNameController.text.trim(),
        'gender': _selectedGender,
        'years_of_experience': _yearsExpController.text.trim(),
        'previous_workplace': _previousWorkplaceController.text.trim(),
        'bank_name': _selectedBank,
        'account_number': _maskAccountNumber(_accountNumberController.text.trim()),
        'account_name': _accountNameController.text.trim(),
        'doc_id_card': _documents['idCard']?.path.split('/').last,
        'doc_security_license': _documents['securityLicense']?.path.split('/').last,
        'doc_training_cert': _documents['trainingCert']?.path.split('/').last,
        'doc_criminal_check': _documents['criminalCheck']?.path.split('/').last,
        'doc_driver_license': _documents['driverLicense']?.path.split('/').last,
        'doc_passbook': _passbookFile?.path.split('/').last,
      });

      // Submit to backend only if profile_token is available (may be null if
      // token expired — local save above ensures pending screen still shows data).
      if (profileToken != null) {
        String? dobString;
        if (_dateOfBirth != null) {
          dobString =
              '${_dateOfBirth!.year.toString().padLeft(4, '0')}-'
              '${_dateOfBirth!.month.toString().padLeft(2, '0')}-'
              '${_dateOfBirth!.day.toString().padLeft(2, '0')}';
        }
        // Collect picked files for upload.
        final filesToUpload = <String, File>{};
        if (_documents['idCard'] != null) filesToUpload['id_card'] = _documents['idCard']!;
        if (_documents['securityLicense'] != null) filesToUpload['security_license'] = _documents['securityLicense']!;
        if (_documents['trainingCert'] != null) filesToUpload['training_cert'] = _documents['trainingCert']!;
        if (_documents['criminalCheck'] != null) filesToUpload['criminal_check'] = _documents['criminalCheck']!;
        if (_documents['driverLicense'] != null) filesToUpload['driver_license'] = _documents['driverLicense']!;
        if (_passbookFile != null) filesToUpload['passbook_photo'] = _passbookFile!;

        await authProvider.submitGuardProfile(
          profileToken: profileToken,
          fullName: _fullNameController.text.trim().isEmpty
              ? null
              : _fullNameController.text.trim(),
          gender: _selectedGender,
          dateOfBirth: dobString,
          yearsOfExperience: int.tryParse(_yearsExpController.text.trim()),
          previousWorkplace: _previousWorkplaceController.text.trim().isEmpty
              ? null
              : _previousWorkplaceController.text.trim(),
          bankName: _selectedBank,
          accountNumber: _accountNumberController.text.trim().isEmpty
              ? null
              : _accountNumberController.text.trim(),
          accountName: _accountNameController.text.trim().isEmpty
              ? null
              : _accountNameController.text.trim(),
          files: filesToUpload,
        );
      }

      await AuthService.clearPhoneVerifiedData();

      if (!mounted) return;

      final isThai = LanguageProvider.of(context).isThai;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                isThai
                    ? 'ส่งใบสมัครสำเร็จ!'
                    : 'Application submitted!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 1200),
        ),
      );

      // Navigate to pending screen — guard must wait for admin approval.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RegistrationPendingScreen()),
          (route) => false,
        );
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.data?['error']?['message'] as String?;
      setState(() {
        _isSubmitting = false;
        _errorMessage = message ?? e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = GuardRegistrationStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(s),
                // Stepper indicator
                _buildStepIndicator(s),
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        if (_currentStep == 0) _buildStep1(s),
                        if (_currentStep == 1) _buildStep2(s),
                        if (_currentStep == 2) _buildStep3(s),
                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Bottom navigation buttons
                _buildBottomButtons(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────
  Widget _buildHeader(GuardRegistrationStrings s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.appBarTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.fillInfo,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ─────────────────────────────────────────
  Widget _buildStepIndicator(GuardRegistrationStrings s) {
    final steps = [
      (Icons.person_outline_rounded, s.stepPersonal),
      (Icons.description_outlined, s.stepDocuments),
      (Icons.account_balance_outlined, s.stepBank),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isActive = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color:
                    isActive ? AppColors.primary : AppColors.border,
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = stepIndex <= _currentStep;
          final isCurrent = stepIndex == _currentStep;
          final icon = steps[stepIndex].$1;
          final label = steps[stepIndex].$2;

          return Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary
                      : (isActive
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.border,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isCurrent
                      ? Colors.white
                      : (isActive
                          ? AppColors.primary
                          : AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Step 1: Personal Info ──────────────────────────────────
  Widget _buildStep1(GuardRegistrationStrings s) {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(s.personalDetails, Icons.person_outline_rounded),
          const SizedBox(height: 16),
          // Full Name
          _buildLabel(s.fullName),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _fullNameController,
            hint: s.fullNameHint,
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.fullNameHint : null,
          ),
          const SizedBox(height: 16),
          // Gender
          _buildLabel(s.gender),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedGender,
            hint: s.selectGender,
            icon: Icons.wc_rounded,
            items: s.genderOptions,
            onChanged: (v) => setState(() => _selectedGender = v),
            validator: (v) =>
                (v == null || v.isEmpty) ? s.selectGender : null,
          ),
          const SizedBox(height: 16),
          // Date of Birth
          _buildLabel(s.dateOfBirth),
          const SizedBox(height: 8),
          _buildDatePicker(),
          const SizedBox(height: 24),
          // Work Experience section
          _sectionHeader(s.workExperience, Icons.work_outline_rounded),
          const SizedBox(height: 16),
          // Years of Experience
          _buildLabel(s.yearsOfExp),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _yearsExpController,
            hint: '0',
            icon: Icons.timer_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.yearsOfExp : null,
          ),
          const SizedBox(height: 16),
          // Previous Workplace
          _buildLabel(s.previousWorkplace),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _previousWorkplaceController,
            hint: s.companyHint,
            icon: Icons.business_outlined,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.companyHint : null,
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Documents ──────────────────────────────────────
  Widget _buildStep2(GuardRegistrationStrings s) {
    final docItems = [
      ('idCard', s.idCard, Icons.badge_outlined),
      ('securityLicense', s.securityLicense, Icons.verified_user_outlined),
      ('trainingCert', s.trainingCert, Icons.school_outlined),
      ('criminalCheck', s.criminalCheck, Icons.gavel_outlined),
      ('driverLicense', s.driverLicense, Icons.directions_car_outlined),
    ];

    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(s.uploadDocuments, Icons.description_outlined),
          const SizedBox(height: 8),
          Text(
            s.uploadDocumentsDesc,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...docItems.map((item) => _buildDocumentTile(
                key: item.$1,
                label: item.$2,
                icon: item.$3,
                fileName: _documents[item.$1]?.path.split('/').last,
                uploadLabel: s.uploadFile,
                notAttachedLabel: s.notAttached,
                previewFile: _documents[item.$1],
              )),
        ],
      ),
    );
  }

  // ─── Step 3: Bank Account ───────────────────────────────────
  Widget _buildStep3(GuardRegistrationStrings s) {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(s.bankDetails, Icons.account_balance_outlined),
          const SizedBox(height: 16),
          // Bank dropdown
          _buildLabel(s.bankName),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedBank,
            hint: s.selectBank,
            icon: Icons.account_balance_outlined,
            items: s.bankOptions,
            onChanged: (v) => setState(() => _selectedBank = v),
            validator: (v) =>
                (v == null || v.isEmpty) ? s.selectBank : null,
          ),
          const SizedBox(height: 16),
          // Account Number
          _buildLabel(s.accountNumber),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _accountNumberController,
            hint: s.accountNumberHint,
            icon: Icons.numbers_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 15,
            enableSuggestions: false,
            autocorrect: false,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.accountNumberHint : null,
          ),
          const SizedBox(height: 16),
          // Account Name
          _buildLabel(s.accountName),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _accountNameController,
            hint: s.accountNameHint,
            icon: Icons.person_outline_rounded,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return s.accountNameHint;
              if (v.trim() != _fullNameController.text.trim()) {
                return s.accountNameMustMatch;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Passbook Photo
          _buildLabel(s.passbookPhoto),
          const SizedBox(height: 8),
          _buildDocumentTile(
            key: 'passbook',
            label: s.passbookPhoto,
            icon: Icons.photo_camera_outlined,
            fileName: _passbookFile?.path.split('/').last,
            uploadLabel: s.uploadFile,
            notAttachedLabel: s.notAttached,
            previewFile: _passbookFile,
          ),
        ],
      ),
    );
  }

  // ─── Bottom Buttons ─────────────────────────────────────────
  Widget _buildBottomButtons(GuardRegistrationStrings s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            Expanded(
              child: GestureDetector(
                onTap: _prevStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          s.back,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          // Next / Submit button
          Expanded(
            flex: _currentStep > 0 ? 1 : 1,
            child: GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : (_currentStep < 2 ? _nextStep : _onSubmit),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isSubmitting
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '...',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep < 2
                                  ? s.next
                                  : s.submitApplication,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (_currentStep < 2) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Colors.white),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ─────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool enableSuggestions = true,
    bool autocorrect = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.border),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(
        hint,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.border),
      ),
      validator: validator,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary),
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
    );
  }

  Widget _buildDatePicker() {
    final isThai = LanguageProvider.of(context).isThai;
    final displayText = _dateOfBirth != null
        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
        : (isThai ? 'เลือกวันเกิด' : 'Select date');

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate:
              _dateOfBirth ?? DateTime(1990, 1, 1),
          firstDate: DateTime(1940),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.background,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _dateOfBirth = picked);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              displayText,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _dateOfBirth != null
                    ? AppColors.textPrimary
                    : AppColors.border,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile({
    required String key,
    required String label,
    required IconData icon,
    required String? fileName,
    required String uploadLabel,
    required String notAttachedLabel,
    File? previewFile,
  }) {
    final isAttached = fileName != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAttached
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isAttached
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isAttached ? AppColors.primary : AppColors.textSecondary,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAttached ? fileName : notAttachedLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isAttached
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isAttached)
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: AppColors.primary),
            ],
          ),
          // Thumbnail preview of the picked image.
          if (previewFile != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                previewFile,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              // Gallery picker
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickFile(key, ImageSource.gallery),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_file_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          uploadLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Camera picker
              GestureDetector(
                onTap: () => _pickFile(key, ImageSource.camera),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
