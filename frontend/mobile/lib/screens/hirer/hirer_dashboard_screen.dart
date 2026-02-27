import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import 'service_selection_screen.dart';
import '../chat_list_screen.dart';
import 'hirer_history_screen.dart';
import 'hirer_profile_screen.dart';

class HirerDashboardScreen extends StatefulWidget {
  const HirerDashboardScreen({super.key});

  @override
  State<HirerDashboardScreen> createState() => _HirerDashboardScreenState();
}

class _HirerDashboardScreenState extends State<HirerDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ServiceSelectionScreen(),
    const ChatListScreen(),
    const HirerHistoryScreen(),
    const HirerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
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
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: isThai ? 'หน้าแรก' : 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_rounded),
              label: isThai ? 'ข้อความ' : 'Messages',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_rounded),
              label: isThai ? 'ประวัติ' : 'History',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_rounded),
              label: isThai ? 'โปรไฟล์' : 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
