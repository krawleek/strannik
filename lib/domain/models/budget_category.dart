import '../../core/result.dart';
import 'models.dart';

/// Planning categories share one spendable Wallet. None is a separate account.
enum BudgetCategory { need, want, save }

extension BudgetPlan on BudgetAllocation {
  int amountFor(BudgetCategory category) => switch (category) {
    BudgetCategory.need => mandatory,
    BudgetCategory.want => optional,
    // Legacy explicitly assignable column; not a derived unallocated balance.
    BudgetCategory.save => remainder,
  };

  BudgetAllocation withCategory(BudgetCategory category, int amount) =>
      BudgetAllocation(
        mandatory: category == BudgetCategory.need ? amount : mandatory,
        optional: category == BudgetCategory.want ? amount : optional,
        remainder: category == BudgetCategory.save ? amount : remainder,
      );

  BudgetAllocation reallocate(
    BudgetCategory source,
    BudgetCategory destination,
    int amount,
  ) {
    validAmount(amount);
    require(source != destination, Failure.invalidState);
    require(amountFor(source) >= amount, Failure.insufficientFunds);
    return withCategory(
      source,
      amountFor(source) - amount,
    ).withCategory(destination, addAmount(amountFor(destination), amount));
  }
}
