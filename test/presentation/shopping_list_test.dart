import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/shopping_list_lesson.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/components/strannik_button.dart';
import 'package:strannik/presentation/learning/learning_screen.dart';
import 'package:strannik/presentation/learning/shopping_list_controller.dart';
import 'package:strannik/presentation/learning/shopping_list_screen.dart';

import '../support/harness.dart';

String get catalog =>
    File('lib/content/seed/development.json').readAsStringSync();
Future<ShoppingListController> open(Harness h, {bool replay = false}) async {
  final attempt = success(
    await h.game.learning.beginTask(ShoppingListLesson.taskId, replay: replay),
  );
  final progress = await h.read(
    (r) => r.learning.learningProgress(ShoppingListLesson.taskId),
  );
  return ShoppingListController(
    h.game,
    attempt,
    rewardClaimed: progress.completed,
  );
}

Future<void> toExercise(ShoppingListController c) async {
  while (c.step != 11) {
    await c.advance();
  }
}

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create(contentSource: catalog);
    await h.start();
    // Gameplay fixtures start at the lesson's owning stage. Stage gating and
    // the real milestone are exercised separately in stage_assignment_test.
    await h.read(
      (r) async => r.pets.savePet(
        (await r.pets.pet())!.copyWith(currentStage: Stage.space),
      ),
    );
  });
  tearDown(() => h.db.close());

  test(
    'real task IDs, locking, reward config and both dialogue branches',
    () async {
      final task = h.content.task('theme1_task')!;
      expect(task.title, 'Список покупок');
      expect(task.rewardXp, 15);
      expect(task.rewardFira, 40);
      rejected(
        await h.game.learning.beginTask('space_theme1_task3'),
        Failure.locked,
      );
      final c = await open(h);
      await c.advance(scared: true);
      expect(c.step, 3);
      await c.advance();
      expect(c.step, 4);
      await c.advance();
      expect(c.step, 2);
      await c.advance();
      expect(c.step, 5);
      await c.back();
      expect(c.step, 2);
      c.dispose();
    },
  );

  test(
    'selection toggles, integer totals, recovery, no wallet purchases',
    () async {
      final c = await open(h);
      await toExercise(c);
      expect(c.budget.valid, false);
      await c.confirm();
      expect(c.step, 11);
      await c.toggle('popcorn');
      expect(c.budget.total, 300);
      expect(c.budget.remaining, 50);
      expect(c.budget.valid, true);
      await c.toggle('juice');
      expect(c.budget.total, 400);
      expect(c.budget.remaining, -50);
      expect(c.budget.shortfall, 50);
      expect(c.budget.valid, false);
      await c.confirm();
      expect(c.step, 11);
      await c.toggle('popcorn');
      await c.toggle('chips');
      await c.toggle('apples');
      expect(c.budget.total, 325);
      expect(c.budget.remaining, 25);
      expect(await h.balance(), 30);
      expect(await h.read((r) => r.items.inventory()), isEmpty);
      expect((await h.read((r) => r.economy.transactions())).length, 1);
      await c.confirm();
      expect(c.step, 12);
      expect(await h.xp(), 0);
      await c.back();
      expect(c.step, 11);
      expect(c.selected, {'juice', 'chips', 'apples'});
      c.dispose();
    },
  );

  test('exact budget is allowed; invalid product IDs are rejected', () {
    // None of the four shipped product subsets totals exactly 350; test the boundary with a controlled product.
    const products = [
      LessonProduct(id: 'exact', title: 'Тест', price: 350, assetId: 'test'),
    ];
    final exact = LessonBudget(350, products, ['exact']);
    expect(exact.remaining, 0);
    expect(exact.valid, true);
    expect(LessonBudget(349, products, ['exact']).valid, false);
    expect(LessonBudget(350, products, ['missing']).valid, false);
  });

  test('rapid finish awards exactly once; replay and stale callbacks never duplicate', () async {
    final c = await open(h);
    await toExercise(c);
    await c.toggle('popcorn');
    await c.confirm();
    await Future.wait([c.finish(), c.finish(), c.finish()]);
    expect(c.step, 13);
    expect(await h.balance(), 70);
    expect(await h.xp(), 15);
    expect(
      (await h.read((r) => r.learning.learningProgress('theme1_task')))
          .completionCount,
      1,
    );
    expect(await h.read((r) => r.items.inventory()), isEmpty);
    expect(
      (await h.read((r) => r.economy.transactions()))
          .where((t) => t.type == TransactionType.learningReward)
          .length,
      1,
    );
    c.dispose();
    final replay = await open(h, replay: true);
    expect(replay.rewardClaimed, true);
    await toExercise(replay);
    await replay.toggle('juice');
    await replay.confirm();
    await replay.finish();
    expect(replay.step, 13);
    expect(await h.balance(), 70);
    expect(await h.xp(), 15);
    expect(
      (await h.read((r) => r.learning.learningProgress('theme1_task')))
          .completionCount,
      1,
    );
    replay.dispose();
  });

  test('domain rejects unconfirmed and over-budget completion', () async {
    final c = await open(h);
    await toExercise(c);
    await c.toggle('popcorn');
    await c.toggle('juice');
    rejected(
      await h.game.learning.completeLearningTask(
        c.attempt.id,
        successful: true,
      ),
      Failure.requirementsNotMet,
    );
    expect(await h.balance(), 30);
    expect(await h.xp(), 0);
    c.dispose();
  });

  test(
    'XP, wallet, attempt and completion roll back together on failure',
    () async {
      final c = await open(h);
      await toExercise(c);
      await c.toggle('juice');
      await c.confirm();
      await h.db.database.execute(
        "CREATE TRIGGER fail_learning BEFORE INSERT ON learning_progress BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      await c.finish();
      expect(c.step, 12);
      expect(c.error, isNotNull);
      expect(await h.balance(), 30);
      expect(await h.xp(), 0);
      expect(
        (await h.read((r) => r.learning.attempt(c.attempt.id)))!.completedAt,
        isNull,
      );
      await h.db.database.execute('DROP TRIGGER fail_learning');
      await c.finish();
      expect(c.step, 13);
      expect(await h.balance(), 70);
      expect(await h.xp(), 15);
      c.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(360, 960),
    const Size(360, 640),
  ]) {
    testWidgets('map entry, native selection and every step at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> waitFor(Finder target) async {
        for (var i = 0; i < 300 && target.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(target, findsWidgets);
        await tester.pumpAndSettle();
      }

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
      await waitFor(find.text('Список покупок'));
      await tester.tap(find.text('Список покупок'));
      await waitFor(find.byType(ShoppingListScreen));
      expect(find.byType(ShoppingListScreen), findsOneWidget);
      final screen = tester.widget<ShoppingListScreen>(
        find.byType(ShoppingListScreen),
      );
      final c = screen.controller;
      await tester.runAsync(() => toExercise(c));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StrannikButton>(
              find.widgetWithText(StrannikButton, 'Оплатить'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Попкорн 300'));
      await waitFor(find.text('Оплатить 300 фир'));
      while (c.busy) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.text('Оплатить 300 фир'), findsOneWidget);
      await tester.tap(find.text('Сок 100'));
      await waitFor(find.text('Не хватает фир'));
      while (c.busy) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.text('Не хватает фир'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final second = await tester.runAsync(() => open(h));
      for (final textScale in [1.0, 1.3]) {
        for (var step = 0; step <= 13; step++) {
          second!.step = step;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: ShoppingListScreen(
                  controller: second,
                  onClose: () async {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'step=$step scale=$textScale',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      second!.dispose();
    });
  }
}
