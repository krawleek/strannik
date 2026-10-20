import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/content/economy_config.dart';
import 'package:strannik/content/lessons/earth_topic_one.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/domain/models/budget_category.dart';
import 'package:strannik/presentation/bank/bank_controller.dart';

import '../support/harness.dart';
import '../support/earth_lessons.dart';

String get catalog =>
    File('lib/content/seed/development.json').readAsStringSync();
void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create(contentSource: catalog);
    await h.start();
  });
  tearDown(() => h.db.close());
  test('approved economy; ordered unlock; validation, correction, one reward and replay', () async {
    expect(await h.balance(), 30);
    expect(EarthTopicOne.items.map((i) => i.title), [
      'Заколка',
      'Молоко',
      'Мячик',
      'Сосиска',
      'Очки',
      'Консерва',
    ]);
    for (final id in EarthTopicOne.ids.skip(1)) {
      rejected(await h.game.learning.beginTask(id), Failure.locked);
    }
    final c = await earthController(h, EarthTopicOne.needsId);
    rejected(
      await h.game.learning.completeLearningTask(
        c.attempt.id,
        successful: true,
      ),
      Failure.requirementsNotMet,
    );
    await c.change(() {
      c.step = 1;
    });
    for (var i = 0; i < 6; i++) {
      await c.classify(false);
    }
    await c.confirmBasket();
    expect(c.step, 2);
    expect(c.error, isNotNull);
    await c.change(() {
      c.step = 3;
    });
    for (final id in EarthTopicOne.necessary) {
      await c.toggle(id);
    }
    await c.confirmBasket();
    await c.check('149');
    expect(c.wrong, true);
    expect(c.answer, '149');
    expect(await h.balance(), 30);
    await c.check('150');
    expect(c.done, true);
    expect(await h.balance(), 70);
    expect(
      await h.read((r) => h.game.context.themeCompleted(r, 'theme1')),
      false,
    );
    final replay = await earthController(
      h,
      EarthTopicOne.needsId,
      replay: true,
    );
    await finishNeeds(replay);
    expect(replay.done, true);
    expect(await h.balance(), 70);
    expect(
      (await h.read((r) => r.economy.transactions()))
          .where((t) => t.relatedEntityId == EarthTopicOne.needsId)
          .length,
      1,
    );
    expect(
      success(await h.game.learning.availableTasks()).map((t) => t.id),
      contains(EarthTopicOne.weeklyId),
    );
    c.dispose();
    replay.dispose();
  });
  for (final branch in WeeklyBranch.values) {
    test(
      'two-week ${branch.name} simulation is isolated, persisted and rewarded once',
      () async {
        final first = await earthController(h, EarthTopicOne.needsId);
        await finishNeeds(first);
        first.dispose();
        var c = await earthController(h, EarthTopicOne.weeklyId);
        await c.check('140');
        expect(c.wrong, true);
        expect(c.simulation.step, WeeklyStep.calculate);
        await c.check('180');
        await c.advanceWeekly();
        await c.change(() => c.simulation.allocate(false));
        await c.advanceWeekly();
        expect(c.simulation.step, WeeklyStep.allocate);
        expect(c.error, isNotNull);
        await c.change(() {
          c.simulation.food = 0;
          c.simulation.savings = 0;
        });
        for (var i = 0; i < 6; i++) {
          await c.change(() => c.simulation.allocate(true));
        }
        for (var i = 0; i < 2; i++) {
          await c.change(() => c.simulation.allocate(false));
        }
        await c.advanceWeekly();
        await c.change(() => c.simulation.choose(branch));
        c.dispose();
        c = await earthController(h, EarthTopicOne.weeklyId);
        expect(c.simulation.branch, branch);
        expect(c.simulation.step, WeeklyStep.nextIncome);
        await c.advanceWeekly();
        expect(c.simulation.food, branch == WeeklyBranch.expensive ? 240 : 180);
        expect(
          c.simulation.savings,
          branch == WeeklyBranch.wait
              ? 120
              : branch == WeeklyBranch.mouse
              ? 60
              : 0,
        );
        expect(await h.balance(), 70);
        expect(await h.read((r) => r.economy.budget()), isNull);
        expect(await h.read((r) => r.items.inventory()), isEmpty);
        await c.advanceWeekly();
        await c.advanceWeekly();
        expect(c.done, true);
        expect(c.simulation.ready, true);
        expect(await h.balance(), 110);
        final replay = await earthController(
          h,
          EarthTopicOne.weeklyId,
          replay: true,
        );
        await finishWeekly(replay, branch);
        expect(await h.balance(), 110);
        c.dispose();
        replay.dispose();
      },
    );
  }
  for (final type in BigGoalType.values) {
    test(
      '${type.name}: single goal, real plan, reward, fulfilment and stage independence',
      () async {
        var c = await earthController(h, EarthTopicOne.needsId);
        await finishNeeds(c);
        c.dispose();
        c = await earthController(h, EarthTopicOne.weeklyId);
        await finishWeekly(c, WeeklyBranch.wait);
        c.dispose();
        c = await earthController(h, EarthTopicOne.goalId);
        await c.chooseGoal(type);
        await c.confirmGoal();
        await c.initialPlan(80, 30);
        await c.allocateGoal(20);
        expect(c.done, true);
        expect(await h.balance(), 150);
        expect((await h.read((r) => r.economy.budget()))!.remainder, 20);
        expect(
          await h.read((r) => h.game.context.themeCompleted(r, 'theme1')),
          true,
        );
        rejected(
          await h.game.progression.selectBigGoal(
            BigGoalType.values.firstWhere((g) => g != type),
          ),
          Failure.immutableSelection,
        );
        final bank = BankController(h.game);
        await bank.load();
        expect(bank.snapshot!.goal!.type, type);
        final target = EconomyConfig.goals[type]!.target;
        success(await h.game.economy.giveParentReward('1234', target));
        success(
          await h.game.economy.allocateBudget(
            mandatory: 50,
            optional: 0,
            remainder: target - 10,
          ),
        );
        success(
          await h.game.economy.reallocateBudget(
            source: BudgetCategory.need,
            destination: BudgetCategory.save,
            amount: 10,
          ),
        );
        final balance = await h.balance();
        final outcomes = await Future.wait([
          h.game.progression.fulfilFinancialGoal(),
          h.game.progression.fulfilFinancialGoal(),
        ]);
        expect(outcomes.whereType<Success<void>>().length, 1);
        expect(await h.balance(), balance - target);
        expect((await h.read((r) => r.progress.bigGoal()))!.isCompleted, true);
        expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.earth);
        expect((await h.read((r) => r.economy.budget()))!.remainder, 0);
        expect(
          (await h.read((r) => r.economy.transactions()))
              .where((t) => t.source == TransactionSource.financialGoal)
              .length,
          1,
        );
        bank.dispose();
        c.dispose();
      },
    );
  }
  test('v4 adaptOnEarth migration preserves savings, budget, wallet and all progress across reopen', () async {
    final dir = await Directory.systemTemp.createTemp('earth-migration-');
    final path = '${dir.path}/old.db';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, v) => LocalDatabase.migrate(db, 0, v),
      ),
    );
    await old.insert('big_goal', {
      'id': 1,
      'type': 'adaptOnEarth',
      'confirmed_at': 1234,
    });
    await old.update('wallet', {'amount': 73});
    await old.insert('budget_allocation', {
      'id': 1,
      'mandatory': 13,
      'optional': 10,
      'remainder': 50,
    });
    await old.insert('savings_goals', {
      'id': 'old',
      'title': 'Мечта',
      'target': 100,
      'saved': 27,
      'created_at': 1234,
    });
    await old.insert('learning_progress', {
      'task_id': 'theme1_task',
      'completion_count': 1,
      'completed_at': 1234,
    });
    await old.close();
    var disk = await Harness.create(path: path, contentSource: catalog);
    expect(
      (await disk.read((r) => r.progress.bigGoal()))!.type,
      BigGoalType.spaceTaxi,
    );
    expect(
      (await disk.read((r) => r.progress.bigGoal()))!
          .confirmedAt!
          .millisecondsSinceEpoch,
      1234,
    );
    expect(await disk.balance(), 73);
    expect((await disk.read((r) => r.economy.budget()))!.remainder, 50);
    expect((await disk.read((r) => r.economy.savings()))!.savedAmount, 27);
    await disk.db.close();
    disk = await Harness.create(path: path, contentSource: catalog);
    expect(
      (await disk.read((r) => r.learning.learningProgress('theme1_task')))
          .completed,
      true,
    );
    await disk.db.close();
    await dir.delete(recursive: true);
  });
}
