import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageNotifier extends ValueNotifier<bool> {
  static const _key = 'app_language_is_thai';

  LanguageNotifier(super.isThai);

  bool get isThai => value;

  static Future<LanguageNotifier> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isThai = prefs.getBool(_key) ?? true;
    return LanguageNotifier(isThai);
  }

  void toggle() {
    value = !value;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_key, value);
    });
  }
}

class LanguageProvider extends InheritedNotifier<LanguageNotifier> {
  const LanguageProvider({
    super.key,
    required LanguageNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static LanguageProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LanguageProvider>()!;
  }

  bool get isThai => notifier!.isThai;

  void toggle() => notifier!.toggle();
}
