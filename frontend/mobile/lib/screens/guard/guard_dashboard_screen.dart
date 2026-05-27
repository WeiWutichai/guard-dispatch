import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';
import 'tabs/guard_home_tab.dart';
import 'tabs/guard_jobs_tab.dart';
import 'tabs/guard_income_tab.dart';
import 'tabs/guard_profile_tab.dart';
import '../chat_list_screen.dart';

class GuardDashboardScreen extends StatefulWidget {
  const GuardDashboardScreen({super.key});

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  int _currentIndex = 0;

  late final List<Widget> _tabs = [
    GuardHomeTab(onSwitchTab: _switchTab),
    const GuardJobsTab(),
    const ChatListScreen(actingRole: 'guard'),
    const GuardIncomeTab(),
    const GuardProfileTab(),
  ];

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });

    // BUG-022. IndexedStack keeps every child mounted, so each tab's
    // initState fires exactly once at dashboard mount. When data
    // changes server-side while another tab is active (e.g. new
    // pending_acceptance arrives via FCM while user is on home tab),
    // the receiving tab's cached list stays stale on switch-in.
    // Refresh the provider's relevant slice on switch so the tab
    // the user lands on reflects current state.
    //
    // Fire-and-forget — notifyListeners() inside the fetchers drives
    // the tab's rebuild when data arrives.
    if (index == 1) {
      context.read<BookingProvider>().fetchJobs();
    } else if (index == 0) {
      context.read<BookingProvider>().fetchDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final strings = GuardDashboardStrings(isThai: isThai);

    return PopScope(
      canPop: false,
      child: Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          // BUG-022. Route through _switchTab so bottom-bar taps get
          // the same refresh-on-switch behavior as the home-tile
          // "ดูงานใหม่" button (which already calls _switchTab).
          onTap: _switchTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: strings.navHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment_rounded),
              label: strings.navJobs,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: const Icon(Icons.chat_bubble_rounded),
              label: strings.navChat,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet_rounded),
              label: strings.navIncome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person_rounded),
              label: strings.navMore,
            ),
          ],
        ),
      ),
    ),
    );
  }
}
