import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../theme/colors.dart';
import 'call_screen.dart';

/// Ringing screen shown when an FCM `incoming_call` payload arrives. User
/// taps Accept → navigates to `CallScreen` with the call id; Reject →
/// service call to `/calls/{id}/reject` then pops.
class IncomingCallScreen extends StatelessWidget {
  final String callId;
  final String callerId;
  final String callType;
  final String? callerName;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    this.callType = 'audio',
    this.callerName,
  });

  @override
  Widget build(BuildContext context) {
    final name = callerName ?? 'ไม่ทราบชื่อ';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  callType == 'video' ? 'สายวิดีโอเข้า' : 'สายเรียกเข้า',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child:
                      const Icon(Icons.person, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleAction(
                      icon: Icons.call_end_rounded,
                      background: Colors.red,
                      label: 'ปฏิเสธ',
                      onTap: () => _reject(context),
                    ),
                    _CircleAction(
                      icon: Icons.call_rounded,
                      background: Colors.green,
                      label: 'รับสาย',
                      onTap: () => _accept(context),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final service = CallService(ApiClient());
    await service.reject(callId);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  void _accept(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          userName: callerName ?? 'ผู้โทร',
          incomingCallId: callId,
          callType: callType,
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color background;
  final String label;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.background,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}
