import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hapticCalls = <MethodCall>[];

  void captureHaptics() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(SystemChannels.platform.name, (
          ByteData? message,
        ) async {
          final call = const JSONMethodCodec().decodeMethodCall(message);
          if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
          return null;
        });
  }

  setUp(captureHaptics);

  tearDown(() {
    debugDevmateSimulateWeb = false;
    debugResetDevmateNotifications();
    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(SystemChannels.platform.name, null);
  });

  /// Runs [body] with the given target platform, resetting the override
  /// inside the test body as required by the framework invariants.
  Future<void> withPlatform(
    WidgetTester tester,
    TargetPlatform? platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpAndSettle();
    }
  }

  Future<void> pumpHarness(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateTheme(),
        home: Scaffold(body: body),
      ),
    );
  }

  group('design system tokens', () {
    test('theme carries semantic feedback colors', () {
      final theme = devmateTheme();
      expect(theme.colorScheme.error, DevmateColors.error);
      expect(theme.colorScheme.onError, DevmateColors.onError);
      expect(theme.hoverColor, DevmateStates.hoverOverlay);
      expect(theme.focusColor, DevmateStates.focusOverlay);
      expect(theme.disabledColor, DevmateColors.disabled);
    });

    testWidgets('chat dots pulse in sequence and stop when removed', (
      tester,
    ) async {
      await pumpHarness(tester, const DevmateDotsLoader());
      final dots = find.descendant(
        of: find.byType(DevmateDotsLoader),
        matching: find.byType(Opacity),
      );
      final before = tester
          .widgetList<Opacity>(dots)
          .map((dot) => dot.opacity)
          .toList();
      await tester.pump(const Duration(milliseconds: 180));
      final after = tester
          .widgetList<Opacity>(dots)
          .map((dot) => dot.opacity)
          .toList();
      expect(after, isNot(before));
      expect(after.toSet().length, greaterThan(1));

      await pumpHarness(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('chat dots stay static when reduced motion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: DevmateDotsLoader()),
          ),
        ),
      );
      final dots = find.descendant(
        of: find.byType(DevmateDotsLoader),
        matching: find.byType(Opacity),
      );
      final before = tester
          .widgetList<Opacity>(dots)
          .map((dot) => dot.opacity)
          .toList();
      await tester.pump(const Duration(seconds: 2));
      final after = tester
          .widgetList<Opacity>(dots)
          .map((dot) => dot.opacity)
          .toList();
      expect(after, before);
      await tester.pumpAndSettle();
    });
  });

  group('DevmatePressable on iOS', () {
    testWidgets('has no ripple and taps with haptic', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        var taps = 0;
        await pumpHarness(
          tester,
          DevmatePressable(
            onTap: () => taps++,
            haptic: DevmateHapticImpact.selection,
            child: const Text('Card'),
          ),
        );
        expect(find.byType(InkWell), findsNothing);

        await tester.tap(find.text('Card'));
        await tester.pump();
        expect(taps, 1);
        expect(hapticCalls, hasLength(1));
        expect(
          hapticCalls.first.arguments,
          'HapticFeedbackType.selectionClick',
        );
      });
    });

    testWidgets('dims softly while pressed', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        await pumpHarness(
          tester,
          DevmatePressable(onTap: () {}, child: const Text('Card')),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Card')),
        );
        await tester.pumpAndSettle();
        final opacity = tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .opacity;
        expect(opacity, lessThan(1));
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets('disabled control neither taps nor haptic-fires', (
      tester,
    ) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        var taps = 0;
        await pumpHarness(
          tester,
          DevmatePressable(
            onTap: () => taps++,
            enabled: false,
            haptic: DevmateHapticImpact.light,
            child: const Text('Card'),
          ),
        );
        await tester.tap(find.text('Card'), warnIfMissed: false);
        await tester.pump();
        expect(taps, 0);
        expect(hapticCalls, isEmpty);
      });
    });
  });

  group('DevmatePressable on Android', () {
    testWidgets('keeps Material ripple and taps', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        var taps = 0;
        await pumpHarness(
          tester,
          DevmatePressable(onTap: () => taps++, child: const Text('Card')),
        );
        expect(find.byType(InkWell), findsOneWidget);
        await tester.tap(find.text('Card'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(taps, 1);
        expect(hapticCalls, isEmpty);
      });
    });

    testWidgets('provides visible hover/focus overlays', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpHarness(
          tester,
          DevmatePressable(onTap: () {}, child: const Text('Card')),
        );
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(
          inkWell.overlayColor?.resolve({WidgetState.hovered}),
          DevmateStates.hoverOverlay,
        );
        expect(
          inkWell.overlayColor?.resolve({WidgetState.focused}),
          DevmateStates.focusOverlay,
        );
      });
    });
  });

  group('DevmatePressable on web', () {
    testWidgets('activates with keyboard and never haptic-fires', (
      tester,
    ) async {
      debugDevmateSimulateWeb = true;
      await withPlatform(tester, TargetPlatform.macOS, () async {
        // Desktop platform so keyboard activation shortcuts are registered.
        var taps = 0;
        final focusNode = FocusNode();
        await pumpHarness(
          tester,
          DevmatePressable(
            onTap: () => taps++,
            haptic: DevmateHapticImpact.light,
            focusNode: focusNode,
            autofocus: true,
            child: const Text('Card'),
          ),
        );
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(taps, 1);
        expect(hapticCalls, isEmpty);

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(taps, 2);
        expect(hapticCalls, isEmpty);
      });
    });

    testWidgets('mouse hover does not trigger tap', (tester) async {
      debugDevmateSimulateWeb = true;
      await withPlatform(tester, TargetPlatform.macOS, () async {
        var taps = 0;
        await pumpHarness(
          tester,
          DevmatePressable(onTap: () => taps++, child: const Text('Card')),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          pointer: 1,
        );
        await gesture.addPointer(location: tester.getCenter(find.text('Card')));
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.text('Card')));
        await tester.pump();
        expect(taps, 0);
      });
    });
  });

  group('showDevmateNotice on iOS', () {
    testWidgets('shows top banner with live-region semantics', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        final semantics = tester.ensureSemantics();
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDevmateNotice(
                context,
                'Saved',
                kind: DevmateNoticeKind.success,
              ),
              child: const Text('notify'),
            ),
          ),
        );
        await tester.tap(find.text('notify'));
        await tester.pump();

        expect(find.text('Saved'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(
          tester.getSemantics(find.text('Saved')).flagsCollection.isLiveRegion,
          isTrue,
        );
        semantics.dispose();
      });
    });

    testWidgets('success auto-dismisses after 3s', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDevmateNotice(
                context,
                'Saved',
                kind: DevmateNoticeKind.success,
              ),
              child: const Text('notify'),
            ),
          ),
        );
        await tester.tap(find.text('notify'));
        await tester.pump();
        expect(find.text('Saved'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text('Saved'), findsNothing);
      });
    });

    testWidgets('error stays longer than success', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDevmateNotice(
                context,
                'Import failed',
                kind: DevmateNoticeKind.error,
              ),
              child: const Text('notify'),
            ),
          ),
        );
        await tester.tap(find.text('notify'));
        await tester.pump();

        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Import failed'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text('Import failed'), findsNothing);
      });
    });

    testWidgets('tapping the banner dismisses it', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDevmateNotice(context, 'Copied'),
              child: const Text('notify'),
            ),
          ),
        );
        await tester.tap(find.text('notify'));
        await tester.pump();
        expect(find.text('Copied'), findsOneWidget);

        await tester.tap(find.text('Copied'));
        await tester.pumpAndSettle();
        expect(find.text('Copied'), findsNothing);
      });
    });

    testWidgets('shows after an async gap when context is mounted', (
      tester,
    ) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await Future<void>.delayed(Duration.zero);
                if (!context.mounted) return;
                showDevmateNotice(
                  context,
                  'Later success',
                  kind: DevmateNoticeKind.success,
                );
              },
              child: const Text('notify'),
            ),
          ),
        );
        await tester.tap(find.text('notify'));
        await tester.pumpAndSettle();
        expect(find.text('Later success'), findsOneWidget);
      });
    });
  });

  group('showDevmateNotice on Android', () {
    testWidgets('uses a themed snackbar with a close affordance', (
      tester,
    ) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDevmateNotice(
                context,
                'Saved on Android',
                kind: DevmateNoticeKind.success,
              ),
              child: const Text('notify'),
            ),
          ),
        );
        await tester.tap(find.text('notify'));
        // Let the entry animation finish so the auto-dismiss timer starts.
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Saved on Android'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      });
    });
  });

  group('showDevmateNotice on web', () {
    testWidgets('non-blocking width-capped banner, content stays tappable', (
      tester,
    ) async {
      debugDevmateSimulateWeb = true;
      await withPlatform(tester, TargetPlatform.macOS, () async {
        var bodyTaps = 0;
        await pumpHarness(
          tester,
          Column(
            children: [
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDevmateNotice(context, 'Copied link'),
                  child: const Text('notify'),
                ),
              ),
              TextButton(
                onPressed: () => bodyTaps++,
                child: const Text('body button'),
              ),
            ],
          ),
        );
        await tester.tap(find.text('notify'));
        await tester.pump();
        expect(find.text('Copied link'), findsOneWidget);

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox && widget.constraints.maxWidth == 520,
          ),
          findsOneWidget,
        );

        // The banner must not block the page beneath it.
        await tester.tap(find.text('body button'));
        await tester.pump();
        expect(bodyTaps, 1);
      });
    });
  });

  group('showDevmateConfirm on iOS', () {
    testWidgets('returns true on confirm and false on cancel', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        final results = <bool>[];
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showDevmateConfirm(
                    context,
                    title: 'Delete topic?',
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                  ),
                );
              },
              child: const Text('ask'),
            ),
          ),
        );
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(results.single, isFalse);

        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(results, [false, true]);
      });
    });

    testWidgets('destructive confirmation alone does not haptic-fire', (
      tester,
    ) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        final results = <bool>[];
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showDevmateConfirm(
                    context,
                    title: 'Reset all?',
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                    destructive: true,
                  ),
                );
              },
              child: const Text('ask'),
            ),
          ),
        );
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();

        final action = tester.widget<CupertinoDialogAction>(
          find.ancestor(
            of: find.text('Delete'),
            matching: find.byType(CupertinoDialogAction),
          ),
        );
        expect(action.isDestructiveAction, isTrue);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(results.single, isTrue);
        expect(hapticCalls, isEmpty);
      });
    });

    testWidgets('completed destructive action uses iOS success feedback only', (
      tester,
    ) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  DevmateHaptics.destructiveActionCompleted(context),
              child: const Text('completed'),
            ),
          ),
        );
        await tester.tap(find.text('completed'));
        expect(
          hapticCalls.single.arguments,
          'HapticFeedbackType.successNotification',
        );
      });
    });

    testWidgets('barrier dismiss counts as cancel', (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        final results = <bool>[];
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showDevmateConfirm(
                    context,
                    title: 'Delete topic?',
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                  ),
                );
              },
              child: const Text('ask'),
            ),
          ),
        );
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 100));
        await tester.pumpAndSettle();
        expect(results.single, isFalse);
      });
    });
  });

  group('showDevmateConfirm on Android and web', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      required bool destructive,
      void Function(bool)? onResult,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final confirmed = await showDevmateConfirm(
                  context,
                  title: 'Reset progress?',
                  confirmLabel: 'Reset',
                  cancelLabel: 'Cancel',
                  destructive: destructive,
                );
                onResult?.call(confirmed);
              },
              child: const Text('ask'),
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('confirm focuses the affirmative action and returns true', (
      tester,
    ) async {
      final results = <bool>[];
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpDialog(tester, destructive: false, onResult: results.add);
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).autofocus,
          isTrue,
        );

        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(results.single, isTrue);
      });
    });

    testWidgets('destructive confirm focuses cancel and styles with error', (
      tester,
    ) async {
      final results = <bool>[];
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpDialog(tester, destructive: true, onResult: results.add);
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();

        final filled = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(filled.autofocus, isFalse);
        expect(
          filled.style?.backgroundColor?.resolve(const <WidgetState>{}),
          DevmateColors.error,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .autofocus,
          isTrue,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(results.single, isFalse);
      });
    });

    testWidgets('web dialog keeps keyboard focus on explicit actions', (
      tester,
    ) async {
      debugDevmateSimulateWeb = true;
      final results = <bool>[];
      await withPlatform(tester, TargetPlatform.macOS, () async {
        await pumpHarness(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showDevmateConfirm(
                    context,
                    title: 'Reset progress?',
                    confirmLabel: 'Reset',
                    cancelLabel: 'Cancel',
                  ),
                );
              },
              child: const Text('ask'),
            ),
          ),
        );
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();

        // Keyboard activation of the focused confirm button.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(results.single, isTrue);
      });
    });
  });
}
