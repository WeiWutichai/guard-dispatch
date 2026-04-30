import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _genderController = TextEditingController();
  final _dobController = TextEditingController();
  final _experienceController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _pushNotif = true;
  bool _smsNotif = false;
  bool _jobAlerts = true;
  bool _initialized = false;
  bool _guardInfoSynced = false;
  bool _uploadingAvatar = false;
  bool _saving = false;
  final Set<String> _uploadingDocs = {};
  // Bank info — fetched separately via /profile/guard/info
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  // Snapshot original values to compute the dirty diff on save
  String? _origFullName;
  String? _origEmail;
  String? _origGender;
  String? _origDob;
  int? _origExperience;
  String? _origWorkplace;
  String? _origAddress;
  String? _origBankName;
  String? _origAccountNumber;
  String? _origAccountName;
  String? _origEmergencyName;
  String? _origEmergencyPhone;
  String? _origEmergencyRelationship;

  AuthProvider? _authProvider;
  void _onAuthChanged() {
    if (!mounted) return;
    final auth = _authProvider;
    if (auth == null) return;
    if (!_guardInfoSynced && auth.guardInfoLoaded) {
      _populateGuardInfoFields(auth);
      _guardInfoSynced = true;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _authProvider = auth;
      auth.addListener(_onAuthChanged);
      auth.fetchGuardDocs(force: true);
      auth.fetchGuardInfo(force: true);
      // If data already loaded (came back to screen), populate now.
      if (auth.guardInfoLoaded && !_guardInfoSynced) {
        _populateGuardInfoFields(auth);
        _guardInfoSynced = true;
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = context.read<AuthProvider>();
      _nameController.text = auth.fullName ?? '';
      _phoneController.text = auth.phone ?? '';
      _emailController.text = auth.email ?? '';
      _origFullName = auth.fullName;
      _origEmail = auth.email;
      _initialized = true;
    }
  }

  void _populateGuardInfoFields(AuthProvider auth) {
    _genderController.text = auth.gender ?? '';
    _dobController.text = auth.dateOfBirth ?? '';
    _experienceController.text = auth.yearsOfExperience?.toString() ?? '';
    _workplaceController.text = auth.previousWorkplace ?? '';
    _addressController.text = auth.guardAddress ?? '';
    _bankNameController.text = auth.bankName ?? '';
    _accountNumberController.text = auth.accountNumber ?? '';
    _accountNameController.text = auth.accountName ?? '';
    _emergencyNameController.text = auth.emergencyContactName ?? '';
    _emergencyPhoneController.text = auth.emergencyContactPhone ?? '';
    _relationshipController.text = auth.emergencyContactRelationship ?? '';
    _origGender = auth.gender;
    _origDob = auth.dateOfBirth;
    _origExperience = auth.yearsOfExperience;
    _origWorkplace = auth.previousWorkplace;
    _origAddress = auth.guardAddress;
    _origBankName = auth.bankName;
    _origAccountNumber = auth.accountNumber;
    _origAccountName = auth.accountName;
    _origEmergencyName = auth.emergencyContactName;
    _origEmergencyPhone = auth.emergencyContactPhone;
    _origEmergencyRelationship = auth.emergencyContactRelationship;
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _experienceController.dispose();
    _workplaceController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _relationshipController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = ProfileSettingsStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
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
                        'P-Guard',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        strings.appBarTitle,
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
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfilePhotoSection(strings),
                  const SizedBox(height: 20),
                  _buildPersonalInfoSection(strings),
                  const SizedBox(height: 20),
                  _buildGuardInfoSection(strings),
                  const SizedBox(height: 20),
                  _buildBankInfoSection(),
                  const SizedBox(height: 20),
                  _buildDocumentsSection(strings),
                  const SizedBox(height: 20),
                  _buildEmergencyContactSection(strings),
                  const SizedBox(height: 20),
                  _buildNotificationsSection(strings),
                  const SizedBox(height: 24),
                  _buildSaveButton(strings),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhotoSection(ProfileSettingsStrings strings) {
    final auth = context.watch<AuthProvider>();
    final avatarUrl = auth.avatarUrl;
    final isThai = LanguageProvider.of(context).isThai;

    // Format registration date
    String? registeredDate;
    if (auth.createdAt != null) {
      try {
        final dt = DateTime.parse(auth.createdAt!);
        registeredDate = DateFormat('d MMM yyyy').format(dt);
      } catch (_) {}
    }

    // Approval status
    final status = auth.approvalStatus;
    Color statusColor;
    String statusLabel;
    if (status == 'approved') {
      statusColor = const Color(0xFF34C759);
      statusLabel = isThai ? 'ใช้งาน' : 'Active';
    } else if (status == 'pending') {
      statusColor = Colors.amber;
      statusLabel = isThai ? 'รอการอนุมัติ' : 'Pending';
    } else {
      statusColor = Colors.red;
      statusLabel = isThai ? 'ถูกปฏิเสธ' : 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarUrl == null ? AppColors.primary.withValues(alpha: 0.1) : null,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3),
                    image: avatarUrl != null
                        ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                      : null,
                ),
                if (_uploadingAvatar)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            auth.fullName ?? '',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // Status badge + registration date
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (registeredDate != null) ...[
                const SizedBox(width: 10),
                Text(
                  registeredDate,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {},
            child: Text(
              strings.changePhoto,
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(ProfileSettingsStrings strings) {
    return _buildSection(
      title: strings.personalInfo,
      icon: Icons.person_outline_rounded,
      children: [
        _buildTextField(strings.fullName, _nameController),
        const SizedBox(height: 16),
        _buildTextField(strings.phone, _phoneController, keyboardType: TextInputType.phone, readOnly: true),
        const SizedBox(height: 16),
        _buildTextField(strings.email, _emailController, hint: strings.emailHint, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField(strings.address, _addressController, hint: strings.addressHint, maxLines: 2),
      ],
    );
  }

  Widget _buildGuardInfoSection(ProfileSettingsStrings strings) {
    final isThai = LanguageProvider.of(context).isThai;

    String genderDisplay() {
      final g = _genderController.text.toLowerCase();
      if (g == 'male') return isThai ? 'ชาย' : 'Male';
      if (g == 'female') return isThai ? 'หญิง' : 'Female';
      if (g == 'other') return isThai ? 'อื่น ๆ' : 'Other';
      return _genderController.text;
    }

    String dobDisplay() {
      try {
        if (_dobController.text.isEmpty) return '';
        return DateFormat('d MMM yyyy').format(DateTime.parse(_dobController.text));
      } catch (_) {
        return _dobController.text;
      }
    }

    return _buildSection(
      title: strings.guardInfo,
      icon: Icons.shield_outlined,
      children: [
        GestureDetector(
          onTap: _pickGender,
          child: AbsorbPointer(
            child: _buildTextField(
              strings.gender,
              TextEditingController(text: genderDisplay()),
              readOnly: false,
              hint: isThai ? 'แตะเพื่อเลือก' : 'Tap to select',
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickDob,
          child: AbsorbPointer(
            child: _buildTextField(
              strings.dateOfBirth,
              TextEditingController(text: dobDisplay()),
              readOnly: false,
              hint: isThai ? 'แตะเพื่อเลือก' : 'Tap to select',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(strings.yearsOfExperience, _experienceController,
            keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTextField(strings.previousWorkplace, _workplaceController),
      ],
    );
  }

  Widget _buildBankInfoSection() {
    final isThai = LanguageProvider.of(context).isThai;
    return _buildSection(
      title: isThai ? 'ข้อมูลธนาคาร' : 'Bank Information',
      icon: Icons.account_balance_rounded,
      children: [
        _buildTextField(
          isThai ? 'ชื่อธนาคาร' : 'Bank name',
          _bankNameController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          isThai ? 'เลขบัญชี' : 'Account number',
          _accountNumberController,
          keyboardType: TextInputType.number,
          hint: isThai
              ? 'พิมพ์เลขบัญชีใหม่เพื่อเปลี่ยน'
              : 'Type new number to change',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          isThai ? 'ชื่อบัญชี' : 'Account name',
          _accountNameController,
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(ProfileSettingsStrings strings) {
    final isThai = LanguageProvider.of(context).isThai;
    final auth = context.watch<AuthProvider>();
    final docs = auth.guardDocUrls;

    final docItems = <_DocItem>[
      _DocItem(
        key: 'id_card',
        label: isThai ? 'บัตรประชาชน' : 'ID Card',
        icon: Icons.badge_rounded,
      ),
      _DocItem(
        key: 'security_license',
        label: isThai ? 'ใบอนุญาตรักษาความปลอดภัย' : 'Security License',
        icon: Icons.verified_user_rounded,
      ),
      _DocItem(
        key: 'training_cert',
        label: isThai ? 'ใบรับรองการฝึกอบรม' : 'Training Certificate',
        icon: Icons.school_rounded,
      ),
      _DocItem(
        key: 'criminal_check',
        label: isThai ? 'ใบผ่านการตรวจสอบประวัติอาชญากรรม' : 'Criminal Background Check',
        icon: Icons.policy_rounded,
      ),
      _DocItem(
        key: 'driver_license',
        label: isThai ? 'ใบขับขี่' : "Driver's License",
        icon: Icons.drive_eta_rounded,
      ),
    ];

    return _buildSection(
      title: isThai ? 'เอกสารที่แนบมา' : 'Attached Documents',
      icon: Icons.folder_rounded,
      children: [
        if (!auth.docsLoaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          )
        else
          ...docItems.map((item) {
            final url = docs[item.key];
            final hasDoc = url != null && url.isNotEmpty;
            final expiry = auth.guardDocExpiry[item.key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 20, color: hasDoc ? AppColors.primary : AppColors.disabled),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: hasDoc ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            if (hasDoc && expiry != null)
                              Text(
                                '${isThai ? "หมดอายุ" : "Exp"}: ${_formatExpiry(expiry)}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      if (hasDoc) ...[
                        if (_uploadingDocs.contains(item.key))
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () => expiry == null
                                ? _pickDocExpiry(item.key, null)
                                : _showDocActionSheet(item.key, expiry, item.label),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: expiry != null ? AppColors.primary.withValues(alpha: 0.08) : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                expiry != null
                                    ? (isThai ? 'แก้ไข' : 'Edit')
                                    : (isThai ? 'กำหนดวันหมดอายุ' : 'Set expiry'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: expiry != null ? AppColors.primary : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showDocumentPreview(context, item.label, url),
                          child: Text(
                            isThai ? 'ดูเอกสาร' : 'View',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ] else
                        Text(
                          isThai ? 'ยังไม่ได้อัพโหลด' : 'Not uploaded',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.disabled),
                        ),
                    ],
                  ),
                  if (hasDoc) const Divider(height: 12, color: AppColors.border),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _formatExpiry(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _pickDocExpiry(String docKey, String? currentExpiry) async {
    final now = DateTime.now();
    DateTime initial;
    try {
      initial = currentExpiry != null ? DateTime.parse(currentExpiry) : now.add(const Duration(days: 365));
    } catch (_) {
      initial = now.add(const Duration(days: 365));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
    if (picked == null || !mounted) return;
    final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      await context.read<AuthProvider>().updateDocExpiry({'${docKey}_expiry': dateStr});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageProvider.of(context).isThai ? 'บันทึกวันหมดอายุสำเร็จ' : 'Expiry date saved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatApiError(e, isThai)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      await context.read<AuthProvider>().uploadAvatar(File(picked.path));
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'อัปโหลดรูปโปรไฟล์สำเร็จ' : 'Avatar updated'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatApiError(e, isThai)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  /// Turn the raw Dio/exception into a message the guard can act on.
  /// Surfaces the server's `error.message` when the response is JSON, falls back
  /// to the HTTP status code, and only reveals a generic phrase for network-level
  /// failures. Helps diagnose silent 4xx/5xx from `PUT /auth/guards/me/expiry`.
  String _formatApiError(Object e, bool isThai) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (data['message'] is String) {
          return data['message'] as String;
        }
      }
      final status = e.response?.statusCode;
      if (status != null) {
        return isThai
            ? 'บันทึกไม่สำเร็จ (HTTP $status)'
            : 'Save failed (HTTP $status)';
      }
      return isThai
          ? 'เครือข่ายขัดข้อง โปรดลองอีกครั้ง'
          : 'Network error, please try again';
    }
    return isThai ? 'บันทึกไม่สำเร็จ: $e' : 'Save failed: $e';
  }

  void _showDocumentPreview(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            // Image
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              width: double.infinity,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                },
                errorBuilder: (context2, error, stackTrace) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.disabled),
                        const SizedBox(height: 8),
                        Text(
                          LanguageProvider.of(context).isThai
                              ? 'ไม่สามารถโหลดรูปภาพได้'
                              : 'Unable to load image',
                          style: GoogleFonts.inter(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactSection(ProfileSettingsStrings strings) {
    return _buildSection(
      title: strings.emergencyContact,
      icon: Icons.emergency_outlined,
      children: [
        _buildTextField(strings.contactName, _emergencyNameController, hint: strings.contactNameHint),
        const SizedBox(height: 16),
        _buildTextField(strings.contactPhone, _emergencyPhoneController, hint: strings.contactPhoneHint, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildTextField(strings.relationship, _relationshipController, hint: strings.relationshipHint),
      ],
    );
  }

  Widget _buildNotificationsSection(ProfileSettingsStrings strings) {
    return _buildSection(
      title: strings.notifications,
      icon: Icons.notifications_outlined,
      children: [
        _buildToggleRow(strings.pushNotif, strings.pushNotifDesc, _pushNotif, (v) => setState(() => _pushNotif = v)),
        const Divider(height: 24),
        _buildToggleRow(strings.smsNotif, strings.smsNotifDesc, _smsNotif, (v) => setState(() => _smsNotif = v)),
        const Divider(height: 24),
        _buildToggleRow(strings.jobAlerts, strings.jobAlertsDesc, _jobAlerts, (v) => setState(() => _jobAlerts = v)),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14),
            filled: true,
            fillColor: readOnly ? const Color(0xFFEEEEEE) : AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: BorderSide(color: readOnly ? AppColors.border : AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSaveButton(ProfileSettingsStrings strings) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                strings.saveChanges,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _onSave() async {
    final auth = context.read<AuthProvider>();
    final isThai = LanguageProvider.of(context).isThai;

    // Build the dirty diff for `PUT /me` (auth.users) and
    // `PUT /profile/guard/info` (auth.guard_profiles).
    final mePatch = <String, dynamic>{};
    final guardPatch = <String, dynamic>{};

    final newName = _nameController.text.trim();
    if (newName != (_origFullName ?? '')) {
      if (newName.isEmpty) {
        _showError(isThai ? 'กรุณากรอกชื่อ' : 'Please enter a name');
        return;
      }
      mePatch['full_name'] = newName;
    }
    final newEmail = _emailController.text.trim();
    if (newEmail != (_origEmail ?? '')) {
      if (newEmail.isNotEmpty &&
          (!newEmail.contains('@') || !newEmail.contains('.'))) {
        _showError(isThai ? 'อีเมลไม่ถูกต้อง' : 'Invalid email');
        return;
      }
      mePatch['email'] = newEmail;
    }

    if (_genderController.text != (_origGender ?? '')) {
      guardPatch['gender'] = _genderController.text;
    }
    if (_dobController.text != (_origDob ?? '')) {
      guardPatch['date_of_birth'] = _dobController.text;
    }
    final exp = int.tryParse(_experienceController.text);
    if (exp != _origExperience) {
      guardPatch['years_of_experience'] = exp;
    }
    if (_workplaceController.text.trim() != (_origWorkplace ?? '')) {
      guardPatch['previous_workplace'] = _workplaceController.text.trim();
    }
    if (_addressController.text.trim() != (_origAddress ?? '')) {
      guardPatch['address'] = _addressController.text.trim();
    }
    if (_bankNameController.text.trim() != (_origBankName ?? '')) {
      guardPatch['bank_name'] = _bankNameController.text.trim();
    }
    // Account number is masked on read; only send when user typed something
    // that doesn't contain '*' (mask character) and differs from the original.
    final acctNumInput = _accountNumberController.text.trim();
    if (!acctNumInput.contains('*') &&
        acctNumInput != (_origAccountNumber ?? '')) {
      guardPatch['account_number'] = acctNumInput;
    }
    if (_accountNameController.text.trim() != (_origAccountName ?? '')) {
      guardPatch['account_name'] = _accountNameController.text.trim();
    }
    if (_emergencyNameController.text.trim() != (_origEmergencyName ?? '')) {
      guardPatch['emergency_contact_name'] =
          _emergencyNameController.text.trim();
    }
    if (_emergencyPhoneController.text.trim() != (_origEmergencyPhone ?? '')) {
      guardPatch['emergency_contact_phone'] =
          _emergencyPhoneController.text.trim();
    }
    if (_relationshipController.text.trim() !=
        (_origEmergencyRelationship ?? '')) {
      guardPatch['emergency_contact_relationship'] =
          _relationshipController.text.trim();
    }

    if (mePatch.isEmpty && guardPatch.isEmpty) {
      _showInfo(isThai ? 'ไม่มีการเปลี่ยนแปลง' : 'Nothing changed');
      return;
    }

    setState(() => _saving = true);
    try {
      if (mePatch.isNotEmpty) {
        await auth.updateUserProfile(
          fullName: mePatch['full_name'] as String?,
          email: mePatch['email'] as String?,
        );
      }
      if (guardPatch.isNotEmpty) {
        await auth.updateGuardInfo(guardPatch);
      }
      // Refresh originals to reflect saved state
      _origFullName = auth.fullName;
      _origEmail = auth.email;
      _origGender = auth.gender;
      _origDob = auth.dateOfBirth;
      _origExperience = auth.yearsOfExperience;
      _origWorkplace = auth.previousWorkplace;
      _origAddress = auth.guardAddress;
      _origBankName = auth.bankName;
      _origAccountNumber = auth.accountNumber;
      _origAccountName = auth.accountName;
      _origEmergencyName = auth.emergencyContactName;
      _origEmergencyPhone = auth.emergencyContactPhone;
      _origEmergencyRelationship = auth.emergencyContactRelationship;
      // Re-sync masked account number from the server
      _accountNumberController.text = auth.accountNumber ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'บันทึกข้อมูลสำเร็จ' : 'Saved'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError(_formatApiError(e, isThai));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickGender() async {
    final isThai = LanguageProvider.of(context).isThai;
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(isThai ? 'ชาย' : 'Male'),
              onTap: () => Navigator.pop(ctx, 'male'),
            ),
            ListTile(
              title: Text(isThai ? 'หญิง' : 'Female'),
              onTap: () => Navigator.pop(ctx, 'female'),
            ),
            ListTile(
              title: Text(isThai ? 'อื่น ๆ' : 'Other'),
              onTap: () => Navigator.pop(ctx, 'other'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _genderController.text = selected);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    DateTime initial = now.subtract(const Duration(days: 365 * 25));
    if (_dobController.text.isNotEmpty) {
      try {
        initial = DateTime.parse(_dobController.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now,
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
    if (picked == null || !mounted) return;
    final iso =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _dobController.text = iso);
  }

  Future<void> _pickAndUploadDocument(String docKey) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingDocs.add(docKey));
    try {
      await context
          .read<AuthProvider>()
          .uploadGuardDocument(docKey, File(picked.path));
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isThai ? 'เปลี่ยนรูปเอกสารสำเร็จ' : 'Document replaced'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isThai = LanguageProvider.of(context).isThai;
        _showError(_formatApiError(e, isThai));
      }
    } finally {
      if (mounted) setState(() => _uploadingDocs.remove(docKey));
    }
  }

  Future<void> _showDocActionSheet(
    String docKey,
    String? expiry,
    String docLabel,
  ) async {
    final isThai = LanguageProvider.of(context).isThai;
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                docLabel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: AppColors.primary),
              title: Text(
                isThai ? 'เปลี่ยนรูปเอกสาร' : 'Replace image',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_rounded,
                  color: AppColors.primary),
              title: Text(
                isThai ? 'แก้ไขวันหมดอายุ' : 'Edit expiry date',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(ctx, 'expiry'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'replace') {
      await _pickAndUploadDocument(docKey);
    } else if (action == 'expiry') {
      await _pickDocExpiry(docKey, expiry);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DocItem {
  final String key;
  final String label;
  final IconData icon;
  const _DocItem({required this.key, required this.label, required this.icon});
}
