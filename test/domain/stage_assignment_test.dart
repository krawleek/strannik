import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/content/lessons/shopping_list_lesson.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/learning/learning_screen.dart';
import 'package:strannik/presentation/learning/shopping_list_controller.dart';
import 'package:strannik/presentation/learning/shopping_list_screen.dart';

import '../support/harness.dart';

String get source =>
    File('lib/content/seed/development.json').readAsStringSync();
Future<void> spaceFixture(Harness h) => h.read(
  (r) async =>
      r.pets.savePet((await r.pets.pet())!.copyWith(currentStage: Stage.space)),
);
Future<void> finishLesson(Harness h) async {
  final a = success(
    await h.game.learning.beginTask(ShoppingListLesson.taskId, replay: true),
  );
  final c = ShoppingListController(h.game, a, rewardClaimed: false);
  while (c.step != 11) {
    await c.advance();
  }
  await c.toggle('juice');
  await c.confirm();
  await c.finish();
  expect(c.step, 13);
  c.dispose();
}

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create(contentSource: source);
    await h.start();
  });
  tearDown(() => h.db.close());

  test(
    'one stable task belongs only to space / topic 1; Earth excludes it',
    () async {
      final task = h.content.task('theme1_task')!;
      expect(
        h.content.tasks.where((t) => t.title == 'Список покупок').length,
        1,
      );
      expect(task.stage, Stage.space);
      expect(task.themeId, 'space_theme1');
      expect(task.order, 0);
      expect(
        h.content.themes.firstWhere((t) => t.id == task.themeId).stage,
        Stage.space,
      );
      expect(
        h.content.tasks.where((t) => t.stage == Stage.earth).map((t) => t.id),
        isNot(contains(task.id)),
      );
      rejected(await h.game.learning.beginTask(task.id), Failure.locked);
      expect(
        success(await h.game.learning.availableTasks()).map((t) => t.id),
        isNot(contains(task.id)),
      );
      expect(success(await h.game.learning.stageProgress(Stage.earth)), (
        completed: 0,
        required: 3,
      ));
      expect(success(await h.game.learning.stageProgress(Stage.space)), (
        completed: 0,
        required: 2,
      ));
    },
  );

  test('existing real progression milestone gates Stage 2 without changing its rules', () async {
    success(await h.game.progression.selectBigGoal(BigGoalType.repairShip));
    success(await h.game.progression.confirmBigGoal());
    rejected(
      await h.game.progression.advanceStage(),
      Failure.requirementsNotMet,
    );
    rejected(await h.game.learning.beginTask('theme1_task'), Failure.locked);
    success(await h.game.store.buyItem('titanium', quantity: 2));
    success(await h.game.store.buyItem('fuel'));
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
    success(await h.game.progression.advanceStage());
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.space);
    expect(
      success(await h.game.learning.availableTasks()).map((t) => t.id),
      contains('theme1_task'),
    );
  });

  test('completion unlocks Task 2, keeps Task 3 locked, and never advances Earth periods', () async {
    await spaceFixture(h);
    final period = (await h.read((r) => r.progress.currentPeriod()))!.id;
    final earthBefore = success(
      await h.game.learning.stageProgress(Stage.earth),
    );
    await finishLesson(h);
    expect(
      success(await h.game.learning.stageProgress(Stage.earth)),
      earthBefore,
    );
    expect(success(await h.game.learning.stageProgress(Stage.space)), (
      completed: 1,
      required: 2,
    ));
    expect(
      success(await h.game.learning.availableTasks()).map((t) => t.id),
      contains('space_theme1_task2'),
    );
    expect(
      success(await h.game.learning.availableTasks()).map((t) => t.id),
      isNot(contains('space_theme1_task3')),
    );
    expect(h.content.task('space_theme1_task2')!.implemented, true);
    success(await h.game.learning.beginTask('space_theme1_task2'));
    expect((await h.read((r) => r.progress.currentPeriod()))!.id, period);
    expect(await h.read((r) => r.progress.periods()), hasLength(1));
    expect(
      success(
        await h.game.context.run(
          (r) => h.game.context.themeCompleted(r, 'space_theme1'),
        ),
      ),
      false,
    );
    expect(await h.balance(), 70);
    expect(await h.xp(), 15);
  });

  test('remaining Earth lessons unlock without depending on reassigned shopping task', () async {
    final available = success(await h.game.learning.availableTasks())
        .map((t) => t.id);
    expect(available, contains('earth_theme1_needs'));
    for (final id in [
      'earth_theme1_needs',
      'earth_theme1_weekly_budget',
      'earth_theme1_goal',
    ]) {
      await h.read(
        (r) => r.learning.saveLearningProgress(
          LearningProgress(
            taskId: id,
            completionCount: 1,
            completedAt: DateTime.now(),
          ),
        ),
      );
    }
    for (final id in ['theme2_task', 'theme3_task', 'fraud_task']) {
      rejected(await h.game.learning.beginTask(id), Failure.locked);
      expect(
        (await h.read((r) => r.learning.learningProgress(id))).completed,
        false,
      );
    }
    expect(success(await h.game.learning.stageProgress(Stage.earth)), (
      completed: 3,
      required: 3,
    ));
    expect(
      (await h.read((r) => r.learning.learningProgress('theme1_task')))
          .completed,
      false,
    );
  });

  test('demo space override allows preview and never changes real stage or grants entry rewards', () async {
    success(await h.game.demo.setEnabled('1234', true));
    success(await h.game.demo.changeDemoStage('1234', Stage.space));
    success(await h.game.learning.beginTask('theme1_task'));
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.earth);
    expect(await h.balance(), 30);
    expect(await h.xp(), 0);
    success(await h.game.demo.setEnabled('1234', false));
    rejected(await h.game.learning.beginTask('theme1_task'), Failure.locked);
    expect(
      await h.read((r) => r.learning.openAttempt('theme1_task')),
      isNotNull,
    );
  });

  test('completed and incomplete old records are reattributed without schema/reward changes', () async {
    final dir = await Directory.systemTemp.createTemp('reassign-stage-');
    try {
      for (final completed in [false, true]) {
        final path = '${dir.path}/$completed.db';
        final oldCatalog = jsonDecode(source) as Map<String, dynamic>;
        oldCatalog['tasks'][0]['themeId'] = 'theme1';
        for (final task in oldCatalog['tasks']) {
          if (task['type'] == 'earthTopicOne' && task['themeId'] == 'theme1') {
            task['order'] += 1;
          }
        }
        var old = await Harness.create(
          path: path,
          contentSource: jsonEncode(oldCatalog),
        );
        await old.start();
        final a = success(await old.game.learning.beginTask('theme1_task'));
        final c = ShoppingListController(old.game, a, rewardClaimed: false);
        while (c.step != 11) {
          await c.advance();
        }
        await c.toggle('popcorn');
        if (completed) {
          await c.confirm();
          await c.finish();
        }
        c.dispose();
        final balance = await old.balance(), xp = await old.xp();
        await old.db.close();
        final current = await Harness.create(path: path, contentSource: source);
        expect(
          await current.db.database.getVersion(),
          LocalDatabase.schemaVersion,
        );
        expect(await current.balance(), balance);
        expect(await current.xp(), xp);
        expect(
          (await current.read(
            (r) => r.learning.learningProgress('theme1_task'),
          )).completed,
          completed,
        );
        expect(
          (await current.read((r) => r.learning.attempt(a.id)))!
              .lessonState['selected'],
          ['popcorn'],
        );
        expect(
          success(await current.game.learning.stageProgress(Stage.earth))
              .completed,
          0,
        );
        expect(
          success(await current.game.learning.stageProgress(Stage.space))
              .completed,
          completed ? 1 : 0,
        );
        rejected(
          await current.game.learning.beginTask('theme1_task', replay: true),
          Failure.locked,
        );
        await spaceFixture(current);
        if (completed) {
          await finishLesson(current);
          expect(await current.balance(), balance);
          expect(await current.xp(), xp);
        } else {
          final resumed = success(
            await current.game.learning.beginTask('theme1_task'),
          );
          expect(resumed.id, a.id);
          expect(resumed.lessonState['step'], 11);
        }
        expect(
          (await current.db.database.rawQuery(
            "SELECT * FROM learning_progress WHERE task_id='theme1_task'",
          )).length,
          completed ? 1 : 0,
        );
        await current.db.close();
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
    'maps follow real/demo stage; closing and completing return to Stage 2',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> show() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: LearningScreen(
              unitOfWork: h.db,
              content: h.content,
              onBack: () {},
              onChanged: () async {},
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        });
        for (
          var i = 0;
          i < 20 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await show();
      expect(find.text('Этап 1'), findsOneWidget);
      expect(find.text('Список покупок'), findsNothing);
      await tester.runAsync(() => spaceFixture(h));
      await show();
      expect(find.text('Этап 2'), findsOneWidget);
      expect(find.text('Список покупок'), findsOneWidget);
      expect(find.text('Ловушки скидок'), findsOneWidget);
      expect(find.text('Выбираем с умом'), findsNothing);
      await tester.tap(find.text('Список покупок'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pumpAndSettle();
      final lesson = tester.widget<ShoppingListScreen>(
        find.byType(ShoppingListScreen),
      );
      await tester.runAsync(lesson.onClose);
      await tester.pumpAndSettle();
      expect(find.text('Этап 2'), findsOneWidget);
      await tester.tap(find.text('Список покупок'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pumpAndSettle();
      final c = tester
          .widget<ShoppingListScreen>(find.byType(ShoppingListScreen))
          .controller;
      await tester.runAsync(() async {
        while (c.step != 11) {
          await c.advance();
        }
        await c.toggle('juice');
        await c.confirm();
        await c.finish();
        expect(c.error, isNull);
        expect(c.step, 13);
      });
      await tester.pumpAndSettle();
      final finishedScreen = tester.widget<ShoppingListScreen>(
        find.byType(ShoppingListScreen),
      );
      await tester.runAsync(finishedScreen.onClose);
      await tester.pumpAndSettle();
      expect(find.text('Этап 2'), findsOneWidget);
      expect(find.text('Выполнено ✓\nПройти ещё раз'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
