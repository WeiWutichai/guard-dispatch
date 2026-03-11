import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../providers/booking_provider.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchMyRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;
    final s = HirerHistoryStrings(isThai: isThai);

    final tabs = [
      isThai ? 'ทั้งหมด' : 'All',
      isThai ? 'รอดำเนินการ' : 'Pending',
      isThai ? 'เสร็จสิ้น' : 'Completed',
      isThai ? 'ยกเลิก' : 'Cancelled',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // SecureGuard green header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 60, 24, 30),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
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
                        'SecureGuard',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        s.appBarTitle,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
            child: Consumer<BookingProvider>(
              builder: (context, booking, _) {
                if (booking.isLoadingRequests) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = _filterRequests(booking.myRequests);
                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.noHistory,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => booking.fetchMyRequests(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildRequestCard(req, isThai, s),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> all,
  ) {
    if (_selectedTabIndex == 0) return all;
    final statusFilter = switch (_selectedTabIndex) {
      1 => ['pending', 'assigned', 'in_progress'],
      2 => ['completed'],
      3 => ['cancelled'],
      _ => <String>[],
    };
    return all
        .where((r) => statusFilter.contains(r['status'] as String?))
        .toList();
  }

  /// Parse description into structured lines with icons (same logic as guard jobs).
  List<_DetailLine> _parseDescription(String description) {
    final lines = description.split('\n').where((l) => l.trim().isNotEmpty);
    final result = <_DetailLine>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      IconData icon;
      if (lower.startsWith('บริการ:') || lower.startsWith('service:')) {
        icon = Icons.shield_rounded;
      } else if (lower.startsWith('วันที่:') || lower.startsWith('date:')) {
        icon = Icons.calendar_today_rounded;
      } else if (lower.startsWith('ระยะเวลา:') || lower.startsWith('duration:')) {
        icon = Icons.access_time_rounded;
      } else if (lower.startsWith('จำนวน') || lower.startsWith('guards:')) {
        icon = Icons.people_rounded;
      } else if (lower.startsWith('บริการเพิ่มเติม:') || lower.startsWith('additional:')) {
        icon = Icons.add_circle_outline_rounded;
      } else if (lower.startsWith('อุปกรณ์:') || lower.startsWith('equipment:')) {
        icon = Icons.construction_rounded;
      } else if (lower.startsWith('รายละเอียดงาน:') || lower.startsWith('job details:')) {
        icon = Icons.description_rounded;
      } else {
        icon = Icons.info_outline_rounded;
      }
      result.add(_DetailLine(icon: icon, text: line.trim()));
    }
    return result;
  }

  Widget _buildRequestCard(
    Map<String, dynamic> req,
    bool isThai,
    HirerHistoryStrings s,
  ) {
    final status = req['status'] as String? ?? 'pending';
    final statusLabel = _statusLabel(status, s);
    final statusColor = _statusColor(status);
    final address = req['address'] as String? ?? '';
    final description = req['description'] as String? ?? '';
    final specialInstructions = req['special_instructions'] as String?;
    final price = req['offered_price'];
    final createdAt = req['created_at'] as String? ?? '';
    final urgency = req['urgency'] as String? ?? 'medium';
    final bookedHours = (req['booked_hours'] as num?)?.toInt();

    final dateDisplay = _formatDate(createdAt, isThai);
    final detailLines = _parseDescription(description);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + Price header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (price != null)
                Text(
                  '฿${(price is num ? price : double.tryParse(price.toString()) ?? 0).toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Urgency + booked hours + created date chips
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildChip(
                Icons.flag_rounded,
                _urgencyLabel(urgency, isThai),
                _urgencyChipColor(urgency),
              ),
              if (bookedHours != null)
                _buildChip(
                  Icons.access_time_rounded,
                  '$bookedHours ${isThai ? "ชม." : "hrs"}',
                  AppColors.info,
                ),
              _buildChip(
                Icons.calendar_today_rounded,
                dateDisplay,
                AppColors.textSecondary,
              ),
            ],
          ),

          // Structured description details
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            ...detailLines.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(d.icon, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Special instructions
          if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        isThai ? 'หมายเหตุ' : 'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialInstructions,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF78350F),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cancel button for pending requests
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelRequest(req['id'] as String),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isThai ? 'ยกเลิกคำขอ' : 'Cancel Request',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyChipColor(String urgency) {
    return switch (urgency) {
      'high' || 'critical' => Colors.red,
      'low' => AppColors.success,
      _ => const Color(0xFFF59E0B),
    };
  }

  Future<void> _cancelRequest(String requestId) async {
    final isThai = LanguageProvider.of(context).isThai;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isThai ? 'ยืนยันการยกเลิก' : 'Confirm Cancel'),
        content: Text(
          isThai
              ? 'คุณต้องการยกเลิกคำขอนี้หรือไม่?'
              : 'Are you sure you want to cancel this request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isThai ? 'ไม่' : 'No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<BookingProvider>().cancelRequest(requestId);
    }
  }

  String _statusLabel(String status, HirerHistoryStrings s) {
    return switch (status) {
      'pending' => s.statusInProgress,
      'assigned' => s.statusInProgress,
      'in_progress' => s.statusInProgress,
      'completed' => s.statusCompleted,
      'cancelled' => s.statusCancelled,
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'pending' => Colors.amber.shade700,
      'assigned' => Colors.blue,
      'in_progress' => AppColors.success,
      'completed' => AppColors.success,
      'cancelled' => Colors.red,
      _ => AppColors.textSecondary,
    };
  }

  String _urgencyLabel(String urgency, bool isThai) {
    return switch (urgency) {
      'low' => isThai ? 'ต่ำ' : 'Low',
      'medium' => isThai ? 'ปกติ' : 'Normal',
      'high' => isThai ? 'เร่งด่วน' : 'Urgent',
      'critical' => isThai ? 'ฉุกเฉิน' : 'Critical',
      _ => urgency,
    };
  }

  String _formatDate(String isoDate, bool isThai) {
    if (isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate);
      final thMonths = [
        '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
      ];
      final enMonths = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      if (isThai) {
        return '${dt.day} ${thMonths[dt.month]} ${dt.year + 543}';
      }
      return '${dt.day} ${enMonths[dt.month]} ${dt.year}';
    } catch (_) {
      return isoDate.substring(0, 10);
    }
  }
}

class _DetailLine {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});
}
