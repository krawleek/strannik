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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'clean player completes Topic 1, satisfies canonical conditions through UI, enters space and restarts',
    (t) async {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final path =
          '${await getDatabasesPath()}/stage_flow_${DateTime.now().microsecondsSinceEpoch}.db';
      var db = await LocalDatabase.open(path);
      final content = LocalContentRepository.fromJson(
        await rootBundle.loadString('lib/content/seed/development.json'),
      );
      var game = GameServices(unitOfWork: db, content: content);
      void ok(Result<void> r) => expect(r, isA<Success<void>>());
      // Start at the normal post-onboarding boundary; no learning/economy/stage shortcuts.
      ok(
        await game.onboarding.saveDraft(
          nickname: 'Алиса',
          avatarId: 'girl',
          petName: 'Веня',
          alienName: 'Зор',
          skinId: 'orange',
        ),
      );
      ok(await game.parentAccess.setPin('1234'));
      ok(await game.onboarding.complete());
      var home = HomeController(
        unitOfWork: db,
        allowDevelopmentPreview: false,
        content: content,
        interactions: game.pet,
      );
      var store = StoreController(game);
      Future<void> settle() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await t.pumpAndSettle();
      }

      Future<void> wait(Finder f) async {
        for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
          await settle();
        }
        expect(f, findsWidgets);
      }

      Future<void> tap(Finder f) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await settle();
        await wait(f);
        await t.ensureVisible(f.first);
        await t.tap(f.first);
        await settle();
      }

      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextField, label);
        await wait(field);
        await t.ensureVisible(field);
        await t.enterText(field, value);
        await settle();
      }

      Future<void> capture(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await settle();
        debugPrint('STAGE_CAPTURE:$name');
        await Future<void>.delayed(const Duration(seconds: 3));
      }

      Future<void> show() async {
        await home.load();
        await store.load();
        await t.pumpWidget(StrannikApp(controller: home, store: store));
        await settle();
      }

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
        for (var i = 0; i < 12 && item.evaluate().isEmpty; i++) {
          await t.drag(list, const Offset(-180, 0));
          await settle();
        }
        await tap(item);
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
      final snapshot = await db.run(
        (r) async => (
          stage: (await r.pets.pet())!.currentStage,
          balance: (await r.economy.wallet()).firaAmount,
          done: (await r.learning.learningProgress('earth_theme1_goal'))
              .completed,
        ),
      );
      expect(snapshot, isA<Success>());
      expect((snapshot as Success).value.stage, Stage.space);
      expect((snapshot as Success).value.done, true);
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
      await wait(find.bySemanticsLabel(RegExp('^Стадия 2')));
      await capture('26-space-restart');
      await tap(find.bySemanticsLabel('Обучение'));
      await wait(find.text('Список покупок'));
      await capture('27-map-restart');
      await t.pumpWidget(const SizedBox());
      home.dispose();
      store.dispose();
      await db.close();
      await deleteDatabase(path);
      expect(t.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
