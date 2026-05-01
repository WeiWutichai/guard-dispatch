import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../screens/chat_list_screen.dart';
import '../screens/guard/guard_job_detail_screen.dart';
import '../screens/hirer/hirer_history_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/notification_screen.dart';

/// FCM auto-banners work only when the app is background/terminated.
/// This bootstrap wires the foreground path (flutter_local_notifications)
/// and the cross-platform defaults so pushes reliably show on the device
/// notification tray.
///
/// Must be called from `main()` before `runApp()`.

const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'default',
  'Default',
  description: 'General notifications from P-Guard',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

/// Android background isolate entry-point. Must be a top-level function.
/// Firebase's background handler runs here; we don't show our own banner
/// because FCM already did it (the `notification` payload has Android
/// priority=high so the system banners it for us).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op. FCM Display notification already shown for us.
  // Kept for future: could deliver data-only messages here.
}

/// Global navigator key — set in main.dart so the FCM `onMessage` handler
/// can push the incoming-call screen without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> initPushNotifications() async {
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground: iOS also needs an explicit opt-in to show in foreground.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android channel — must match `channel_id` used in the backend FCM payload.
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);

    await _localNotifs.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      // Tap on the foreground banner we showed via flutter_local_notifications
      // → route the same way as a system FCM tap.
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          // We encode the data map as JSON before showing — see _showLocalBanner.
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _routeFromPayload(decoded);
          }
        } catch (_) {}
      },
    );

    // Foreground listener — FCM delivers here instead of showing a banner,
    // so we show one ourselves. Also handles the `incoming_call` payload by
    // pushing the incoming-call screen directly (preempts the banner).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (_tryOpenIncomingCall(message.data)) return;

      final notification = message.notification;
      if (notification == null) return;

      _localNotifs.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannel.id,
            _defaultChannel.name,
            channelDescription: _defaultChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // JSON-encode the FCM data map so the tap handler can decode it back.
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    });

    // Tap on a system push while the app is backgrounded → route by payload.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _routeFromPayload(message.data);
    });

    // Cold-start path: if the app was killed and the user tapped a push to
    // open it, the message is delivered here on first launch instead of
    // through onMessageOpenedApp. Wait one frame so the navigator is mounted.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _routeFromPayload(initialMessage.data);
      });
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[FCM] initPushNotifications error: $e');
  }
}

/// Decode an FCM data payload and navigate to the matching screen. Called
/// from three places — system push tap (background), system push tap from
/// a killed-app cold start, and the user tapping our own foreground
/// banner that flutter_local_notifications shows. Behaviour mirrors
/// `NotificationScreen._onNotificationTap` so users get the same routing
/// whether they came in from the OS tray or from the in-app list.
void _routeFromPayload(Map<String, dynamic> data) {
  // 1. Special-case incoming calls — they have a dedicated full-screen UI
  //    with Accept / Reject buttons.
  if (_tryOpenIncomingCall(data)) return;

  final nav = appNavigatorKey.currentState;
  final ctx = appNavigatorKey.currentContext;
  if (nav == null || ctx == null) return;

  final kind = data['kind'] as String?;
  final targetRole = data['target_role'] as String?;
  final requestId = data['request_id'] as String?;

  // 2. Call-related events that aren't `incoming_call` — missed/rejected
  //    calls just open the in-app notification list.
  if (kind == 'call_missed' || kind == 'call_rejected') {
    nav.push(MaterialPageRoute(
      builder: (_) => NotificationScreen(isGuard: targetRole == 'guard'),
    ));
    return;
  }

  // 3. Booking events with a request_id and a guard recipient → go to job
  //    detail. We need the full job map (the screen reads many fields), so
  //    we fetch the guard's jobs first and find the matching row.
  if (requestId != null && targetRole == 'guard') {
    () async {
      try {
        final booking = ctx.read<BookingProvider>();
        final allJobs = await booking.fetchJobsAndReturn();
        final match = allJobs.where(
          (j) => j['request_id']?.toString() == requestId,
        );
        if (match.isNotEmpty) {
          nav.push(MaterialPageRoute(
            builder: (_) => GuardJobDetailScreen(job: match.first),
          ));
          return;
        }
        // Fallback when the job isn't in our cache yet — open the
        // notification list so the user can drill in manually.
        nav.push(MaterialPageRoute(
          builder: (_) => const NotificationScreen(isGuard: true),
        ));
      } catch (_) {
        nav.push(MaterialPageRoute(
          builder: (_) => const NotificationScreen(isGuard: true),
        ));
      }
    }();
    return;
  }

  // 4. Booking events going to the customer → history screen lists the
  //    request and lets them drill in.
  if (requestId != null && targetRole == 'customer') {
    nav.push(MaterialPageRoute(
      builder: (_) => const HirerHistoryScreen(),
    ));
    return;
  }

  // 5. Chat-message kind (currently unused via FCM but we cover it for
  //    parity with NotificationScreen's routing).
  if (kind == 'chat_message') {
    final auth = ctx.read<AuthProvider>();
    final actingRole = targetRole ?? (auth.role == 'guard' ? 'guard' : 'customer');
    nav.push(MaterialPageRoute(
      builder: (_) => ChatListScreen(actingRole: actingRole),
    ));
    return;
  }

  // 6. Unknown payload → fall back to the in-app notification list.
  final isGuard = targetRole == 'guard' ||
      (ctx.read<AuthProvider>().role == 'guard');
  nav.push(MaterialPageRoute(
    builder: (_) => NotificationScreen(isGuard: isGuard),
  ));
}

/// Peek at FCM data payload and open the incoming-call screen if `kind` is
/// `"incoming_call"`. Returns true when handled so the default banner path
/// can be skipped.
bool _tryOpenIncomingCall(Map<String, dynamic> data) {
  if (data['kind'] != 'incoming_call') return false;
  final callId = data['call_id'] as String?;
  final callerId = data['caller_id'] as String?;
  final callType = (data['call_type'] as String?) ?? 'audio';
  if (callId == null || callerId == null) return false;

  final nav = appNavigatorKey.currentState;
  if (nav == null) return false;

  nav.push(
    MaterialPageRoute(
      builder: (_) => IncomingCallScreen(
        callId: callId,
        callerId: callerId,
        callType: callType,
      ),
    ),
  );
  return true;
}
