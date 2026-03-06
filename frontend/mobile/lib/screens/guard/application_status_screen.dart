import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getPendingProfile();
    if (mounted) setState(() { _profile = profile; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = AppStatusStrings(isThai: isThai);
    final auth = context.watch<AuthProvider>();

    final p = _profile ?? {};
    final name = auth.fullName ?? p['full_name'] as String? ?? '-';
    final gender = p['gender'] as String? ?? '-';
    final dob = p['date_of_birth'] as String? ?? '-';
    final exp = p['years_of_experience'] as String? ?? '-';
    final workplace = p['previous_workplace'] as String? ?? '-';
    final bank = p['bank_name'] as String? ?? '-';
    final accountNum = p['account_number'] as String? ?? '-';
    final accountName = p['account_name'] as String? ?? name;

    // Derive status from AuthProvider — approved users are authenticated
    final String status;
    if (auth.isAuthenticated) {
      status = 'approved';
    } else if (auth.isPendingApproval) {
      status = 'pending';
    } else {
      status = 'pending';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.deepBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          strings.appBarTitle,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatusHeader(strings, status, ''),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPersonalInfoCard(strings, name, gender, dob, exp, workplace),
                        const SizedBox(height: 16),
                        _buildDocumentsCard(strings),
                        const SizedBox(height: 16),
                        _buildBankCard(strings, bank, accountNum, accountName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusHeader(AppStatusStrings strings, String status, String submittedDate) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    final String statusDesc;

    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusText = strings.statusApproved;
        statusDesc = strings.approvedDesc;
        break;
      case 'rejected':
        statusColor = AppColors.danger;
        statusIcon = Icons.cancel_rounded;
        statusText = strings.statusRejected;
        statusDesc = strings.rejectedDesc;
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top_rounded;
        statusText = strings.statusPending;
        statusDesc = strings.pendingDesc;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 44),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusDesc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                '${strings.submittedOn} $submittedDate',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(
    AppStatusStrings strings,
    String name,
    String gender,
    String dob,
    String exp,
    String workplace,
  ) {
    return _buildCard(
      icon: Icons.person_outline_rounded,
      title: strings.personalInfo,
      children: [
        _buildInfoRow(strings.fullName, name),
        _buildInfoRow(strings.gender, gender),
        _buildInfoRow(strings.dateOfBirth, dob),
        _buildInfoRow(strings.experience, '$exp ${strings.yearsUnit}'),
        _buildInfoRow(strings.previousWorkplace, workplace, isLast: true),
      ],
    );
  }

  Widget _buildDocumentsCard(AppStatusStrings strings) {
    final docs = [
      {'label': strings.idCard, 'uploaded': true},
      {'label': strings.securityLicense, 'uploaded': true},
      {'label': strings.trainingCert, 'uploaded': true},
      {'label': strings.criminalCheck, 'uploaded': true},
      {'label': strings.driverLicense, 'uploaded': true},
      {'label': strings.passbookPhoto, 'uploaded': true},
    ];

    return _buildCard(
      icon: Icons.folder_outlined,
      title: strings.documents,
      children: docs.asMap().entries.map((entry) {
        final doc = entry.value;
        final isLast = entry.key == docs.length - 1;
        final isUploaded = doc['uploaded'] as bool;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: isUploaded ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  doc['label'] as String,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              Text(
                isUploaded ? strings.uploaded : strings.notUploaded,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isUploaded ? AppColors.success : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBankCard(
    AppStatusStrings strings,
    String bank,
    String accountNum,
    String accountName,
  ) {
    return _buildCard(
      icon: Icons.account_balance_outlined,
      title: strings.bankAccount,
      children: [
        _buildInfoRow(strings.bankName, bank),
        _buildInfoRow(strings.accountNumber, accountNum),
        _buildInfoRow(strings.accountName, accountName, isLast: true),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
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
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
