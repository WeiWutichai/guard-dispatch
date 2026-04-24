import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: fetch guard document URLs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchGuardDocs(force: true);
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
      _genderController.text = auth.gender ?? '';
      _dobController.text = auth.dateOfBirth ?? '';
      _experienceController.text =
          auth.yearsOfExperience?.toString() ?? '';
      _workplaceController.text = auth.previousWorkplace ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
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
          Stack(
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
    // Format date_of_birth for display
    if (_dobController.text.isNotEmpty && _dobController.text.contains('-')) {
      try {
        final dt = DateTime.parse(_dobController.text);
        _dobController.text = DateFormat('d MMM yyyy').format(dt);
      } catch (_) {}
    }
    // Translate gender for display
    if (_genderController.text.isNotEmpty) {
      final g = _genderController.text.toLowerCase();
      if (g == 'male' || g == 'ชาย') {
        _genderController.text = isThai ? 'ชาย' : 'Male';
      } else if (g == 'female' || g == 'หญิง') {
        _genderController.text = isThai ? 'หญิง' : 'Female';
      }
    }

    return _buildSection(
      title: strings.guardInfo,
      icon: Icons.shield_outlined,
      children: [
        _buildTextField(strings.gender, _genderController, readOnly: true),
        const SizedBox(height: 16),
        _buildTextField(strings.dateOfBirth, _dobController, readOnly: true),
        const SizedBox(height: 16),
        _buildTextField(strings.yearsOfExperience, _experienceController, keyboardType: TextInputType.number, readOnly: true),
        const SizedBox(height: 16),
        _buildTextField(strings.previousWorkplace, _workplaceController, readOnly: true),
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
                        GestureDetector(
                          onTap: () => _pickDocExpiry(item.key, expiry),
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
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          strings.saveChanges,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
