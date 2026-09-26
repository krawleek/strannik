import '../../core/result.dart';
import '../models/models.dart';

abstract interface class ProfileRepository {
  Future<ChildProfile?> profile();
  Future<void> saveProfile(ChildProfile value);
}

abstract interface class ParentSettingsRepository {
  Future<ParentSettings> parentSettings();
  Future<void> saveParentSettings(ParentSettings value);
}

abstract interface class PetRepository {
  Future<Pet?> pet();
  Future<void> savePet(Pet value);
}

abstract interface class EconomyRepository {
  Future<Wallet> wallet();
  Future<void> saveWallet(Wallet value);
  Future<BudgetAllocation?> budget();
  Future<void> saveBudget(BudgetAllocation value);
  Future<SavingsGoal?> savings();
  Future<void> saveSavings(SavingsGoal value);
  Future<List<Transaction>> transactions({String? periodId});
  Future<void> recordTransaction(Transaction value);
  Future<bool> hasTransactionKey(String key);
}

abstract interface class InventoryRepository {
  Future<InventoryEntry?> inventoryEntry(String id);
  Future<List<InventoryEntry>> inventory();
  Future<void> saveInventoryEntry(InventoryEntry value);
}

abstract interface class LearningRepository {
  Future<LearningProgress> learningProgress(String taskId);
  Future<void> saveLearningProgress(LearningProgress value);
  Future<LearningAttempt?> attempt(String id);
  Future<LearningAttempt?> openAttempt(String taskId);
  Future<void> saveAttempt(LearningAttempt value);
}

abstract interface class ProgressRepository {
  Future<BigGoal?> bigGoal();
  Future<void> saveBigGoal(BigGoal value);
  Future<GamePeriod?> currentPeriod();
  Future<List<GamePeriod>> periods();
  Future<void> savePeriod(GamePeriod value);
  Future<void> recordEvent(ProgressEvent value);
  Future<List<ProgressEvent>> events(String periodId);
  Future<bool> hasEventKey(String key);
  Future<GamePeriodSummary?> periodSummary(String periodId);
  Future<void> savePeriodSummary(GamePeriodSummary value);
}

abstract interface class AppStateRepository {
  Future<AppState> appState();
  Future<void> saveAppState(AppState value);
  Future<Set<String>> shownTooltips();
  Future<void> markTooltipShown(String id);
  Future<void> resetProgress();
  Future<void> deleteAllData();
}

abstract interface class Repositories {
  ProfileRepository get profiles;
  ParentSettingsRepository get parents;
  PetRepository get pets;
  EconomyRepository get economy;
  InventoryRepository get items;
  LearningRepository get learning;
  ProgressRepository get progress;
  AppStateRepository get system;
}

abstract interface class UnitOfWork {
  Future<Result<T>> run<T>(
    Future<T> Function(Repositories repositories) operation,
  );
}

abstract interface class ContentRepository {
  List<StoreItem> get storeItems;
  List<ResourceDefinition> get resources;
  List<LearningTheme> get themes;
  List<LearningTask> get tasks;
  List<StageRequirements> get stageRequirements;
  String get savingsUnlockThemeId;
  StoreItem? item(String id);
  LearningTask? task(String id);
}

abstract interface class PinHasher {
  Future<PinCredential> hash(String pin);
  Future<bool> verify(String pin, PinCredential credential);
}
