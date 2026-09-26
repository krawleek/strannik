import '../../core/result.dart';

enum Stage { earth, space, homePlanet }

enum EmotionalState { neutral, happy, thoughtful }

enum BigGoalType { repairShip, contactHome, adaptOnEarth }

enum ItemCategory { accessory, treat, toy, shipMaterial }

enum SavingsStatus { active, completed }

enum RewardPolicy { oneTime, repeatable }

enum RepeatRule { newCompletedAttempt }

enum TransactionType {
  initialGrant,
  learningReward,
  parentReward,
  purchase,
  savingsDeposit,
  savingsWithdrawal,
}

enum TransactionSource { onboarding, learning, parentReward, store, savings }

enum FinancialDirection { income, expense, internalTransfer }

enum PeriodKind {
  firstMoney,
  afterTheme1,
  afterTheme2,
  afterTheme3,
  afterFraudTheme,
}

enum ProgressEventType {
  xpEarned,
  materialGained,
  materialUsed,
  stageChanged,
  bigGoalConfirmed,
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.avatarId,
    required this.onboardingCompleted,
    required this.createdAt,
  });
  final String id, nickname, avatarId;
  final bool onboardingCompleted;
  final DateTime createdAt;
  ChildProfile copyWith({String? nickname, bool? onboardingCompleted}) =>
      ChildProfile(
        id: id,
        nickname: nickname ?? this.nickname,
        avatarId: avatarId,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        createdAt: createdAt,
      );
}

class PinCredential {
  const PinCredential({
    required this.salt,
    required this.hash,
    required this.iterations,
    this.algorithm = 'pbkdf2-sha256',
  });
  final String salt, hash, algorithm;
  final int iterations;
}

class ParentSettings {
  const ParentSettings({
    this.credential,
    this.failedAttempts = 0,
    this.lockUntil,
  });
  final PinCredential? credential;
  final int failedAttempts;
  final DateTime? lockUntil;
  bool get hasPin => credential != null;
}

class Pet {
  Pet({
    required this.id,
    required this.childGivenName,
    required this.alienName,
    required this.skinId,
    this.currentStage = Stage.earth,
    this.xp = 0,
    this.emotionalState = EmotionalState.neutral,
    this.equippedAccessoryId,
    this.activeToyId,
  }) {
    validAmount(xp, allowZero: true);
  }
  final String id, childGivenName, alienName, skinId;
  final Stage currentStage;
  final int xp;
  final EmotionalState emotionalState;
  final String? equippedAccessoryId, activeToyId;
  Pet withXp(int value) => copyWith(xp: value);
  Pet copyWith({
    String? childGivenName,
    String? skinId,
    Stage? currentStage,
    int? xp,
    EmotionalState? emotionalState,
    String? equippedAccessoryId,
    String? activeToyId,
    bool clearAccessory = false,
    bool clearToy = false,
  }) => Pet(
    id: id,
    childGivenName: childGivenName ?? this.childGivenName,
    alienName: alienName,
    skinId: skinId ?? this.skinId,
    currentStage: currentStage ?? this.currentStage,
    xp: xp ?? this.xp,
    emotionalState: emotionalState ?? this.emotionalState,
    equippedAccessoryId: clearAccessory
        ? null
        : equippedAccessoryId ?? this.equippedAccessoryId,
    activeToyId: clearToy ? null : activeToyId ?? this.activeToyId,
  );
}

class Wallet {
  Wallet(this.firaAmount) {
    validAmount(firaAmount, allowZero: true);
  }
  final int firaAmount;
}

class BudgetAllocation {
  BudgetAllocation({
    required this.mandatory,
    required this.optional,
    required this.remainder,
  }) {
    validAmount(mandatory, allowZero: true);
    validAmount(optional, allowZero: true);
    validAmount(remainder, allowZero: true);
    validAmount(total, allowZero: true);
  }
  final int mandatory, optional, remainder;
  int get total => mandatory + optional + remainder;
  int shortfall(Wallet wallet) =>
      total > wallet.firaAmount ? total - wallet.firaAmount : 0;
}

class BigGoal {
  const BigGoal(this.type, {this.confirmedAt});
  final BigGoalType type;
  final DateTime? confirmedAt;
  bool get isConfirmed => confirmedAt != null;
}

class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.createdAt,
  }) {
    validAmount(targetAmount);
    validAmount(savedAmount, allowZero: true);
    require(savedAmount <= targetAmount, Failure.targetExceeded);
  }
  final String id, title;
  final int targetAmount, savedAmount;
  final DateTime createdAt;
  SavingsStatus get status => savedAmount == targetAmount
      ? SavingsStatus.completed
      : SavingsStatus.active;
  SavingsGoal withAmount(int amount) => SavingsGoal(
    id: id,
    title: title,
    targetAmount: targetAmount,
    savedAmount: amount,
    createdAt: createdAt,
  );
}

class Transaction {
  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.source,
    required this.createdAt,
    required this.periodId,
    this.relatedEntityId,
    this.category,
    this.title,
    this.description,
    this.operationKey,
  }) {
    validAmount(amount, allowZero: true);
  }
  final String id, periodId;
  final String? relatedEntityId, category, title, description, operationKey;
  final int amount;
  final TransactionType type;
  final TransactionSource source;
  final DateTime createdAt;
  FinancialDirection get direction => switch (type) {
    TransactionType.initialGrant ||
    TransactionType.learningReward ||
    TransactionType.parentReward => FinancialDirection.income,
    TransactionType.purchase => FinancialDirection.expense,
    _ => FinancialDirection.internalTransfer,
  };
  int get availableDelta => switch (type) {
    TransactionType.purchase || TransactionType.savingsDeposit => -amount,
    _ => amount,
  };
}

class StoreItem {
  StoreItem({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.assetId,
    required this.description,
    this.requiredXp = 0,
    this.requiredStage = Stage.earth,
    this.interactionXp = 0,
    this.resourceId,
    this.available = true,
  }) {
    validAmount(price, allowZero: true);
    validAmount(requiredXp, allowZero: true);
    validAmount(interactionXp, allowZero: true);
    require(
      category != ItemCategory.shipMaterial || resourceId != null,
      Failure.invalidState,
    );
  }
  final String id, title, assetId, description;
  final ItemCategory category;
  final int price, requiredXp, interactionXp;
  final Stage requiredStage;
  final String? resourceId;
  final bool available;
  bool get permanent =>
      category == ItemCategory.accessory || category == ItemCategory.toy;
  String get inventoryId =>
      resourceId == null ? 'item:$id' : 'resource:$resourceId';
}

class InventoryEntry {
  InventoryEntry({
    required this.id,
    required this.category,
    required this.quantity,
  }) {
    validAmount(quantity, allowZero: true);
    require(!permanent || quantity <= 1, Failure.invalidAmount);
  }
  final String id;
  final ItemCategory category;
  final int quantity;
  bool get permanent =>
      category == ItemCategory.accessory || category == ItemCategory.toy;
}

class ResourceDefinition {
  const ResourceDefinition(this.id, this.title);
  final String id, title;
}

class ResourceRequirement {
  ResourceRequirement(this.resourceId, this.amount) {
    validAmount(amount);
  }
  final String resourceId;
  final int amount;
}

class StageRequirements {
  StageRequirements({
    required this.from,
    required this.to,
    required this.bigGoal,
    required this.requiredXp,
    required List<ResourceRequirement> resources,
    this.workXp = 0,
  }) : resources = List.unmodifiable(resources) {
    validAmount(requiredXp, allowZero: true);
    validAmount(workXp, allowZero: true);
    require(to.index == from.index + 1, Failure.invalidState);
  }
  final Stage from, to;
  final BigGoalType bigGoal;
  final int requiredXp, workXp;
  final List<ResourceRequirement> resources;
}

class LearningTheme {
  const LearningTheme({
    required this.id,
    required this.title,
    required this.order,
  });
  final String id, title;
  final int order;
}

class LearningTask {
  LearningTask({
    required this.id,
    required this.themeId,
    required this.title,
    required this.type,
    required this.rewardFira,
    required this.order,
    required this.contentReference,
    this.rewardPolicy = RewardPolicy.oneTime,
    this.repeatRule = RepeatRule.newCompletedAttempt,
  }) {
    validAmount(rewardFira, allowZero: true);
  }
  final String id, themeId, title, type, contentReference;
  final int rewardFira, order;
  final RewardPolicy rewardPolicy;
  final RepeatRule repeatRule;
}

class LearningProgress {
  const LearningProgress({
    required this.taskId,
    this.completionCount = 0,
    this.completedAt,
  });
  final String taskId;
  final int completionCount;
  final DateTime? completedAt;
  bool get completed => completionCount > 0;
}

class LearningAttempt {
  const LearningAttempt({
    required this.id,
    required this.taskId,
    required this.startedAt,
    this.completedAt,
  });
  final String id, taskId;
  final DateTime startedAt;
  final DateTime? completedAt;
}

class GamePeriod {
  const GamePeriod({
    required this.id,
    required this.kind,
    required this.startedAt,
    this.endedAt,
  });
  final String id;
  final PeriodKind kind;
  final DateTime startedAt;
  final DateTime? endedAt;
  bool get completed => endedAt != null;
}

class ProgressEvent {
  const ProgressEvent({
    required this.id,
    required this.periodId,
    required this.type,
    required this.createdAt,
    this.amount = 0,
    this.resourceId,
    this.stage,
    this.bigGoal,
    this.operationKey,
  });
  final String id, periodId;
  final ProgressEventType type;
  final DateTime createdAt;
  final int amount;
  final String? resourceId, operationKey;
  final Stage? stage;
  final BigGoalType? bigGoal;
}

class GamePeriodSummary {
  GamePeriodSummary({
    required this.periodId,
    required this.receivedFira,
    required this.spentFira,
    required this.savedFira,
    required this.remainingFira,
    required this.xpEarned,
    required Map<String, int> materialsGained,
    required Map<String, int> goalResources,
    required this.stage,
    this.bigGoal,
  }) : materialsGained = Map.unmodifiable(materialsGained),
       goalResources = Map.unmodifiable(goalResources);
  final String periodId;
  final int receivedFira, spentFira, savedFira, remainingFira, xpEarned;
  final Map<String, int> materialsGained, goalResources;
  final Stage stage;
  final BigGoalType? bigGoal;
}

class AppState {
  const AppState({this.demoMode = false, this.demoStage});
  final bool demoMode;
  final Stage? demoStage;
  Stage effectiveStage(Pet pet) =>
      demoMode ? demoStage ?? pet.currentStage : pet.currentStage;
}
