import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/financial_safety_lesson.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/learning/financial_safety_controller.dart';

import '../support/harness.dart';

String get safetyCatalog =>
    File('lib/content/seed/development.json').readAsStringSync();
Future<void> stage3(Harness h) => h.read(
  (r) async => r.pets.savePet(
    (await r.pets.pet())!.copyWith(currentStage: Stage.homePlanet),
  ),
);
Future<FinancialSafetyController> safetyController(
  Harness h,
  String id, {
  bool replay = false,
}) async => FinancialSafetyController(
  h.game,
  success(await h.game.learning.beginTask(id, replay: replay)),
  rewardClaimed: (await h.read((r) => r.learning.learningProgress(id)))
      .completed,
);
Future<void> finishSafety(
  FinancialSafetyController c, {
  bool hangUp = false,
  bool wrong = false,
}) async {
  while (!c.completed) {
    final p = c.progress;
    if (p.ready) {
      await c.finish();
      continue;
    }
    if (p.node.view == SafetyView.question) {
      if (!p.feedback) {
        await c.send(
          'answer:${p.node.answers.firstWhere((a) => a.correct != wrong).id}',
        );
        await c.send('check_answer');
      } else {
        await c.send('next');
      }
    } else if (p.node.view == SafetyView.clues && p.clues.length != 3) {
      for (final id in ['link', 'sender', 'prize']) {
        await c.send('inspect:$id');
      }
    } else {
      await c.send(
        p.nodeId == 'decision' && hangUp ? 'hang_up' : p.node.actions.first.id,
      );
    }
    expect(c.error, isNull);
  }
}

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create(contentSource: safetyCatalog);
    await h.start();
  });
  tearDown(() => h.db.close());

  test(
    'stable Stage 3 ownership, no legacy replacement, real and demo locks',
    () async {
      for (final id in [
        FinancialSafetyLesson.callId,
        FinancialSafetyLesson.emailId,
      ]) {
        final task = h.content.task(id)!;
        expect(task.stage, Stage.homePlanet);
        expect(task.themeId, FinancialSafetyLesson.topicId);
        rejected(await h.game.learning.beginTask(id), Failure.locked);
      }
      expect(h.content.task('fraud_task')!.stage, Stage.earth);
      expect(h.content.task('theme1_task')!.stage, Stage.space);
      await h.read(
        (r) async => r.pets.savePet(
          (await r.pets.pet())!.copyWith(currentStage: Stage.space),
        ),
      );
      rejected(
        await h.game.learning.beginTask(FinancialSafetyLesson.callId),
        Failure.locked,
      );
      success(await h.game.demo.setEnabled('1234', true));
      success(await h.game.demo.changeDemoStage('1234', Stage.homePlanet));
      final c = await safetyController(h, FinancialSafetyLesson.emailId);
      await finishSafety(c);
      expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.space);
      success(await h.game.demo.setEnabled('1234', false));
      rejected(
        await h.game.learning.beginTask(
          FinancialSafetyLesson.emailId,
          replay: true,
        ),
        Failure.locked,
      );
      c.dispose();
    },
  );

  test('real milestone unlocks Stage 3 and uses the existing resource and XP rules', () async {
    await h.read(
      (r) async => r.pets.savePet(
        (await r.pets.pet())!.copyWith(currentStage: Stage.space),
      ),
    );
    success(await h.game.progression.selectBigGoal(BigGoalType.repairShip));
    success(await h.game.progression.confirmBigGoal());
    rejected(
      await h.game.progression.advanceStage(),
      Failure.requirementsNotMet,
    );
    success(await h.game.store.buyItem('titanium', quantity: 2));
    success(await h.game.store.buyItem('fuel'));
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
    success(await h.game.economy.giveParentReward('1234', 5));
    success(await h.game.store.buyItem('treat', quantity: 2));
    for (var i = 0; i < 2; i++) {
      success(await h.game.pet.useTreat('treat'));
    }
    success(await h.game.progression.advanceStage());
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.homePlanet);
    expect(
      success(await h.game.learning.availableTasks()).map((t) => t.id),
      containsAll([
        FinancialSafetyLesson.callId,
        FinancialSafetyLesson.emailId,
      ]),
    );
  });

  test(
    'independent completion, all rewards once, duplicate callbacks and replay',
    () async {
      await stage3(h);
      final earth = success(await h.game.learning.stageProgress(Stage.earth));
      final space = success(await h.game.learning.stageProgress(Stage.space));
      final period = (await h.read((r) => r.progress.currentPeriod()))!.id;
      final initial = await h.balance();
      final email = await safetyController(h, FinancialSafetyLesson.emailId);
      await finishSafety(email, wrong: true);
      expect(await h.balance(), initial + 40);
      expect(await h.xp(), 15);
      expect(
        (await h.read(
          (r) => r.learning.learningProgress(FinancialSafetyLesson.callId),
        )).completed,
        false,
      );
      expect(
        success(
          await h.game.context.run(
            (r) =>
                h.game.context.themeCompleted(r, FinancialSafetyLesson.topicId),
          ),
        ),
        false,
      );
      final call = await safetyController(h, FinancialSafetyLesson.callId);
      await finishSafety(call, hangUp: true);
      expect(await h.balance(), initial + 80);
      expect(await h.xp(), 30);
      expect(
        success(
          await h.game.context.run(
            (r) =>
                h.game.context.themeCompleted(r, FinancialSafetyLesson.topicId),
          ),
        ),
        true,
      );
      await Future.wait([call.finish(), call.finish(), call.send('finish')]);
      rejected(
        await h.game.learning.completeLearningTask(
          call.attempt.id,
          successful: true,
        ),
        Failure.alreadyCompleted,
      );
      for (final id in [
        FinancialSafetyLesson.callId,
        FinancialSafetyLesson.emailId,
      ]) {
        final replay = await safetyController(h, id, replay: true);
        expect(replay.rewardClaimed, true);
        await finishSafety(replay);
        replay.dispose();
      }
      expect(await h.balance(), initial + 80);
      expect(await h.xp(), 30);
      expect(success(await h.game.learning.stageProgress(Stage.earth)), earth);
      expect(success(await h.game.learning.stageProgress(Stage.space)), space);
      expect((await h.read((r) => r.progress.currentPeriod()))!.id, period);
      expect(await h.quantity('ball'), 0);
      email.dispose();
      call.dispose();
    },
  );

  test(
    'cannot skip questions, clues or conclusion to claim an award',
    () async {
      await stage3(h);
      final c = await safetyController(h, FinancialSafetyLesson.emailId);
      await c.send('finish');
      expect(c.progress.nodeId, 'email');
      await h.game.learning.saveLessonState(c.attempt.id, {
        'node': 'complete',
        'events': ['finish'],
      });
      rejected(
        await h.game.learning.completeLearningTask(
          c.attempt.id,
          successful: true,
        ),
        Failure.requirementsNotMet,
      );
      expect(await h.balance(), 30);
      await c.send('next');
      await c.send('next');
      expect(c.progress.nodeId, 'email_trust');
      await c.send('answer:check');
      await c.send('check_answer');
      await c.send('next');
      await c.send('inspect:sender');
      await c.send('next');
      expect(c.progress.nodeId, 'clues');
      await c.send('inspect:prize');
      await c.send('inspect:link');
      await c.send('next');
      expect(c.progress.nodeId, 'email_summary');
      expect(await h.balance(), 30);
      await finishSafety(c);
      expect(await h.balance(), 70);
      c.dispose();
    },
  );

  test(
    'every question and answer branch gives its own recoverable feedback',
    () {
      for (final lesson in [
        FinancialSafetyLesson.call,
        FinancialSafetyLesson.email,
      ]) {
        final ids = <String>{};
        for (final node in lesson.nodes) {
          expect(ids.add(node.id), true);
          if (node.view != SafetyView.question) continue;
          expect(node.answers.where((a) => a.correct), hasLength(1));
          expect(node.answers.map((a) => a.id).toSet(), hasLength(3));
          for (final answer in node.answers) {
            final p = SafetyProgress(lesson)..nodeId = node.id;
            expect(p.apply('answer:${answer.id}'), true);
            expect(p.feedback, false);
            expect(p.apply('next'), false);
            expect(p.apply('check_answer'), true);
            expect(p.selected!.feedback, isNotEmpty);
            expect(p.apply('next'), true);
            expect(p.nodeId, node.actions.first.next);
          }
        }
      }
    },
  );

  test('SQLite restart restores clue, selected answer and feedback; finished rewards survive restart', () async {
    final dir = await Directory.systemTemp.createTemp('safety-resume-');
    final filename = '${dir.path}/game.db';
    var disk = await Harness.create(
      path: filename,
      contentSource: safetyCatalog,
    );
    try {
      await disk.start();
      await stage3(disk);
      var c = await safetyController(disk, FinancialSafetyLesson.emailId);
      await c.send('next');
      await c.send('answer:trust');
      await c.send('check_answer');
      final attemptId = c.attempt.id;
      c.dispose();
      await disk.db.close();
      disk = await Harness.create(path: filename, contentSource: safetyCatalog);
      c = await safetyController(disk, FinancialSafetyLesson.emailId);
      expect(c.attempt.id, attemptId);
      expect(c.progress.selectedId, 'trust');
      expect(c.progress.feedback, true);
      await c.send('next');
      await c.send('inspect:link');
      c.dispose();
      await disk.db.close();
      disk = await Harness.create(path: filename, contentSource: safetyCatalog);
      c = await safetyController(disk, FinancialSafetyLesson.emailId);
      expect(c.progress.clues, {'link'});
      expect(c.progress.lastClue, 'link');
      await finishSafety(c);
      c.dispose();
      await disk.db.close();
      disk = await Harness.create(path: filename, contentSource: safetyCatalog);
      expect(await disk.balance(), 70);
      expect(await disk.xp(), 15);
      c = await safetyController(
        disk,
        FinancialSafetyLesson.emailId,
        replay: true,
      );
      await finishSafety(c);
      expect(await disk.balance(), 70);
      expect(await disk.xp(), 15);
      c.dispose();
    } finally {
      await disk.db.close();
      await dir.delete(recursive: true);
    }
  });
}
