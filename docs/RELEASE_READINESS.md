# Конкурсная сборка и подпись

[Главная](../README.md) · [Ревизия документации](DOCUMENTATION_AUDIT.md)

Этот документ описывает текущую конфигурацию, не заменяет релизный QA. Версия в `pubspec.yaml` — **1.0.0+1**, applicationId — `ru.strannik.strannik`, minSdk — 26.

`android/app/build.gradle.kts` предусматривает production signing и проверку перед `preReleaseBuild`. Release не использует debug signing как запасной вариант. После ревизии, **20 октября 2026 года**, создан первый локальный release-ключ и успешно выполнен `flutter build apk --release` с обычным entrypoint `lib/main.dart`. AAB не собирался. APK размещён в [предварительном GitHub Release v1.0.0](https://github.com/krawleek/strannik/releases/tag/v1.0.0); публикация в магазинах приложений не выполнялась.

## Полученная release-сборка

- Файл: `build/app/outputs/flutter-apk/app-release.apk`, около 79,2 МБ; Android 8.0+; ABI arm64-v8a, armeabi-v7a, x86_64.
- Версия: `1.0.0+1`, пакет: `ru.strannik.strannik`; debug-флаг отсутствует.
- APK SHA-256: `a3f959251adc493012625509eb9890fdce76798ce571f1d94fcc4901b7997729`.
- Сертификат SHA-256: `61c240061fe03a5ab2b6c72f14852e3481338fc9e8ef0f3f84fdbe37729ddaca`; CN=Strannik; RSA 2048. `apksigner verify` успешно проверил подпись v2.
- Ключ: `android/strannik-release.jks`; alias: `strannik-release`. Пароли находятся только в локальном `android/key.properties`. Оба файла исключены из Git и имеют права 0600. Скопируйте их в защищённую резервную копию вне репозитория; для следующих обновлений нужен этот же ключ. Не передавайте их жюри вместе с APK.
- Установка и полное прохождение именно этого release APK в текущем этапе не проверялись. Debug и release подписаны разными ключами: обычная установка release поверх debug отклоняется Android. Не удаляйте debug-приложение с нужными сохранениями без резервного копирования данных.

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
- Проверить установку опубликованного APK на устройстве; версия, подпись, SHA-256 и ссылка для жюри записаны выше.
- Переснять галерею этой сборки, включая Store; проверить запуск без сети и после перезапуска.
- Указать участников / роли и условия использования кода и материалов.
- Проверить требования конкретного конкурса к APK, видео и доступности ссылки. Публикация в RuStore и его одобрение не подтверждены и не требуются самой документацией.
