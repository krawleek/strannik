# Stage 3 implementation report — 2026-10-20

This report describes the current working tree. Existing player saves were not reset; unrelated pre-existing changes remain in place.

## 1. Current Stage 3 inventory

| Content | Stable ID / reference | Status | Required |
| --- | --- | --- | --- |
| Financial safety topic «Финансовая безопасность», ТЕМА 3 | `home_planet_safety`, stage `homePlanet` | COMPLETE | Both published investigations |
| «Секретный звонок», order 0 | `home_planet_safety_call` / `financial_safety_call_v1` | COMPLETE | Yes |
| «Поздравляем, ты выиграл!», order 1 | `home_planet_safety_email` / `financial_safety_email_v1` | COMPLETE | Yes |
| «Мама, это ты?» | Design concept `40000220:35583`; no executable task ID | BLOCKED BY DESIGN (card UI ONLY) | No: final approved map explicitly specifies 2/2 |
| Full reference guide | `40000220:35612`, eight numbered rules | COMPLETE | Reference, no reward |
| Topic finale, reward → detective story → map | `40000215:83212`, `83317`, `83381` | COMPLETE | Requires both published tasks |

Only one published Stage 3 topic exists in the supplied final/prototype sections. Both investigations remain independently available after the existing Stage 3 gate, ordered call then email on the map. Existing IDs, journals and completion records are preserved.

## 2. Existing lessons verified

The existing graph/controllers/screens were retained. Domain and widget tests cover every question's three answer branches, explanatory feedback, early hang-up/debrief, continued call, all three email clues, clue gating, fictional prize and fee, display-only card, safe ending, completion, replay and SQLite reopening. Android UI coverage completes both investigations through their controls, deliberately chooses wrong answers, inspects all clues, and replays both.

No real call, mail, browser, link navigation, payment or editable financial-data field is introduced. Simulated prizes and fees never touch the wallet.

## 3. Missing lessons implemented

None invented. All fully specified published investigations already existed. This extension implements the missing reference guide, topic finale, persisted topic state and normal navigation between these experiences.

## 4. «Мама, это ты?» — BLOCKED BY DESIGN

[Locked card](https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App?node-id=40000220-35583) contains only title, description and shield/lock artwork. File-wide searches covered all six pages: Final design, Прототип, Wireframes, UI-kit, Presentation and Черновые работы/завод Вика тыкает. Matching content exists only in this card; the card/map has no prototype reactions or destinations.

Missing: introduction, actual message/dialogue, decision screens, answer options, validation rules, feedback, conclusion, task-specific completion/reward, and dependency requirements. It is not a rename of either current lesson. It remains visible, labelled unavailable and untappable, with no fabricated completion or reward. It is recorded here and in `FinancialSafetyTopic` as planned content, outside executable tasks. The newer [final topic map](https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App?node-id=40000215-83381) explicitly says two investigations / 2 of 2; the undefined concept does not block that approved finale. If product makes it mandatory later, a full specification is required.

## 5. Reference guide — COMPLETE

All eight Figma titles and explanations are stored verbatim in `financial_safety_topic.dart`. The scrollable lavender screen includes the original cat avatar, approved blue speech-bubble artwork, numbered alternating white/blue tip cards, close action and return button. It opens from the map's «Справка» / «Узнать больше» and the lesson header.

A separate route overlays the lesson; opening/closing it retains the same controller, accepted events, answer and clues. Guide reading has no service mutation and grants nothing. Widget coverage verifies every paragraph, return navigation and unchanged wallet/journal at 360×800 and 320×800 with system insets.

## 6. Topic finale — COMPLETE

Normal exit from the last completed investigation opens the distinct topic reward screen automatically. «Финал темы» on the map also opens/resumes it. Reward → «К Страннику» → original detective scene → «Продолжить приключение» → Stage 3 task map. Back returns to the map without losing the saved finale step.

`LearningService.beginSafetyFinale` derives requirements from the canonical enabled one-time topic tasks, verifies each is implemented, available and persisted complete, and rejects missing specifications. `advanceSafetyFinale` persists scene progress. Migration v6 adds only `learning_topic_progress`; existing task, attempt, transaction, wallet, budget, savings and inventory rows are retained. Previously completed investigations remain eligible for the newly added finale without replaying or receiving their lesson rewards again.

The UI displays real current Stage 3 and XP values. Figma's example «Стадия 1», 285/300 and 1,250 wallet are illustrative and are not written into player state.

## 7. Task map and Home integration — COMPLETE

The map uses the final title «Финансовая безопасность», stable task order, persisted completion, canonical reward indicators, 0/2–2/2 progress, completed/replay states, a gated finale action, reference entry and explicitly unavailable mother concept. Completed tasks remain replayable. The final map's original phone-off and mail-check artwork is reused.

Existing stage-aware AppShell/HomeRuntime and asset mappings remain in use: home planet background, player's selected pet, stage 3 badge, Learning, Bank, Store and Profile. No alternative shell or database is introduced. QA uses isolated databases, never the player's `strannik.db`.

## 8. Rewards and persistence

Current canonical economy defaults were newer than the old audit: each published lesson now pays **40 фир +15 XP**. These values are preserved. The reward UI now reads the actual task configuration instead of displaying the obsolete +250 фир.

The [approved finale note `40000215:83316`](https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App?node-id=40000215-83212) explicitly defines an **additional +500 фир +30 XP** and forbids re-awarding task bonuses. Those new topic values are centralized in `FinancialSafetyTopic`. Topic money, XP, unique operation keys and completion marker share the existing SQLite UnitOfWork transaction. Repeated calls return the existing topic marker. Scene advances/replays grant no rewards.

Tests include concurrent finale entry, a failed topic write rolling back both money and XP, legacy v5 migration, close/reopen recovery, nonempty existing bank plan/savings/inventory preservation, and rejection of unavailable required content. At a fresh isolated Stage 3 fixture the expected final state is 30 +40 +40 +500 = **610 фир**, and 15 +15 +30 = **60 XP**.

## 9. Files created and modified by this extension

Created:
- `lib/content/lessons/financial_safety_topic.dart`
- `lib/presentation/learning/financial_safety_topic_screen.dart`
- `lib/data/local/migrations/schema_v6.dart`
- `test/domain/financial_safety_topic_test.dart`
- `test/presentation/financial_safety_topic_widget_test.dart`
- `integration_test/stage3_complete_journey_test.dart`
- `integration_test/financial_safety_restart_test.dart` (separate Android-process verification of the completed QA save)
- `assets/learning/safety_{finale_cat,celebration_star,detective,story_cat,locked,map_call,map_email,guide_bubble}.png`

Updated:
- `lib/content/seed/development.json` (topic title only in this extension)
- `lib/domain/services/learning_service.dart` (topic finale operations)
- `lib/domain/models/models.dart`, `lib/domain/repositories/repositories.dart` (topic state)
- `lib/data/local/database.dart`, `lib/data/repositories/sqlite_repositories.dart` (additive migration, topic persistence/reset support)
- `lib/presentation/learning/learning_screen.dart` (guide/map/finale navigation)
- `lib/presentation/learning/financial_safety_screen.dart` (guide entry, configured reward amounts, reusable bubble/background parameters)
- `test/domain/financial_safety_test.dart` (current reward assertions and valid funded progression fixture)
- `integration_test/financial_safety_flow_test.dart` (guide/finale/restart and canonical economy)
- `test/support/harness.dart` (restore enabled legacy tasks only in the isolated old economy fixture)
- `test/domain/stage_assignment_test.dart` (current published curriculum, async map refresh)
- `lib/presentation/learning/discount_traps_screen.dart` (regression fixes for price-tag row and unconstrained falling label height)
- `test/presentation/discount_traps_widget_test.dart`, `integration_test/stage_progress_flow_test.dart` (analysis/formatting fixes)
- `android/app/build.gradle.kts` (explicit `Properties` import; debug build otherwise failed after an independent signing configuration update)
- `PRODUCT.md`, `assets/learning/SAFETY_ASSETS.md`, this report.

## 10. Tests, build and screenshots

- `dart format .`: run successfully; final verification recorded below.
- `flutter analyze`: no issues at the latest completed analysis; final verification recorded below.
- `flutter build apk --debug`: final standalone build succeeded after all integration runs (14.1s), using ordinary `lib/main.dart`. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Stage 3 targeted domain/widget tests passed, including both existing lessons, full guide, gated finale and resume/replay. Topic migration/rollback suite: 5 tests passed, including nonempty saved plan, savings and inventory preservation.
- Android Stage 3 UI run: **passed**, `emulator-5562`, both lessons with wrong-answer recovery, full guide, both finale scenes, SQLite reopen, both replays. Final isolated wallet **610**, XP **60**. Log: `/tmp/stage3-android-qa.log`; screenshots: `build/safety-qa/android-topic/`.
- Topic UI screenshots at 360 and 320 logical width: `build/safety-qa/topic/`. Manrope and MaterialIcons are loaded for visual QA. Original illustration assets, scrolling and system insets verified.

Final full suite: **160 tests passed** (`/tmp/stage3-final-all-tests.log`). `flutter analyze`: **No issues found**. `dart format .`: completed successfully. The first full-suite attempts exposed old fixture/async failures, then a concurrent Android build temporarily removed the macOS SQLite native asset. After repairing fixtures and running the suite after Android compilation, all checks passed. No production behavior or tests were removed to suppress failures.

Complete new-player Android journey: **PASSED** in 8m34s (latest repeat; preceding run also passed in 8m48s) on isolated `Stage3Acceptance`, Android 360×800 logical pixels, separate ADB server. Real UI input and basket gestures, no seeded stage/completion/economy or controller-dispatched progression. Covered onboarding including parent PIN, all three Stage 1 lessons with wrong-answer recovery, real goal and Bank allocation, Store purchases and toy XP, both stage transitions, both Stage 2 lessons including 10/10 discount catches, both safety investigations, guide, both finale scenes, return Home and SQLite/UI reconstruction. Log: `/tmp/stage3-full-journey.log`; screenshots: `build/safety-qa/android-full-journey/`. Ordinary UI returns replaced fixed-count Android back presses in the test harness.

A separate new-process verification uses a QA-only copy made after closing SQLite at the final restored-Home checkpoint. The test runner retains the QA app between invocations (`--keep-app-running`); the default Flutter driver uninstalls it and deletes its data after a run. **PASSED** in a new Android process (journey PID 22406 → restart PID 27464): Stage 3 Home and 2/2 map restored, acknowledged finale replayed, wallet **783 фир**, XP **102**, money transaction count unchanged, one topic reward operation. Wallet also equals the sum of the persisted ledger. Log: `/tmp/stage3-process-restart.log`; screenshot: `build/safety-qa/android-topic/process-restart-home.png`. The QA-only copied database is removed after verification. The temporary Stage3Acceptance emulator was stopped after QA. Reproduce by running `flutter drive --driver=test_driver/profile_driver.dart --target=integration_test/stage3_complete_journey_test.dart -d <device> --keep-app-running`, then the same command with target `integration_test/financial_safety_restart_test.dart` on the same device.

Android screenshots verify the reference 360×800 viewport. The older `font130`, `dark` and `narrow` capture markers in the safety-only test were not applied by the host capture runner, so those filenames do not establish Android setting-variant coverage. Narrow 320-wide layout coverage is from the actual widget tests.

## 11. Remaining design blockers

«Мама, это ты?» remains BLOCKED BY DESIGN as detailed above. It is not a required investigation in the newer approved two-task finale. Old prototype topic heading «Покупки и скидки» and sample balances/XP conflict with the final topic screens; the final topic title and real persisted values take precedence. Existing call/email graph content was preserved; this task does not invent dialogue or extra safety advice.

## 12. Is Stage 3 fully playable?

The published **two-investigation financial-safety topic** is playable through ordinary application navigation, with reference guide, topic finale and persistent one-time rewards. The separate undefined mother concept is not playable and is not reported complete. The complete ordinary-UI cross-stage journey also passed. A separate new-process Android verification also passed, preserving wallet, XP and one-time topic rewards.
