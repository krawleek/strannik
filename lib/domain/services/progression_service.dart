import '../../core/result.dart';
import '../../content/economy_config.dart';
import '../models/models.dart';
import '../models/stage_progress.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class ProgressionService {
  ProgressionService(this.game);
  final GameContext game;
  Future<Result<StageProgress>> progress() => game.run((r) async {
    final pet = await game.pet(r);
    final goal = await r.progress.bigGoal();
    final requirements = game.content.stageRequirements
        .where(
          (q) =>
              q.from == pet.currentStage &&
              (goal == null || q.bigGoal == goal.type),
        )
        .firstOrNull;
    final lessons = game.content.tasks.where(
      (t) =>
          t.enabled &&
          t.stage == pet.currentStage &&
          t.rewardPolicy == RewardPolicy.oneTime,
    );
    var completed = 0;
    for (final lesson in lessons) {
      if ((await r.learning.learningProgress(lesson.id)).completed) completed++;
    }
    return StageProgress(
      pet: pet,
      goal: goal,
      budget: await r.economy.budget(),
      requirements: requirements,
      inventory: await r.items.inventory(),
      completedLessons: completed,
      requiredLessons: lessons.length,
    );
  });

  /// Funding enables the story purchase; it never advances the pet's stage.
  Future<Result<void>> fulfilFinancialGoal() => game.run((r) async {
    final goal = await r.progress.bigGoal();
    require(goal?.isConfirmed == true, Failure.invalidState);
    require(!goal!.isCompleted, Failure.alreadyCompleted);
    final definition = EconomyConfig.goals[goal.type]!;
    final plan = await r.economy.budget();
    require(
      plan != null && plan.remainder >= definition.target,
      Failure.insufficientFunds,
    );
    require(
      plan!.shortfall(await r.economy.wallet()) == 0,
      Failure.insufficientFunds,
    );
    await game.money(
      r,
      amount: definition.target,
      type: TransactionType.purchase,
      source: TransactionSource.financialGoal,
      key: 'financialGoal:${goal.type.name}',
      title: definition.title,
      relatedId: goal.type.name,
    );
    await r.economy.saveBudget(
      BudgetAllocation(
        mandatory: plan.mandatory,
        optional: plan.optional,
        remainder: plan.remainder - definition.target,
      ),
    );
    await r.progress.saveBigGoal(
      BigGoal(
        goal.type,
        confirmedAt: goal.confirmedAt,
        completedAt: game.clock.now(),
      ),
    );
    await game.event(
      r,
      ProgressEventType.financialGoalCompleted,
      bigGoal: goal.type,
      key: 'financialGoal:${goal.type.name}',
    );
  });
  Future<Result<void>> selectBigGoal(BigGoalType type) => game.run((r) async {
    final old = await r.progress.bigGoal();
    require(old?.isConfirmed != true, Failure.immutableSelection);
    await r.progress.saveBigGoal(BigGoal(type));
  });
  Future<Result<void>> confirmBigGoal() => game.run((r) async {
    final goal = await r.progress.bigGoal();
    require(goal != null, Failure.notFound);
    require(!goal!.isConfirmed, Failure.immutableSelection);
    await r.progress.saveBigGoal(
      BigGoal(goal.type, confirmedAt: game.clock.now()),
    );
    await game.event(r, ProgressEventType.bigGoalConfirmed, bigGoal: goal.type);
  });
  Future<StageRequirements> _requirements(Repositories r) async {
    final pet = await game.pet(r);
    final goal = await r.progress.bigGoal();
    require(goal?.isConfirmed == true, Failure.invalidState);
    final matches = game.content.stageRequirements.where(
      (v) => v.from == pet.currentStage && v.bigGoal == goal!.type,
    );
    require(matches.length == 1, Failure.notFound);
    return matches.single;
  }

  Future<bool> _meets(Repositories r, StageRequirements requirements) async {
    if ((await game.pet(r)).xp < requirements.requiredXp) return false;
    for (final resource in requirements.resources) {
      if (((await r.items.inventoryEntry('resource:${resource.resourceId}'))
                  ?.quantity ??
              0) <
          resource.amount) {
        return false;
      }
    }
    return true;
  }

  Future<Result<bool>> checkStageRequirements() =>
      game.run((r) async => _meets(r, await _requirements(r)));
  Future<Result<void>> advanceStage({Stage? fromStage}) => game.run((r) async {
    if (fromStage != null) {
      require(
        (await game.pet(r)).currentStage == fromStage,
        Failure.alreadyCompleted,
      );
      require(
        !await r.progress.hasEventKey('stageTransition:${fromStage.name}'),
        Failure.alreadyCompleted,
      );
    }
    final requirements = await _requirements(r);
    require(await _meets(r, requirements), Failure.requirementsNotMet);
    for (final resource in requirements.resources) {
      final entry = (await r.items.inventoryEntry(
        'resource:${resource.resourceId}',
      ))!;
      await r.items.saveInventoryEntry(
        InventoryEntry(
          id: entry.id,
          category: entry.category,
          quantity: entry.quantity - resource.amount,
        ),
      );
      await game.event(
        r,
        ProgressEventType.materialUsed,
        amount: resource.amount,
        resourceId: resource.resourceId,
      );
    }
    // Work XP is tied to this actual, irreversible use of the required materials.
    if (requirements.workXp > 0) await game.earnXp(r, requirements.workXp);
    await r.pets.savePet(
      (await game.pet(r)).copyWith(currentStage: requirements.to),
    );
    await game.event(
      r,
      ProgressEventType.stageChanged,
      stage: requirements.to,
      bigGoal: requirements.bigGoal,
      key: 'stageTransition:${requirements.from.name}',
    );
  });
}
