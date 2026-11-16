import 'package:flutter/widgets.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import 'app_localizations.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension LlmErrorText on BuildContext {
  String llmErrorText(LlmErrorKind kind) => switch (kind) {
    LlmErrorKind.keyRejected => l10n.llmKeyRejected,
    LlmErrorKind.notFound => l10n.llmNotFound,
    LlmErrorKind.rateLimited => l10n.llmRateLimited,
    LlmErrorKind.noBalance => l10n.llmNoBalance,
    LlmErrorKind.webConnection => l10n.llmWebConnectionError,
    LlmErrorKind.connection => l10n.llmConnectionError,
    LlmErrorKind.emptyTestResponse => l10n.llmTestEmptyResponse,
    LlmErrorKind.emptyReply => l10n.llmEmptyReply,
  };
}

extension PresetLabel on BuildContext {
  String presetLabel(LlmPreset preset) => switch (preset.id) {
    'zaiCoding' => l10n.presetZaiCodingLabel,
    'zai' => l10n.presetZaiLabel,
    'ollama' => l10n.presetOllamaLabel,
    'custom' => l10n.presetCustomLabel,
    _ => preset.label,
  };
}
