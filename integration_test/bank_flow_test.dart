import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/bank/bank_screen.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/store/store_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Bank plan, reallocation, Store and SQLite restart on Android', (
    t,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final filename =
        '${await getDatabasesPath()}/bank_qa_${DateTime.now().microsecondsSinceEpoch}.db';
    var db = await LocalDatabase.open(filename);
    final content = LocalContentRepository.fromJson(
      await rootBundle.loadString('lib/content/seed/development.json'),
    );
    var game = GameServices(unitOfWork: db, content: content);
    void ok(Result<void> r) => expect(r, isA<Success<void>>());
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
    ok(await game.economy.giveParentReward('1234', 100));
    var home = HomeController(
      unitOfWork: db,
      allowDevelopmentPreview: false,
      content: content,
      interactions: game.pet,
    );
    var store = StoreController(game);
    Future<void> show() async {
      await home.load();
      await store.load();
      await t.pumpWidget(StrannikApp(controller: home, store: store));
      await t.pumpAndSettle();
    }

    Future<void> waitFor(Finder f) async {
      for (var i = 0; i < 150 && f.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await t.pump();
      }
      expect(f, findsWidgets);
      await t.pumpAndSettle();
    }

    Future<void> tap(Finder f) async {
      await t.ensureVisible(f);
      await t.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await t.pumpAndSettle();
      debugPrint('BANK_CAPTURE:$name');
      // Host adb captures the real surface; avoids Android screenshot API stalls.
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    Future<void> enter(String label, String text) async {
      final f = find.byKey(ValueKey('amount-$label'));
      await t.ensureVisible(f);
      await t.enterText(f, text);
      await t.pumpAndSettle();
    }

    await show();
    await tap(find.bySemanticsLabel('Банк'));
    await waitFor(find.textContaining('У нас есть фиры!'));
    await capture('00-explanation');
    await tap(find.byTooltip('Закрыть подсказку'));
    await waitFor(find.text('Распределить 200 фир'));
    await capture('01-initial-bank');
    await tap(find.text('Распределить 200 фир'));
    for (final name in ['Нужно', 'Хочу', 'Коплю']) {
      await enter(name, '50');
    }
    await capture('02-allocation-editor');
    await enter('Нужно', '-1');
    await capture('03-invalid-amount');
    await enter('Нужно', '50');
    await tap(find.text('Сохранить'));
    await waitFor(find.text('Готово! Фиры распределены'));
    await capture('04-success');
    await tap(find.text('Отлично'));
    await capture('05-allocated-bank');
    await tap(find.bySemanticsLabel('Нужно: 50 фир. Изменить план'));
    await tap(find.bySemanticsLabel('Хочу: 50 фир. Выбрать источник'));
    await enter('Сумма перераспределения', '20');
    await capture('06-reallocation-editor');
    await tap(find.text('Сохранить'));
    await waitFor(find.text('Готово! Фиры распределены'));
    await tap(find.text('Отлично'));
    var state = await db.run(
      (r) async => (
        (await r.economy.wallet()).firaAmount,
        await r.economy.budget(),
        await r.economy.transactions(),
      ),
    );
    expect(state, isA<Success>());
    final saved = (state as Success).value;
    expect(saved.$1, 200);
    expect(
      (saved.$2!.mandatory, saved.$2!.optional, saved.$2!.remainder),
      (70, 30, 50),
    );
    expect(saved.$3, hasLength(2));
    await tap(find.text('В магазин'));
    await waitFor(find.bySemanticsLabel(RegExp(r'^Шарфик\.')));
    await tap(find.bySemanticsLabel(RegExp(r'^Шарфик\.')));
    await tap(find.bySemanticsLabel('Корзина'));
    await tap(find.text('Купить'));
    await tap(find.text('Оплатить 15 фир'));
    await waitFor(find.text('Ура! Покупка твоя!'));
    await tap(find.text('Назад в магазин'));
    await tap(find.bySemanticsLabel('Назад'));
    await waitFor(find.byType(BankScreen));
    await waitFor(find.text('Распределить 35 фир'));
    await capture('07-after-store');
    // Existing Store UI offers one selected item; service fixture adds a larger
    // purchase solely to exercise a stale plan, never writing wallet directly.
    ok(
      await game.store.buyItem(
        'treat',
        quantity: 11,
        operationId: 'bank-mismatch',
      ),
    );
    await tap(find.byKey(const ValueKey('bank-back')));
    await tap(find.bySemanticsLabel('Банк'));
    await waitFor(find.text('Исправить план'));
    await capture('08-plan-exceeds-wallet');
    await t.pumpWidget(const SizedBox());
    home.dispose();
    store.dispose();
    await db.close();
    db = await LocalDatabase.open(filename);
    game = GameServices(unitOfWork: db, content: content);
    home = HomeController(
      unitOfWork: db,
      allowDevelopmentPreview: false,
      content: content,
      interactions: game.pet,
    );
    store = StoreController(game);
    await show();
    await tap(find.bySemanticsLabel('Банк'));
    await waitFor(find.text('Исправить план'));
    expect(find.textContaining('У нас есть фиры!'), findsNothing);
    state = await db.run(
      (r) async => (
        (await r.economy.wallet()).firaAmount,
        await r.economy.budget(),
        await r.economy.transactions(),
      ),
    );
    final reopened = (state as Success).value;
    expect(reopened.$1, 130);
    expect(
      (reopened.$2!.mandatory, reopened.$2!.optional, reopened.$2!.remainder),
      (70, 30, 50),
    );
    expect(reopened.$3, hasLength(4));
    await capture('09-restarted-bank');
    await tap(find.text('Вся история'));
    await capture('10-history');
    expect(find.text('Шарфик'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    home.dispose();
    store.dispose();
    await db.close();
    await deleteDatabase(filename);
  });
}
