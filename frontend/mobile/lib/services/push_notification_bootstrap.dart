import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/guard/guard_job_detail_screen.dart';
import 'language_service.dart';
import '../screens/hirer/customer_active_job_screen.dart';
import '../screens/hirer/customer_tracking_screen.dart';
import '../screens/hirer/hirer_history_screen.dart';
import '../screens/hirer/payment_screen.dart';
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
  //    we fetch the guard's jobs first and find the matching row. If the
  //    push arrived before the cached list saw the new assignment (race
  //    condition — common because backend FCM dispatch beats most clients
  //    fetching their job list), fall through to a request-by-id fetch and
  //    compose the job map ourselves so the deep-link still lands on the
  //    job detail screen instead of the notification list.
  if (requestId != null && targetRole == 'guard') {
    () async {
      try {
        final booking = ctx.read<BookingProvider>();

        // Fast path: cached list.
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

        // Cache miss → fetch by id (race-safe).
        final request = await booking.getRequest(requestId);
        final assignments = await booking.getAssignments(requestId);
        final jobMap = _composeGuardJobMap(request, assignments);
        nav.push(MaterialPageRoute(
          builder: (_) => GuardJobDetailScreen(job: jobMap),
        ));
      } catch (_) {
        // Last-ditch fallback only if BOTH cache lookup and direct fetch
        // failed (network out, server down, etc.).
        nav.push(MaterialPageRoute(
          builder: (_) => const NotificationScreen(isGuard: true),
        ));
      }
    }();
    return;
  }

  // 4. Booking events going to the customer → route by request + assignment
  //    state, mirroring HirerHistoryScreen._trackGuard (lines 543-661). The
  //    matching screen for the current state (PaymentScreen / ActiveJob /
  //    Tracking) is what the user actually wants — the old behaviour of
  //    always landing on HirerHistoryScreen forced an extra tap and lost
  //    deep-link intent. NOTE: the routing logic here is intentionally a
  //    duplicate of _trackGuard; extracting it into a shared helper is
  //    deferred (B12-D follow-up — out of Task 13 scope).
  if (requestId != null && targetRole == 'customer') {
    () async {
      try {
        final booking = ctx.read<BookingProvider>();
        final request = await booking.getRequest(requestId);
        final assignments = await booking.getAssignments(requestId);

        // Find the active assignment (mirrors _trackGuard:566-569).
        final active = assignments.where((a) {
          final s = a['status'] as String?;
          return s == 'awaiting_payment' ||
              s == 'accepted' ||
              s == 'en_route' ||
              s == 'arrived' ||
              s == 'pending_completion';
        });

        if (active.isEmpty) {
          // No active assignment yet (declined / cancelled / pre-acceptance).
          // History screen lets the user drill in manually.
          nav.push(MaterialPageRoute(
            builder: (_) => const HirerHistoryScreen(),
          ));
          return;
        }

        final assignment = active.first;
        final status = assignment['status'] as String?;
        final guardId = assignment['guard_id']?.toString() ?? '';
        final guardName = assignment['guard_name'] as String? ?? '-';
        final startedAt = assignment['started_at'] as String?;
        final customerLat = (request['location_lat'] as num?)?.toDouble();
        final customerLng = (request['location_lng'] as num?)?.toDouble();
        final bookedHours = (request['booked_hours'] as num?)?.toInt() ?? 6;

        if (status == 'awaiting_payment' &&
            customerLat != null &&
            customerLng != null) {
          final price = request['offered_price'];
          final totalAmount = price is num
              ? price.toDouble()
              : double.tryParse(price?.toString() ?? '') ?? 0;
          nav.push(MaterialPageRoute(
            builder: (_) => PaymentScreen(
              requestId: requestId,
              totalAmount: totalAmount,
              subtotal: totalAmount,
              baseFee: 0,
              tip: 0,
              bookedHours: bookedHours,
              guardCount: 1,
              guardName: guardName,
              guardId: guardId,
              customerLat: customerLat,
              customerLng: customerLng,
            ),
          ));
          return;
        }

        if ((status == 'arrived' || status == 'pending_completion') &&
            startedAt != null) {
          final address = request['address'] as String?;
          final startTime = DateTime.parse(startedAt);
          final elapsed =
              DateTime.now().toUtc().difference(startTime).inSeconds;
          final total = bookedHours * 3600;
          final remainingSeconds = (total - elapsed).clamp(0, total);
          nav.push(MaterialPageRoute(
            builder: (_) => CustomerActiveJobScreen(
              requestId: requestId,
              guardName: guardName,
              address: address,
              bookedHours: bookedHours,
              remainingSeconds: remainingSeconds,
              startedAt: startedAt,
            ),
          ));
          return;
        }

        // Default: tracking screen for accepted/en_route. Requires lat/lng;
        // fall back to history if the request never captured them.
        if (customerLat != null && customerLng != null) {
          nav.push(MaterialPageRoute(
            builder: (_) => CustomerTrackingScreen(
              requestId: requestId,
              guardId: guardId,
              guardName: guardName,
              customerLat: customerLat,
              customerLng: customerLng,
            ),
          ));
        } else {
          nav.push(MaterialPageRoute(
            builder: (_) => const HirerHistoryScreen(),
          ));
        }
      } catch (_) {
        nav.push(MaterialPageRoute(
          builder: (_) => const HirerHistoryScreen(),
        ));
      }
    }();
    return;
  }

  // 5. Chat-message — deep-link straight to the conversation when we have
  //    a conversation_id (Task 14 — chat now triggers FCM push). Falls back
  //    to the chat list if the conversation isn't found in the cached list
  //    (e.g., very new conversation, or fetchConversations failed).
  if (kind == 'chat_message') {
    () async {
      final auth = ctx.read<AuthProvider>();
      // Resolve locale before any awaits — ChatListScreen uses the same
      // LanguageProvider.of(context).isThai pattern at line 29 to localize
      // strings, so reuse it here for parity with in-app navigation.
      final isThai = LanguageProvider.of(ctx).isThai;
      // target_role for chat is "any" (backend sets this) — we resolve the
      // acting role from the local AuthProvider in that case.
      final actingRole = (targetRole == 'guard' || targetRole == 'customer')
          ? targetRole!
          : (auth.role == 'guard' ? 'guard' : 'customer');
      final conversationId = data['conversation_id'] as String?;

      if (conversationId == null || conversationId.isEmpty) {
        nav.push(MaterialPageRoute(
          builder: (_) => ChatListScreen(actingRole: actingRole),
        ));
        return;
      }

      try {
        final chat = ctx.read<ChatProvider>();
        // No backend GET /conversations/{id} yet (carry-forward B12-H), so
        // we list-then-filter. fetchConversations populates ChatProvider's
        // _conversations field which we then search by id.
        await chat.fetchConversations(role: actingRole);
        Map<String, dynamic>? conv;
        for (final c in chat.conversations) {
          if (c['id']?.toString() == conversationId) {
            conv = c;
            break;
          }
        }
        if (conv == null) {
          nav.push(MaterialPageRoute(
            builder: (_) => ChatListScreen(actingRole: actingRole),
          ));
          return;
        }

        // Field names + locale-aware fallback mirror chat_list_screen.dart's
        // mapping (lines 91-94) so we stay consistent with in-app navigation.
        final requestId = conv['request_id']?.toString() ?? '';
        final counterpartName = conv['participant_name'] as String? ??
            (isThai ? 'ไม่ทราบชื่อ' : 'Unknown');
        final requestStatus = conv['request_status'] as String? ?? '';
        final isReadOnly =
            requestStatus == 'completed' || requestStatus == 'cancelled';
        // Counterpart label flips by acting role (guard ↔ customer) and
        // localizes; matches ChatListScreen's localized userRole at line 204
        // but corrects the side: previously hardcoded 'Client' on both sides.
        final counterpartRoleLabel = actingRole == 'guard'
            ? (isThai ? 'ลูกค้า' : 'Client')
            : (isThai ? 'รปภ.' : 'Security');

        nav.push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            requestId: requestId,
            userName: counterpartName,
            userRole: counterpartRoleLabel,
            actingRole: actingRole,
            readOnly: isReadOnly,
          ),
        ));
      } catch (_) {
        nav.push(MaterialPageRoute(
          builder: (_) => ChatListScreen(actingRole: actingRole),
        ));
      }
    }();
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

/// Compose the merged job map that `GuardJobDetailScreen` reads. The screen
/// expects a single map containing request fields (id, address, booked_hours,
/// offered_price, customer_*, etc.) plus assignment fields (assignment_id,
/// assignment_status, started_at, en_route_*, arrived_*, etc.). The
/// `/booking/guard/jobs` list endpoint already returns this merged shape; this
/// helper exists for the cache-miss path where we only have request +
/// assignments separately (Task 13 race-condition fix).
Map<String, dynamic> _composeGuardJobMap(
  Map<String, dynamic> request,
  List<Map<String, dynamic>> assignments,
) {
  // Start with request fields.
  final merged = Map<String, dynamic>.from(request);

  // Overlay assignment fields. There may be multiple historical assignments
  // for one request (declined guards then re-assigned); for push routing we
  // want the most recent non-declined one. Heuristic: the first row not in
  // {declined, cancelled, rejected} — the API orders newest-first.
  Map<String, dynamic>? active;
  for (final a in assignments) {
    final s = a['status'] as String?;
    if (s == 'declined' || s == 'cancelled' || s == 'rejected') continue;
    active = a;
    break;
  }
  active ??= assignments.isNotEmpty ? assignments.first : null;
  if (active == null) return merged;

  merged['assignment_id'] = active['id'];
  merged['assignment_status'] = active['status'];
  // Copy timestamps + location fields the detail screen reads (see
  // guard_job_detail_screen.dart lines 736-750).
  const assignmentFields = [
    'started_at',
    'en_route_at',
    'arrived_at',
    'completed_at',
    'completion_requested_at',
    'en_route_lat',
    'en_route_lng',
    'arrived_lat',
    'arrived_lng',
    'started_lat',
    'started_lng',
    'completion_lat',
    'completion_lng',
    'en_route_place',
    'arrived_place',
    'started_place',
    'completion_place',
    'guard_id',
    'guard_name',
  ];
  for (final key in assignmentFields) {
    if (active[key] != null) merged[key] = active[key];
  }
  return merged;
}
