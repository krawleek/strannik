import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show getDatabasesPath, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/lessons/discount_traps_lesson.dart';
import 'package:strannik/content/lessons/earth_topic_one.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/data/security/pbkdf2_pin_hasher.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/learning/discount_traps_screen.dart';
import 'package:strannik/presentation/learning/earth_topic_controller.dart';
import 'package:strannik/presentation/learning/financial_safety_screen.dart';
import 'package:strannik/presentation/learning/shopping_list_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Stage 2 lessons, canonical transition, Stage 3 safety and SQLite restart',
    (tester) async {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final file = path.join(
        await getDatabasesPath(),
        'stage2_qa_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      var db = await LocalDatabase.open(file);
      final content = LocalContentRepository.fromJson(
        await rootBundle.loadString('lib/content/seed/development.json'),
      );
      GameServices services() => GameServices(
        unitOfWork: db,
        content: content,
        pinHasher: Pbkdf2PinHasher(iterations: 1000),
      );
      var game = services();
      T ok<T>(Result<T> value) {
        expect(value, isA<Success<T>>());
        return (value as Success<T>).value;
      }

      ok(
        await game.onboarding.saveDraft(
          nickname: 'Путник',
          avatarId: 'girl',
          petName: 'Веня',
          alienName: 'Зор',
          skinId: 'gray',
        ),
      );
      ok(await game.parentAccess.setPin('1234'));
      ok(await game.onboarding.complete());
      Future<EarthTopicController> earth(String id) async =>
          EarthTopicController(
            game,
            ok(await game.learning.beginTask(id)),
            rewardClaimed: false,
          );
      var e = await earth(EarthTopicOne.needsId);
      await e.change(() => e.step = 1);
      for (final item in EarthTopicOne.items) {
        await e.classify(EarthTopicOne.necessary.contains(item.id));
      }
      await e.confirmBasket();
      await e.check('150');
      e.dispose();
      e = await earth(EarthTopicOne.weeklyId);
      await e.check('180');
      await e.advanceWeekly();
      for (var i = 0; i < 6; i++) {
        await e.change(() => e.simulation.allocate(true));
      }
      for (var i = 0; i < 2; i++) {
        await e.change(() => e.simulation.allocate(false));
      }
      await e.advanceWeekly();
      await e.change(() => e.simulation.choose(WeeklyBranch.wait));
      for (var i = 0; i < 3; i++) {
        await e.advanceWeekly();
      }
      e.dispose();
      e = await earth(EarthTopicOne.goalId);
      await e.chooseGoal(BigGoalType.spaceTaxi);
      await e.confirmGoal();
      await e.initialPlan(80, 30);
      await e.allocateGoal(10);
      e.dispose();
      ok(await game.store.buyItem('titanium', quantity: 2));
      ok(await game.store.buyItem('fuel'));
      ok(await game.store.buyItem('ball'));
      ok(await game.pet.activateToy('ball'));
      ok(await game.pet.playWithToy('ball'));
      ok(await game.progression.advanceStage(fromStage: Stage.earth));
      var home = HomeController(
        unitOfWork: db,
        allowDevelopmentPreview: false,
        content: content,
        interactions: game.pet,
      );
      await home.load();
      await tester.pumpWidget(StrannikApp(controller: home));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      Future<void> pump() async {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }

      Future<void> capture(String name) async {
        debugPrint('QA capture $name');
        await pump();
        final shot = binding.takeScreenshot(name);
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await shot.timeout(const Duration(seconds: 25));
        debugPrint('QA captured $name');
      }

      Future<void> tap(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await pump();
      }

      for (var i = 0; i < 20 && find.text('Понятно').evaluate().isEmpty; i++) {
        await pump();
      }
      if (find.text('Понятно').evaluate().isNotEmpty) {
        await tap('Понятно');
        for (
          var i = 0;
          i < 20 && find.text('Понятно').evaluate().isNotEmpty;
          i++
        ) {
          await pump();
        }
      }
      await capture('stage2-home');
      await tester.tap(find.bySemanticsLabel(RegExp('^Стадия 2')));
      await pump();
      await capture('stage2-missing');
      expect(find.text('Перейти на стадию 3'), findsOneWidget);
      await tap('Задания этапа');
      await capture('stage2-map');
      expect(find.text('Выбираем с умом'), findsNothing);
      await tap('Список покупок');
      final shopping = tester
          .widget<ShoppingListScreen>(find.byType(ShoppingListScreen))
          .controller;
      while (shopping.step < 11) {
        await shopping.advance();
        await pump();
      }
      await shopping.toggle('juice');
      await shopping.confirm();
      await shopping.finish();
      await pump();
      await tap('За попкорном!');
      await tap('Ловушки скидок');
      await capture('discount-intro');
      final c = tester
          .widget<DiscountTrapsScreen>(find.byType(DiscountTrapsScreen))
          .controller;
      while (c.step < DiscountTrapsLesson.rulesStep) {
        if (c.step == 14) await capture('discount-quantity');
        await tap(DiscountTrapsLesson.actions[c.step]);
      }
      await capture('discount-rules');
      await tap('Начать ловить');
      final field = find.byKey(const ValueKey('discount-field'));
      final rect = tester.getRect(field);
      await tester.tapAt(
        Offset(rect.left + 56 + .1 * (rect.width - 112), rect.bottom - 55),
      );
      await capture('discount-game');
      for (var i = 0; i < 95; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await pump();
      expect(c.progress.caught, 1);
      await c.resolve(c.progress.round, caught: true);
      await capture('discount-mistake');
      await tap('Продолжить');
      // Remaining rounds exercise the same persisted answer validator without waiting for each fall.
      while (c.step == DiscountTrapsLesson.gameStep) {
        await c.resolve(c.progress.round, caught: c.progress.offer.shouldCatch);
      }
      await capture('discount-result');
      await tap('Далее');
      await tap('Далее');
      expect(c.completed, true);
      await capture('discount-reward');
      await tap('Ура!');
      await capture('topic-completed');
      expect(find.text('Тема завершена ✓'), findsOneWidget);
      ok(await game.store.buyItem('titanium', quantity: 2));
      ok(await game.store.buyItem('fuel'));
      await tester.tap(find.bySemanticsLabel('Вернуться домой'));
      await pump();
      await tester.tap(find.bySemanticsLabel(RegExp('^Стадия 2')));
      await pump();
      await capture('stage2-ready');
      final before = ok(
        await game.context.run(
          (r) async => (
            wallet: (await r.economy.wallet()).firaAmount,
            plan: (await r.economy.budget())!,
            xp: (await r.pets.pet())!.xp,
          ),
        ),
      );
      await tap('Перейти на стадию 3');
      await capture('transition-confirm');
      await tap('Подтвердить переход');
      await pump();
      await capture('stage3-home');
      expect(home.state.effectiveStage, Stage.homePlanet);
      await tester.tap(find.bySemanticsLabel('Задания'));
      await pump();
      await capture('stage3-map');
      await tap('Секретный звонок');
      expect(find.byType(FinancialSafetyScreen), findsOneWidget);
      await capture('safety-start');
      await tester.pumpWidget(const SizedBox());
      home.dispose();
      await db.close();
      db = await LocalDatabase.open(file);
      game = services();
      final after = ok(
        await game.context.run(
          (r) async => (
            wallet: (await r.economy.wallet()).firaAmount,
            plan: (await r.economy.budget())!,
            xp: (await r.pets.pet())!.xp,
          ),
        ),
      );
      expect(after.wallet, before.wallet);
      expect(after.plan.mandatory, before.plan.mandatory);
      expect(after.plan.optional, before.plan.optional);
      expect(after.plan.remainder, before.plan.remainder);
      expect(after.xp, before.xp + 1);
      expect(ok(await game.learning.stageProgress(Stage.space)), (
        completed: 2,
        required: 2,
      ));
      expect(ok(await game.learning.stageProgress(Stage.earth)), (
        completed: 3,
        required: 3,
      ));
      home = HomeController(
        unitOfWork: db,
        allowDevelopmentPreview: false,
        content: content,
        interactions: game.pet,
      );
      await home.load();
      await tester.pumpWidget(StrannikApp(controller: home));
      await tester.pumpAndSettle();
      await capture('restart-stage3-home');
      expect(home.state.effectiveStage, Stage.homePlanet);
      await tester.pumpWidget(const SizedBox());
      home.dispose();
      await db.close();
      await deleteDatabase(file);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
