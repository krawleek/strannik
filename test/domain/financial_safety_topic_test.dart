import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/financial_safety_lesson.dart';
import 'package:strannik/content/lessons/financial_safety_topic.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';

import '../support/harness.dart';
import 'financial_safety_test.dart'
    show safetyCatalog, stage3, safetyController, finishSafety;

void main() {
  test(
    'canonical two-task inventory excludes the undefined mother concept',
    () async {
      final h = await Harness.create(contentSource: safetyCatalog);
      addTearDown(h.db.close);
      final tasks = FinancialSafetyTopic.requiredTasks(h.content);
      expect(tasks.map((t) => t.id), [
        FinancialSafetyLesson.callId,
        FinancialSafetyLesson.emailId,
      ]);
      expect(
        h.content.tasks.any(
          (t) => t.title == FinancialSafetyTopic.plannedTitle,
        ),
        false,
      );
      expect(FinancialSafetyTopic.tips, hasLength(8));
    },
  );
  test('finale requires actual persisted tasks, atomic bonus, concurrent taps and restart', () async {
    final dir = await Directory.systemTemp.createTemp('safety-topic-');
    final path = '${dir.path}/save.db';
    var h = await Harness.create(path: path, contentSource: safetyCatalog);
    try {
      await h.start();
      rejected(await h.game.learning.beginSafetyFinale(), Failure.locked);
      await stage3(h);
      rejected(
        await h.game.learning.beginSafetyFinale(),
        Failure.requirementsNotMet,
      );
      await h.read((r) async {
        await r.economy.saveBudget(
          BudgetAllocation(mandatory: 10, optional: 5, remainder: 15),
        );
        await r.economy.saveSavings(
          SavingsGoal(
            id: 'existing',
            title: 'Самокат',
            targetAmount: 100,
            savedAmount: 7,
            createdAt: h.clock.now(),
          ),
        );
        await r.items.saveInventoryEntry(
          InventoryEntry(
            id: 'toy:ball',
            category: ItemCategory.toy,
            quantity: 1,
          ),
        );
      });
      final start = await h.balance();
      final inventory = await h.read((r) => r.items.inventory());
      final goal = await h.read((r) => r.economy.savings());
      final budget = await h.read((r) => r.economy.budget());
      final call = await safetyController(h, FinancialSafetyLesson.callId);
      await finishSafety(call);
      call.dispose();
      rejected(
        await h.game.learning.beginSafetyFinale(),
        Failure.requirementsNotMet,
      );
      final email = await safetyController(h, FinancialSafetyLesson.emailId);
      await finishSafety(email, wrong: true);
      email.dispose();
      final lessonFira = FinancialSafetyTopic.requiredTasks(h.content)
          .fold(0, (n, t) => n + t.rewardFira);
      final lessonXp = FinancialSafetyTopic.requiredTasks(h.content)
          .fold(0, (n, t) => n + t.rewardXp);
      expect(await h.balance(), start + lessonFira);
      final states = await Future.wait([
        h.game.learning.beginSafetyFinale(),
        h.game.learning.beginSafetyFinale(),
      ]);
      for (final state in states) {
        expect(success(state).completed, true);
      }
      expect(
        await h.balance(),
        start + lessonFira + FinancialSafetyTopic.rewardFira,
      );
      expect(await h.xp(), lessonXp + FinancialSafetyTopic.rewardXp);
      expect(
        success(await h.game.learning.advanceSafetyFinale()).finaleStep,
        1,
      );
      await h.db.close();
      h = await Harness.create(path: path, contentSource: safetyCatalog);
      final restored = success(await h.game.learning.beginSafetyFinale());
      expect(restored.finaleStep, 1);
      expect(
        success(await h.game.learning.advanceSafetyFinale()).finaleStep,
        2,
      );
      expect(
        success(await h.game.learning.advanceSafetyFinale()).finaleStep,
        2,
      );
      expect(
        await h.balance(),
        start + lessonFira + FinancialSafetyTopic.rewardFira,
      );
      expect(await h.xp(), lessonXp + FinancialSafetyTopic.rewardXp);
      expect(
        (await h.read((r) => r.items.inventory())).length,
        inventory.length,
      );
      final afterGoal = (await h.read((r) => r.economy.savings()))!;
      expect(
        (
          afterGoal.id,
          afterGoal.title,
          afterGoal.savedAmount,
          afterGoal.targetAmount,
        ),
        (goal!.id, goal.title, goal.savedAmount, goal.targetAmount),
      );
      final afterBudget = (await h.read((r) => r.economy.budget()))!;
      expect(
        (afterBudget.mandatory, afterBudget.optional, afterBudget.remainder),
        (budget!.mandatory, budget.optional, budget.remainder),
      );
      expect(
        (await h.read((r) => r.economy.transactions()))
            .where((t) => t.operationKey == 'learningTopic:home_planet_safety'),
        hasLength(1),
      );
    } finally {
      await h.db.close();
      await dir.delete(recursive: true);
    }
  });
  test('topic bonus rolls back money, XP and marker together on persistence failure', () async {
    final h = await Harness.create(contentSource: safetyCatalog);
    addTearDown(h.db.close);
    await h.start();
    await stage3(h);
    for (final id in [
      FinancialSafetyLesson.callId,
      FinancialSafetyLesson.emailId,
    ]) {
      final c = await safetyController(h, id);
      await finishSafety(c);
      c.dispose();
    }
    final before = await h.balance();
    final xp = await h.xp();
    await h.db.database.execute(
      "CREATE TRIGGER reject_topic BEFORE INSERT ON learning_topic_progress BEGIN SELECT RAISE(ABORT,'qa'); END",
    );
    rejected(
      await h.game.learning.beginSafetyFinale(),
      Failure.persistenceFailure,
    );
    expect(await h.balance(), before);
    expect(await h.xp(), xp);
    expect(
      (await h.read((r) => r.learning.topicProgress(FinancialSafetyTopic.id)))
          .completed,
      false,
    );
    await h.db.database.execute('DROP TRIGGER reject_topic');
    success(await h.game.learning.beginSafetyFinale());
    expect(await h.balance(), before + FinancialSafetyTopic.rewardFira);
  });
  test('v5 upgrade preserves existing lesson rewards, savings, budget and inventory', () async {
    final dir = await Directory.systemTemp.createTemp('safety-upgrade-');
    final path = '${dir.path}/save.db';
    var h = await Harness.create(path: path, contentSource: safetyCatalog);
    try {
      await h.start();
      await stage3(h);
      final c = await safetyController(h, FinancialSafetyLesson.callId);
      await finishSafety(c);
      c.dispose();
      await h.read(
        (r) => r.economy.saveBudget(
          BudgetAllocation(mandatory: 10, optional: 10, remainder: 10),
        ),
      );
      final wallet = await h.balance();
      final xp = await h.xp();
      // Recreate the actual v5 schema boundary in this disposable QA database.
      await h.db.database.execute('DROP TABLE learning_topic_progress');
      await h.db.database.execute('PRAGMA user_version = 5');
      await h.db.close();
      h = await Harness.create(path: path, contentSource: safetyCatalog);
      expect(await h.balance(), wallet);
      expect(await h.xp(), xp);
      expect(
        (await h.read(
          (r) => r.learning.learningProgress(FinancialSafetyLesson.callId),
        )).completed,
        true,
      );
      expect((await h.read((r) => r.economy.budget()))!.mandatory, 10);
      expect(
        (await h.read((r) => r.learning.topicProgress(FinancialSafetyTopic.id)))
            .completed,
        false,
      );
      rejected(
        await h.game.learning.beginSafetyFinale(),
        Failure.requirementsNotMet,
      );
    } finally {
      await h.db.close();
      await dir.delete(recursive: true);
    }
  });
  test(
    'missing required specification can never be rewarded as a complete topic',
    () async {
      final source = safetyCatalog.replaceFirst(
        '"id": "home_planet_safety_call",',
        '"id": "home_planet_safety_call", "implemented": false,',
      );
      final h = await Harness.create(contentSource: source);
      addTearDown(h.db.close);
      await h.start();
      await stage3(h);
      await h.read((r) async {
        for (final task in FinancialSafetyTopic.requiredTasks(h.content)) {
          await r.learning.saveLearningProgress(
            LearningProgress(taskId: task.id, completionCount: 1),
          );
        }
      });
      rejected(await h.game.learning.beginSafetyFinale(), Failure.locked);
      expect(await h.balance(), 30);
    },
  );
}
