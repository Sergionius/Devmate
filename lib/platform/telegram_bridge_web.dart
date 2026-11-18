import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_environment.dart';

@JS('Telegram')
external TelegramNamespace? get _telegram;

extension type TelegramNamespace._(JSObject _) implements JSObject {
  @JS('WebApp')
  external TelegramWebApp? get webApp;
}

extension type TelegramWebApp._(JSObject _) implements JSObject {
  external JSString get initData;
  external JSString get colorScheme;
  @JS('BackButton')
  external TelegramBackButton get backButton;
  external void ready();
  external void expand();
  external void onEvent(JSString event, JSFunction callback);
  external void offEvent(JSString event, JSFunction callback);
}

extension type TelegramBackButton._(JSObject _) implements JSObject {
  external void show();
  external void hide();
  external void onClick(JSFunction callback);
  external void offClick(JSFunction callback);
}

AppEnvironment createEnvironment() {
  final app = _telegram?.webApp;
  // The SDK script also loads in a regular browser; its presence alone is
  // not evidence that the page was opened by Telegram. Never trust initData
  // for authentication without validating its signature on a server.
  if (app == null || app.initData.toDart.isEmpty) return BrowserEnvironment();
  return _TelegramEnvironment(app);
}

class _TelegramEnvironment implements AppEnvironment {
  _TelegramEnvironment(this._app) {
    _updateTheme();
    _themeCallback = _updateTheme.toJS;
    _backCallback = _handleBack.toJS;
    _app.onEvent('themeChanged'.toJS, _themeCallback);
  }

  final TelegramWebApp _app;
  final ValueNotifier<ThemeMode?> _theme = ValueNotifier(null);
  late final JSFunction _themeCallback;
  late final JSFunction _backCallback;
  GoRouter? _router;

  @override
  bool get isTelegram => true;

  @override
  ValueListenable<ThemeMode?> get preferredTheme => _theme;

  void _updateTheme() {
    _theme.value = _app.colorScheme.toDart == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  void _handleBack() {
    final router = _router;
    if (router != null && router.canPop()) router.pop();
  }

  void _updateBack() {
    if (_router?.canPop() ?? false) {
      _app.backButton.show();
    } else {
      _app.backButton.hide();
    }
  }

  @override
  void attachRouter(GoRouter router) {
    if (identical(_router, router)) return;
    _router?.routerDelegate.removeListener(_updateBack);
    _app.backButton.offClick(_backCallback);
    _router = router;
    router.routerDelegate.addListener(_updateBack);
    _app.backButton.onClick(_backCallback);
    _updateBack();
  }

  @override
  void ready() {
    _app.ready();
    _app.expand();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_updateBack);
    _app.backButton.offClick(_backCallback);
    _app.offEvent('themeChanged'.toJS, _themeCallback);
    _theme.dispose();
  }
}
