import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_strings.dart';

class HirerHistoryScreen extends StatefulWidget {
  const HirerHistoryScreen({super.key});

  @override
  State<HirerHistoryScreen> createState() => _HirerHistoryScreenState();
}

class _HirerHistoryScreenState extends State<HirerHistoryScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = HirerHistoryStrings(isThai: isThai);

    final tabs = [
      isThai ? 'ทั้งหมด' : 'All',
      isThai ? 'กำลังดำเนินการ' : 'Ongoing',
      isThai ? 'เสร็จสิ้น' : 'Completed',
      isThai ? 'ยกเลิก' : 'Cancelled',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          s.appBarTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          tabs[index],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _buildFilteredItems(isThai, s),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredItems(bool isThai, HirerHistoryStrings s) {
    // Dummy data with status
    final allItems = [
      _HistoryData(
        name: isThai ? 'สมชาย วีรชน' : 'Somchai Wirachon',
        service: s.securityGuard,
        date: isThai ? '15 ก.พ. 2568' : '15 Feb 2025',
        time: '14:00 - 20:00',
        price: '฿1,200',
        status: s.statusCompleted,
        statusColor: AppColors.success,
        avatar: 'https://i.pravatar.cc/150?u=1',
        type: 2, // Completed
      ),
      _HistoryData(
        name: isThai ? 'วิชัย นามสมมุติ' : 'Wichai Namsommut',
        service: s.bodyguard,
        date: isThai ? '10 ก.พ. 2568' : '10 Feb 2025',
        time: '18:00 - 00:00',
        price: '฿3,200',
        status: s.statusCompleted,
        statusColor: AppColors.success,
        avatar: 'https://i.pravatar.cc/150?u=3',
        type: 2, // Completed
      ),
      _HistoryData(
        name: isThai ? 'มานี มีทรัพย์' : 'Manee Meesup',
        service: s.securityGuard,
        date: isThai ? '05 ก.พ. 2568' : '05 Feb 2025',
        time: '08:00 - 16:00',
        price: '฿1,600',
        status: s.statusCancelled,
        statusColor: Colors.red,
        avatar: 'https://i.pravatar.cc/150?u=4',
        type: 3, // Cancelled
      ),
    ];

    final filtered = _selectedTabIndex == 0
        ? allItems
        : allItems.where((item) => item.type == _selectedTabIndex).toList();

    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                isThai ? 'ไม่มีรายการ' : 'No history found',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return filtered.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildHistoryItem(
          isThai: isThai,
          strings: s,
          name: item.name,
          service: item.service,
          date: item.date,
          time: item.time,
          price: item.price,
          status: item.status,
          statusColor: item.statusColor,
          avatar: item.avatar,
        ),
      );
    }).toList();
  }

  Widget _buildHistoryItem({
    required bool isThai,
    required HirerHistoryStrings strings,
    required String name,
    required String service,
    required String date,
    required String time,
    required String price,
    required String status,
    required Color statusColor,
    required String avatar,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatar)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      service,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    strings.total,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryData {
  final String name;
  final String service;
  final String date;
  final String time;
  final String price;
  final String status;
  final Color statusColor;
  final String avatar;
  final int type; // 1: In progress, 2: Completed, 3: Cancelled

  _HistoryData({
    required this.name,
    required this.service,
    required this.date,
    required this.time,
    required this.price,
    required this.status,
    required this.statusColor,
    required this.avatar,
    required this.type,
  });
}
