# Devmate

Офлайн-тренажёр для подготовки к техническому собеседованию. Flutter-приложение для iOS, Android и Web.

## Возможности

- 120 вопросов по 10 темам: Frontend, Flutter, iOS, AI-first, архитектура, сложность O(n), JavaScript / TypeScript, алгоритмы и структуры данных, тестирование, системный дизайн.
- Ответ своими словами → эталон → самооценка. Если ответ требует повторения, нужно ещё раз сформулировать его перед завершением.
- Прогресс по темам и XP (5 или 10 за вопрос), сохранение локально на устройстве. Повторение не накручивает очки; улучшение оценки обновляет результат.
- Вопросы встроены в приложение, аккаунт и API не требуются. Для первой загрузки Web-версии нужен доступ к размещённому приложению.

## Запуск

Установите Flutter SDK и запустите:

```sh
flutter pub get
flutter run -d chrome    # Web
flutter run -d ios       # iOS: нужен macOS и Xcode
flutter run -d android   # Android: нужен SDK и эмулятор/устройство
```

Проверка: `flutter analyze` и `flutter test`. Сборка Web: `flutter build web`.

Вопросы хранятся в `assets/data/questions.json` — это источник данных. После правки JSON запустите `python3 tools/generate_catalog.py`, и он пересоберёт `lib/data/question_catalog.dart` (править сгенерированный файл руками не нужно). Модели — в `lib/domain/`, хранение прогресса — в `lib/data/progress_repository.dart`, состояние и экраны — в `lib/ui/`. Автоматической оценки свободного текста пока нет: пользователь сравнивает ответ с эталоном самостоятельно.

## Иконки

Исходник — `assets/branding/devmate_source.png`. После изменения изображения установите Pillow (`python3 -m pip install Pillow`) и запустите `python3 tools/generate_icons.py`: скрипт пересоздаст иконки iOS, Android (обычную, адаптивную и монохромную), Web, favicon и монохромный Android-значок уведомлений `@drawable/ic_stat_devmate`. Для локальных уведомлений используйте этот ресурс как small icon; метаданные для Firebase Messaging уже прописаны в AndroidManifest. Доставка push-уведомлений пока не настроена.
