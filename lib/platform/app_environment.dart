import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'telegram_bridge_stub.dart'
    if (dart.library.js_interop) 'telegram_bridge_web.dart'
    as bridge;

/// Platform-specific host behavior, independent of the app's routes and data.
abstract class AppEnvironment {
  bool get isTelegram;
  ValueListenable<ThemeMode?> get preferredTheme;
  void attachRouter(GoRouter router);
  void ready();
  void dispose();
}

AppEnvironment createAppEnvironment() => bridge.createEnvironment();

/// Regular browser and native apps retain their own theme and navigation.
class BrowserEnvironment implements AppEnvironment {
  final ValueNotifier<ThemeMode?> _theme = ValueNotifier(null);

  @override
  bool get isTelegram => false;

  @override
  ValueListenable<ThemeMode?> get preferredTheme => _theme;

  @override
  void attachRouter(GoRouter router) {}

  @override
  void ready() {}

  @override
  void dispose() => _theme.dispose();
}

ThemeMode effectiveThemeMode(ThemeMode saved, ThemeMode? host) => host ?? saved;
