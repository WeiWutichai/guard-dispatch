import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../services/booking_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/language_service.dart';

/// Shows the assignment status for a specific booking request.
///
/// If the request is still pending, shows "waiting for admin to assign".
/// If assignments exist, shows the assigned guard info.
class GuardSelectionScreen extends StatefulWidget {
  /// The booking request ID to check assignments for.
  /// When null, shows a generic "waiting" message.
  final String? requestId;

  const GuardSelectionScreen({super.key, this.requestId});

  @override
  State<GuardSelectionScreen> createState() => _GuardSelectionScreenState();
}

class _GuardSelectionScreenState extends State<GuardSelectionScreen> {
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      _fetchAssignments();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _fetchAssignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthProvider>().apiClient;
      final service = BookingService(apiClient);
      _assignments = await service.getAssignments(widget.requestId!);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageProvider.of(context).isThai;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context, isThai),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(isThai)
                    : _assignments.isEmpty
                        ? _buildWaitingState(isThai)
                        : _buildAssignmentList(isThai),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isThai) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThai ? 'สถานะการจัดสรร' : 'Assignment Status',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isThai ? 'รายละเอียดเจ้าหน้าที่' : 'Guard Details',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState(bool isThai) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 64,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isThai
                  ? 'กำลังรอ Admin จัดสรร รปภ.'
                  : 'Waiting for Admin to Assign Guard',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isThai
                  ? 'คำขอของคุณอยู่ในระหว่างการพิจารณา\nAdmin จะจัดสรรเจ้าหน้าที่ให้เร็วที่สุด'
                  : 'Your request is being reviewed.\nAn admin will assign a guard shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (widget.requestId != null)
              OutlinedButton.icon(
                onPressed: _fetchAssignments,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isThai ? 'ตรวจสอบอีกครั้ง' : 'Check Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList(bool isThai) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildAssignmentCard(assignment, isThai),
        );
      },
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment, bool isThai) {
    final status = assignment['status'] as String? ?? 'assigned';
    final assignedAt = assignment['assigned_at'] as String? ?? '';
    final guardId = assignment['guard_id'] as String? ?? '';

    final statusLabel = switch (status) {
      'assigned' => isThai ? 'ได้รับมอบหมาย' : 'Assigned',
      'en_route' => isThai ? 'กำลังเดินทาง' : 'En Route',
      'arrived' => isThai ? 'มาถึงแล้ว' : 'Arrived',
      'completed' => isThai ? 'เสร็จสิ้น' : 'Completed',
      'cancelled' => isThai ? 'ยกเลิก' : 'Cancelled',
      _ => status,
    };

    final statusColor = switch (status) {
      'assigned' => Colors.blue,
      'en_route' => Colors.orange,
      'arrived' => AppColors.success,
      'completed' => AppColors.success,
      'cancelled' => Colors.red,
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThai ? 'เจ้าหน้าที่ รปภ.' : 'Security Guard',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${guardId.length > 8 ? guardId.substring(0, 8) : guardId}...',
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
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (assignedAt.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${isThai ? 'มอบหมายเมื่อ: ' : 'Assigned: '}${assignedAt.substring(0, 10)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(bool isThai) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isThai ? 'เกิดข้อผิดพลาด' : 'Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _fetchAssignments,
              child: Text(isThai ? 'ลองอีกครั้ง' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
