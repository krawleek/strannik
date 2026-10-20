import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/economy_config.dart';
import 'package:strannik/content/lessons/discount_traps_lesson.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/learning/discount_traps_controller.dart';
import 'package:strannik/presentation/learning/shopping_list_controller.dart';

import '../support/harness.dart';

String get source =>
    File('lib/content/seed/development.json').readAsStringSync();
Future<void> unlockDiscounts(Harness h) async {
  await h.read(
    (r) async => r.pets.savePet(
      (await r.pets.pet())!.copyWith(currentStage: Stage.space),
    ),
  );
  final a = success(await h.game.learning.beginTask('theme1_task'));
  final shopping = ShoppingListController(h.game, a, rewardClaimed: false);
  while (shopping.step < 11) {
    await shopping.advance();
  }
  await shopping.toggle('juice');
  await shopping.confirm();
  await shopping.finish();
  shopping.dispose();
}

Future<DiscountTrapsController> begin(Harness h, {bool replay = false}) async =>
    DiscountTrapsController(
      h.game,
      success(
        await h.game.learning.beginTask(
          DiscountTrapsLesson.taskId,
          replay: replay,
        ),
      ),
      rewardClaimed: replay,
    );
Future<void> enterGame(DiscountTrapsController c) async {
  while (c.step < DiscountTrapsLesson.gameStep) {
    await c.advance();
  }
}

Future<void> win(DiscountTrapsController c) async {
  while (c.step == DiscountTrapsLesson.gameStep) {
    if (c.progress.feedback) {
      await c.retry();
      continue;
    }
    await c.resolve(c.progress.round, caught: c.progress.offer.shouldCatch);
  }
  await c.advance();
  await c.finish();
  expect(c.completed, true);
}

void main() {
  test('yellow is the approved target; prices never determine correctness', () {
    expect(
      DiscountTrapsLesson.offers.where((o) => o.shouldCatch).map((o) => o.id),
      ['popcorn', 'milk'],
    );
    final p = DiscountProgress();
    expect(p.apply('catch:0'), false);
    while (p.step < DiscountTrapsLesson.gameStep) {
      expect(p.apply('next'), true);
    }
    expect(p.apply('next'), false);
    expect(p.apply('skip:0'), true);
    expect(p.feedback, true);
    expect(p.missedTarget, true);
    expect(p.apply('catch:1'), false);
    expect(p.apply('retry'), true);
    expect(p.apply('catch:1'), true);
    expect(p.feedback, true);
    expect(p.caught, 0);
    expect(p.apply('retry'), true);
    expect(p.apply('skip:2'), true);
    expect(p.feedback, false);
    expect(p.apply('catch:0'), false);
    expect(DiscountProgress.restore({'step': 20, 'caught': 10}).ready, false);
    expect(
      DiscountProgress.restore({
        'version': 1,
        'events': ['catch:0'],
      }).ready,
      false,
    );
  });

  test(
    'registry, sequential unlock, disabled Task 3 and guarded completion',
    () async {
      final h = await Harness.create(contentSource: source);
      addTearDown(h.db.close);
      await h.start();
      final tasks =
          h.content.tasks
              .where((t) => t.themeId == 'space_theme1' && t.enabled)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      expect(tasks.map((t) => t.id), ['theme1_task', 'space_theme1_task2']);
      expect(h.content.task('space_theme1_task3')!.enabled, false);
      rejected(
        await h.game.learning.beginTask('space_theme1_task2'),
        Failure.locked,
      );
      await unlockDiscounts(h);
      rejected(
        await h.game.learning.beginTask('space_theme1_task3'),
        Failure.locked,
      );
      final c = await begin(h);
      addTearDown(c.dispose);
      rejected(
        await h.game.learning.completeLearningTask(
          c.attempt.id,
          successful: true,
        ),
        Failure.requirementsNotMet,
      );
      await enterGame(c);
      rejected(
        await h.game.learning.completeLearningTask(
          c.attempt.id,
          successful: true,
        ),
        Failure.requirementsNotMet,
      );
      expect(success(await h.game.learning.stageProgress(Stage.space)), (
        completed: 1,
        required: 2,
      ));
    },
  );

  test('SQLite restart restores mistakes, round and progress; one-time reward, replay and topic completion', () async {
    final dir = await Directory.systemTemp.createTemp('strannik-discounts-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/game.db';
    var h = await Harness.create(path: path, contentSource: source);
    await h.start();
    await unlockDiscounts(h);
    final balance = await h.balance(), xp = await h.xp();
    final before = await h.read(
      (r) async => (
        inventory: await r.items.inventory(),
        budget: await r.economy.budget(),
        savings: await r.economy.savings(),
        pet: (await r.pets.pet())!,
        period: (await r.progress.currentPeriod())!.id,
      ),
    );
    var c = await begin(h);
    await enterGame(c);
    final id = c.attempt.id;
    await c.resolve(0, caught: true);
    await c.resolve(1, caught: true);
    expect(c.progress.caught, 1);
    expect(c.progress.feedback, true);
    c.dispose();
    await h.db.close();
    h = await Harness.create(path: path, contentSource: source);
    c = await begin(h);
    expect(c.attempt.id, id);
    expect(c.progress.caught, 1);
    expect(c.progress.round, 2);
    expect(c.progress.feedback, true);
    await c.retry();
    await win(c);
    expect(await h.balance(), balance + EconomyConfig.firstCompletionReward);
    expect(await h.xp(), xp + 15);
    final after = await h.read(
      (r) async => (
        inventory: await r.items.inventory(),
        budget: await r.economy.budget(),
        savings: await r.economy.savings(),
        pet: (await r.pets.pet())!,
        period: (await r.progress.currentPeriod())!.id,
      ),
    );
    expect(
      after.inventory.map((v) => (v.id, v.quantity)),
      before.inventory.map((v) => (v.id, v.quantity)),
    );
    expect(after.budget?.mandatory, before.budget?.mandatory);
    expect(after.budget?.optional, before.budget?.optional);
    expect(after.budget?.remainder, before.budget?.remainder);
    expect(after.savings?.savedAmount, before.savings?.savedAmount);
    expect(after.pet.currentStage, Stage.space);
    expect(after.period, before.period);
    expect(
      success(
        await h.game.context.run(
          (r) => h.game.context.themeCompleted(r, 'space_theme1'),
        ),
      ),
      true,
    );
    rejected(
      await h.game.learning.completeLearningTask(id, successful: true),
      Failure.alreadyCompleted,
    );
    c.dispose();
    await h.db.close();
    h = await Harness.create(path: path, contentSource: source);
    expect(success(await h.game.learning.stageProgress(Stage.space)), (
      completed: 2,
      required: 2,
    ));
    c = await begin(h, replay: true);
    await enterGame(c);
    await win(c);
    expect(await h.balance(), balance + EconomyConfig.firstCompletionReward);
    expect(await h.xp(), xp + 15);
    expect(
      (await h.read(
        (r) => r.learning.learningProgress(DiscountTrapsLesson.taskId),
      )).completionCount,
      1,
    );
    expect(await h.db.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    c.dispose();
    await h.db.close();
  });
}
