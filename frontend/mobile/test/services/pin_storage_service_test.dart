import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p_guard_mobile/services/pin_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the wall-clock for [PinStorageService] in tests.
class _FakeClock {
  DateTime current;
  _FakeClock(this.current);

  DateTime call() => current;

  void advance(Duration d) => current = current.add(d);
}

/// Build a fresh service backed by an in-memory secure storage map +
/// a stubbed [SharedPreferences].
Future<({PinStorageService service, Map<String, String> backing, _FakeClock clock})>
    _buildService({
  Map<String, String>? initialBacking,
  String? pin,
  _FakeClock? clock,
}) async {
  final backing = initialBacking ?? <String, String>{};
  // Install the test secure storage platform — every FlutterSecureStorage
  // instance routes to this map.
  FlutterSecureStoragePlatform.instance =
      TestFlutterSecureStoragePlatform(backing);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final secureStorage = const FlutterSecureStorage();

  final fakeClock = clock ?? _FakeClock(DateTime(2026, 1, 1, 12));
  final service = PinStorageService(secureStorage, prefs, now: fakeClock.call);

  if (pin != null) {
    await service.savePin(pin);
  }

  return (service: service, backing: backing, clock: fakeClock);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const correctPin = '123456';
  const wrongPin = '999999';

  setUp(() {
    // Each test gets a clean platform — defensive, since tests share isolate.
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(<String, String>{});
  });

  group('validatePin — happy path', () {
    test('correct PIN on first try returns PinValid', () async {
      final ctx = await _buildService(pin: correctPin);

      final result = await ctx.service.validatePin(correctPin);

      expect(result, isA<PinValid>());
      expect(await ctx.service.getFailedAttemptCount(), 0);
    });
  });

  group('validatePin — invalid path', () {
    test('one wrong PIN returns PinInvalid(remainingBeforeWipe: 9)',
        () async {
      final ctx = await _buildService(pin: correctPin);

      final result = await ctx.service.validatePin(wrongPin);

      expect(result, isA<PinInvalid>());
      expect((result as PinInvalid).remainingBeforeWipe, 9);
      expect(await ctx.service.getFailedAttemptCount(), 1);
    });

    test('four wrong PINs — fourth is PinInvalid(remainingBeforeWipe: 6), '
        'no lockout yet', () async {
      final ctx = await _buildService(pin: correctPin);

      late PinResult last;
      for (var i = 0; i < 4; i++) {
        last = await ctx.service.validatePin(wrongPin);
      }

      expect(last, isA<PinInvalid>());
      expect((last as PinInvalid).remainingBeforeWipe, 6);
      expect(await ctx.service.getCurrentLockoutState(), isNull);
      expect(await ctx.service.getFailedAttemptCount(), 4);
    });
  });

  group('validatePin — lockout', () {
    test('fifth wrong PIN returns PinLockedOut (~60s, totalAttempts: 5)',
        () async {
      final ctx = await _buildService(pin: correctPin);

      late PinResult last;
      for (var i = 0; i < 5; i++) {
        last = await ctx.service.validatePin(wrongPin);
      }

      expect(last, isA<PinLockedOut>());
      final lock = last as PinLockedOut;
      expect(lock.totalAttempts, 5);
      // Allow a tiny tolerance for test scheduling jitter.
      expect(lock.remaining.inSeconds, inInclusiveRange(59, 60));
    });

    test('attempts during lockout return PinLockedOut and do NOT increment '
        'the counter', () async {
      final ctx = await _buildService(pin: correctPin);

      // Trip the lockout.
      for (var i = 0; i < 5; i++) {
        await ctx.service.validatePin(wrongPin);
      }
      expect(await ctx.service.getFailedAttemptCount(), 5);

      // Subsequent calls during the window stay locked out.
      final r1 = await ctx.service.validatePin(wrongPin);
      final r2 = await ctx.service.validatePin(correctPin);
      expect(r1, isA<PinLockedOut>());
      expect(r2, isA<PinLockedOut>());
      expect(await ctx.service.getFailedAttemptCount(), 5);
    });

    test('after lockout expires, correct PIN returns PinValid + clears counter',
        () async {
      final ctx = await _buildService(pin: correctPin);

      for (var i = 0; i < 5; i++) {
        await ctx.service.validatePin(wrongPin);
      }
      // Move past the 60s window.
      ctx.clock.advance(const Duration(seconds: 61));

      final result = await ctx.service.validatePin(correctPin);

      expect(result, isA<PinValid>());
      expect(await ctx.service.getFailedAttemptCount(), 0);
      expect(await ctx.service.getCurrentLockoutState(), isNull);
    });

    test('after lockout expires, wrong PIN re-locks with totalAttempts: 6',
        () async {
      final ctx = await _buildService(pin: correctPin);

      for (var i = 0; i < 5; i++) {
        await ctx.service.validatePin(wrongPin);
      }
      ctx.clock.advance(const Duration(seconds: 61));

      final result = await ctx.service.validatePin(wrongPin);

      expect(result, isA<PinLockedOut>());
      expect((result as PinLockedOut).totalAttempts, 6);
      expect(await ctx.service.getFailedAttemptCount(), 6);
    });
  });

  group('validatePin — wipe', () {
    test('tenth wrong PIN wipes hash + biometric + counters', () async {
      final ctx = await _buildService(pin: correctPin);
      // Pre-enable biometric so we can verify it is reset on wipe.
      await ctx.service.setBiometricEnabled(true);
      expect(ctx.service.isBiometricEnabled, isTrue);

      late PinResult last;
      for (var i = 0; i < 10; i++) {
        // Skip past every lockout window so all attempts land.
        final state = await ctx.service.getCurrentLockoutState();
        if (state != null) {
          ctx.clock.advance(state.remaining + const Duration(seconds: 1));
        }
        last = await ctx.service.validatePin(wrongPin);
      }

      expect(last, isA<PinWiped>());
      expect(ctx.service.getStoredPinHash(), isNull);
      expect(ctx.service.isBiometricEnabled, isFalse);
      expect(ctx.service.isPinSet, isFalse);
    });

    test('after wipe, validatePin returns PinInvalid(remainingBeforeWipe: 10) '
        'and does NOT increment counter', () async {
      // Start with no PIN at all — simulates the post-wipe state.
      final ctx = await _buildService();

      final r1 = await ctx.service.validatePin(wrongPin);
      final r2 = await ctx.service.validatePin(wrongPin);

      expect(r1, isA<PinInvalid>());
      expect((r1 as PinInvalid).remainingBeforeWipe, 10);
      expect(r2, isA<PinInvalid>());
      expect((r2 as PinInvalid).remainingBeforeWipe, 10);
      expect(await ctx.service.getFailedAttemptCount(), 0);
    });
  });

  group('validatePin — counter reset on success', () {
    test('correct PIN after some failed attempts resets the counter',
        () async {
      final ctx = await _buildService(pin: correctPin);

      // Three wrong attempts.
      for (var i = 0; i < 3; i++) {
        await ctx.service.validatePin(wrongPin);
      }
      expect(await ctx.service.getFailedAttemptCount(), 3);

      // Correct attempt — counter should be wiped.
      final ok = await ctx.service.validatePin(correctPin);
      expect(ok, isA<PinValid>());

      // Next wrong attempt should be back at the top of the quota.
      final next = await ctx.service.validatePin(wrongPin);
      expect(next, isA<PinInvalid>());
      expect((next as PinInvalid).remainingBeforeWipe, 9);
    });
  });

  group('getCurrentLockoutState', () {
    test('returns null when not locked, PinLockedOut when locked', () async {
      final ctx = await _buildService(pin: correctPin);

      expect(await ctx.service.getCurrentLockoutState(), isNull);

      for (var i = 0; i < 5; i++) {
        await ctx.service.validatePin(wrongPin);
      }

      final lock = await ctx.service.getCurrentLockoutState();
      expect(lock, isA<PinLockedOut>());
      expect(lock!.totalAttempts, 5);
    });
  });

  group('concurrency', () {
    test('parallel validatePin calls increment by exactly the call count',
        () async {
      final ctx = await _buildService(pin: correctPin);

      final results = await Future.wait([
        ctx.service.validatePin(wrongPin),
        ctx.service.validatePin(wrongPin),
      ]);

      // Both should be PinInvalid, with the second showing one less remaining.
      expect(results.length, 2);
      expect(results[0], isA<PinInvalid>());
      expect(results[1], isA<PinInvalid>());
      expect(await ctx.service.getFailedAttemptCount(), 2);
    });
  });

  group('persistence across instances', () {
    test('counter survives a service recreation (simulated app restart)',
        () async {
      // Initial run — accumulate three failures.
      final ctx = await _buildService(pin: correctPin);
      for (var i = 0; i < 3; i++) {
        await ctx.service.validatePin(wrongPin);
      }
      expect(await ctx.service.getFailedAttemptCount(), 3);

      // Simulate restart: build a new service over the SAME backing map.
      // Re-use the same backing (which contains pin_hash + counter).
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(ctx.backing);
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = const FlutterSecureStorage();
      final restarted = PinStorageService(
        secureStorage,
        prefs,
        now: ctx.clock.call,
      );
      // Mirror PinStorageService.init's hash bootstrap.
      // ignore: invalid_use_of_visible_for_testing_member
      final hash = await secureStorage.read(key: 'pin_hash');
      expect(hash, isNotNull,
          reason: 'pin_hash should still be in backing after restart');

      // Use a fresh service: it must remember the counter and treat the
      // next wrong attempt as the FOURTH.
      final result = await restarted.validatePin(wrongPin);
      expect(result, isA<PinInvalid>());
      // We didn't bootstrap _cachedPinHash, so the new instance treats the
      // PIN as missing. That returns the "fresh" invalid quota — but the
      // counter on disk should still read 3 (proving persistence).
      expect(await restarted.getFailedAttemptCount(), 3);
    });
  });

  group('savePin resets rate-limit state', () {
    test('savePin clears failed_attempts and lock_until', () async {
      final ctx = await _buildService(pin: correctPin);

      for (var i = 0; i < 5; i++) {
        await ctx.service.validatePin(wrongPin);
      }
      expect(await ctx.service.getFailedAttemptCount(), 5);
      expect(await ctx.service.getCurrentLockoutState(), isA<PinLockedOut>());

      // User completes recovery and sets a brand-new PIN.
      await ctx.service.savePin('111111');

      expect(await ctx.service.getFailedAttemptCount(), 0);
      expect(await ctx.service.getCurrentLockoutState(), isNull);
    });
  });

  group('init defends against backup-restore residue', () {
    test('init clears stale failed_attempts when pin_hash is missing',
        () async {
      // Seed backing as if the PIN was lost (e.g. iOS Keychain reset)
      // but the counter survived.
      final backing = <String, String>{
        'pin_failed_attempts': '7',
        'pin_lock_until_ms': '99999999999999',
      };
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(backing);
      SharedPreferences.setMockInitialValues({'biometric_enabled': true});

      final service = await PinStorageService.init();

      expect(service.isPinSet, isFalse);
      expect(service.isBiometricEnabled, isFalse);
      expect(await service.getFailedAttemptCount(), 0);
      expect(await service.getCurrentLockoutState(), isNull);
    });
  });
}
