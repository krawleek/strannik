import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class ProgressionService {
  ProgressionService(this.game);
  final GameContext game;
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
  Future<Result<void>> advanceStage() => game.run((r) async {
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
    );
  });
}
