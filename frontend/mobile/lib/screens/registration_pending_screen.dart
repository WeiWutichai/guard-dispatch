import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/auth_provider.dart';
import '../services/language_service.dart';
import '../services/auth_service.dart';
import '../services/pin_storage_service.dart';
import '../l10n/app_strings.dart';
import 'guard_registration_screen.dart';
import 'guard/guard_dashboard_screen.dart';
import 'hirer/hirer_dashboard_screen.dart';

class RegistrationPendingScreen extends StatefulWidget {
  const RegistrationPendingScreen({super.key});

  @override
  State<RegistrationPendingScreen> createState() =>
      _RegistrationPendingScreenState();
}

class _RegistrationPendingScreenState extends State<RegistrationPendingScreen> {
  Map<String, dynamic>? _profile;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Attempt login with stored phone + PIN hash.
  /// If approved → navigate to dashboard. If still pending → show message.
  Future<void> _checkApprovalStatus(RegistrationPendingStrings strings) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    // Capture providers before async gap
    final pinService = context.read<PinStorageService>();
    final authProvider = context.read<AuthProvider>();

    try {
      // Fall back to profile data for users registered before storePhone() was added.
      var phone = await AuthService.getStoredPhone();
      phone ??= _profile?['phone'] as String?;
      final pinHash = pinService.getStoredPinHash();

      if (phone == null || pinHash == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.checkStatusError),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      await authProvider.loginWithPhone(phone, pinHash);

      if (!mounted) return;

      // Login succeeded — user is approved. Navigate to dashboard.
      final role = authProvider.role;
      final Widget dashboard = role == 'guard'
          ? const GuardDashboardScreen()
          : const HirerDashboardScreen();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
        (route) => false,
      );
    } on DioException {
      // Login failed — still pending or rejected
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.notYetApproved),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _navigateToEdit(RegistrationPendingStrings strings) async {
    final phone = _profile?['phone'] as String?;
    if (phone == null || phone.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(strings.editDialogTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(strings.editDialogMessage,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.editDialogCancel,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.editDialogConfirm,
                style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => GuardRegistrationScreen(
          phone: phone,
          initialProfile: _profile,
          dashboard: const GuardDashboardScreen(),
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _loadProfile() async {
    final data = await AuthService.getPendingProfile();
    if (mounted && data != null) {
      setState(() => _profile = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = RegistrationPendingStrings(isThai: isThai);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          // Hourglass icon
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            strings.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            strings.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Detail card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              strings.detail,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          // Profile data cards (shown after guard form submission)
                          if (_profile != null) ...[
                            const SizedBox(height: 14),
                            _buildProfileCard(strings),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  // Check approval status button — tries login with phone + PIN hash
                  GestureDetector(
                    onTap: _isChecking ? null : () => _checkApprovalStatus(strings),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isChecking ? AppColors.primary.withValues(alpha: 0.6) : AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isChecking
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              strings.checkStatus,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Edit profile button — navigate to guard form with pre-filled data
                  GestureDetector(
                    onTap: () => _navigateToEdit(strings),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Text(
                        strings.editButton,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(RegistrationPendingStrings strings) {
    final p = _profile!;
    String? s(String key) {
      final v = p[key] as String?;
      return (v != null && v.isNotEmpty) ? v : null;
    }

    return Column(
      children: [
        // ── Personal info ──
        _buildSection(strings.appDataTitle, Icons.person_outline_rounded, [
          if (s('full_name') != null)
            _ProfileRow(Icons.badge_outlined, strings.fieldName, s('full_name')!),
          if (s('gender') != null)
            _ProfileRow(Icons.wc_rounded, strings.fieldGender, s('gender')!),
          if (s('years_of_experience') != null)
            _ProfileRow(Icons.work_outline_rounded, strings.fieldExperience,
                '${s('years_of_experience')} ${strings.years}'),
          if (s('previous_workplace') != null)
            _ProfileRow(Icons.business_outlined, strings.fieldWorkplace, s('previous_workplace')!),
        ]),
        const SizedBox(height: 10),
        // ── Documents ──
        _buildDocSection(strings, p),
        const SizedBox(height: 10),
        // ── Bank account ──
        _buildSection(strings.bankTitle, Icons.account_balance_outlined, [
          if (s('bank_name') != null)
            _ProfileRow(Icons.account_balance_outlined, strings.fieldBank, s('bank_name')!),
          if (s('account_number') != null)
            _ProfileRow(Icons.credit_card_outlined, strings.fieldAccountNumber,
                _maskAccount(s('account_number')!)),
          if (s('account_name') != null)
            _ProfileRow(Icons.person_outline_rounded, strings.fieldAccountName, s('account_name')!),
        ]),
      ],
    );
  }

  String _maskAccount(String acc) {
    if (acc.length <= 4) return acc;
    return '${'*' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }

  Widget _buildSection(String title, IconData icon, List<_ProfileRow> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title),
          const SizedBox(height: 10),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(row.icon, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('${row.label}: ',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                Expanded(
                  child: Text(row.value,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDocSection(RegistrationPendingStrings strings, Map<String, dynamic> p) {
    final docs = [
      _DocRow(strings.docIdCard, p['doc_id_card'] as String?),
      _DocRow(strings.docSecurityLicense, p['doc_security_license'] as String?),
      _DocRow(strings.docTrainingCert, p['doc_training_cert'] as String?),
      _DocRow(strings.docCriminalCheck, p['doc_criminal_check'] as String?),
      _DocRow(strings.docDriverLicense, p['doc_driver_license'] as String?),
      _DocRow(strings.docPassbook, p['doc_passbook'] as String?),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.folder_outlined, strings.documentsTitle),
          const SizedBox(height: 10),
          ...docs.map((doc) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  doc.filename != null
                      ? Icons.check_circle_outline_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: doc.filename != null ? AppColors.primary : AppColors.border,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(doc.label,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: doc.filename != null
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    doc.filename != null ? strings.docAttached : strings.docNotAttached,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: doc.filename != null ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 15, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(title,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
    ],
  );
}

class _ProfileRow {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileRow(this.icon, this.label, this.value);
}

class _DocRow {
  final String label;
  final String? filename;
  const _DocRow(this.label, this.filename);
}
