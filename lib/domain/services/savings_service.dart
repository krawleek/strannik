import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class SavingsService {
  SavingsService(this.game);
  final GameContext game;
  Future<void> _unlocked(Repositories r) async {
    await game.period(r);
    require(
      (await r.system.appState()).demoMode ||
          await game.themeCompleted(r, game.content.savingsUnlockThemeId),
      Failure.locked,
    );
  }

  Future<Result<void>> createSavingsGoal(String title, int targetAmount) =>
      game.run((r) async {
        await _unlocked(r);
        validAmount(targetAmount);
        require(title.trim().isNotEmpty, Failure.invalidState);
        require(await r.economy.savings() == null, Failure.savingsGoalExists);
        await r.economy.saveSavings(
          SavingsGoal(
            id: game.ids.next(),
            title: title,
            targetAmount: targetAmount,
            savedAmount: 0,
            createdAt: game.clock.now(),
          ),
        );
      });
  Future<Result<void>> depositToSavings(int amount) => game.run((r) async {
    await _unlocked(r);
    validAmount(amount);
    final goal = await r.economy.savings();
    require(goal != null, Failure.notFound);
    require(
      amount <= goal!.targetAmount - goal.savedAmount,
      Failure.targetExceeded,
    );
    await game.money(
      r,
      amount: amount,
      type: TransactionType.savingsDeposit,
      source: TransactionSource.savings,
      relatedId: goal.id,
      title: goal.title,
    );
    await r.economy.saveSavings(goal.withAmount(goal.savedAmount + amount));
  });
  Future<Result<void>> withdrawFromSavings(int amount) => game.run((r) async {
    // Existing savings remain withdrawable after disabling demo mode.
    await game.period(r);
    validAmount(amount);
    final goal = await r.economy.savings();
    require(goal != null, Failure.notFound);
    require(amount <= goal!.savedAmount, Failure.insufficientSavings);
    await game.money(
      r,
      amount: amount,
      type: TransactionType.savingsWithdrawal,
      source: TransactionSource.savings,
      relatedId: goal.id,
      title: goal.title,
    );
    await r.economy.saveSavings(goal.withAmount(goal.savedAmount - amount));
  });
}
