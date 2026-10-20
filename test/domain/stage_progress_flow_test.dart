import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/earth_topic_one.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/assets/presentation_assets.dart';

import '../support/harness.dart';
import '../support/earth_lessons.dart';

void main() {
  String catalog() =>
      File('lib/content/seed/development.json').readAsStringSync();
  late Harness h;
  setUp(() async {
    h = await Harness.create(contentSource: catalog());
    await h.start();
  });
  tearDown(() => h.db.close());
  Future<void> topic() async {
    var c = await earthController(h, EarthTopicOne.needsId);
    await finishNeeds(c);
    c.dispose();
    c = await earthController(h, EarthTopicOne.weeklyId);
    await finishWeekly(c, WeeklyBranch.wait);
    c.dispose();
    c = await earthController(h, EarthTopicOne.goalId);
    await c.chooseGoal(BigGoalType.spaceTaxi);
    await c.confirmGoal();
    await c.initialPlan(80, 30);
    await c.allocateGoal(10);
    expect(c.done, true);
    c.dispose();
  }

  Future<void> supplies() async {
    success(await h.game.store.buyItem('titanium', quantity: 2));
    success(await h.game.store.buyItem('fuel'));
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
  }

  test(
    'real conditions and missing actions are derived from canonical rules',
    () async {
      var p = success(await h.game.progression.progress());
      expect(p.eligible, false);
      expect(p.goalMet, false);
      expect(p.requirements!.requiredXp, 10);
      rejected(
        await h.game.progression.advanceStage(fromStage: Stage.earth),
        Failure.invalidState,
      );
      await topic();
      p = success(await h.game.progression.progress());
      expect(p.goalMet, true);
      expect(p.completedLessons, 3);
      expect(p.requiredLessons, 3);
      expect(p.xpMet, false);
      expect(p.materialsMet, false);
      rejected(
        await h.game.progression.advanceStage(fromStage: Stage.earth),
        Failure.requirementsNotMet,
      );
      await supplies();
      p = success(await h.game.progression.progress());
      expect(p.eligible, true);
      expect(p.pet.xp, 10);
      expect(p.owned('titanium'), 2);
    },
  );
  test('atomic transition preserves wallet/plan/savings, lessons, inventory; duplicates do not consume again', () async {
    await topic();
    await supplies();
    // Extra materials + XP make a stale second submission dangerous without a from-stage guard.
    success(await h.game.store.buyItem('titanium', quantity: 2));
    success(await h.game.store.buyItem('fuel'));
    success(await h.game.store.buyItem('treat', quantity: 2));
    success(await h.game.pet.useTreat('treat'));
    success(await h.game.pet.useTreat('treat'));
    await h.read(
      (r) => r.economy.saveSavings(
        SavingsGoal(
          id: 'legacy',
          title: 'Старая цель',
          targetAmount: 100,
          savedAmount: 17,
          createdAt: DateTime.now(),
        ),
      ),
    );
    final wallet = await h.balance();
    final plan = await h.read((r) => r.economy.budget());
    final txs = (await h.read((r) => r.economy.transactions())).length;
    final results = await Future.wait([
      h.game.progression.advanceStage(fromStage: Stage.earth),
      h.game.progression.advanceStage(fromStage: Stage.earth),
    ]);
    expect(results.whereType<Success<void>>().length, 1);
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.space);
    expect(await h.quantity('resource:titanium'), 2);
    expect(await h.quantity('resource:fuel'), 1);
    expect(await h.xp(), 21);
    expect(await h.balance(), wallet);
    expect((await h.read((r) => r.economy.transactions())).length, txs);
    expect(
      (await h.read((r) => r.economy.budget()))!.remainder,
      plan!.remainder,
    );
    expect((await h.read((r) => r.economy.savings()))!.savedAmount, 17);
    expect(
      await h.read((r) => h.game.context.themeCompleted(r, 'theme1')),
      true,
    );
    expect(
      success(await h.game.learning.availableTasks()).map((t) => t.id),
      contains('theme1_task'),
    );
    expect(h.content.task('theme1_task')!.stage, Stage.space);
    expect(
      PresentationAssets.backgroundFor(Stage.space),
      'assets/backgrounds/space.png',
    );
    rejected(
      await h.game.progression.advanceStage(fromStage: Stage.earth),
      Failure.alreadyCompleted,
    );
  });
  test('failed stage write rolls back materials, work XP and event; retry succeeds', () async {
    await topic();
    await supplies();
    await h.db.database.execute(
      "CREATE TRIGGER reject_stage BEFORE UPDATE OF stage ON pet BEGIN SELECT RAISE(ABORT,'qa'); END",
    );
    rejected(
      await h.game.progression.advanceStage(fromStage: Stage.earth),
      Failure.persistenceFailure,
    );
    expect(await h.quantity('resource:titanium'), 2);
    expect(await h.quantity('resource:fuel'), 1);
    expect(await h.xp(), 10);
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.earth);
    await h.db.database.execute('DROP TRIGGER reject_stage');
    success(await h.game.progression.advanceStage(fromStage: Stage.earth));
    expect(await h.xp(), 11);
  });
  test('SQLite restart restores stage and starts Stage 2 lesson without resetting Earth', () async {
    final dir = await Directory.systemTemp.createTemp('stage-progress-');
    final path = '${dir.path}/game.db';
    final original = h;
    h = await Harness.create(path: path, contentSource: catalog());
    await h.start();
    await topic();
    await supplies();
    success(await h.game.progression.advanceStage(fromStage: Stage.earth));
    final balance = await h.balance();
    await h.db.close();
    h = await Harness.create(path: path, contentSource: catalog());
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.space);
    expect(await h.balance(), balance);
    expect(
      await h.read((r) => h.game.context.themeCompleted(r, 'theme1')),
      true,
    );
    success(await h.game.learning.beginTask('theme1_task'));
    expect(
      (await h.read((r) => r.progress.bigGoal()))!.type,
      BigGoalType.spaceTaxi,
    );
    await h.db.close();
    h = original;
    await dir.delete(recursive: true);
  });
}
