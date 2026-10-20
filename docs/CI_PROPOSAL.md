# Предложение минимального CI

[Главная](../README.md) · [Архитектура](ARCHITECTURE.md)

На момент ревизии `.github/workflows/` отсутствует: в репозитории нет GitHub Actions для analyze, test и APK. Ниже подготовлены **неактивные шаблоны**, поскольку запрос — предложить минимальные workflows. Автоматическая публикация не включена.

| Шаблон | Предлагаемый путь после принятия командой | Действия |
|---|---|---|
| [ci.yml.example](ci/ci.yml.example) | `.github/workflows/ci.yml` | push / pull_request → зависимости → analyze → test |
| [debug-apk.yml.example](ci/debug-apk.yml.example) | `.github/workflows/debug-apk.yml` | Ручной workflow_dispatch → проверки → debug APK → artifact на 7 дней |

Flutter закреплён на локально проверенной 3.47.5, а не на плавающей latest. Для APK выбран Temurin 21; target Android-кода в проекте остаётся 17. Используются GitHub-hosted Ubuntu runners. Тесты SQLite через FFI требуют доступной нативной SQLite-библиотеки; первый Linux-прогон шаблонов ещё не выполнен.

Синтаксис actions сверён с документацией поставщиков: [checkout](https://github.com/actions/checkout), [setup-java](https://github.com/actions/setup-java), [Flutter action](https://github.com/subosito/flutter-action), [upload-artifact](https://github.com/actions/upload-artifact). Шаблоны используют major-теги; перед включением команда может закрепить проверенные commit SHA. Это не утверждение об успешном CI: серверного запуска ещё не было.

Сборка APK запускается только вручную и не создаёт GitHub Release, не публикует приложение в магазине и не использует keystore. Debug artifact предназначен для просмотра, не для production-дистрибуции. Права — `contents: read`; отсутствуют secrets, deploy и `pull_request_target`.

Перед включением: просмотреть diff, убедиться, что выбран обычный `lib/main.dart`, перенести шаблоны по указанным путям, выполнить один CI-прогон и установить полученный APK на тестовое Android-устройство. Release workflow здесь намеренно не предлагается до настройки и проверки production-подписи.
