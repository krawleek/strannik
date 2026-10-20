# Child profile and parent area

Implemented in the existing Flutter app; primary visual reference is Figma frame
`40000126:19936` (360×800). Profile is opened through the existing child-avatar
navigation destination. The native status and navigation bars are retained.

## Flows

- Child profile: persisted name, avatar display, name editing, five settings rows,
  parent sign-in, progress reset requiring PIN authentication and confirmation.
- Parent PIN sheet: native obscured four-digit input, invalid feedback, persisted
  lockout after three failures for five minutes, and support recovery. A trivia
  answer never authenticates a parent, changes PIN, or removes lockout. Parent
  sessions expire after ten minutes and end when returning to child mode or
  backgrounding the app.
- Parent dashboard: actual topic completion, current game stage, local weekly
  foreground usage (Monday–Sunday), empty chart, feedback mail action, deletion.
- Progress list and task status; topic detail with discussion guidance from Figma.
- Firs reward: integer input, 50/100/200/500 presets, atomic ledger/wallet update,
  per-operation idempotency and busy guard, success state.
- Profile deletion and progress reset remain separate. Both use existing
  transaction-scoped repositories and return to onboarding. Reset preserves
  profile/PIN; deletion clears them, settings and playtime.

## Reused architecture

`GameServices`, `GameContext`, `LocalDatabase`/`SqliteRepositories`,
`ParentAccessService`, PBKDF2 PIN hashing, `EconomyService`/`Wallet`/`Transaction`,
`ChildProfile`, `LearningTheme`/`LearningTask`/`LearningProgress`,
`FeedbackServices`, `PresentationAssets`, Manrope typography, existing design
colors, `StrannikButton`, `StrannikPinInput`, existing onboarding and app shell.
No backend or alternate state/persistence framework was introduced.

## Local persistence

SQLite migration v3 adds daily foreground milliseconds in `playtime` and a
notifications preference column (disabled by default). Existing profile, salted
PIN credential, failure counter/lock expiry, feedback preferences, demo state,
learning and economy tables remain authoritative. Session capabilities and raw
PIN input are transient and never saved or logged. Playtime checkpoints every
15 seconds, splits at local midnight, and excludes background and parent usage.
A force kill may lose the time since the last checkpoint.

## Files

Created:
- `lib/data/local/migrations/schema_v3.dart`
- `lib/domain/services/profile_service.dart`
- `lib/app/profile_playtime.dart`, `lib/app/support_mail.dart`
- `lib/presentation/profile/profile_controller.dart`, `profile_screen.dart`
- `assets/profile/*.png` (original Figma artwork)
- `test/domain/profile_test.dart`, `test/presentation/profile_widget_test.dart`

Modified:
- `lib/app/bootstrap.dart`, `lib/main.dart`
- `lib/data/local/database.dart`, `lib/data/repositories/sqlite_repositories.dart`
- `lib/domain/models/models.dart`
- `lib/domain/services/parent_access_service.dart`, `economy_service.dart`
- `lib/presentation/app/{app_shell,home_runtime,strannik_app}.dart`
- `lib/presentation/components/strannik_button.dart` (configurable minimum height)
- `android/app/src/main/kotlin/ru/strannik/strannik/MainActivity.kt`
- `pubspec.yaml`
- `test/data/{feedback_settings_test,persistence_test}.dart`
- `test/domain/parent_demo_test.dart`

Changes to onboarding artwork/screens visible in the working tree were made
concurrently outside this implementation and are not claimed here.

## Validation

- `flutter analyze --no-pub`: no issues at last completed check.
- `flutter test --no-pub --reporter compact`: 70 tests passed.
- `flutter build apk --debug --no-pub`: succeeded before final visual refinements.
- Flutter widget captures: `build/profile-qa/profile-360.png` (360×800) and
  `profile-412.png` (412×915), with 40/24 system insets and local fonts.
- Android installation succeeded, but the emulator disconnected repeatedly;
  device navigation, email chooser, keyboard and native screenshot QA remain
  unverified. Widget captures are not device screenshots.

## Explicit limitations / differences

- Notifications are not scheduled by the existing app. Its row explains that
  notifications are unavailable; it does not pretend that delivery is enabled.
- Existing SFX/music/haptics services default to no-op outputs. Sound/music/
  vibration preferences persist and are wired to those services, but audible
  assets, notification scheduling and real output integration are absent.
- Avatar picker currently offers only the approved girl illustration; additional
  complete avatar exports are needed to implement the full carousel.
- The supplied Figma section contains no playtime-limit controls. No guessed
  limit-management UI was added.
- Parent reward/success and topic-detail layouts are functional translations,
  but have not received the same visual refinement as the requested child
  profile; decorative reward stars/scene and deletion farewell are incomplete.
- The current catalog is the repository's development content. Topic counts
  and statuses use it dynamically; authored production lesson content and
  topic-specific parent discussion material are not supplied by that model.
- Reset onboarding retains the existing project's reset semantics, including
  clearing wallet/pet/game periods, rather than deleting profile/PIN.
- Support recovery requires a human reply; no insecure automatic PIN reset.

Final child-profile review found no material visual mismatch in the supplied
360/412 widget captures. Avatar now uses the existing focusable tap target,
and unavailable notifications expose explanatory button semantics. Android
platform sign-off remains pending because the emulator repeatedly disconnected.
