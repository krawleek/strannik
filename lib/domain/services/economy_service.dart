import '../../core/result.dart';
import '../models/models.dart';
import 'game_context.dart';
import 'parent_access_service.dart';

class EconomyService {
  EconomyService(this.game, this.parentAccess);
  final GameContext game;
  final ParentAccessService parentAccess;
  Future<Result<void>> giveParentReward(String pin, int amount) =>
      parentAccess.perform(pin, (r) async {
        validAmount(amount);
        await game.money(
          r,
          amount: amount,
          type: TransactionType.parentReward,
          source: TransactionSource.parentReward,
        );
      });
  Future<Result<void>> allocateBudget({
    required int mandatory,
    required int optional,
    required int remainder,
  }) => game.run((r) async {
    await game.period(r);
    final plan = BudgetAllocation(
      mandatory: mandatory,
      optional: optional,
      remainder: remainder,
    );
    require(
      plan.total <= (await r.economy.wallet()).firaAmount,
      Failure.insufficientFunds,
    );
    await r.economy.saveBudget(plan);
  });
}
