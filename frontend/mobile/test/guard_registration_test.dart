import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secureguard_mobile/providers/auth_provider.dart';
import 'package:secureguard_mobile/screens/guard/guard_registration_screen.dart';
import 'package:secureguard_mobile/services/language_service.dart';

// ─── Fake AuthProvider ───────────────────────────────────────────────────────
class _FakeAuthProvider extends AuthProvider {
  bool submitGuardProfileCalled = false;
  String? capturedFullName;
  String? capturedAccountName;

  @override
  Future<void> submitGuardProfile({
    required String profileToken,
    String? fullName,
    String? gender,
    String? dateOfBirth,
    int? yearsOfExperience,
    String? previousWorkplace,
    String? bankName,
    String? accountNumber,
    String? accountName,
    Map<String, File> files = const {},
  }) async {
    submitGuardProfileCalled = true;
    capturedFullName = fullName;
    capturedAccountName = accountName;
  }

  @override
  Future<String> reissueProfileToken(String phone) async {
    return 'test_reissued_profile_token';
  }
}

// ─── Test widget ─────────────────────────────────────────────────────────────

Widget _buildTestApp(_FakeAuthProvider fakeAuth) {
  return LanguageProvider(
    notifier: LanguageNotifier(true), // Thai
    child: ChangeNotifierProvider<AuthProvider>.value(
      value: fakeAuth,
      child: MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            },
          ),
        ),
        home: GuardRegistrationScreen(
          phone: '0863208235',
          phoneVerifiedToken: 'test_phone_verified_token',
        ),
      ),
    ),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Scrolls [finder] into view, then taps it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scrolls [finder] into view, then enters [text].
Future<void> _enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

/// Fills all required fields in Step 1 and taps "ถัดไป".
Future<void> _completeStep1(
  WidgetTester tester, {
  String fullName = 'สมชาย ใจดี',
}) async {
  await _enter(tester, find.byType(TextFormField).first, fullName);

  // Gender dropdown
  await _tapVisible(
      tester, find.byType(DropdownButtonFormField<String>).first);
  await tester.tap(find.text('ชาย').last, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));

  await _enter(tester, find.byType(TextFormField).at(1), '5');
  await _enter(
      tester, find.byType(TextFormField).at(2), 'บริษัท เทส จำกัด');

  await _tapVisible(tester, find.text('ถัดไป'));
}

/// Step 2 has no required validators — tap "ถัดไป".
Future<void> _completeStep2(WidgetTester tester) async {
  await _tapVisible(tester, find.text('ถัดไป'));
}

/// Fills bank fields in Step 3.
Future<void> _fillStep3(
  WidgetTester tester, {
  required String accountName,
}) async {
  await _tapVisible(
      tester, find.byType(DropdownButtonFormField<String>).first);
  await tester.tap(find.text('ธนาคารกสิกรไทย').last, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));

  // Step 3 fields: at(0)=accountNumber, at(1)=accountName
  await _enter(tester, find.byType(TextFormField).at(0), '0123456789');
  await _enter(tester, find.byType(TextFormField).at(1), accountName);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group(
    'GuardRegistrationScreen — 3-step flow (profile submission only)\n'
    'เงื่อนไข: ชื่อบัญชีต้องตรงกับชื่อ-นามสกุล',
    () {
      void setUpScreen(WidgetTester tester) {
        tester.view.physicalSize = const Size(1284, 2778);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      // ── 1. Name mismatch → validation error ────────────────────────────
      testWidgets('แสดง error เมื่อชื่อบัญชีไม่ตรงกับชื่อ-นามสกุล',
          (tester) async {
        setUpScreen(tester);
        final fakeAuth = _FakeAuthProvider();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pump();

        await _completeStep1(tester, fullName: 'สมชาย ใจดี');
        await _completeStep2(tester);
        await _fillStep3(tester, accountName: 'สมหญิง คนละชื่อ');

        await tester.ensureVisible(find.text('ส่งใบสมัคร'));
        await tester.tap(find.text('ส่งใบสมัคร'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('ชื่อบัญชีต้องตรงกับชื่อ-นามสกุลที่กรอกในขั้นตอนแรก'),
          findsOneWidget,
          reason: 'ต้องแสดง error เมื่อชื่อบัญชีไม่ตรงกัน',
        );
        expect(fakeAuth.submitGuardProfileCalled, isFalse,
            reason: 'ต้องไม่เรียก API เมื่อ validation ไม่ผ่าน');
      });

      // ── 2. Empty account name → required error ──────────────────────────
      testWidgets('แสดง error เมื่อไม่กรอกชื่อบัญชี', (tester) async {
        setUpScreen(tester);
        final fakeAuth = _FakeAuthProvider();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pump();

        await _completeStep1(tester, fullName: 'สมชาย ใจดี');
        await _completeStep2(tester);

        await _tapVisible(
            tester, find.byType(DropdownButtonFormField<String>).first);
        await tester.tap(find.text('ธนาคารกสิกรไทย').last,
            warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 200));
        await _enter(tester, find.byType(TextFormField).at(0), '0123456789');

        await tester.ensureVisible(find.text('ส่งใบสมัคร'));
        await tester.tap(find.text('ส่งใบสมัคร'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('กรอกชื่อบัญชี'),
          findsAtLeastNWidgets(1),
          reason: 'ต้องแสดง required error เมื่อไม่กรอกชื่อบัญชี',
        );
        expect(fakeAuth.submitGuardProfileCalled, isFalse);
      });

      // ── 3. Happy path — name matches ───────────────────────────────────
      testWidgets('สมัครสำเร็จเมื่อชื่อบัญชีตรงกับชื่อ-นามสกุล',
          (tester) async {
        setUpScreen(tester);
        final fakeAuth = _FakeAuthProvider();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pump();

        const testFullName = 'สมชาย ใจดี';

        await _completeStep1(tester, fullName: testFullName);
        await _completeStep2(tester);
        await _fillStep3(tester, accountName: testFullName);

        await tester.ensureVisible(find.text('ส่งใบสมัคร'));
        await tester.tap(find.text('ส่งใบสมัคร'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(fakeAuth.submitGuardProfileCalled, isTrue,
            reason: 'ต้องเรียก submitGuardProfile เมื่อ validation ผ่าน');
        expect(fakeAuth.capturedAccountName, equals(testFullName),
            reason: 'account_name ที่ส่งต้องตรงกับชื่อ-นามสกุล');
      });

      // ── 4. Whitespace trimming ──────────────────────────────────────────
      testWidgets('ตัด whitespace ก่อนเปรียบเทียบชื่อ', (tester) async {
        setUpScreen(tester);
        final fakeAuth = _FakeAuthProvider();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pump();

        await _completeStep1(tester, fullName: '  สมชาย ใจดี  ');
        await _completeStep2(tester);
        await _fillStep3(tester, accountName: 'สมชาย ใจดี ');

        await tester.ensureVisible(find.text('ส่งใบสมัคร'));
        await tester.tap(find.text('ส่งใบสมัคร'), warnIfMissed: false);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(fakeAuth.submitGuardProfileCalled, isTrue,
            reason: 'ต้องผ่าน validation เมื่อชื่อตรงกันหลัง trim whitespace');
      });
    },
  );
}
