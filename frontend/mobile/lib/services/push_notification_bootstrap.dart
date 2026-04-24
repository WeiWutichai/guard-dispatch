import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/incoming_call_screen.dart';

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
        payload: message.data.isEmpty ? null : message.data.toString(),
      );
    });

    // Tap on a push while the app is backgrounded → check for incoming-call
    // payload too.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _tryOpenIncomingCall(message.data);
    });
  } catch (e) {
    if (kDebugMode) debugPrint('[FCM] initPushNotifications error: $e');
  }
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
