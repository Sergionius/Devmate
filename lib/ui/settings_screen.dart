import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/app_preferences.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'settings_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.appLocale,
    this.aiDisabled,
    this.themeMode,
    this.appPreferences,
  });

  final ValueNotifier<Locale?>? appLocale;

  final ValueNotifier<bool>? aiDisabled;

  final ValueNotifier<ThemeMode>? themeMode;

  final AppPreferencesRepository? appPreferences;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppLanguage _language = AppLanguage.system;
  AppThemePreference _theme = AppThemePreference.dark;

  bool _aiDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadTheme();
    _loadAiDisabled();
    widget.aiDisabled?.addListener(_onAiDisabledChanged);
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aiDisabled != oldWidget.aiDisabled) {
      oldWidget.aiDisabled?.removeListener(_onAiDisabledChanged);
      widget.aiDisabled?.addListener(_onAiDisabledChanged);
      _aiDisabled = widget.aiDisabled?.value ?? _aiDisabled;
    }
  }

  @override
  void dispose() {
    widget.aiDisabled?.removeListener(_onAiDisabledChanged);
    super.dispose();
  }

  void _onAiDisabledChanged() {
    if (mounted) setState(() => _aiDisabled = widget.aiDisabled!.value);
  }

  Future<void> _loadAiDisabled() async {
    bool? disabled = widget.aiDisabled?.value;
    try {
      final saved = await widget.appPreferences?.loadAiDisabled();
      if (saved != null) disabled = saved;
    } catch (error) {
      debugPrint('SettingsScreen: failed to read AI-disabled setting: $error');
    }
    if (mounted && disabled != null && disabled != _aiDisabled) {
      final resolved = disabled;
      setState(() => _aiDisabled = resolved);
      final notifier = widget.aiDisabled;
      if (notifier != null && notifier.value != resolved) {
        notifier.value = resolved;
      }
    }
  }

  Future<void> _changeAiDisabled(bool disabled) async {
    if (disabled == _aiDisabled) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() => _aiDisabled = disabled);
    widget.aiDisabled?.value = disabled;
    final preferences = widget.appPreferences;
    if (preferences == null) return;
    try {
      await preferences.saveAiDisabled(disabled);
    } catch (error) {
      debugPrint('SettingsScreen: failed to save AI-disabled setting: $error');
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final language = await widget.appPreferences?.loadLanguage();
      if (mounted && language != null && _language != language) {
        setState(() => _language = language);
      }
    } catch (error) {
      debugPrint('SettingsScreen: failed to read language: $error');
    }
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await widget.appPreferences?.loadTheme();
      if (mounted && theme != null && _theme != theme) {
        setState(() => _theme = theme);
      }
    } catch (error) {
      debugPrint('SettingsScreen: failed to read theme: $error');
    }
  }

  Future<void> _changeTheme(AppThemePreference theme) async {
    if (theme == _theme) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() => _theme = theme);
    widget.themeMode?.value = theme.mode;
    final preferences = widget.appPreferences;
    if (preferences == null) return;
    try {
      await preferences.saveTheme(theme);
    } catch (error) {
      debugPrint('SettingsScreen: failed to save theme: $error');
    }
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    if (language == _language) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() => _language = language);
    widget.appLocale?.value = language.locale;
    final preferences = widget.appPreferences;
    if (preferences == null) return;
    try {
      await preferences.saveLanguage(language);
    } catch (error) {
      debugPrint('SettingsScreen: failed to save language: $error');
    }
  }

  Future<void> _chooseLanguage() async {
    final selected = await showCupertinoModalPopup<AppLanguage>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(sheetContext).brightness,
          primaryColor: context.colors.accent,
          scaffoldBackgroundColor: context.colors.canvas,
          barBackgroundColor: context.colors.surfaceRaised,
        ),
        child: CupertinoActionSheet(
          title: Text(context.l10n.settingsLanguage),
          actions: [
            for (final language in AppLanguage.values)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, language),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(switch (language) {
                      AppLanguage.system => context.l10n.settingsLanguageSystem,
                      AppLanguage.russian => 'Russian',
                      AppLanguage.english => 'English',
                    }),
                    if (language == _language) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.check_mark, size: 18),
                    ],
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(context.l10n.cancelAction),
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _changeLanguage(selected);
  }

  String _themeLabel(AppThemePreference theme) => switch (theme) {
    AppThemePreference.dark => context.l10n.settingsThemeDark,
    AppThemePreference.light => context.l10n.settingsThemeLight,
    AppThemePreference.system => context.l10n.settingsThemeSystem,
  };

  Future<void> _chooseTheme() async {
    final selected = await showCupertinoModalPopup<AppThemePreference>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(sheetContext).brightness,
          primaryColor: context.colors.accent,
          scaffoldBackgroundColor: context.colors.canvas,
          barBackgroundColor: context.colors.surfaceRaised,
        ),
        child: CupertinoActionSheet(
          title: Text(context.l10n.settingsTheme),
          actions: [
            for (final theme in AppThemePreference.values)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, theme),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(_themeLabel(theme))),
                    if (theme == _theme) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.check_mark, size: 18),
                    ],
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(context.l10n.cancelAction),
          ),
        ),
      ),
    );
    if (selected != null && mounted) await _changeTheme(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: settingsAppBar(context, context.l10n.settingsTitle, fallback: '/'),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS)
              OutlinedButton(
                onPressed: _chooseLanguage,
                child: Row(
                  children: [
                    Expanded(child: Text(context.l10n.settingsLanguage)),
                    Text(switch (_language) {
                      AppLanguage.system => context.l10n.settingsLanguageSystem,
                      AppLanguage.russian => 'Russian',
                      AppLanguage.english => 'English',
                    }),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.chevron_down, size: 16),
                  ],
                ),
              )
            else
              DropdownButtonFormField<AppLanguage>(
                initialValue: _language,
                items: [
                  DropdownMenuItem(
                    value: AppLanguage.system,
                    child: Text(context.l10n.settingsLanguageSystem),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.russian,
                    child: Text('Russian'),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.english,
                    child: Text('English'),
                  ),
                ],
                onChanged: (language) => _changeLanguage(language!),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsLanguage,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settingsLanguageRestartNote,
              style: TextStyle(color: context.colors.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS)
              OutlinedButton(
                onPressed: _chooseTheme,
                child: Row(
                  children: [
                    Expanded(child: Text(context.l10n.settingsTheme)),
                    Text(_themeLabel(_theme)),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.chevron_down, size: 16),
                  ],
                ),
              )
            else
              DropdownButtonFormField<AppThemePreference>(
                initialValue: _theme,
                items: [
                  for (final theme in AppThemePreference.values)
                    DropdownMenuItem(
                      value: theme,
                      child: Text(_themeLabel(theme)),
                    ),
                ],
                onChanged: (theme) => _changeTheme(theme!),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsTheme,
                ),
              ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                value: _aiDisabled,
                onChanged: (disabled) => _changeAiDisabled(disabled ?? false),
                title: Text(context.l10n.settingsDisableAi),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (!_aiDisabled) ...[
                    DevmatePressable(
                      onTap: () => context.push('/settings/ai'),
                      child: ListTile(
                        title: Text(context.l10n.settingsAiSection),
                        subtitle: Text(context.l10n.settingsAiSectionNote),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.colors.border,
                    ),
                  ],
                  DevmatePressable(
                    onTap: () => context.push('/settings/data'),
                    child: ListTile(
                      title: Text(context.l10n.settingsDataTitle),
                      subtitle: Text(context.l10n.settingsDataSectionNote),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
