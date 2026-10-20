import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/store/store_controller.dart';
import 'package:strannik/presentation/store/store_screen.dart';
import 'package:strannik/presentation/stages/stage_progress_screen.dart';
import 'package:strannik/presentation/onboarding/onboarding_controller.dart';
import 'package:strannik/presentation/components/strannik_button.dart';
import 'package:strannik/content/lessons/discount_traps_lesson.dart';
import 'package:strannik/content/lessons/financial_safety_lesson.dart';
import 'package:strannik/presentation/learning/discount_traps_screen.dart';
import 'package:strannik/presentation/learning/financial_safety_screen.dart';
import 'package:strannik/presentation/learning/earth_topic_screen.dart';
import 'package:strannik/presentation/learning/shopping_list_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'new player onboarding through all published learning to Stage 3 finale and restart',
    (t) async {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final path =
          '${await getDatabasesPath()}/complete_stage3_${DateTime.now().microsecondsSinceEpoch}.db';
      var db = await LocalDatabase.open(path);
      final content = LocalContentRepository.fromJson(
        await rootBundle.loadString('lib/content/seed/development.json'),
      );
      var game = GameServices(unitOfWork: db, content: content);
      final onboarding = OnboardingController(game);
      await onboarding.load();
      var home = HomeController(
        unitOfWork: db,
        allowDevelopmentPreview: false,
        content: content,
        interactions: game.pet,
      );
      var store = StoreController(game);
      Future<void> settle() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (find.byType(DiscountCatchingGame).evaluate().isNotEmpty) {
          await t.pump(const Duration(milliseconds: 100));
        } else {
          await t.pumpAndSettle();
        }
      }

      Future<void> awaitWrites() async {
        for (var i = 0; i < 200; i++) {
          final e = find.byType(EarthTopicScreen);
          final s = find.byType(ShoppingListScreen);
          final f = find.byType(FinancialSafetyScreen);
          final d = find.byType(DiscountTrapsScreen);
          final busy =
              (e.evaluate().isNotEmpty &&
                  t.widget<EarthTopicScreen>(e).controller.busy) ||
              (s.evaluate().isNotEmpty &&
                  t.widget<ShoppingListScreen>(s).controller.busy) ||
              (f.evaluate().isNotEmpty &&
                  t.widget<FinancialSafetyScreen>(f).controller.busy) ||
              (d.evaluate().isNotEmpty &&
                  t.widget<DiscountTrapsScreen>(d).controller.busy);
          if (!busy) break;
          await Future<void>.delayed(const Duration(milliseconds: 25));
          await t.pump();
        }
      }

      Future<void> wait(Finder f) async {
        for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
          await settle();
        }
        expect(f, findsWidgets);
      }

      Future<void> tap(Finder f) async {
        await settle();
        await wait(f);
        await t.ensureVisible(f.first);
        await t.tap(f.first);
        await settle();
        await awaitWrites();
        await settle();
      }

      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextField, label);
        await wait(field);
        await t.ensureVisible(field);
        await t.tap(field);
        await settle();
        await t.enterText(field, value);
        await settle();
        expect(t.widget<TextField>(field).controller!.text, value);
      }

      Future<void> capture(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await settle();
        debugPrint('JOURNEY_CAPTURE:$name');
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      Future<void> show() async {
        await home.load();
        await store.load();
        await t.pumpWidget(
          StrannikApp(
            controller: home,
            store: store,
            onboarding: onboarding.completed == true ? null : onboarding,
          ),
        );
        await settle();
      }

      await show();
      for (
        var screen = 0;
        onboarding.completed != true && screen < 35;
        screen++
      ) {
        final step = onboarding.step;
        debugPrint('JOURNEY_ONBOARDING:$step');
        if (step.index <= OnboardingStep.street.index) {
          await tap(find.bySemanticsLabel(RegExp('^Странник[. ]')));
        } else if (step == OnboardingStep.childName ||
            step == OnboardingStep.petName ||
            step == OnboardingStep.pin) {
          await t.enterText(
            find.byType(TextField),
            step == OnboardingStep.pin
                ? '1234'
                : step == OnboardingStep.childName
                ? 'Алиса'
                : 'Веня',
          );
          await tap(find.text('Отправить'));
        } else if (step == OnboardingStep.parentOffer ||
            step == OnboardingStep.permission) {
          await tap(find.text('Хорошо, оставайся'));
        } else {
          final buttons = find.byWidgetPredicate(
            (w) => w is StrannikButton && w.onPressed != null,
          );
          await tap(step == OnboardingStep.skin ? buttons.last : buttons.first);
        }
        await settle();
        while (onboarding.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await t.pump();
        }
        await settle();
        expect(onboarding.error, isNull);
      }
      expect(onboarding.completed, true);
      await show();
      await capture('00-earth-home');
      await tap(find.bySemanticsLabel(RegExp('^Стадия 1')));
      await wait(find.byType(StageProgressScreen));
      await capture('01-missing-requirements');
      await tap(find.byTooltip('Вернуться домой'));
      await tap(find.bySemanticsLabel('Обучение'));
      await tap(find.text('Хочу или нужно?'));
      await capture('02-needs-intro');
      await tap(find.text('Начать'));
      for (final yes in [false, true, false, true, false, true]) {
        await tap(find.text(yes ? 'Нужно' : 'Нет'));
      }
      await capture('03-basket');
      await tap(find.text('Изменить выбор'));
      await capture('04-grid');
      await tap(find.text('Всё необходимое взяли'));
      await enter('Всего фир', '140');
      await tap(find.text('Проверить'));
      await capture('05-wrong-total');
      await enter('Всего фир', '150');
      await tap(find.text('Проверить'));
      final needs = t
          .widget<EarthTopicScreen>(find.byType(EarthTopicScreen))
          .controller;
      debugPrint(
        'JOURNEY_NEEDS:step=${needs.step},answer=${needs.answer},done=${needs.done},error=${needs.error},selected=${needs.selected}',
      );
      await capture('05b-needs-state');
      await wait(find.text('Ура! Мы купили всё необходимое'));
      await capture('06-needs-complete');
      await tap(find.text('Следующее задание'));
      await wait(find.text('Всего за неделю'));
      await capture('07-weekly-food');
      await enter('Всего за неделю', '180');
      await tap(find.text('Проверить'));
      await capture('08-weekly-income');
      await tap(find.text('Продолжить'));
      for (var i = 0; i < 6; i++) {
        await tap(find.bySemanticsLabel('На еду: добавить 30 фир'));
      }
      for (var i = 0; i < 2; i++) {
        await tap(find.bySemanticsLabel('В копилку: добавить 30 фир'));
      }
      await capture('09-weekly-allocation');
      await tap(find.text('Продолжить'));
      await capture('10-weekly-shop');
      await tap(find.text('Подождать и копить'));
      await capture('11-next-week');
      await tap(find.text('Продолжить'));
      await capture('12-wait-summary');
      await tap(find.text('Продолжить'));
      await capture('13-expensive-affordable');
      await tap(find.text('Купить крутую ракету'));
      await wait(
        find.text('Ты научил Странника планировать бюджет на неделю!'),
      );
      await tap(find.text('Следующее задание'));
      await capture('14-goal-dream');
      await tap(find.text('Какие?'));
      await tap(find.bySemanticsLabel('Космо-такси'));
      await capture('15-goal-selection');
      await tap(find.text('Выбрать'));
      await enter('Нужно', '80');
      await enter('Хочу', '30');
      await tap(find.text('Сохранить план'));
      await enter('Сколько отложить', '10');
      await capture('16-goal-allocation');
      await tap(find.text('Сохранить'));
      await wait(find.text('Цель поставлена'));
      await capture('17-goal-complete');
      await tap(find.text('Следующее задание'));
      await wait(find.text('Открыть Банк'));
      await capture('18-home-tutorial');
      await tap(find.text('Открыть Банк'));
      await settle();
      final dismiss = find.byTooltip('Закрыть подсказку');
      if (dismiss.evaluate().isNotEmpty) await tap(dismiss);
      await capture('19-bank-goal');
      // Back from Bank returns to real Home, then use existing Shop and Closet.
      await tap(find.byTooltip('Назад'));
      await tap(find.bySemanticsLabel('Магазин'));
      await wait(find.byType(StoreScreen));
      Future<void> buy(String title) async {
        final item = find.bySemanticsLabel(RegExp('^$title\\.'));
        final list = find
            .descendant(
              of: find.byType(StoreScreen),
              matching: find.byType(ListView),
            )
            .last;
        for (var i = 0; i < 20 && item.hitTestable().evaluate().isEmpty; i++) {
          await t.drag(list, Offset(title == 'Мяч' ? 160 : -160, 0));
          await settle();
        }
        await tap(item.hitTestable());
        await tap(find.bySemanticsLabel('Корзина'));
        await tap(find.text('Купить'));
        await tap(find.text('Нужно'));
        await tap(find.textContaining('Оплатить '));
        await wait(find.text('Ура! Покупка твоя!'));
        await tap(find.byTooltip('Закрыть'));
      }

      await buy('Титан');
      await buy('Титан');
      await buy('Топливо');
      await buy('Мяч');
      await tap(find.bySemanticsLabel('Шкаф'));
      await tap(find.bySemanticsLabel(RegExp('^Мяч\\.')));
      await tap(find.text('Поиграть'));
      await capture('20-earned-xp');
      // Android back clears selected item, closes Closet, then returns Home.
      for (var i = 0; i < 3; i++) {
        await t.binding.handlePopRoute();
        await settle();
      }
      await tap(find.bySemanticsLabel(RegExp('^Стадия 1')));
      await wait(find.text('Перейти на стадию 2'));
      await capture('21-ready');
      await tap(find.text('Перейти на стадию 2'));
      await capture('22-confirm');
      await tap(find.text('Подтвердить переход'));
      await wait(find.bySemanticsLabel(RegExp('^Стадия 2')));
      await capture('23-space-home');
      await tap(find.bySemanticsLabel('Обучение'));
      await wait(find.text('Список покупок'));
      await capture('24-space-map');
      await tap(find.text('Список покупок'));
      await settle();
      await capture('25-space-lesson');
      for (final label in [
        'Даже не знаю, что сказать...',
        'Давай!',
        'Делаем киновечер!',
        'Какой список?',
        'Спросить',
        'Далее',
        'Далее',
        'Далее',
        'Давай!',
      ]) {
        await tap(find.text(label));
      }
      await tap(find.text('Попкорн 300'));
      await tap(find.text('Оплатить 300 фир'));
      await tap(find.text('Ура!'));
      await tap(find.text('За попкорном!'));
      await tap(find.text('Ловушки скидок'));
      for (final label in DiscountTrapsLesson.actions) {
        await tap(find.text(label));
      }
      await tap(find.text('Начать ловить'));
      final discount = t
          .widget<DiscountTrapsScreen>(find.byType(DiscountTrapsScreen))
          .controller;
      // Observe the round to move the basket via real gestures; no completion shortcuts.
      while (discount.progress.caught < 10) {
        final round = discount.progress.round;
        final lane = const [.1, .55, .9, .3, .7, .12, .5, .85][round % 8];
        final target = discount.progress.offer.shouldCatch
            ? lane
            : lane > .5
            ? 0.0
            : 1.0;
        final field = t.getRect(find.byKey(const ValueKey('discount-field')));
        await t.tapAt(
          Offset(
            field.left + 56 + target * (field.width - 112),
            field.bottom - 55,
          ),
        );
        for (
          var frame = 0;
          frame < 130 &&
              discount.progress.round == round &&
              !discount.progress.feedback;
          frame++
        ) {
          await t.pump(const Duration(milliseconds: 50));
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await t.pump();
        expect(discount.progress.feedback, false);
        expect(discount.error, isNull);
      }
      await tap(find.text('Далее'));
      await tap(find.text('Далее'));
      await tap(find.text('Ура!'));
      await capture('28-space-completed');
      await tap(find.bySemanticsLabel('Вернуться домой'));
      await tap(find.bySemanticsLabel('Магазин'));
      await buy('Титан');
      await buy('Титан');
      await buy('Топливо');
      for (var i = 0; i < 2; i++) {
        await t.binding.handlePopRoute();
        await settle();
      }
      await tap(find.bySemanticsLabel(RegExp('^Стадия 2')));
      await tap(find.text('Перейти на стадию 3'));
      await tap(find.text('Подтвердить переход'));
      await wait(find.bySemanticsLabel(RegExp('^Стадия 3')));
      await capture('29-stage3-home');
      await tap(find.bySemanticsLabel('Обучение'));
      for (final title in ['Секретный звонок', 'Поздравляем, ты выиграл!']) {
        await tap(find.text(title));
        await wait(find.byType(FinancialSafetyScreen));
        final c = t
            .widget<FinancialSafetyScreen>(find.byType(FinancialSafetyScreen))
            .controller;
        while (!c.completed) {
          final p = c.progress;
          if (p.node.view == SafetyView.question && !p.feedback) {
            await tap(
              find.text(p.node.answers.firstWhere((a) => a.correct).text),
            );
            await tap(find.text('Проверить'));
          } else if (p.node.view == SafetyView.clues && p.clues.length < 3) {
            for (final id in ['sender', 'prize', 'link']) {
              await tap(
                find.bySemanticsLabel(
                  'Проверить: ${FinancialSafetyLesson.clueLabels[id]}',
                ),
              );
            }
          } else {
            await tap(find.text(p.node.actions.first.label));
          }
          expect(c.error, isNull);
        }
        await capture(
          c.lesson.taskId == FinancialSafetyLesson.callId
              ? '30-call-finished'
              : '31-email-finished',
        );
        await tap(find.text(c.lesson.exitLabel));
      }
      await capture('32-topic-reward');
      await tap(find.text('К Страннику'));
      await capture('33-detective');
      await tap(find.text('Продолжить приключение'));
      await tap(find.text('Узнать больше'));
      await capture('34-guide');
      await tap(find.text('Вернуться к теме'));
      await tap(find.bySemanticsLabel('Вернуться домой'));
      await capture('35-stage3-home-complete');
      final snapshot = (await db.run(
        (r) async => (
          stage: (await r.pets.pet())!.currentStage,
          balance: (await r.economy.wallet()).firaAmount,
          xp: (await r.pets.pet())!.xp,
        ),
      )) as Success;
      expect(snapshot.value.stage, Stage.homePlanet);
      final topic = await db.run(
        (r) => r.learning.topicProgress(FinancialSafetyLesson.topicId),
      );
      expect((topic as Success).value.finaleStep, 2);
      await t.pumpWidget(const SizedBox());
      home.dispose();
      store.dispose();
      await db.close();
      db = await LocalDatabase.open(path);
      game = GameServices(unitOfWork: db, content: content);
      home = HomeController(
        unitOfWork: db,
        allowDevelopmentPreview: false,
        content: content,
        interactions: game.pet,
      );
      store = StoreController(game);
      await show();
      await wait(find.bySemanticsLabel(RegExp('^Стадия 3')));
      await capture('36-stage3-restored');
      final restored = (await db.run(
        (r) async => (
          balance: (await r.economy.wallet()).firaAmount,
          xp: (await r.pets.pet())!.xp,
        ),
      )) as Success;
      expect(restored.value.balance, snapshot.value.balance);
      expect(restored.value.xp, snapshot.value.xp);
      await t.pumpWidget(const SizedBox());
      home.dispose();
      store.dispose();
      onboarding.dispose();
      await db.close();
      await deleteDatabase(path);
      expect(t.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
