import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import 'design_system.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.title,
    required this.systemPrompt,
    required this.settingsRepository,
  });
  final String title;
  final String systemPrompt;
  final LlmSettingsRepository settingsRepository;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<LlmSettings> _settingsFuture;
  OpenAiCompatibleProvider? _provider;

  @override
  void initState() {
    super.initState();
    _settingsFuture = widget.settingsRepository.load();
  }

  Future<void> _openSettings() async {
    await context.push('/settings');
    if (mounted) {
      _provider?.dispose();
      _provider = null;
      setState(() => _settingsFuture = widget.settingsRepository.load());
    }
  }

  @override
  void dispose() {
    _provider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      automaticallyImplyLeading: !kIsWeb,
      actions: [
        IconButton(
          tooltip: 'Настройки AI',
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LlmSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Не удалось прочитать настройки: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final settings = snapshot.data!;
        if (!settings.isConfigured) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.key_rounded,
                    size: 44,
                    color: DevmateColors.lavender,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Нужен API-ключ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'AI-чат работает с вашим ключом OpenAI-совместимого провайдера. Добавьте его в настройках — он останется на этом устройстве.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DevmateColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Открыть настройки'),
                  ),
                ],
              ),
            ),
          );
        }
        _provider ??= OpenAiCompatibleProvider(
          settings: settings,
          systemPrompt: widget.systemPrompt,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: LlmChatView(
            provider: _provider!,
            enableAttachments: false,
            enableVoiceNotes: false,
            welcomeMessage: 'Спросите что угодно по теме.',
            style: LlmChatViewStyle(
              backgroundColor: DevmateColors.canvas,
              chatInputStyle: ChatInputStyle(
                backgroundColor: DevmateColors.surface,
                hintText: 'Спросите что угодно…',
                textStyle: const TextStyle(color: DevmateColors.primary),
                hintStyle: const TextStyle(color: DevmateColors.muted),
              ),
              llmMessageStyle: LlmMessageStyle(
                markdownStyle: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: const TextStyle(
                        color: DevmateColors.primary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      code: const TextStyle(
                        color: DevmateColors.accent,
                        fontFamily: 'monospace',
                      ),
                      a: const TextStyle(color: DevmateColors.lavender),
                    ),
                decoration: BoxDecoration(
                  color: DevmateColors.surface,
                  border: Border.all(color: DevmateColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              userMessageStyle: UserMessageStyle(
                textStyle: const TextStyle(
                  color: DevmateColors.accentInk,
                  fontSize: 15,
                  height: 1.5,
                ),
                decoration: BoxDecoration(
                  color: DevmateColors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
