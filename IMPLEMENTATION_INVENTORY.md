# Инвентаризация реализации «Странник»

Дата: 20 октября 2026, Europe/Moscow. Проверен рабочий каталог `/Users/admin/Documents/GitHub/strannik`, базовый HEAD `08b2e7b`, включая незакоммиченные и untracked реализации. Это аудит текущего рабочего дерева, а не содержимого одного коммита и не оценка готовности к релизу.

## 1. Краткий вывод

Приложение имеет рабочие onboarding, взаимодействия с питомцем, покупки/шкаф, профиль и три интерактивных урока. Полный путь ребёнка через три стадии не завершён: курс этапа 1 не проигрывается, экран стадий/большой цели отсутствует, Банк заменён заглушкой. Бизнес-логика накоплений существует отдельно от UI. Переводы «Нужно ↔ Хочу» не реализованы ни в сервисах, ни в интерфейсе.

Счётчики ниже относятся **только к уникальным строкам A1–H12 основной таблицы**, а не к числу экранов, тестов или повторяющимся подробностям отчёта. COMPLETE означает подтверждённый ограниченный сценарий строки (обычно widget + domain/SQLite); это не утверждение о полном совпадении с Figma или о возможности новичка добраться до этапа 3 через UI.

Всего **74 функций**. **COMPLETE: 30**, **PARTIAL: 12**, **UI ONLY: 5**, **SERVICE ONLY: 16**, **MISSING: 11**, **BROKEN: 0**, **UNVERIFIED: 0**.

Зарегистрировано **9 задач в 6 темах**: 3 имеют настоящий проигрыватель, 4 являются legacy placeholder, ещё 2 явно `implemented=false`. У этапа 1 нет ни одного проигрываемого урока. Этап 2 — «Список покупок». Этап 3 — «Секретный звонок» и «Поздравляем, ты выиграл!». Число всех запланированных дизайнером уроков по одному рабочему каталогу определить нельзя.

Код приложения, модели, schema и зависимости в рамках аудита не исправлялись. Проверочные сценарий и driver созданы только в `/tmp`; единственный добавленный исходный документ проекта — этот отчёт. Обнаружены параллельные изменения файлов/тестов и параллельный Android driver другого запуска; результаты ниже привязаны к конкретным логам.

### Источники и границы Figma

Figma доступна. Прочитаны структура страниц `1:3` (Final design) и `40000027:35093` (Прототип), контекст секции Stage 1 Tasks `40000220:31420`; найдены разделы onboarding, Store, Bank, стадий, Stage 2/3. Это **выборочное сопоставление структуры и содержания**, не покадровый визуальный аудит всего файла. Страница прототипа содержит копии и прежние подписи; нельзя считать каждый её frame отдельным обязательным новым экраном.

| Раздел Figma | Узел | Что установлено |
| --- | --- | --- |
| Onboarding | `40000220:26692`; исходный обновлённый раздел `40000126:20977` | Код имеет 23 состояния; полная визуальная идентичность не сертифицирована. |
| Store | `40000220:27748` | Есть StoreScreen/checkout/closet; каталог ограниченный. |
| Bank | `40000220:29296` | В макетах есть «Денежный счёт», «Перевод средств», «Пополнить счёт», история; в app только placeholder. |
| Stage 1 Tasks | `40000220:31420` | В карте: «Хочу или нужно?», «Планы на неделю», «Цель»; полноценного зарегистрированного контента для них нет. |
| Stage 2 Tasks | `40000220:30087` (Task1 `30774`, Discounts `30088` с тем же префиксом) | Shopping реализован; discounts — только карточка. |
| Stage 3 Tasks | `40000220:35049` (Task1 `35050`, Task2 `35634`) | Два расследования реализованы; карточка «Мама, это ты?» в `40000220:35583` в каталоге отсутствует. |
| Общий финал / справка safety | `40000215:83208`, `40000215:83464` | Отдельных экранов справки и финала темы в приложении не найдено. |

[Открыть Figma](https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App).

## 2. Основной реестр функций

Статусы: COMPLETE — проверенный сценарий; PARTIAL — часть сценария; UI ONLY — внешний вид без полноценной функции; SERVICE ONLY — логика без доступного пользовательского сценария; MISSING — реализация не найдена; BROKEN — воспроизводимая неисправность функции; UNVERIFIED — существующий код без проверки.

В колонке «Проверка» восемь значений: **код / UI / достижим / controls / реальные данные / persistence / тесты / E2E**. `1` — да, `0` — нет, `—` — неприменимо; `часть` — ограниченная поддержка. `W` в E2E — сценарий widget-теста, без утверждения о ручной проверке Android. Родительские/стадийные предпосылки создаются тестовой fixture, если полный UI-путь к ним отсутствует.

Ключи тестов: O — onboarding controller/widget; H — home_controller + widget_test; L — shopping_list + stage_assignment; F — financial_safety domain/widget; S — store domain/widget; P — profile domain/widget и notification_settings; D — прочие domain/app; DATA — SQLite persistence/migration. Финальный полный прогон всех этих тестов: 112 passed. Подробности запуска — раздел 10.


### A. Онбординг

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| A1 Первый запуск и вход после завершения | COMPLETE | 1/1/1/1/1/1/O/W | [lib/presentation/app/strannik_app.dart:36](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/strannik_app.dart:36) — `StrannikApp` | Сценарий startup проверен; Android-визуальная сверка всех экранов не проводилась. | P2 |
| A2 Знакомство с питомцем, последовательность и Back | COMPLETE | 1/1/1/1/1/—/O/W | [lib/presentation/onboarding/onboarding_controller.dart:8](/Users/admin/Documents/GitHub/strannik/lib/presentation/onboarding/onboarding_controller.dart:8) — `OnboardingStep, next/back` | 23 состояния; после принятия PIN возврат ограничен. | P2 |
| A3 Имя ребёнка и валидация | COMPLETE | 1/1/1/1/1/1/O/W | [lib/presentation/onboarding/onboarding_controller.dart:50](/Users/admin/Documents/GitHub/strannik/lib/presentation/onboarding/onboarding_controller.dart:50) — `canContinue, setChildName` | Пустые/пробельные имена запрещены; клавиатура проверена widget-тестом. | P2 |
| A4 Выбор скина и имя питомца | COMPLETE | 1/1/1/1/1/1/O/W | [lib/presentation/onboarding/onboarding_controller.dart:93](/Users/admin/Documents/GitHub/strannik/lib/presentation/onboarding/onboarding_controller.dart:93) — `setPetName, changeSkin` | gray/orange/cream сохраняются при финализации. | P2 |
| A5 Согласие, родительский PIN, Skip | COMPLETE | 1/1/1/1/1/1/O/W | [lib/app/onboarding/onboarding_flow_service.dart:15](/Users/admin/Documents/GitHub/strannik/lib/app/onboarding/onboarding_flow_service.dart:15) — `acceptPin, complete` | Skip объяснений ведёт на PIN; существующий PIN проверяется, не заменяется. | P2 |
| A6 Завершение, первые 100 фир и первый период | COMPLETE | 1/1/1/1/1/1/O,D/W | [lib/domain/services/onboarding_service.dart:49](/Users/admin/Documents/GitHub/strannik/lib/domain/services/onboarding_service.dart:49) — `complete` | Атомарная запись, однократность и rollback проверены. | P2 |
| A7 Восстановление незавершённого знакомства | PARTIAL | 1/1/1/1/1/0/O/0 | [lib/presentation/onboarding/onboarding_controller.dart:7](/Users/admin/Documents/GitHub/strannik/lib/presentation/onboarding/onboarding_controller.dart:7) — `transient draft` | Шаг, имена и выбор скина до финала только в памяти; после перезапуска начало заново. Сохранённый PIN учитывается. | P1 |

### B. Home

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| B1 Отображение питомца, имени и экипировки | COMPLETE | 1/1/1/—/1/1/H,S/W | [lib/presentation/components/pet_appearance.dart:9](/Users/admin/Documents/GitHub/strannik/lib/presentation/components/pet_appearance.dart:9) — `PetAppearance` | Общий компонент с Магазином; доступные скины и шарфик. | P2 |
| B2 Погладить и реакции | COMPLETE | 1/1/1/1/1/—/H/W | [lib/presentation/home/home_controller.dart:89](/Users/admin/Documents/GitHub/strannik/lib/presentation/home/home_controller.dart:89) — `strokePet` | Реакция локальная, наград и сохранения не требует. | P2 |
| B3 Угостить и играть | COMPLETE | 1/1/1/1/1/1/H,D/W | [lib/presentation/home/home_controller.dart:93](/Users/admin/Documents/GitHub/strannik/lib/presentation/home/home_controller.dart:93) — `giveTreat, play` | Потребление лакомств и XP игрушки один раз за финансовый период проверены. | P2 |
| B4 Индикатор XP / прогресс этапа на Home | UI ONLY | 1/1/1/1/0/0/H/0 | [lib/presentation/home/home_screen.dart:130](/Users/admin/Documents/GitHub/strannik/lib/presentation/home/home_screen.dart:130) — `StrannikStageBadge` | Номер этапа реальный, прогресс всегда DevelopmentHomePreview.stageProgress = 0/3; XP не показан. | P1 |
| B5 Баланс валюты на Home | MISSING | 0/0/0/0/0/0/—/0 | [lib/presentation/home/home_view_state.dart:6](/Users/admin/Documents/GitHub/strannik/lib/presentation/home/home_view_state.dart:6) — `HomeSnapshot` | В snapshot нет Wallet, в HomeScreen нет числового баланса; он есть в Магазине/Обучении. | P1 |
| B6 Открытие стадий / переход из Home | SERVICE ONLY | 1/0/0/0/1/1/D/0 | [lib/presentation/app/app_shell.dart:151](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:151) — `DestinationPlaceholder(stages)` | Бейдж открывает заглушку; UI выбора большой цели и advanceStage отсутствует. | P0 |
| B7 Ежедневная награда | MISSING | 0/0/0/0/0/0/—/0 | [lib/domain/models/models.dart:17](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:17) — `TransactionType` | Нет daily-операции, календарного claim, экрана или тестов; 100 фир — только onboarding. | P1 |
| B8 Основная навигация | PARTIAL | 1/1/1/1/1/—/H,W/часть | [lib/presentation/app/app_shell.dart:86](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:86) — `build, _navigate` | Home/Магазин/Обучение/профиль подключены; Bank/petProfile/stages — тупики-заглушки. | P0 |
| B9 Окружение и вид питомца по трём стадиям | PARTIAL | 1/1/1/—/часть/1/H,S/0 | [lib/presentation/components/pet_appearance.dart:14](/Users/admin/Documents/GitHub/strannik/lib/presentation/components/pet_appearance.dart:14) — `build` | currentStage не выбирает отдельную сцену/позу; Home использует одну комнату, pet emotionalState не управляет артом. | P1 |

### C. Обучение

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| C1 Учебный курс этапа 1 | UI ONLY | 1/1/1/0/1/1/L/0 | [lib/presentation/learning/learning_screen.dart:259](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/learning_screen.dart:259) — `_taskCard` | Четыре старые записи choice/placeholder; ни одна не имеет проигрывателя UI. | P0 |
| C2 Этап 2: Список покупок | COMPLETE | 1/1/1/1/1/1/L,W/W | [lib/presentation/learning/shopping_list_controller.dart:8](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/shopping_list_controller.dart:8) — `ShoppingListController` | Функциональный урок при уже открытом этапе 2; переход этапа из UI — отдельный пробел B6. | P2 |
| C3 Этап 3: Секретный звонок | COMPLETE | 1/1/1/1/1/1/F,W/W | [lib/content/lessons/financial_safety_lesson.dart:70](/Users/admin/Documents/GitHub/strannik/lib/content/lessons/financial_safety_lesson.dart:70) — `FinancialSafetyLesson.call` | Ветвление, вопросы, feedback, безопасное окончание и награда проверены; Android полный проход в этом аудите не подтверждён. | P2 |
| C4 Этап 3: Поздравляем, ты выиграл! | COMPLETE | 1/1/1/1/1/1/F,W/W | [lib/content/lessons/financial_safety_lesson.dart:195](/Users/admin/Documents/GitHub/strannik/lib/content/lessons/financial_safety_lesson.dart:195) — `FinancialSafetyLesson.email` | Письмо, три улики, вопросы, учебный сайт/карта, удаление и награда проверены; карта намеренно не принимает настоящие данные. | P2 |
| C5 Этап 2: Ловушки скидок | UI ONLY | 1/1/1/0/1/0/L/0 | [lib/content/seed/development.json:203](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:203) — `space_theme1_task2` | Карточка есть, implemented=false; нет игровых экранов. | P1 |
| C6 Этап 2: Выбираем с умом | UI ONLY | 1/1/1/0/1/0/L/0 | [lib/content/seed/development.json:214](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:214) — `space_theme1_task3` | Карточка есть, implemented=false; нет игровых экранов. | P1 |
| C7 Разблокировка и фильтрация по этапу | COMPLETE | 1/1/1/1/1/1/L,F/W | [lib/domain/services/learning_service.dart:11](/Users/admin/Documents/GitHub/strannik/lib/domain/services/learning_service.dart:11) — `_available, LearningScreen._tasks` | Внутри этапа 2 последовательность; два расследования этапа 3 независимы; demo учитывается. | P2 |
| C8 Черновик попытки и прогресс после перезапуска | COMPLETE | 1/1/1/1/1/1/L,F,DATA/W | [lib/data/local/migrations/schema_v4.dart:1](/Users/admin/Documents/GitHub/strannik/lib/data/local/migrations/schema_v4.dart:1) — `lesson_state` | SQLite reopen проверен для shopping и safety; UI-карты перечитывают состояние. | P2 |
| C9 Награды, completion и replay трёх уроков | COMPLETE | 1/1/1/1/1/1/L,F,DATA/W | [lib/domain/services/learning_service.dart:112](/Users/admin/Documents/GitHub/strannik/lib/domain/services/learning_service.dart:112) — `completeLearningTask` | Каждый 250 фир +15 XP один раз; replay не повторяет награду/финансовый период. | P2 |
| C10 Справочники и общий финал темы | MISSING | 0/0/0/0/0/0/—/0 | [lib/presentation/learning/learning_screen.dart:140](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/learning_screen.dart:140) — `build` | Нет самостоятельного справочника и общего финала темы из Figma; есть только completion отдельных уроков. | P1 |
| C11 Replay уроков предыдущих этапов из интерфейса | PARTIAL | 1/часть/0/0/1/1/L,F/0 | [lib/presentation/learning/learning_screen.dart:148](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/learning_screen.dart:148) — `topics filtered by current stage` | Replay текущего этапа работает; UI выбора предыдущего этапа/каталога пройденных уроков отсутствует. | P1 |

### D. Магазин

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| D1 Каталог из локального контента | PARTIAL | 1/1/1/1/1/1/S/W | [lib/content/seed/development.json:22](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:22) — `items` | 7 рабочих товаров, но описания тестовые, assetId=placeholder; titanium/iron без собственного изображения. | P1 |
| D2 Фильтрация по категориям | MISSING | 0/0/0/0/0/0/—/0 | [lib/presentation/store/store_controller.dart:17](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_controller.dart:17) — `visibleItems` | Enum категорий есть; visibleItems фильтрует только владение для шкафа, категории выбрать нельзя. | P1 |
| D3 Выбор товара и временная примерка | COMPLETE | 1/1/1/1/1/—/S/W | [lib/presentation/store/store_controller.dart:33](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_controller.dart:33) — `previewAccessory, select` | Примерка шарфика не покупает и не экипирует предмет. | P2 |
| D4 Корзина | PARTIAL | 1/1/1/1/1/0/S/W | [lib/presentation/store/store_screen.dart:104](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_screen.dart:104) — `checkout, _CheckoutSheet` | Корзина одного выбранного товара, без количества/набора товаров и сохранённого черновика; не многотоварная корзина. | P1 |
| D5 Выбор Нужно/Хочу при оплате | PARTIAL | 1/1/1/часть/1/1/S/W | [lib/presentation/store/store_screen.dart:865](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_screen.dart:865) — `accounts` | Это метка PurchasePurpose и предупреждение о плане; категории не счета. При budget=null выбор отключён, остаётся общий баланс. | P1 |
| D6 Покупка и запись inventory/history | COMPLETE | 1/1/1/1/1/1/S,D,DATA/W | [lib/domain/services/store_service.dart:21](/Users/admin/Documents/GitHub/strannik/lib/domain/services/store_service.dart:21) — `buyItem` | Цена из каталога, атомарность, повтор операции и overspend проверены. | P2 |
| D7 Недостаточно средств и переход заработать | COMPLETE | 1/1/1/1/1/—/S/W | [lib/presentation/store/store_screen.dart:839](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_screen.dart:839) — `_CheckoutSheet` | Покупка отклоняется; кнопка «Заработать в заданиях» вызывает onLearning. | P2 |
| D8 Успех покупки | COMPLETE | 1/1/1/1/1/1/S/W | [lib/presentation/store/store_screen.dart:778](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_screen.dart:778) — `_CheckoutSheet` | Обновляется реальный snapshot, показан успех, возврат в магазин. | P2 |

### E. Шкаф

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| E1 Принадлежащие предметы и пустое состояние | COMPLETE | 1/1/1/1/1/1/S/W | [lib/presentation/store/store_controller.dart:17](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_controller.dart:17) — `visibleItems, showCloset` | Вкладка Шкаф в StoreScreen, не отдельный маршрут. | P2 |
| E2 Надеть / снять аксессуар | COMPLETE | 1/1/1/1/1/1/S,D/W | [lib/presentation/store/store_controller.dart:134](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_controller.dart:134) — `use` | Требуется владение; шарфик визуально отображается на Home/в магазине. | P2 |
| E3 Лакомства и игрушки | COMPLETE | 1/1/1/1/1/1/S,D/W | [lib/domain/services/pet_interaction_service.dart:26](/Users/admin/Documents/GitHub/strannik/lib/domain/services/pet_interaction_service.dart:26) — `useTreat, activateToy, playWithToy` | Расходник уменьшается; игрушка активируется, XP ограничен периодом. | P2 |
| E4 Сохранение inventory и equipment | COMPLETE | 1/1/1/1/1/1/S,DATA/W | [test/domain/store_test.dart:167](/Users/admin/Documents/GitHub/strannik/test/domain/store_test.dart:167) — `ownership and equipped appearance survive database restart` | Проверено закрытие/повторное открытие SQLite. | P2 |
| E5 Использование материалов большой цели из UI | SERVICE ONLY | 1/0/0/0/1/1/D/0 | [lib/domain/services/progression_service.dart:55](/Users/admin/Documents/GitHub/strannik/lib/domain/services/progression_service.dart:55) — `advanceStage` | Материалы купить можно; расходовать для перехода через интерфейс нельзя. | P0 |

### F. Банк

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| F1 Экран Банка | MISSING | 0/0/0/0/0/0/H/0 | [lib/presentation/app/app_shell.dart:151](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:151) — `DestinationPlaceholder(bank)` | Кнопка Банк доступна, фактического BankScreen нет. | P0 |
| F2 Баланс и итог wallet + savings в Банке | SERVICE ONLY | 1/0/0/0/1/1/D,DATA/0 | [lib/data/repositories/sqlite_repositories.dart:145](/Users/admin/Documents/GitHub/strannik/lib/data/repositories/sqlite_repositories.dart:145) — `wallet, savings` | Данные хранятся отдельно; нет экрана, суммирования/пояснения общей суммы пользователю. | P1 |
| F3 Распределение бюджета | SERVICE ONLY | 1/0/0/0/1/1/D,DATA/0 | [lib/domain/services/economy_service.dart:35](/Users/admin/Documents/GitHub/strannik/lib/domain/services/economy_service.dart:35) — `allocateBudget` | Есть план mandatory/optional/remainder и сумма <= wallet; нет интерфейса создания/редактирования. | P0 |
| F4 Категория Нужно | SERVICE ONLY | 1/часть/часть/0/1/1/S,D/0 | [lib/domain/models/models.dart:145](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:145) — `BudgetAllocation.mandatory` | План показывается в checkout, не независимый баланс; отсутствует экран категории. | P1 |
| F5 Категория Хочу | SERVICE ONLY | 1/часть/часть/0/1/1/S,D/0 | [lib/domain/models/models.dart:145](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:145) — `BudgetAllocation.optional` | Аналогично Нужно; покупки не уменьшают optional. | P1 |
| F6 Перевод между распределениями бюджета | MISSING | 0/0/0/0/0/0/—/0 | [lib/domain/services/economy_service.dart:6](/Users/admin/Documents/GitHub/strannik/lib/domain/services/economy_service.dart:6) — `EconomyService` | Нет transfer(from,to,amount), типа транзакции, источника/получателя или UI. allocateBudget заменяет план целиком. | P0 |
| F7 Валидация перевода между категориями | MISSING | 0/0/0/0/0/0/—/0 | [lib/domain/models/models.dart:17](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:17) — `TransactionType` | Нет операции — нет проверки source!=destination, достаточности источника, атомарного дебета/кредита или transfer-тестов. | P0 |
| F8 Создание цели накопления | SERVICE ONLY | 1/0/0/0/1/1/D/0 | [lib/domain/services/savings_service.dart:20](/Users/admin/Documents/GitHub/strannik/lib/domain/services/savings_service.dart:20) — `createSavingsGoal` | Одна цель, положительный target, после theme2/demo; нет подключённой формы. | P1 |
| F9 Взнос в накопления | SERVICE ONLY | 1/0/0/0/1/1/D,DATA/0 | [lib/domain/services/savings_service.dart:38](/Users/admin/Documents/GitHub/strannik/lib/domain/services/savings_service.dart:38) — `depositToSavings` | Уменьшает wallet, увеличивает saved и историю атомарно; нет UI. | P1 |
| F10 Снятие накоплений | SERVICE ONLY | 1/0/0/0/1/1/D,DATA/0 | [lib/domain/services/savings_service.dart:61](/Users/admin/Documents/GitHub/strannik/lib/domain/services/savings_service.dart:61) — `withdrawFromSavings` | Поддерживается сервисом; saved уменьшается, wallet увеличивается. Нет UI. | P1 |
| F11 Отделение накоплений и сохранение суммы денег | SERVICE ONLY | 1/0/0/0/1/1/D/0 | [lib/domain/models/models.dart:218](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:218) — `Transaction.availableDelta, direction` | deposit/withdraw сохраняют wallet+saved и не считаются доходом/расходом; это не перевод Нужно↔Хочу. | P1 |
| F12 Недостаток средств / превышение цели | SERVICE ONLY | 1/0/0/0/1/1/D/0 | [lib/domain/services/savings_service.dart:38](/Users/admin/Documents/GitHub/strannik/lib/domain/services/savings_service.dart:38) — `depositToSavings, withdrawFromSavings` | Проверяются positive/target/wallet/saved; пользователь не видит ошибки, потому что формы нет. | P1 |
| F13 История транзакций | SERVICE ONLY | 1/0/0/0/1/1/D,DATA/0 | [lib/data/repositories/sqlite_repositories.dart:194](/Users/admin/Documents/GitHub/strannik/lib/data/repositories/sqlite_repositories.dart:194) — `transactions, recordTransaction` | SQLite-история и periodId есть; экран/фильтрация/детали Банка отсутствуют. | P1 |
| F14 Мгновенное обновление UI после перевода | MISSING | 0/0/0/0/0/0/—/0 | [lib/presentation/app/app_shell.dart:151](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:151) — `bank placeholder` | Нет BankController/BankScreen и команды перевода. | P1 |
| F15 Состояние Банка после перезапуска | SERVICE ONLY | 1/0/0/0/1/1/DATA/0 | [test/data/persistence_test.dart:46](/Users/admin/Documents/GitHub/strannik/test/data/persistence_test.dart:46) — `all state survives closing and reopening SQLite` | wallet/план/цель/history переживают reopen; банковского пользовательского сценария нет. | P1 |

### G. Прогрессия

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| G1 Три стадии и сохранение текущей | COMPLETE | 1/1/1/—/1/1/L,F,DATA/W | [lib/domain/models/models.dart:3](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:3) — `Stage; Pet.currentStage` | Номер/карта читают effectiveStage; переход оценивается отдельно. | P2 |
| G2 Контент, специфичный для стадии | PARTIAL | 1/1/1/1/1/1/L,F/часть | [lib/content/seed/development.json:88](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:88) — `themes, tasks` | Этап1: нет playable; этап2: 1 урок; этап3: 2 урока. Остальное покрытие Figma неполное. | P0 |
| G3 Большая цель и правила перехода | SERVICE ONLY | 1/0/0/0/1/1/D,L,F/0 | [lib/domain/services/progression_service.dart:10](/Users/admin/Documents/GitHub/strannik/lib/domain/services/progression_service.dart:10) — `selectBigGoal, confirmBigGoal, checkStageRequirements` | XP+материалы+подтверждённая цель; в интерфейсе выбрать/подтвердить нельзя. | P0 |
| G4 Фактическое продвижение и списание ресурсов | SERVICE ONLY | 1/0/0/0/1/1/D,L,F,DATA/0 | [lib/domain/services/progression_service.dart:55](/Users/admin/Documents/GitHub/strannik/lib/domain/services/progression_service.dart:55) — `advanceStage` | Транзакция меняет stage и события; нет доступной кнопки/сценария ребёнка. | P0 |
| G5 Начисление XP и фир | COMPLETE | 1/1/1/1/1/1/D,L,F,S/W | [lib/domain/services/game_context.dart:44](/Users/admin/Documents/GitHub/strannik/lib/domain/services/game_context.dart:44) — `money, earnXp` | Работает через подключённые уроки/взаимодействия/покупки/родительскую награду; уникальные ключи. | P2 |
| G6 Финансовые периоды и отчёт | SERVICE ONLY | 1/0/0/0/1/1/D,DATA/0 | [lib/domain/services/period_service.dart:19](/Users/admin/Documents/GitHub/strannik/lib/domain/services/period_service.dart:19) — `summary, advanceCompletedThemes` | 5 периодов, снимки summary; самостоятельного экрана отчёта нет. В shipped Earth-контенте триггеры недостижимы через UI. | P1 |
| G7 Demo: включение и переключение стадии | PARTIAL | 1/часть/часть/часть/1/1/D/0 | [lib/domain/services/demo_service.dart:15](/Users/admin/Documents/GitHub/strannik/lib/domain/services/demo_service.dart:15) — `changeDemoStage` | Переключатель demo в профиле есть; UI выбора demoStage отсутствует. Это не реальная прогрессия. | P1 |

### H. Профили

| ID / функция | Статус | Проверка | Доказательство: файл и символ | Недостающее / ограничение | Приоритет |
| --- | --- | --- | --- | --- | --- |
| H1 Профиль ребёнка, имя и аватар | COMPLETE | 1/1/1/1/1/1/P,DATA/W | [lib/presentation/profile/profile_screen.dart:406](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_screen.dart:406) — `child, rename, avatar` | Сохранение и отображение реальных данных проверены. cap отображается тем же boy asset. | P2 |
| H2 Достижения / badges | MISSING | 0/0/0/0/0/0/—/0 | [lib/domain/models/models.dart:38](/Users/admin/Documents/GitHub/strannik/lib/domain/models/models.dart:38) — `ProgressEventType` | Есть события прогресса и статус уроков; отдельной системы достижений/награды за achievement нет. | P1 |
| H3 Streak / серия дней | MISSING | 0/0/0/0/0/0/—/0 | [lib/app/profile_playtime.dart:8](/Users/admin/Documents/GitHub/strannik/lib/app/profile_playtime.dart:8) — `PlaytimeService` | Playtime — минуты по дням, не streak и не ежедневный claim. | P1 |
| H4 Сохранение настроек звук/музыка/вибрация | COMPLETE | 1/1/1/1/1/1/P,DATA/W | [lib/presentation/profile/profile_controller.dart:82](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_controller.dart:82) — `setting` | Флаги и переключатели рабочие; реальное воспроизведение музыки — отдельный H5. | P2 |
| H5 Воспроизведение фоновой музыки | UI ONLY | 1/1/1/1/0/часть/D/0 | [lib/app/feedback/feedback_services.dart:83](/Users/admin/Documents/GitHub/strannik/lib/app/feedback/feedback_services.dart:83) — `MusicService, NoOpMusicOutput` | В production factory нет MusicOutput; переключатель сохраняется, но аудио/плеера нет. | P1 |
| H6 Уведомления Android | PARTIAL | 1/1/1/1/1/1/P,D/0 | [lib/app/settings/notification_settings.dart:13](/Users/admin/Documents/GitHub/strannik/lib/app/settings/notification_settings.dart:13) — `AndroidNotifications` | MethodChannel/permission/уведомление о родительском подарке есть; доставка на Android в аудите не проверена. Планировщика ежедневных уведомлений нет. | P2 |
| H7 Родительский вход и защищённая сессия | COMPLETE | 1/1/1/1/1/часть/P,D/W | [lib/domain/services/parent_access_service.dart:26](/Users/admin/Documents/GitHub/strannik/lib/domain/services/parent_access_service.dart:26) — `authenticate, authorized` | 10 минут, выход при background/возврате ребёнку; PIN hash/lockout сохраняются, сессия намеренно в памяти. | P2 |
| H8 Родительский прогресс и время | PARTIAL | 1/1/1/1/1/1/P/часть | [lib/presentation/profile/profile_screen.dart:560](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_screen.dart:560) — `dashboard, progress, topic` | Реальные completion/minutes; темы всех этапов смешаны, нумерация нулевая, обсуждения одинаковы для всех тем. | P1 |
| H9 Родительский подарок фир | COMPLETE | 1/1/1/1/1/1/P,D/W | [lib/presentation/profile/profile_controller.dart:104](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_controller.dart:104) — `reward` | Защищённая операция с operationId, положительной суммой, транзакцией и обновлением wallet. | P2 |
| H10 Сброс и удаление данных | COMPLETE | 1/1/1/1/1/1/P,DATA/W | [lib/data/repositories/sqlite_repositories.dart:488](/Users/admin/Documents/GitHub/strannik/lib/data/repositories/sqlite_repositories.dart:488) — `resetProgress, deleteAllData` | Подтверждение + родительская сессия; reset сохраняет имя/PIN, delete очищает их. | P2 |
| H11 Забытый PIN / восстановление | PARTIAL | 1/1/1/часть/1/1/P/0 | [lib/presentation/profile/profile_screen.dart:995](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_screen.dart:995) — `PIN recovery UI` | Информационный flow и обращение в поддержку есть; успешной процедуры изменения забытого PIN без старого нет. Сам по себе ответ на вопрос доступ не выдаёт. | P1 |
| H12 Профиль питомца | MISSING | 0/0/0/0/0/0/H/0 | [lib/presentation/app/app_shell.dart:151](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:151) — `DestinationPlaceholder(petProfile)` | Кликабельный аватар ведёт на временный экран. | P1 |

## 3. Все зарегистрированные учебные задания

Единственный runtime-реестр — [development.json](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:88), загружаемый `HomeRuntime.open` через `LocalContentRepository`. Имя development не означает, что подключён другой production-каталог. Порядок в JSON нулевой; в таблице показан пользовательский номер `order + 1`. Stage наследуется от темы, если не задан у задачи.

| Этап / тема | № | Название / stable ID / contentReference | Экраны и механика | Завершение / награды | Зависимости | Статус / недостающее / приоритет |
| --- | --- | --- | --- | --- | --- | --- |
| 1 earth / `theme1`, «Тема 1» | 2 | Дополнительное учебное задание / `practice` / `placeholder` | Только карточка в LearningScreen; type=choice, проигрывателя нет | repeatable: 5 фир, 0 XP за новую завершённую попытку в сервисе | В текущем/более позднем этапе логически доступно; UI запуска нет | UI ONLY; настоящий дополнительный урок отсутствует; P0 |
| 1 earth / `theme2`, «Тема 2» | 1 | Пример задания / `theme2_task` / `placeholder` | Карточка, type=choice, без механики | oneTime: 20 фир, 0 XP; `completeLearningTask` не проверяет ответы generic choice | В `theme1` нет обязательной oneTime задачи, поэтому сервис пропускает её | UI ONLY; нет урока/реального evaluator; P0 |
| 1 earth / `theme3`, «Тема 3» | 1 | Пример задания / `theme3_task` / `placeholder` | Аналогично, нет проигрывателя | oneTime: 20 фир, 0 XP | После `theme2_task` | UI ONLY; нет урока; P0 |
| 1 earth / `fraud`, «Безопасность» | 1 | Пример задания / `fraud_task` / `placeholder` | Аналогично; это legacy-запись, не новый safety-урок этапа 3 | oneTime: 20 фир, 0 XP | После `theme2_task` и `theme3_task` | UI ONLY; нет урока; P1 |
| 2 space / `space_theme1`, «Покупки и скидки» | 1 | Список покупок / **`theme1_task`** / `shopping_list_v1` | 14 шагов: интро с развилкой, подготовка к киновечеру, учебный диалог, выбор четырёх товаров, бюджет, успех, награда | Не пустой набор и сумма ≤350; подтверждение выбора; **250 фир +15 XP один раз**; replay без награды | Реальный/effective этап ≥2; карта показывает на этапе 2 | COMPLETE в пределах открытого этапа; полноценный UI-путь перехода к этапу 2 отсутствует; P2 для самого урока |
| 2 space / `space_theme1` | 2 | Ловушки скидок / `space_theme1_task2` / `discount_traps` | Только карточка, type=unavailable, implemented=false | Награды отсутствуют в JSON → 0/0; завершить нельзя | Логически после `theme1_task`, даже после unlock кнопка неактивна | UI ONLY; все игровые экраны отсутствуют; P1 |
| 2 space / `space_theme1` | 3 | Выбираем с умом / `space_theme1_task3` / `choose_wisely` | Только карточка, implemented=false | 0/0; завершить нельзя | После первых двух задач, в текущем продукте недостижимо | UI ONLY; все игровые экраны отсутствуют; P1 |
| 3 homePlanet / `home_planet_safety`, «Безопасность» (order=2, тема №3) | 1 | Секретный звонок / `home_planet_safety_call` / `financial_safety_call_v1` | Входящий звонок, реплики, ветки слушать/положить трубку, два вопроса с feedback, безопасный вывод, reward | Журнал допустимых событий должен привести к complete; **250 фир +15 XP один раз**; replay без повтора | Effective этап 3; независимо от второго расследования | COMPLETE по domain/widget/SQLite; Android весь урок в этом аудите не пройден; P2 |
| 3 homePlanet / `home_planet_safety` | 2 | Поздравляем, ты выиграл! / `home_planet_safety_email` / `financial_safety_email_v1` | Письмо, ответы, три интерактивные улики, учебная страница приза, муляж карты, вывод/удалить письмо, reward | Все 3 улики + принятые переходы/feedback; **250 фир +15 XP один раз** | Effective этап 3; независимо от звонка | COMPLETE по domain/widget/SQLite; Android весь урок в этом аудите не пройден; P2 |

### Источники реализаций и результаты проверки содержания

- Shopping: [shopping_list_lesson.dart](/Users/admin/Documents/GitHub/strannik/lib/content/lessons/shopping_list_lesson.dart), [controller](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/shopping_list_controller.dart), [screen](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/shopping_list_screen.dart). Учебные 350 фир не списываются с настоящего wallet; товары упражнения не попадают в inventory. Это симуляция, а не реальные Store-покупки.
- Safety: [financial_safety_lesson.dart](/Users/admin/Documents/GitHub/strannik/lib/content/lessons/financial_safety_lesson.dart:43), [controller](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/financial_safety_controller.dart), [screen](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/financial_safety_screen.dart). Неверный ответ сопровождается объяснением и допускает продолжение; награда за прохождение, а не за безошибочную попытку. Ссылки/карта — намеренная безопасная учебная имитация, не недоделанная платёжная интеграция.
- Сопоставление экранов с реестром: [LearningScreen._taskCard](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/learning_screen.dart:259) допускает запуск только shopping ID и двух safety ID. Отдельных скрытых проигрывателей других типов в `lib/` не найдено.
- Stable ID не дублируются. Shopping корректно принадлежит **этапу 2**, несмотря на историческое имя `theme1_task`. Safety принадлежит **этапу 3** и не заменяет `fraud_task` этапа 1. Есть проверки ownership/наследования stage/дубликатов в parser и тестах.
- Не найдено реализованных, но незарегистрированных уроков. Найдены зарегистрированные, но не проигрываемые шесть записей; у четырёх placeholder значение `implemented` по умолчанию true — оно **не доказывает** наличие UI. P1: привести метаданные к фактической доступности после определения контента.
- В Figma найдены отсутствующие по названию сценарии этапа 1 «Хочу или нужно?» (`40000220:31686`), «Планы на неделю» (`40000220:31690`), «Цель» (`40000220:31694`) и карточка этапа 3 «Мама, это ты?» (`40000220:35583`). **MISSING, P1**, а для курса этапа 1 — P0. У них нет стабильных ID и полноценных проигрывателей; однозначное соответствие legacy-placeholder не задано. Не складывать эти четыре названия с шестью недоделанными записями как точное число всего будущего курса.
- В `homePlanet` зарегистрирована только тема order=2; order=0/1 отсутствуют. **PARTIAL, P1**: это неполный каталог этапа, не доказательство ошибки нумерации; перечень всех обязательных тем требует утверждённой карты контента.
- Экран reward safety не является общим финалом темы. «Завершить тему» возвращает к карте; completion темы вычисляется по её зарегистрированным oneTime-задачам (сейчас двум).

## 4. Подробный аудит Банка и переводов

### Реальная модель денег

`Wallet.firaAmount` — единый доступный баланс. `BudgetAllocation(mandatory, optional, remainder)` — **план**, не три кошелька. `SavingsGoal.savedAmount` — отдельные накопления, выведенные из доступного wallet. Единственная цель с target/status предусмотрена схемой; несколько параллельных целей не поддерживаются.

[EconomyService.allocateBudget](/Users/admin/Documents/GitHub/strannik/lib/domain/services/economy_service.dart:35) сохраняет три неотрицательных целых значения с общей суммой не выше текущего wallet. Метод не меняет wallet, не создаёт перевод и не пишет историю распределений. [StoreService.buyItem](/Users/admin/Documents/GitHub/strannik/lib/domain/services/store_service.dart:21) списывает только wallet. Выбор «Нужно/Хочу» сохраняется строкой «План: …» в `Transaction.description`; `mandatory/optional` не уменьшаются.

**F6/F7 — MISSING, P0:** перевод между категориями не работает. Нельзя считать замену плана через allocateBudget банковским переводом. В `TransactionType` нет budgetTransfer, в schema нет счетов отправителя/получателя, в EconomyService нет команды transfer. Соответственно, сохранение общей суммы, нехватка денег на источнике и история таких переводов не проверены и не реализованы.

### Что проверено сервисными тестами

| Операция | Реальное поведение | Статус / доказательство / пробел / приоритет |
| --- | --- | --- |
| Установить план | Отрицательные значения запрещены, total ≤ wallet; wallet неизменен | SERVICE ONLY — `BudgetAllocation`, `allocateBudget`, [economy_test.dart](/Users/admin/Documents/GitHub/strannik/test/domain/economy_test.dart:147). Нет Bank UI, P0. |
| Создать накопление | После `theme2` или demo; непустое имя, target>0, одна цель | SERVICE ONLY — `SavingsService.createSavingsGoal`, [savings_service.dart](/Users/admin/Documents/GitHub/strannik/lib/domain/services/savings_service.dart:20). Нет формы, P1. |
| Внести в накопления | wallet −amount, saved +amount; запрет сверх target/wallet/неположительных | SERVICE ONLY — `depositToSavings`, [economy_test.dart](/Users/admin/Documents/GitHub/strannik/test/domain/economy_test.dart:188). Нет кнопки и сообщения об ошибке, P1. |
| Снять накопления | saved −amount, wallet +amount; нельзя снять больше saved | SERVICE ONLY — `withdrawFromSavings`, тот же тест. Можно снять существующее накопление и после отключения demo. Нет UI, P1. |
| Сохранение общей суммы | wallet+saved не увеличивается от deposit/withdraw; операции internalTransfer, не доход/расход | SERVICE ONLY — `Transaction.availableDelta/direction`, `PeriodService._calculate`; нет категорийных переводов, P1. |
| Сохранение истории | Transaction со временем, periodId, source/type, relatedId; операция в одной SQLite transaction | SERVICE ONLY — `GameContext.money`, `SqliteRepositories.recordTransaction`, [schema_v1.dart](/Users/admin/Documents/GitHub/strannik/lib/data/local/migrations/schema_v1.dart). Нет просмотра истории, P1. |
| Перезапуск | Wallet, план, цель, суммы и записи history восстанавливаются после actual SQLite reopen | SERVICE ONLY — [persistence_test.dart:46](/Users/admin/Documents/GitHub/strannik/test/data/persistence_test.dart:46). Нет end-to-end банковского экрана, P1. |
| Немедленная реакция UI | Для Store snapshot перечитывается; для Банка нечему обновляться | MISSING — `AppShell` направляет Bank в placeholder, P1. |

**Граница тестов:** большинство старых economy-тестов используют fixture с играбельным служебным `choice`, а не настоящий курс этапа 1. Поэтому тестовая возможность `unlockSavings()` не доказывает, что ребёнок может открыть накопления в текущем UI. В обычном shipped-каталоге `theme2_task` нельзя пройти через экран.

**Согласованность плана: PARTIAL, P1.** Покупка или вклад могут оставить сохранённый план выше остатка wallet. `BudgetAllocation.shortfall()` умеет вычислить разницу, но автоматической балансировки нет. В текущей модели это необязательный план, не повреждение wallet и не доказательство потери/эмиссии денег. Если дизайн предполагает настоящие счета «Нужно/Хочу», потребуется отдельно согласовать их семантику; аудит её не менял.

## 5. Отсутствующие экраны и взаимодействия

| Экран / действие | Статус | Доказательство | Что отсутствует | Приоритет |
| --- | --- | --- | --- | --- |
| Bank / денежный счёт / история / перевод / пополнение | MISSING | `AppShell.build` → [DestinationPlaceholder](/Users/admin/Documents/GitHub/strannik/lib/presentation/placeholders/destination_placeholder.dart:8) | Все BankScreen, формы, controller и привязки к сервисам | P0 |
| Стадии / большая цель | SERVICE ONLY | [ProgressionService](/Users/admin/Documents/GitHub/strannik/lib/domain/services/progression_service.dart:6), route stages — placeholder | Показ условий, выбор/подтверждение цели, действие перехода и использование ресурсов | P0 |
| Игровые экраны этапа 1 | UI ONLY | `LearningScreen._taskCard`, seed placeholder | Учебные механики, ответы, объяснения, completion реального курса | P0 |
| Скидки / разумный выбор этапа 2 | UI ONLY | `space_theme1_task2/3`, implemented=false | Проигрыватели и реальные reward config | P1 |
| Профиль питомца | MISSING | route petProfile → placeholder | Полноценный профиль и связанное управление | P1 |
| Справочники / финал темы / обзор финансового периода | MISSING / SERVICE ONLY | `LearningScreen.build`; `PeriodService.summary` | Справочник и финал не реализованы, summary только в сервисе | P1 |
| Ежедневные награды / streak / achievements | MISSING | `TransactionType`, schema, `PlaytimeService` | Экран, правила, сохранение, награды и контроль повторов | P1 |
| Выбор старой стадии для replay | PARTIAL | [LearningScreen](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/learning_screen.dart:148) | Карта фильтруется текущим stage, выбора прежних стадий нет | P1 |
| Полная музыка / специфичные состояния питомца | UI ONLY / PARTIAL | `NoOpMusicOutput`; `PetAppearance` | Музыкальное воспроизведение; новые позы/окружение по stage/emotion | P1 |

Выключенная кнопка не всегда является дефектом: busy-защита, недостаток средств, отсутствие предмета или locked-таск намеренно отключены. Например, `onTap:null` у карточки в checkout — статическое резюме товара, а не потерянная покупка; кнопка оплатить находится ниже.

## 6. Заглушки, временные данные и отключённые части

| Место | Статус / что найдено | Недостающее / значение для аудита | Приоритет |
| --- | --- | --- | --- |
| [app_shell.dart:151](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:151), `DestinationPlaceholder` | UI ONLY: «Временный экран разработки.» для Bank/petProfile/stages | Реальные экраны и маршрутизация; пункт меню сам по себе не равен реализации | P0 |
| [home_view_state.dart:43](/Users/admin/Documents/GitHub/strannik/lib/presentation/home/home_view_state.dart:43), `DevelopmentHomePreview.stageProgress` | UI ONLY: константа `0/3`, используется даже с настоящим pet | Привязка Home-бейджа к реальному прогрессу | P1 |
| [home_runtime.dart:33](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/home_runtime.dart:33), `STRANNIK_DEVELOPMENT_PREVIEW` | PARTIAL: отладочный preview, выключен по умолчанию и ограничен debug | Не считать preview рабочим onboarding/данными пользователя | P2 |
| [development.json:29](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:29), store `assetId/description` | PARTIAL: все 7 items имеют assetId=placeholder, описания «Тестовый …» | `StoreAssets.product` спасает известные item ID; titanium/iron без предметного арта | P1 |
| [store_assets.dart:10](/Users/admin/Documents/GitHub/strannik/lib/presentation/store/store_assets.dart:10), `products` | PARTIAL: изображения только scarf/treat/ball/fuel/medicine | Недостающий art каталога; новых assets аудит не добавлял | P2 |
| [development.json:159](/Users/admin/Documents/GitHub/strannik/lib/content/seed/development.json:159), legacy choice | UI ONLY: «Пример задания», contentReference=placeholder, implemented по умолчанию true | Настоящие уроки и честные availability-метаданные | P0 |
| [learning_screen.dart:278](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/learning_screen.dart:278), `_taskCard.onTap` | UI ONLY: callback отсутствует для всех кроме трёх ID | «Продолжение скоро» — подтверждённый тупик, не ошибка нажатия | P1 |
| [feedback_services.dart:41](/Users/admin/Documents/GitHub/strannik/lib/app/feedback/feedback_services.dart:41), `NoOpMusicOutput` + [bootstrap.dart:70](/Users/admin/Documents/GitHub/strannik/lib/app/bootstrap.dart:70) | UI ONLY: музыка всегда no-op; в production SFX/haptics имеют платформенные output | Настоящая музыка и assets; нельзя переносить наличие NoOp на весь звук — click и haptics подключены | P1 |
| [profile_screen.dart:767](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_screen.dart:767), `progress/topic` | PARTIAL: показывается `order` с нуля и темы всех стадий одним списком | Согласовать представление стадий и номера, без изменения реальных completion | P1 |
| [profile_screen.dart:858](/Users/admin/Documents/GitHub/strannik/lib/presentation/profile/profile_screen.dart:858), `topic` | PARTIAL: одинаковые обсуждения/практические советы для каждой темы | Тематический контент для shopping/safety/других тем | P2 |
| [presentation_assets.dart:25](/Users/admin/Documents/GitHub/strannik/lib/presentation/assets/presentation_assets.dart:25), `_avatars` | PARTIAL: cap использует boy asset; legacy неизвестные ID имеют fallback | Полный art набора; fallback не переписывает доменный ID | P2 |
| [test/support/harness.dart:50](/Users/admin/Documents/GitHub/strannik/test/support/harness.dart:50), `Harness.create` | UNVERIFIED как доказательство shipped-контента: fixture меняет shopping на choice, 20 фир/0 XP, возвращает theme1 и удаляет space theme | Это тестовая подмена, не runtime mock. Для реального каталога нужны stage/shopping/safety tests, которые передают contentSource явно | P1 |
| [financial_safety_screen.dart:725](/Users/admin/Documents/GitHub/strannik/lib/presentation/learning/financial_safety_screen.dart:725), `SafetyMockCard` | COMPLETE в учебном смысле: фиксированные 0000, нет EditableText и настоящего платежа | Намеренная симуляция. Не требуются реальные данные карты/телефония/сеть | P2 |
| [android/app/build.gradle.kts:18](/Users/admin/Documents/GitHub/strannik/android/app/build.gradle.kts:18) | PARTIAL: шаблонный TODO application ID; фактически ID уже ru.strannik.strannik | Убрать устаревший комментарий позже; на debug-функции не влияет | P2 |
| [android/app/build.gradle.kts:34](/Users/admin/Documents/GitHub/strannik/android/app/build.gradle.kts:34) | PARTIAL: TODO release signing; release пока подписывается debug key | Не относится к debug-аудиту. Release не собирался и не готовился | P2 |

Поиск TODO/FIXME в `lib/`, `test/`, `integration_test/`, Android не обнаружил дополнительных TODO/FIXME приложения кроме двух Gradle-комментариев. Проверены пустые callback: в `lib/` это преимущественно NoOp outputs, необязательные catch обработки платформы и `verifyPin` с пустым действием после реальной проверки — не самостоятельные потерянные функции. В `lib/` не найдено runtime Figma URL / Image.network / NetworkImage. Жёстко заданные цены, XP и учебный бюджет находятся в локальном контенте, а не являются поддельным wallet.

## 7. Данные, SQLite и сохранение

База [LocalDatabase](/Users/admin/Documents/GitHub/strannik/lib/data/local/database.dart:12) schemaVersion=4; открывается как `strannik.db`. `UnitOfWork.run` использует SQLite transaction и откатывает DomainRejection/DatabaseException. Включены foreign keys и secure_delete. При upgrade применяются последовательные migration SQL, не пересоздание пользовательских данных.

| Область | Состояние / доказательство | Пробел / статус / приоритет |
| --- | --- | --- |
| Schema v1 | profile, parent PIN credential/lockout, pet/stage/XP/equipment, wallet, budget, goal, inventory, periods, transactions, attempts/progress/events, summaries, demo/tooltips | COMPLETE для проверенного хранения, [persistence_test.dart](/Users/admin/Documents/GitHub/strannik/test/data/persistence_test.dart); отдельные UI отсутствуют по реестру; P2 |
| v2 | sound/music/haptics flags с defaults | COMPLETE persistence, feedback_settings_test; actual music no-op; P2 |
| v3 | notifications_enabled, playtime по календарным дням | COMPLETE persistence, notification/profile tests; физическая доставка уведомлений UNVERIFIED; P2 |
| v4 | `learning_attempts.lesson_state` JSON | COMPLETE, shopping_list_persistence + financial_safety tests с actual reopen; P2 |
| Старые shopping records | Stable ID `theme1_task` сохранён, stage определяется владельцем в контенте; второй grant не создаётся | COMPLETE по stage_assignment_test; название ID историческое, P2 |
| Награды и покупки | operation_key UNIQUE, отдельный unique initialGrant, сохранение wallet+history+progress/inventory в транзакции | COMPLETE по race/rollback/reopen тестам; это не реализует Bank transfer, P2 |
| Онбординг до финализации | Controller хранит шаг/имена/скин в памяти; PIN может быть сохранён раньше завершения | PARTIAL, A7; после процесса ребёнок повторяет начало, P1 |
| Начатые уроки | Попытки/выбор/feedback/улики восстанавливаются; JSON состояния shopping и safety хранится в SQLite | COMPLETE, L/F/DATA; P2 |
| Корзина / selectedId | Только память StoreController / checkout state | PARTIAL, D4; перезапуск закрывает незавершённый выбор, реальные деньги до pay не меняются, P1 |
| Родительская сессия | Токен только в памяти, expires=10min; logout при background | COMPLETE по tests; намеренно не сохраняется как открытый доступ после рестарта, P2 |
| Reset / delete | reset очищает gameplay и playtime, wallet=0, onboarding=false; сохраняет profile/PIN/preferences. delete дополнительно удаляет profile/PIN и сбрасывает настройки | COMPLETE по profile/persistence tests; нет облачного восстановления/нескольких аккаунтов, P2 |

Нет найденной воспроизводимой порчи сохранённых денег или повторной выдачи награды в финальном тестовом прогоне. Это не гарантия отсутствия всех дефектов: новый каталожный контент может менять доступность, а файловое дерево менялось параллельно аудиту. Финансовые периоды относятся к Earth-курсу, не к номеру Stage; выполнение shopping/safety не продвигает старые периоды.

## 8. Навигация и достижимость

Корень — [StrannikApp](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/strannik_app.dart), локальные destination в [AppShell](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:73). Именованного роутера/deep link к урокам в проекте не найдено.

- **COMPLETE, P2:** после completion onboarding открывается Home, системный Back не возвращает завершённое знакомство; тест onboarding_widget.
- **PARTIAL, P0:** Home → Store/Closet, Learning и ChildProfile реально подключены production `HomeRuntime`; Home → Bank/petProfile/stages открывает лишь placeholder. [AppShell.build](/Users/admin/Documents/GitHub/strannik/lib/presentation/app/app_shell.dart:86).
- **SERVICE ONLY, P0:** настоящая смена Stage требует вызова progression из кода. Покупки материалов/XP сами по себе Stage не повышают; пользователь не может подтвердить большую цель и начать переход.
- **PARTIAL, P1:** после выхода из урока карта перечитывает баланс/XP/completion; карты прошлых этапов выбрать нельзя. Два safety-урока открываются независимо, но только на effective Stage 3.
- **COMPLETE, P2:** Store Back сначала закрывает selection, затем closet, затем Home; покупка при нехватке средств может отправить в Learning. Не считать отсутствие постоянной нижней панели на вложенном экране потерей маршрута.
- **PARTIAL, P1:** demo switch только включает режим; `DemoService.changeDemoStage` не имеет UI. Demo не следует выдавать за реальный проход трёх этапов.
- **PARTIAL, P1:** parent progress показывает реальные записи, но не служит навигацией к проигрывателям уроков; строка темы открывает только её родительскую сводку.

## 9. Assets, UI и responsive

Assets полностью локальные: Manrope 600/700/800, backgrounds, icons с 3.0x вариантами, skin/pet/bubble, onboarding, learning (shopping и safety), profile, store, source SVG. Шрифты/PNG включены в pubspec, runtime-сеть не требуется. Текст, inputs, CTA, выбор ответов/товаров — Flutter widgets; whole-screen Figma screenshots в runtime не найдены. Новые/заменённые assets в рамках аудита: **нет**.

**PARTIAL, P2:** один фон Home 360×800 и общий pet canvas используются на разных стадиях. Store item art ограничен пятью ID; cap avatar совпадает с boy. Это наблюдаемое ограничение покрытия, а не указание заново экспортировать весь дизайн.

Подтверждённые widget-проверки: onboarding 360×800/960, клавиатура 300dp, text scale 1.3; Home 360×800/960 с semantics; shopping 360×800/960 и 360×640 с увеличенным текстом; Store 360×800, 412×915, 320×640 с safe areas; safety 360×800, 412×915 и 320×640; profile несколькими размерами и клавиатурой. Это **не** полная матрица Android-устройств или визуальное pixel-by-pixel соответствие Figma. Audio/haptics/permission на физическом устройстве не проверены.


## 10. Фактические результаты проверок

| Проверка | Результат | Доказательство / ограничение |
| --- | --- | --- |
| `flutter analyze` | **PASS — No issues found**, 4.0s | [analyze log](/tmp/strannik-inventory-analyze.log). Предупреждения pub о более новых версиях не являются ошибками analyze; зависимости не обновлялись. |
| Первый полный `flutter test --timeout 90s --reporter expanded` | **FAIL / затем остановлен после зависания teardown**; на момент ошибки +111, ошибка навигационного widget-теста Stage 3, `pumpAndSettle timed out`, предупреждение SQLite locked | [первый log](/tmp/strannik-inventory-tests.log). После ~7 минут послан SIGINT только своему процессу. Успешный exit оболочки после остановки нельзя считать прохождением тестов. |
| Отдельный доменный/data/UI поднабор | **PASS — 101 тест**, ~8s | [subset log](/tmp/strannik-inventory-subset.log). Не включал stage_assignment и safety widget file с зависавшей картой; не подменяет полный прогон. |
| Повторный полный `flutter test --no-pub --reporter expanded` | **PASS — 112 тестов**, ~20s | [финальный log](/tmp/strannik-inventory-tests-final.log). Во время аудита файл safety widget-теста был изменён параллельной работой; аудит сам его не исправлял. Факт первоначального сбоя сохранён, приложение по нему не объявляется BROKEN. |
| `flutter build apk --debug` | **PASS**, первая сборка 11.9s; финальная обычного приложения **12.7s** | [финальный build log](/tmp/strannik-inventory-build-final.log), [app-debug.apk](/Users/admin/Documents/GitHub/strannik/build/app/outputs/flutter-apk/app-debug.apk). После временных integration-target сборок восстановлен обычный APK. Есть предупреждение JVM native-access, сборку не блокирует. |
| Release APK / release signing | **Не запускались** | Не запрашивались; аудит не является подготовкой релиза. |
| Android `flutter drive`, существующий shopping scenario, emulator-5560 | **Не подтверждён** | [log](/tmp/strannik-inventory-emulator.log): обнаружен параллельный driver другого теста на том же эмуляторе, соединение оборвалось. Не используется как доказательство дефекта приложения или успешного урока. |
| Android изолированно, emulator-5562 (новый временный AVD Inventory) | **PARTIAL** | Временный `/tmp/strannik-inventory-flow.dart` с настоящими AppShell/Home/Store/Learning, отдельной SQLite-базой и production JSON. Подготовка профиля/Stage выполнена через сервисы, не через полный UI onboarding/большой цели. Подтверждённые шаги перечислены ниже. |

### Android: что действительно проверено

Временный integration-сценарий через нативные Flutter UI-контролы последовательно подтвердил:

1. Home отображается с созданным профилем (есть отдельный adb screenshot).
2. Нажатие Bank открывает **«Временный экран разработки.»**, возврат Home работает. Это проверенный тупик продукта, а не работающий Банк.
3. Store открывается, выбирается шарфик, открывается корзина и checkout; без плана остаётся общий баланс.
4. Оплата 15 фир показывает «Ура! Покупка твоя!», snapshot обновляется.
5. Шкаф показывает купленный шарфик; нажатие экипирует его, `equippedAccessoryId == scarf`.
6. Возврат Back из selection/шкафа/магазина работает; карта этапа 1 открывается и не показывает «Список покупок».
7. Тест вызывает существующую progression-логику с настоящими XP/ресурсами; карта этапа 2 открывается. Это **не** подтверждает существование пользовательского UI перехода.

После нажатия «Список покупок» немедленная проверка наличия ShoppingListScreen дала `Expected exactly one matching candidate; Found 0`. Асинхронный beginTask требует дополнительного ожидания; причина на Android не установлена этим прогоном. **Открытие и полный проход урока на Android — UNVERIFIED**, несмотря на успешные 112 host-тестов. Последняя попытка повторить Android-тест с ожиданием была отклонена пользователем в запросе разрешения и не запускалась. В процессе подготовки повторного запуска прежний временный navigation log был очищен; перечисленные результаты и текст assertion зафиксированы в выводе инструментов этого аудита, полный локальный лог того прогона не сохранён. Не считать пустой `/tmp/strannik-inventory-navigation-final.log` успешным логом.

Первые варианты захвата через `IntegrationTestWidgetsFlutterBinding.takeScreenshot` зависали на screenshot API; это также не доказательство поломки Bank/Store. Захват имён экранов после завершения теста дал бы одну и ту же картинку под разными именами, поэтому такие невалидные снимки удалены и в отчёт не включены.

### Визуальные свидетельства и непроверенное

- [Home на отдельном Android-эмуляторе](/tmp/strannik-inventory-current.png) — просмотрен в аудите.
- [Шкаф с купленным и надетым шарфиком, widget capture](/Users/admin/Documents/GitHub/strannik/build/store-qa/widgets/equipped.png) — просмотрен, отображает 85 фир после покупки за 15.
- [Магазин, widget capture](/Users/admin/Documents/GitHub/strannik/build/store-qa/widgets/store.png). Widget captures сделаны существующим тестом; не называть их Android-снимками. RepaintBoundary этого теста не включает overlay bottom sheet, поэтому файлы accounts/success не доказывают визуальный вид модалок, хотя действия и тексты проверены assertions.
- Другие существующие файлы `build/safety-qa/android`, `build/profile-qa` и прежние onboarding screenshots могли быть созданы другой работой. Их наличие **не** засчитывается как выполненная в этом аудите Android-проверка.
- Не проверены в данном Android-прогоне: полный onboarding руками, полный проход/replay shopping и safety, физические звук/вибрация, доставка notification, успешное внешнее письмо поддержки, визуальная сверка всех Figma кадров, все системные text scale/размеры.

## 11. Рекомендуемый порядок реализации

Аудит не выполняет эти изменения; список нужен для следующего согласованного этапа работы.

1. **P0 — завершить курс этапа 1.** Заменить legacy choice/placeholder настоящими lesson definitions и проигрывателями, утвердить stable ID/награды/порядок. Иначе новый пользователь сразу сталкивается с неактивными задачами; накопления и финансовые периоды нельзя пройти через UI. Доказательство: C1 и реестр задач, `LearningScreen._taskCard`.
2. **P0 — подключить большую цель и реальный переход Stage.** Показать существующие требования XP/ресурсов, выбор/подтверждение цели, `advanceStage` и результат. Не заменять это demo-switch. Доказательство: B6, E5, G3/G4, route stages.
3. **P0 — реализовать Bank UI и определить модель распределений/переводов.** Сначала согласовать, остаются ли Нужно/Хочу планом или становятся отдельными счетами. Затем UI баланса/плана/истории и перевод с валидацией, атомарностью, сохранением общей суммы и restart-тестом. Сейчас transfer-операции нет. Доказательство: F1–F7/F14.
4. **P1 — подключить накопления и существующую историю.** Create/deposit/withdraw, ошибки и мгновенное обновление, перезапуск из UI; не дублировать деньги между wallet и savings. Доказательство: F8–F15, SavingsService.
5. **P1 — закрыть недостающий учебный контент.** Этап2 Task2/3, проверить необходимость «Мама, это ты?», справочников и финалов; обеспечить replay прежних этапов. Доказательство: C5/C6/C10/C11, Figma-секции и каталог.
6. **P1 — довести Home/профили до реального состояния.** Убрать 0/3, отобразить баланс/XP, реализовать профиль питомца, стадии и полную тематическую сводку родителя; отдельно подтвердить требование daily/streak/achievements. Доказательство: B4/B5/B9, H2/H3/H8/H12.
7. **P2 — завершить контент и QA.** Финальные описания/арт каталога, музыка, проверка Android notifications, сохранение черновиков по согласованному UX, карта Figma→экран→тест. Стабилизировать Android/test screenshot harness; не чинить продукт по одному race в тесте без воспроизведения.

Критерий следующей проверки: обычный новый профиль должен пройти onboarding → первые реальные уроки → заработок/покупку/распределение → цель/переход → новые уроки, закрыть приложение и продолжить без повторной награды. До этого приложение остаётся частично реализованным, даже при зелёных analyze, 112 тестах и debug-сборке.
