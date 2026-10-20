import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/earth_topic_one.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/assets/presentation_assets.dart';

import '../support/earth_lessons.dart';
import '../support/harness.dart';
import 'discount_traps_test.dart' as discounts;

void main() {
  final catalog = File('lib/content/seed/development.json').readAsStringSync();
  Future<void> earth(Harness h) async {
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
    c.dispose();
    success(await h.game.store.buyItem('titanium', quantity: 2));
    success(await h.game.store.buyItem('fuel'));
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
    success(await h.game.progression.advanceStage(fromStage: Stage.earth));
  }

  Future<Harness> fixture(BigGoalType goal) async {
    final h = await Harness.create(contentSource: catalog);
    await h.start();
    success(await h.game.progression.selectBigGoal(goal));
    success(await h.game.progression.confirmBigGoal());
    await h.read(
      (r) async => r.pets.savePet(
        (await r.pets.pet())!.copyWith(currentStage: Stage.space),
      ),
    );
    return h;
  }

  for (final goal in BigGoalType.values) {
    test(
      'Stage 2 canonical requirements for ${goal.name}; individual missing resources and XP',
      () async {
        final h = await fixture(goal);
        addTearDown(h.db.close);
        var p = success(await h.game.progression.progress());
        expect(p.requirements!.from, Stage.space);
        expect(p.requirements!.to, Stage.homePlanet);
        expect(p.requirements!.requiredXp, 20);
        expect(p.requirements!.workXp, 1);
        expect(p.requirements!.resources.map((r) => (r.resourceId, r.amount)), [
          ('titanium', 2),
          ('fuel', 1),
        ]);
        expect(p.goalMet, true);
        expect(p.eligible, false);
        rejected(
          await h.game.progression.advanceStage(fromStage: Stage.space),
          Failure.requirementsNotMet,
        );
        success(await h.game.economy.giveParentReward('1234', 100));
        success(await h.game.store.buyItem('titanium', quantity: 2));
        p = success(await h.game.progression.progress());
        expect(p.owned('titanium'), 2);
        expect(p.materialsMet, false);
        success(await h.game.store.buyItem('fuel'));
        p = success(await h.game.progression.progress());
        expect(p.materialsMet, true);
        expect(p.xpMet, false);
        await h.read(
          (r) async => r.pets.savePet((await r.pets.pet())!.copyWith(xp: 20)),
        );
        p = success(await h.game.progression.progress());
        expect(p.eligible, true);
        // The catalog does not define a lesson-completion or savings gate.
        expect(p.completedLessons, 0);
        expect(p.requiredLessons, 2);
        expect(
          success(await h.game.progression.checkStageRequirements()),
          true,
        );
      },
    );
  }

  test('real Stage 1 and Stage 2 lessons -> atomic Stage 3 -> reopen and existing safety access', () async {
    final dir = await Directory.systemTemp.createTemp('stage-two-transition-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/game.db';
    var h = await Harness.create(path: path, contentSource: catalog);
    await h.start();
    await earth(h);
    await discounts.unlockDiscounts(h);
    final c = await discounts.begin(h);
    await discounts.enterGame(c);
    await discounts.win(c);
    c.dispose();
    success(await h.game.store.buyItem('titanium', quantity: 2));
    success(await h.game.store.buyItem('fuel'));
    await h.read(
      (r) => r.economy.saveSavings(
        SavingsGoal(
          id: 'legacy',
          title: 'Накопления',
          targetAmount: 100,
          savedAmount: 7,
          createdAt: DateTime(2026),
        ),
      ),
    );
    final balance = await h.balance(), xp = await h.xp();
    final plan = await h.read((r) => r.economy.budget());
    final transactions = (await h.read((r) => r.economy.transactions())).length;
    final completions = await h.db.database.query('learning_progress');
    expect(success(await h.game.learning.stageProgress(Stage.space)), (
      completed: 2,
      required: 2,
    ));
    final p = success(await h.game.progression.progress());
    expect(p.eligible, true);
    // Simulate interruption: the stage write fails inside the same transaction.
    await h.db.database.execute(
      "CREATE TRIGGER reject_stage3 BEFORE UPDATE OF stage ON pet BEGIN SELECT RAISE(ABORT,'qa'); END",
    );
    rejected(
      await h.game.progression.advanceStage(fromStage: Stage.space),
      Failure.persistenceFailure,
    );
    expect(await h.quantity('resource:titanium'), 2);
    expect(await h.quantity('resource:fuel'), 1);
    expect(await h.xp(), xp);
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.space);
    await h.db.database.execute('DROP TRIGGER reject_stage3');
    final results = await Future.wait([
      h.game.progression.advanceStage(fromStage: Stage.space),
      h.game.progression.advanceStage(fromStage: Stage.space),
    ]);
    expect(results.whereType<Success<void>>(), hasLength(1));
    expect(await h.quantity('resource:titanium'), 0);
    expect(await h.quantity('resource:fuel'), 0);
    expect(await h.xp(), xp + 1);
    expect(await h.balance(), balance);
    expect(
      (await h.read((r) => r.economy.transactions())).length,
      transactions,
    );
    expect(await h.db.database.query('learning_progress'), completions);
    await h.db.close();
    h = await Harness.create(path: path, contentSource: catalog);
    addTearDown(h.db.close);
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.homePlanet);
    expect(
      (await h.read((r) => r.progress.bigGoal()))!.type,
      BigGoalType.spaceTaxi,
    );
    expect(
      (await h.read((r) => r.economy.budget()))!.mandatory,
      plan!.mandatory,
    );
    expect((await h.read((r) => r.economy.budget()))!.optional, plan.optional);
    expect(
      (await h.read((r) => r.economy.budget()))!.remainder,
      plan.remainder,
    );
    expect((await h.read((r) => r.economy.savings()))!.savedAmount, 7);
    expect(await h.balance(), balance);
    expect(await h.xp(), xp + 1);
    rejected(
      await h.game.progression.advanceStage(fromStage: Stage.space),
      Failure.alreadyCompleted,
    );
    expect(
      PresentationAssets.backgroundFor(Stage.homePlanet),
      'assets/backgrounds/home_planet.png',
    );
    final available = success(await h.game.learning.availableTasks())
        .map((t) => t.id);
    expect(
      available,
      containsAll(['home_planet_safety_call', 'home_planet_safety_email']),
    );
    success(await h.game.learning.beginTask('home_planet_safety_call'));
    success(await h.game.learning.beginTask('home_planet_safety_email'));
    expect(await h.db.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
