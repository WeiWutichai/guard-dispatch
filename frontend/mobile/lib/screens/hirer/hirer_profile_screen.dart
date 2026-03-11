import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import '../phone_input_screen.dart';
import 'hirer_profile_settings_screen.dart';
import '../guard/contact_support_screen.dart';
import '../notification_screen.dart';

class HirerProfileScreen extends StatelessWidget {
  const HirerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = HirerProfileStrings(isThai: isThai);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: topPadding + 8),
            // Large title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                s.profileHeader,
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile card
            _buildProfileCard(context, s),
            const SizedBox(height: 24),

            // Account section
            _buildSettingsGroup(context, [
              _SettingsItem(
                icon: Icons.person_rounded,
                iconBg: AppColors.primary,
                title: s.editProfile,
                onTap: () =>
                    _navigateTo(context, const HirerProfileSettingsScreen()),
              ),
              _SettingsItem(
                icon: Icons.location_on_rounded,
                iconBg: const Color(0xFF5856D6),
                title: s.savedLocations,
                onTap: () => _showComingSoon(context, s.savedLocations),
              ),
              _SettingsItem(
                icon: Icons.credit_card_rounded,
                iconBg: const Color(0xFFFF9500),
                title: s.paymentMethods,
                onTap: () => _showComingSoon(context, s.paymentMethods),
              ),
            ]),
            const SizedBox(height: 24),

            // Security & Notifications
            _buildSettingsGroup(context, [
              _SettingsItem(
                icon: Icons.lock_rounded,
                iconBg: const Color(0xFFFF3B30),
                title: s.changePin,
                onTap: () => _showComingSoon(context, s.changePin),
              ),
              _SettingsItem(
                icon: Icons.notifications_rounded,
                iconBg: const Color(0xFFFF3B30),
                title: s.notifications,
                onTap: () => _navigateTo(
                  context,
                  const NotificationScreen(isGuard: false),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Support
            _buildSettingsGroup(context, [
              _SettingsItem(
                icon: Icons.help_rounded,
                iconBg: const Color(0xFF34C759),
                title: s.support,
                onTap: () => _navigateTo(context, const ContactSupportScreen()),
              ),
            ]),
            const SizedBox(height: 24),

            // Logout
            _buildLogoutButton(context, s),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, HirerProfileStrings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _navigateTo(context, const HirerProfileSettingsScreen()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Builder(builder: (context) {
                final avatarUrl = context.watch<AuthProvider>().avatarUrl;
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
                    color: avatarUrl == null ? AppColors.primary.withValues(alpha: 0.1) : null,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? const Icon(Icons.person_rounded, size: 32, color: AppColors.primary)
                      : null,
                );
              }),
              const SizedBox(width: 14),
              Expanded(
                child: Builder(builder: (context) {
                  final auth = context.watch<AuthProvider>();
                  final phoneDisplay = auth.phone != null
                      ? 'ID: ${auth.phone!.replaceAllMapped(RegExp(r'(\d{3})(\d{3})(\d{4})'), (m) => '${m[1]}-${m[2]}-${m[3]}')}'
                      : s.sampleHirerCode;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.customerFullName ?? auth.fullName ?? s.sampleHirerName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phoneDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      if (auth.companyName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          auth.companyName!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC7C7CC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<_SettingsItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: item.iconBg,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(item.icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFC7C7CC),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: Container(
                      height: 0.5,
                      color: const Color(0xFFE5E5EA),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, HirerProfileStrings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          await context.read<AuthProvider>().logout();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
            (route) => false,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              s.logout,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFFFF3B30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final Color iconBg;
  final String title;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.onTap,
  });
}
