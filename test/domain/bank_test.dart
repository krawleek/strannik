import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/budget_category.dart';
import 'package:strannik/presentation/bank/bank_controller.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create();
    await h.start();
    success(await h.game.economy.giveParentReward('1234', 100));
  });
  tearDown(() => h.db.close());

  Future<void> plan() async => success(
    await h.game.economy.allocateBudget(
      mandatory: 50,
      optional: 50,
      remainder: 50,
    ),
  );

  test(
    'assignable remainder is planned savings; unallocated is separate',
    () async {
      await plan();
      final c = BankController(h.game);
      await c.load();
      expect(c.available, 200);
      expect(c.snapshot!.plan.remainder, 50);
      expect(c.snapshot!.unallocated, 50);
      expect(c.snapshot!.savings, isNull);
      final history = await h.read((r) => r.economy.transactions());
      expect(history.length, 2); // only initial grant and parent gift
      c.dispose();
    },
  );

  test(
    'allocation rejects negatives, overspending and accepts all-zero plan',
    () async {
      rejected(
        await h.game.economy.allocateBudget(
          mandatory: -1,
          optional: 0,
          remainder: 0,
        ),
        Failure.invalidAmount,
      );
      rejected(
        await h.game.economy.allocateBudget(
          mandatory: 100,
          optional: 100,
          remainder: 1,
        ),
        Failure.insufficientFunds,
      );
      expect(await h.read((r) => r.economy.budget()), isNull);
      success(
        await h.game.economy.allocateBudget(
          mandatory: 0,
          optional: 0,
          remainder: 0,
        ),
      );
      expect((await h.read((r) => r.economy.budget()))!.total, 0);
      expect(await h.balance(), 200);
      expect(await h.xp(), 0);
    },
  );

  test(
    'reallocation preserves plan total, wallet, real savings, XP and history',
    () async {
      await h.unlockSavings();
      success(await h.game.savings.createSavingsGoal('Корабль', 300));
      success(await h.game.savings.depositToSavings(20));
      await plan();
      final before = await h.read(
        (r) async => (
          await r.economy.wallet(),
          await r.economy.savings(),
          await r.economy.transactions(),
          await r.pets.pet(),
          await r.progress.events((await r.progress.currentPeriod())!.id),
        ),
      );
      success(
        await h.game.economy.reallocateBudget(
          source: BudgetCategory.want,
          destination: BudgetCategory.need,
          amount: 20,
        ),
      );
      final saved = (await h.read((r) => r.economy.budget()))!;
      expect(
        (saved.mandatory, saved.optional, saved.remainder, saved.total),
        (70, 30, 50, 150),
      );
      expect(await h.balance(), before.$1.firaAmount);
      expect(
        (await h.read((r) => r.economy.savings()))!.savedAmount,
        before.$2!.savedAmount,
      );
      expect(
        (await h.read((r) => r.economy.savings()))!.targetAmount,
        before.$2!.targetAmount,
      );
      expect(await h.xp(), before.$4!.xp);
      expect(
        (await h.read((r) => r.economy.transactions())).map((t) => t.id),
        before.$3.map((t) => t.id),
      );
      expect(
        (await h.read((r) => r.progress.events((before.$3.last.periodId))))
            .map((e) => e.id),
        before.$5.map((e) => e.id),
      );
    },
  );

  test('reallocation validates zero, negative, same category and insufficient source', () async {
    await plan();
    for (final amount in [0, -1, 51]) {
      rejected(
        await h.game.economy.reallocateBudget(
          source: BudgetCategory.want,
          destination: BudgetCategory.need,
          amount: amount,
        ),
        amount <= 0 ? Failure.invalidAmount : Failure.insufficientFunds,
      );
    }
    rejected(
      await h.game.economy.reallocateBudget(
        source: BudgetCategory.need,
        destination: BudgetCategory.need,
        amount: 1,
      ),
      Failure.invalidState,
    );
    final saved = (await h.read((r) => r.economy.budget()))!;
    expect((saved.mandatory, saved.optional, saved.remainder), (50, 50, 50));
  });

  test('atomic reallocation re-reads source; concurrent changes cannot overdraw it', () async {
    success(
      await h.game.economy.allocateBudget(
        mandatory: 0,
        optional: 10,
        remainder: 0,
      ),
    );
    final results = await Future.wait(
      List.generate(
        2,
        (_) => h.game.economy.reallocateBudget(
          source: BudgetCategory.want,
          destination: BudgetCategory.save,
          amount: 7,
        ),
      ),
    );
    expect(results.whereType<Success<void>>(), hasLength(1));
    final saved = (await h.read((r) => r.economy.budget()))!;
    expect((saved.optional, saved.remainder, saved.total), (3, 7, 10));
    expect(await h.balance(), 200);
  });

  test(
    'controller double-save guards and post-purchase mismatch preserve plan',
    () async {
      await plan();
      final c = BankController(h.game);
      await c.load();
      c.openReallocation(BudgetCategory.need);
      c.selectSource(BudgetCategory.want);
      c.setMoveAmount(20);
      expect(await Future.wait([c.save(), c.save()]), [true, false]);
      expect(await c.save(), false); // success screen cannot reapply the action
      expect(c.snapshot!.plan.optional, 30);
      final txBefore = (await h.read((r) => r.economy.transactions())).length;
      success(
        await h.game.store.buyItem(
          'treat',
          quantity: 11,
          operationId: 'bank-spend',
        ),
      );
      rejected(
        await h.game.store.buyItem(
          'treat',
          quantity: 11,
          operationId: 'bank-spend',
        ),
        Failure.alreadyCompleted,
      );
      c.home();
      await c.load();
      expect(c.available, 145);
      expect(c.snapshot!.shortfall, 5);
      expect(c.snapshot!.plan.total, 150);
      expect(
        (await h.read((r) => r.economy.transactions())).length,
        txBefore + 1,
      );
      c.openReallocation(BudgetCategory.need);
      expect(c.page, BankPage.allocation); // revise obsolete plan first
      expect(c.validDraft, false);
      c.setAllocation(BudgetCategory.save, 45);
      expect(await c.save(), true);
      expect(c.snapshot!.plan.total, 145);
      expect(await h.balance(), 145);
      c.dispose();
    },
  );

  test(
    'SQLite write failure never shows success and keeps saved plan',
    () async {
      await plan();
      final c = BankController(h.game);
      await c.load();
      c.openAllocation();
      c.setAllocation(BudgetCategory.need, 60);
      await h.db.database.execute(
        "CREATE TRIGGER fail_plan BEFORE UPDATE ON budget_allocation BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      expect(await c.save(), false);
      expect(c.page, BankPage.allocation);
      expect(c.error, contains('Не получилось сохранить'));
      expect((await h.read((r) => r.economy.budget()))!.mandatory, 50);
      expect(await h.balance(), 200);
      c.dispose();
    },
  );

  test('wallet changed while editing is checked at save; draft cancel does not write', () async {
    await plan();
    final c = BankController(h.game);
    await c.load();
    c.openAllocation();
    c.setAllocation(BudgetCategory.need, 80);
    success(await h.game.store.buyItem('treat', quantity: 11));
    expect(await c.save(), false);
    expect(c.available, 145);
    expect(c.error, contains('изменился'));
    expect((await h.read((r) => r.economy.budget()))!.total, 150);
    c.home();
    c.openAllocation();
    c.setAllocation(BudgetCategory.need, 0);
    c.home();
    expect((await h.read((r) => r.economy.budget()))!.mandatory, 50);
    c.dispose();
  });

  test(
    'zero wallet stays editable; invalid text and huge totals cannot save',
    () async {
      success(await h.game.store.buyItem('treat', quantity: 40));
      final c = BankController(h.game);
      await c.load();
      c.openAllocation();
      expect(c.available, 0);
      expect(c.validDraft, true);
      c.setAllocation(BudgetCategory.need, -1);
      expect(c.validDraft, false);
      c.setAllocation(BudgetCategory.need, null);
      expect(c.validDraft, false);
      c.setAllocation(BudgetCategory.need, 0);
      expect(await c.save(), true);
      c.home();
      c.openAllocation();
      c.setAllocation(BudgetCategory.need, maxGameValue);
      c.setAllocation(BudgetCategory.want, maxGameValue);
      expect(c.validDraft, false);
      expect(await c.save(), false);
      c.dispose();
    },
  );

  test(
    'explanation can be dismissed even if tooltip persistence fails',
    () async {
      final c = BankController(h.game);
      await c.load();
      expect(c.explanationStep, 0);
      await h.db.database.execute(
        "CREATE TRIGGER fail_hint BEFORE INSERT ON tooltip_flags BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await c.dismissExplanation();
      expect(c.explanationStep, isNull);
      expect(c.error, contains('Счёт всё равно доступен'));
      c.dispose();
    },
  );

  test(
    'plan, dismissal and history survive actual SQLite close and reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('strannik-bank-');
      final path = '${dir.path}/bank.db';
      final persistent = await Harness.create(path: path);
      await persistent.start();
      success(
        await persistent.game.economy.allocateBudget(
          mandatory: 20,
          optional: 30,
          remainder: 40,
        ),
      );
      success(
        await persistent.game.economy.reallocateBudget(
          source: BudgetCategory.want,
          destination: BudgetCategory.need,
          amount: 10,
        ),
      );
      success(
        await persistent.db.run(
          (r) => r.system.markTooltipShown(BankController.tooltipId),
        ),
      );
      await persistent.db.close();
      final reopened = await LocalDatabase.open(
        path,
        factory: databaseFactoryFfi,
      );
      final result = success(
        await reopened.run(
          (r) async => (
            await r.economy.wallet(),
            await r.economy.budget(),
            await r.economy.transactions(),
            await r.system.shownTooltips(),
          ),
        ),
      );
      expect(result.$1.firaAmount, 100);
      expect(
        (result.$2!.mandatory, result.$2!.optional, result.$2!.remainder),
        (30, 20, 40),
      );
      expect(result.$3, hasLength(1));
      expect(result.$4, contains(BankController.tooltipId));
      await reopened.close();
      await dir.delete(recursive: true);
    },
  );
}
