import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class PeriodService {
  PeriodService(this.game);
  final GameContext game;
  Future<GamePeriodSummary> _calculate(
    Repositories r,
    GamePeriod period,
  ) async {
    final transactions = await r.economy.transactions(periodId: period.id);
    final events = await r.progress.events(period.id);
    var received = 0, spent = 0, saved = 0, xp = 0;
    for (final tx in transactions) {
      if (tx.direction == FinancialDirection.income) received += tx.amount;
      if (tx.direction == FinancialDirection.expense) spent += tx.amount;
      if (tx.type == TransactionType.savingsDeposit) saved += tx.amount;
      if (tx.type == TransactionType.savingsWithdrawal) saved -= tx.amount;
    }
    final materials = <String, int>{};
    for (final event in events) {
      if (event.type == ProgressEventType.xpEarned) xp += event.amount;
      if (event.type == ProgressEventType.materialGained) {
        materials.update(
          event.resourceId!,
          (v) => v + event.amount,
          ifAbsent: () => event.amount,
        );
      }
    }
    final inventory = await r.items.inventory();
    return GamePeriodSummary(
      periodId: period.id,
      receivedFira: received,
      spentFira: spent,
      savedFira: saved,
      remainingFira: (await r.economy.wallet()).firaAmount,
      xpEarned: xp,
      materialsGained: materials,
      goalResources: {
        for (final entry in inventory.where(
          (e) => e.category == ItemCategory.shipMaterial,
        ))
          entry.id.substring('resource:'.length): entry.quantity,
      },
      stage: (await game.pet(r)).currentStage,
      bigGoal: (await r.progress.bigGoal())?.type,
    );
  }

  Future<Result<GamePeriodSummary>> summary(String periodId) =>
      game.run((r) async {
        final fixed = await r.progress.periodSummary(periodId);
        if (fixed != null) return fixed;
        final current = await game.period(r);
        require(current.id == periodId, Failure.notFound);
        return _calculate(r, current);
      });

  /// Called inside learning's transaction, after the final reward is recorded.
  Future<void> advanceCompletedThemes(Repositories r) async {
    var current = await game.period(r);
    final themes = [...game.content.themes]
      ..sort((a, b) => a.order.compareTo(b.order));
    while (current.kind != PeriodKind.afterFraudTheme &&
        await game.themeCompleted(r, themes[current.kind.index].id)) {
      final now = game.clock.now();
      await r.progress.savePeriodSummary(await _calculate(r, current));
      await r.progress.savePeriod(
        GamePeriod(
          id: current.id,
          kind: current.kind,
          startedAt: current.startedAt,
          endedAt: now,
        ),
      );
      current = GamePeriod(
        id: game.ids.next(),
        kind: PeriodKind.values[current.kind.index + 1],
        startedAt: now,
      );
      await r.progress.savePeriod(current);
    }
  }
}
