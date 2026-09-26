import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'feedback/feedback_services.dart';
import '../data/repositories/sqlite_feedback_settings_store.dart';
import '../core/clock.dart';
import '../data/local/database.dart';
import '../data/security/pbkdf2_pin_hasher.dart';
import '../domain/repositories/repositories.dart';
import '../domain/services/demo_service.dart';
import '../domain/services/economy_service.dart';
import '../domain/services/game_context.dart';
import '../domain/services/learning_service.dart';
import '../domain/services/local_data_service.dart';
import '../domain/services/onboarding_service.dart';
import '../domain/services/parent_access_service.dart';
import '../domain/services/period_service.dart';
import '../domain/services/pet_interaction_service.dart';
import '../domain/services/progression_service.dart';
import '../domain/services/savings_service.dart';
import '../domain/services/store_service.dart';

/// Explicit content injection prevents development seed becoming production data.
class GameServices {
  GameServices({
    required UnitOfWork unitOfWork,
    required ContentRepository content,
    Clock clock = const SystemClock(),
    PinHasher? pinHasher,
  }) {
    context = GameContext(
      unitOfWork: unitOfWork,
      content: content,
      clock: clock,
    );
    parentAccess = ParentAccessService(context, pinHasher ?? Pbkdf2PinHasher());
    onboarding = OnboardingService(context);
    economy = EconomyService(context, parentAccess);
    savings = SavingsService(context);
    store = StoreService(context);
    pet = PetInteractionService(context);
    periods = PeriodService(context);
    learning = LearningService(context, periods);
    progression = ProgressionService(context);
    demo = DemoService(parentAccess);
    localData = LocalDataService(parentAccess);
  }
  late final GameContext context;
  late final ParentAccessService parentAccess;
  late final OnboardingService onboarding;
  late final EconomyService economy;
  late final SavingsService savings;
  late final StoreService store;
  late final PetInteractionService pet;
  late final PeriodService periods;
  late final LearningService learning;
  late final ProgressionService progression;
  late final DemoService demo;
  late final LocalDataService localData;
}

Future<LocalDatabase> openGameDatabase() async =>
    LocalDatabase.open(path.join(await getDatabasesPath(), 'strannik.db'));

/// Uses the same open local database; no player, assets or network initialized.
FeedbackServices createFeedbackServices(LocalDatabase database) =>
    FeedbackServices(store: SqliteFeedbackSettingsStore(database.database));
