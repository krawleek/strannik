# Конкурсная сборка и подпись

[Главная](../README.md) · [Ревизия документации](DOCUMENTATION_AUDIT.md)

Этот документ описывает текущую конфигурацию, не заменяет релизный QA. Версия в `pubspec.yaml` — **1.0.0+1**, applicationId — `ru.strannik.strannik`, minSdk — 26.

`android/app/build.gradle.kts` предусматривает production signing и проверку перед `preReleaseBuild`. Release не использует debug signing как запасной вариант. На момент проверки `android/key.properties` отсутствует, полный набор signing environment variables не задан. Конкурсный подписанный APK не подтверждён. Сборки release APK / AAB в рамках ревизии документации не запускались.

## Как передать уже существующие ключи

Конфигурация читает `android/key.properties` либо переменные окружения:

| key.properties | Переменная окружения |
|---|---|
| `storeFile` | `STRANNIK_KEYSTORE_PATH` |
| `storePassword` | `STRANNIK_KEYSTORE_PASSWORD` |
| `keyAlias` | `STRANNIK_KEY_ALIAS` |
| `keyPassword` | `STRANNIK_KEY_PASSWORD` |

Environment имеет приоритет. Путь keystore разрешается относительно Android-проекта; для внешнего защищённого хранения удобен абсолютный путь. Реальные пароли, ключи и keystore не следует помещать в Git; `android/.gitignore` исключает key.properties, jks и keystore. Не создавайте новый ключ взамен уже используемого без решения владельца приложения.

После безопасной настройки команда собирает обычный production entrypoint:

```bash
flutter build apk --release
flutter build appbundle --release
```

Успех команды не доказывает пригодность подписи: отдельно проверьте сертификат подписанта Android build-tools, установку / обновление и соответствие applicationId. Не используйте alias `androiddebugkey` и debug-сертификат для production. Не добавляйте секреты в примеры документации или скриншоты.

## Перед конкурсной сдачей

- Выбрать commit и обычный entrypoint, завершить Android-прохождение до третьей стадии.
- Получить проверенный APK, записать версию, подпись и SHA-256, добавить действительную ссылку для жюри.
- Переснять галерею этой сборки, включая Store; проверить запуск без сети и после перезапуска.
- Указать участников / роли и условия использования кода и материалов.
- Проверить требования конкретного конкурса к APK, видео и доступности ссылки. Публикация в RuStore и его одобрение не подтверждены и не требуются самой документацией.
