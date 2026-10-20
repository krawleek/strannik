import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show getDatabasesPath, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/learning/shopping_list_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('shopping list full Android journey and one-time rewards', (
    tester,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final filename = path.join(
      await getDatabasesPath(),
      'shopping_list_qa_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    var db = await LocalDatabase.open(filename);
    final catalog = LocalContentRepository.fromJson(
      await rootBundle.loadString('lib/content/seed/development.json'),
    );
    var game = GameServices(unitOfWork: db, content: catalog);
    void ok(Result<void> result) => expect(result, isA<Success<void>>());
    ok(
      await game.onboarding.saveDraft(
        nickname: 'Марина',
        avatarId: 'girl',
        petName: 'Веня',
        alienName: 'Зор',
        skinId: 'gray',
      ),
    );
    ok(await game.parentAccess.setPin('1234'));
    ok(await game.onboarding.complete());
    var home = HomeController(
      unitOfWork: db,
      allowDevelopmentPreview: false,
      content: catalog,
      interactions: game.pet,
    );
    await home.load();
    await tester.pumpWidget(StrannikApp(controller: home));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(String text) async {
      final target = find.text(text);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.bySemanticsLabel('Обучение').last);
    await tester.pumpAndSettle();
    expect(find.text('Этап 1'), findsOneWidget);
    expect(find.text('Список покупок'), findsNothing);
    await capture('00-stage1-map');
    await tester.tap(find.bySemanticsLabel('Вернуться домой'));
    await tester.pumpAndSettle();
    ok(await game.progression.selectBigGoal(BigGoalType.repairShip));
    ok(await game.progression.confirmBigGoal());
    ok(await game.store.buyItem('titanium', quantity: 2));
    ok(await game.store.buyItem('fuel'));
    ok(await game.store.buyItem('ball'));
    ok(await game.pet.activateToy('ball'));
    expect(await game.pet.playWithToy('ball'), isA<Success<int>>());
    ok(await game.progression.advanceStage());
    final baseline = await db.run(
      (r) async =>
          ((await r.economy.wallet()).firaAmount, (await r.pets.pet())!.xp),
    );
    final before = (baseline as Success).value;
    final beforeInventory = (await db.run(
      (r) async => (await r.items.inventory())
          .map((i) => '${i.id}:${i.quantity}')
          .toList(),
    )) as Success;
    await home.load();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Обучение').last);
    await tester.pumpAndSettle();
    expect(find.text('Этап 2'), findsOneWidget);
    await capture('01-stage2-map');
    await tap('Список покупок');
    await capture('02-story-intro');
    await tap('Даже не знаю, что сказать...');
    await tap('Давай!');
    await tap('Делаем киновечер!');
    await capture('03-educational-dialogue');
    await tap('Какой список?');
    await tap('Спросить');
    await tap('Далее');
    await tap('Далее');
    await tap('Далее');
    await tap('Давай!');
    await capture('04-empty-selection');
    await tap('Попкорн 300');
    await capture('05-valid-selection');
    await tap('Сок 100');
    await capture('06-over-budget');
    expect(find.text('Не хватает фир'), findsOneWidget);
    await tap('Сок 100');
    await tap('Оплатить 300 фир');
    await capture('07-success');
    await tap('Ура!');
    await capture('08-reward');
    final state = await db.run(
      (r) async => (
        (await r.economy.wallet()).firaAmount,
        (await r.pets.pet())!.xp,
        await r.items.inventory(),
      ),
    );
    expect(state, isA<Success>());
    final result = (state as Success).value;
    expect(result.$1, before.$1 + 250);
    expect(result.$2, before.$2 + 15);
    expect(
      result.$3.map((i) => '${i.id}:${i.quantity}').toList(),
      beforeInventory.value,
    );
    await tap('За попкорном!');
    expect(find.text('Выполнено ✓\nПройти ещё раз'), findsOneWidget);
    await capture('09-completed-map');
    await tester.pumpWidget(const SizedBox());
    home.dispose();
    await db.close();
    db = await LocalDatabase.open(filename);
    game = GameServices(unitOfWork: db, content: catalog);
    home = HomeController(
      unitOfWork: db,
      allowDevelopmentPreview: false,
      content: catalog,
      interactions: game.pet,
    );
    await home.load();
    await tester.pumpWidget(StrannikApp(controller: home));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Обучение').last);
    await tester.pumpAndSettle();
    expect(find.text('Этап 2'), findsOneWidget);
    expect(find.text('Выполнено ✓\nПройти ещё раз'), findsOneWidget);
    await capture('10-stage2-restarted');
    await tap('Список покупок');
    final c = tester
        .widget<ShoppingListScreen>(find.byType(ShoppingListScreen))
        .controller;
    while (c.step != 11) {
      await c.advance();
    }
    await c.toggle('juice');
    await c.confirm();
    await c.finish();
    await tester.pumpAndSettle();
    expect(c.rewardClaimed, true);
    await capture('11-replay-reward');
    final balance = await db.run(
      (r) async => (await r.economy.wallet()).firaAmount,
    );
    expect((balance as Success).value, before.$1 + 250);
    await tester.pumpWidget(const SizedBox());
    home.dispose();
    await db.close();
    await deleteDatabase(filename);
  });
}
