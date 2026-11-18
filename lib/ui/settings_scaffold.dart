import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// App bar shared by all settings sub-screens; on web the back button
/// falls back to [fallback] because the browser history may be empty.
PreferredSizeWidget settingsAppBar(
  BuildContext context,
  String title, {
  String fallback = '/settings',
}) => AppBar(
  title: Text(title),
  leading: kIsWeb
      ? BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallback);
            }
          },
        )
      : null,
);
