import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    // so we show one ourselves.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
  } catch (e) {
    if (kDebugMode) debugPrint('[FCM] initPushNotifications error: $e');
  }
}
