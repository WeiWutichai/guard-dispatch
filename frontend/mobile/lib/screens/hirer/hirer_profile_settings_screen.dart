import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

class HirerProfileSettingsScreen extends StatefulWidget {
  const HirerProfileSettingsScreen({super.key});

  @override
  State<HirerProfileSettingsScreen> createState() =>
      _HirerProfileSettingsScreenState();
}

class _HirerProfileSettingsScreenState
    extends State<HirerProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();

  bool _pushNotif = true;
  bool _smsNotif = false;
  bool _bookingAlerts = true;

  // Guard info controllers (for dual-role users)
  final _genderController = TextEditingController();
  final _dobController = TextEditingController();
  final _experienceController = TextEditingController();
  final _workplaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.customerFullName ?? auth.fullName ?? '';
    _phoneController.text = auth.phone ?? '';
    _companyController.text = auth.companyName ?? '';
    _addressController.text = auth.customerAddress ?? '';

    // Populate guard fields if dual-role user
    _genderController.text = auth.gender ?? '';
    _dobController.text = auth.dateOfBirth ?? '';
    _experienceController.text = auth.yearsOfExperience?.toString() ?? '';
    _workplaceController.text = auth.previousWorkplace ?? '';

    // Fetch guard document URLs if user has guard data
    if (auth.gender != null || auth.fullName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AuthProvider>().fetchGuardDocs(force: true);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _experienceController.dispose();
    _workplaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = HirerProfileSettingsStrings(isThai: isThai);

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
                  // Guard info & documents for dual-role users
                  ..._buildGuardSections(context),
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

  Widget _buildProfilePhotoSection(HirerProfileSettingsStrings strings) {
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
              Builder(builder: (context) {
                final avatarUrl = context.watch<AuthProvider>().avatarUrl;
                return Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                      : null,
                );
              }),
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
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

  Widget _buildPersonalInfoSection(HirerProfileSettingsStrings strings) {
    return _buildSection(
      title: strings.personalInfo,
      icon: Icons.person_outline_rounded,
      children: [
        _buildTextField(strings.fullName, _nameController),
        const SizedBox(height: 16),
        _buildTextField(
          strings.phone,
          _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          strings.email,
          _emailController,
          hint: strings.emailHint,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          strings.company,
          _companyController,
          hint: strings.companyHint,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          strings.address,
          _addressController,
          hint: strings.addressHint,
          maxLines: 2,
        ),
      ],
    );
  }

  // ─── Guard Info & Documents (dual-role users only) ───────────────────────

  List<Widget> _buildGuardSections(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasGuardData = auth.gender != null ||
        auth.dateOfBirth != null ||
        auth.yearsOfExperience != null ||
        auth.guardDocUrls.isNotEmpty;
    if (!hasGuardData) return [];

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

    return [
      const SizedBox(height: 20),
      _buildSection(
        title: isThai ? 'ข้อมูลเจ้าหน้าที่ รปภ.' : 'Guard Information',
        icon: Icons.shield_outlined,
        children: [
          _buildReadOnlyField(isThai ? 'เพศ' : 'Gender', _genderController),
          const SizedBox(height: 16),
          _buildReadOnlyField(isThai ? 'วันเกิด' : 'Date of Birth', _dobController),
          const SizedBox(height: 16),
          _buildReadOnlyField(
            isThai ? 'ประสบการณ์ (ปี)' : 'Years of Experience',
            _experienceController,
          ),
          const SizedBox(height: 16),
          _buildReadOnlyField(
            isThai ? 'สถานที่ทำงานเดิม' : 'Previous Workplace',
            _workplaceController,
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildGuardDocumentsSection(context),
    ];
  }

  Widget _buildGuardDocumentsSection(BuildContext context) {
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
      title: isThai ? 'เอกสารเจ้าหน้าที่' : 'Guard Documents',
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 20, color: hasDoc ? AppColors.primary : AppColors.disabled),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: hasDoc ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (hasDoc)
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
                        )
                      else
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

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
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
          readOnly: true,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFEEEEEE),
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
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  void _showDocumentPreview(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                errorBuilder: (_, error, stackTrace) => SizedBox(
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

  Widget _buildNotificationsSection(HirerProfileSettingsStrings strings) {
    return _buildSection(
      title: strings.notifications,
      icon: Icons.notifications_outlined,
      children: [
        _buildToggleRow(
          strings.pushNotif,
          strings.pushNotifDesc,
          _pushNotif,
          (v) => setState(() => _pushNotif = v),
        ),
        const Divider(height: 24),
        _buildToggleRow(
          strings.smsNotif,
          strings.smsNotifDesc,
          _smsNotif,
          (v) => setState(() => _smsNotif = v),
        ),
        const Divider(height: 24),
        _buildToggleRow(
          strings.bookingAlerts,
          strings.bookingAlertsDesc,
          _bookingAlerts,
          (v) => setState(() => _bookingAlerts = v),
        ),
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
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 14,
            ),
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
        ),
      ],
    );
  }

  Widget _buildToggleRow(
    String title,
    String desc,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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

  Widget _buildSaveButton(HirerProfileSettingsStrings strings) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
