// Smoke test for the P-Guard mobile app.
//
// The previous content of this file was the Flutter scaffold counter test
// (find.text('0') / tap Icons.add), which is meaningless because this app is
// not a counter app — that test would always have failed if anyone actually
// ran it.
//
// A richer smoke test that pumps `MyApp` and asserts the initial
// CircularProgressIndicator (from AuthStatus.unknown) was considered, but
// requires mocking platform channels for SharedPreferences,
// FlutterSecureStorage, Firebase, and FCM — none of which have testing
// helpers wired up in this project, and the task scope forbids adding new
// dependencies. So we limit this file to a compile-only check: the test
// failing to compile would mean MyApp's public surface has drifted from
// what the rest of the codebase imports.

import 'package:flutter_test/flutter_test.dart';
import 'package:p_guard_mobile/main.dart';

void main() {
  test('MyApp class is exported from main.dart', () {
    expect(MyApp, isNotNull);
  });
}
