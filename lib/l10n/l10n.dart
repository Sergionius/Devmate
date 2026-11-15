import 'package:flutter/widgets.dart';

import '../data/llm_chat_provider.dart';
import 'app_localizations.dart';

/// Быстрый доступ к локализованным строкам: `context.l10n.someKey`.
extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Локализованный текст для вида ошибки LLM-провайдера.
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
    LlmErrorKind.subscriptionExpired => l10n.llmSubscriptionExpired,
  };
}
