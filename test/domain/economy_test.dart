import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create();
    await h.start();
  });
  tearDown(() => h.db.close());

  test(
    'initial grant is exactly 100, only once including concurrent retry',
    () async {
      expect(await h.balance(), 100);
      final results = await Future.wait([
        h.game.onboarding.complete(),
        h.game.onboarding.complete(),
      ]);
      for (final r in results) {
        rejected(r, Failure.alreadyCompleted);
      }
      expect(await h.balance(), 100);
      expect((await h.read((r) => r.economy.transactions())).length, 1);
    },
  );
  test(
    'parent reward credits exact amount and separate dated transaction',
    () async {
      success(await h.game.economy.giveParentReward('1234', 30));
      expect(await h.balance(), 130);
      final tx = (await h.read((r) => r.economy.transactions())).last;
      expect(tx.amount, 30);
      expect(tx.type, TransactionType.parentReward);
      expect(tx.source, TransactionSource.parentReward);
      expect(tx.createdAt, h.clock.now());
      rejected(
        await h.game.economy.giveParentReward('0000', 30),
        Failure.invalidPin,
      );
      rejected(
        await h.game.economy.giveParentReward('1234', -1),
        Failure.invalidAmount,
      );
      expect(await h.balance(), 130);
    },
  );
  test(
    'learning reward follows successful completion and is one-time',
    () async {
      final attempt = success(await h.game.learning.beginTask('theme1_task'));
      expect(await h.balance(), 100);
      success(
        await h.game.learning.completeLearningTask(
          attempt.id,
          successful: false,
        ),
      );
      expect(await h.balance(), 100);
      expect(await h.xp(), 0);
      success(
        await h.game.learning.completeLearningTask(
          attempt.id,
          successful: true,
        ),
      );
      expect(await h.balance(), 120);
      rejected(
        await h.game.learning.completeLearningTask(
          attempt.id,
          successful: true,
        ),
        Failure.alreadyCompleted,
      );
      rejected(
        await h.game.learning.beginTask('theme1_task'),
        Failure.alreadyCompleted,
      );
      expect(await h.balance(), 120);
    },
  );
  test('repeatable rewards require distinct completed attempts; duplicate callbacks safe', () async {
    final first = success(await h.game.learning.beginTask('practice'));
    final openAgain = success(await h.game.learning.beginTask('practice'));
    expect(openAgain.id, first.id);
    final results = await Future.wait([
      h.game.learning.completeLearningTask(first.id, successful: true),
      h.game.learning.completeLearningTask(first.id, successful: true),
    ]);
    expect(results.whereType<Success<void>>().length, 1);
    expect(await h.balance(), 105);
    final next = success(await h.game.learning.beginTask('practice'));
    expect(next.id, isNot(first.id));
    success(
      await h.game.learning.completeLearningTask(next.id, successful: true),
    );
    expect(await h.balance(), 110);
    expect(
      (await h.read((r) => r.learning.learningProgress('practice')))
          .completionCount,
      2,
    );
  });
  test('purchase debits catalog price, no XP, cannot duplicate permanent ownership', () async {
    success(await h.game.store.buyItem('scarf'));
    expect(await h.balance(), 85);
    expect(await h.xp(), 0);
    expect(await h.quantity('item:scarf'), 1);
    rejected(await h.game.store.buyItem('scarf'), Failure.alreadyOwned);
    expect(await h.balance(), 85);
  });
  test(
    'insufficient funds and invalid quantities leave state unchanged',
    () async {
      rejected(
        await h.game.store.buyItem('treat', quantity: 21),
        Failure.insufficientFunds,
      );
      rejected(
        await h.game.store.buyItem('treat', quantity: -1),
        Failure.invalidAmount,
      );
      rejected(
        await h.game.store.buyItem('treat', quantity: 0),
        Failure.invalidAmount,
      );
      rejected(
        await h.game.store.buyItem('treat', quantity: maxGameValue),
        Failure.invalidAmount,
      );
      expect(await h.balance(), 100);
      expect(await h.quantity('item:treat'), 0);
      expect((await h.read((r) => r.economy.transactions())).length, 1);
    },
  );
  test('concurrent purchases cannot overspend', () async {
    final results = await Future.wait(
      List.generate(3, (_) => h.game.store.buyItem('treat', quantity: 10)),
    );
    expect(results.whereType<Success<void>>().length, 2);
    expect(await h.balance(), 0);
    expect(await h.quantity('item:treat'), 20);
  });
  test(
    'budget is an intention and survives overspending its categories',
    () async {
      success(
        await h.game.economy.allocateBudget(
          mandatory: 80,
          optional: 10,
          remainder: 10,
        ),
      );
      success(await h.game.store.buyItem('scarf'));
      final plan = (await h.read((r) => r.economy.budget()))!;
      expect(plan.total, 100);
      expect(plan.mandatory, 80);
      expect(plan.shortfall(await h.read((r) => r.economy.wallet())), 15);
      rejected(
        await h.game.economy.allocateBudget(
          mandatory: 100,
          optional: 0,
          remainder: 0,
        ),
        Failure.insufficientFunds,
      );
      expect((await h.read((r) => r.economy.transactions())).length, 2);
    },
  );
  test(
    'savings unlock after configured theme, exactly one current goal',
    () async {
      rejected(
        await h.game.savings.createSavingsGoal('Цель', 50),
        Failure.locked,
      );
      await h.unlockSavings();
      success(await h.game.savings.createSavingsGoal('Цель', 50));
      rejected(
        await h.game.savings.createSavingsGoal('Вторая', 20),
        Failure.savingsGoalExists,
      );
    },
  );
  test('deposit and withdrawal conserve money, history and status', () async {
    await h.unlockSavings();
    success(await h.game.savings.createSavingsGoal('Цель', 50));
    success(await h.game.savings.depositToSavings(50));
    expect(await h.balance(), 90);
    final full = (await h.read((r) => r.economy.savings()))!;
    expect(full.savedAmount, 50);
    expect(full.status, SavingsStatus.completed);
    rejected(
      await h.game.savings.createSavingsGoal('Другая', 50),
      Failure.savingsGoalExists,
    );
    rejected(await h.game.savings.depositToSavings(1), Failure.targetExceeded);
    success(await h.game.savings.withdrawFromSavings(20));
    expect(await h.balance(), 110);
    final goal = (await h.read((r) => r.economy.savings()))!;
    expect(goal.savedAmount, 30);
    expect(goal.status, SavingsStatus.active);
    final txs = await h.read((r) => r.economy.transactions());
    expect(txs[txs.length - 2].type, TransactionType.savingsDeposit);
    expect(txs.last.type, TransactionType.savingsWithdrawal);
    expect(txs.last.direction, FinancialDirection.internalTransfer);
  });
  test(
    'cannot deposit unavailable funds or withdraw more than saved',
    () async {
      await h.unlockSavings();
      success(await h.game.savings.createSavingsGoal('Цель', 500));
      rejected(
        await h.game.savings.depositToSavings(141),
        Failure.insufficientFunds,
      );
      success(await h.game.savings.depositToSavings(10));
      rejected(
        await h.game.savings.withdrawFromSavings(11),
        Failure.insufficientSavings,
      );
      rejected(
        await h.game.savings.withdrawFromSavings(-1),
        Failure.invalidAmount,
      );
      expect(await h.balance(), 130);
      expect((await h.read((r) => r.economy.savings()))!.savedAmount, 10);
    },
  );
}
