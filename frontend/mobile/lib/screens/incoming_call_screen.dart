import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../theme/colors.dart';
import 'call_screen.dart';

/// Ringing screen shown when an FCM `incoming_call` payload arrives. User
/// taps Accept → navigates to `CallScreen` with the call id; Reject →
/// service call to `/calls/{id}/reject` then pops.
///
/// During the ringing phase there is NO signalling WebSocket connected, so the
/// screen polls the call status (every 2s) to detect the caller hanging up /
/// cancelling before we accept — otherwise the callee would sit ringing until
/// the 45s server-side timeout (BUG-042).
class IncomingCallScreen extends StatefulWidget {
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
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _statusPoll;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _statusPoll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkCallerStillCalling(),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    super.dispose();
  }

  /// Poll the call record; if the caller has hung up / cancelled (any terminal
  /// status) before we accept, close this ringing screen.
  Future<void> _checkCallerStillCalling() async {
    final call = await CallService(ApiClient()).getCall(widget.callId);
    final status = call?['status'] as String?;
    if (status == null) return; // network blip — keep ringing
    const stillActive = {'initiated', 'ringing', 'accepted', 'connected'};
    if (!stillActive.contains(status)) {
      // ended / rejected / missed / failed → the caller is gone.
      _closeRinging();
    }
  }

  void _closeRinging() {
    if (_closed || !mounted) return;
    _closed = true;
    _statusPoll?.cancel();
    Navigator.of(context).pop();
  }

  void _reject() {
    // Pop FIRST, with pop() not maybePop(): this screen is wrapped in
    // PopScope(canPop: false) (to block the OS back-gesture), which makes
    // maybePop() a silent no-op. pop() bypasses PopScope.canPop. reject() is
    // best-effort; the server transitions the call out of pending regardless.
    if (_closed) return;
    _closed = true;
    _statusPoll?.cancel();
    final callId = widget.callId;
    Navigator.of(context).pop();
    CallService(ApiClient()).reject(callId);
  }

  void _accept() {
    _statusPoll?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          userName: widget.callerName ?? 'ผู้โทร',
          incomingCallId: widget.callId,
          callType: widget.callType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.callerName ?? 'ไม่ทราบชื่อ';
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
                  widget.callType == 'video' ? 'สายวิดีโอเข้า' : 'สายเรียกเข้า',
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
                      onTap: _reject,
                    ),
                    _CircleAction(
                      icon: Icons.call_rounded,
                      background: Colors.green,
                      label: 'รับสาย',
                      onTap: _accept,
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
