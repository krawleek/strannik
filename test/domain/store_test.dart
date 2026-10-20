import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/store_snapshot.dart';
import 'package:strannik/presentation/store/store_controller.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create();
    await h.start();
  });
  tearDown(() => h.db.close());
  test(
    'same consumable operation debits wallet and grants inventory exactly once',
    () async {
      final results = await Future.wait(
        List.generate(
          3,
          (_) => h.game.store.buyItem('treat', quantity: 2, operationId: 'one'),
        ),
      );
      expect(results.whereType<Success<void>>().length, 1);
      expect(await h.balance(), 90);
      expect(await h.quantity('item:treat'), 2);
      expect(await h.xp(), 0);
      expect(
        (await h.read((r) => r.economy.transactions()))
            .where((t) => t.operationKey == 'store:one')
            .length,
        1,
      );
      rejected(
        await h.game.store.buyItem('ball', operationId: 'one'),
        Failure.alreadyCompleted,
      );
      expect(await h.quantity('item:ball'), 0);
    },
  );
  test(
    'failed inventory write rolls back payment and transaction key',
    () async {
      await h.db.database.execute(
        "CREATE TRIGGER fail_inventory BEFORE INSERT ON inventory_entries BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      rejected(
        await h.game.store.buyItem('scarf', operationId: 'rollback'),
        Failure.persistenceFailure,
      );
      expect(await h.balance(), 100);
      expect(await h.quantity('item:scarf'), 0);
      expect(
        await h.read((r) => r.economy.hasTransactionKey('store:rollback')),
        false,
      );
      await h.db.database.execute('DROP TRIGGER fail_inventory');
      success(await h.game.store.buyItem('scarf', operationId: 'rollback'));
      expect(await h.balance(), 85);
    },
  );
  test(
    'budget selection classifies expense without inventing separate wallets',
    () async {
      success(
        await h.game.economy.allocateBudget(
          mandatory: 90,
          optional: 2,
          remainder: 8,
        ),
      );
      success(
        await h.game.store.buyItem(
          'scarf',
          operationId: 'plan',
          purpose: PurchasePurpose.want,
        ),
      );
      expect(await h.balance(), 85);
      final budget = (await h.read((r) => r.economy.budget()))!;
      expect(budget.optional, 2);
      expect(budget.mandatory, 90);
      expect(budget.remainder, 8);
      final transaction = (await h.read((r) => r.economy.transactions())).last;
      expect(transaction.description, 'План: Хочу');
      expect(transaction.category, 'accessory');
    },
  );
  test(
    'purchase cannot use goal savings when spendable wallet is insufficient',
    () async {
      await h.unlockSavings();
      success(await h.game.savings.createSavingsGoal('Цель', 135));
      success(await h.game.savings.depositToSavings(135));
      expect(await h.balance(), 5);
      rejected(
        await h.game.store.buyItem('scarf', operationId: 'goal'),
        Failure.insufficientFunds,
      );
      expect((await h.read((r) => r.economy.savings()))!.savedAmount, 135);
      expect(await h.quantity('item:scarf'), 0);
      expect(await h.balance(), 5);
    },
  );
  test(
    'preview cancellation and Store/Closet switching never persist equipment',
    () async {
      final controller = StoreController(h.game);
      await controller.load();
      controller.select('scarf');
      expect(controller.previewAccessory, 'scarf');
      expect((await h.read((r) => r.pets.pet()))!.equippedAccessoryId, isNull);
      expect(await h.quantity('item:scarf'), 0);
      expect(await h.balance(), 100);
      controller.showCloset(true);
      expect(controller.previewAccessory, isNull);
      expect(controller.visibleItems, isEmpty);
      controller.showCloset(false);
      expect(controller.selectedId, isNull);
      controller.dispose();
    },
  );
  test('controller busy guard prevents duplicate independent consumable submissions', () async {
    final c = StoreController(h.game);
    await c.load();
    final results = await Future.wait([
      c.buy(h.content.item('treat')!, 'a'),
      c.buy(h.content.item('treat')!, 'b'),
    ]);
    expect(results.where((r) => r).length, 1);
    expect(await h.balance(), 95);
    expect(await h.quantity('item:treat'), 1);
    c.dispose();
  });
  test(
    'Closet supports equipment toggling, depletion and toy XP rules',
    () async {
      final c = StoreController(h.game);
      await c.load();
      for (final id in ['scarf', 'treat', 'ball']) {
        expect(await c.buy(h.content.item(id)!, 'buy-$id'), true);
      }
      expect(await h.xp(), 0);
      c.showCloset(true);
      expect(await c.use(h.content.item('scarf')!), true);
      expect((await h.read((r) => r.pets.pet()))!.equippedAccessoryId, 'scarf');
      expect(await c.use(h.content.item('scarf')!), true);
      expect((await h.read((r) => r.pets.pet()))!.equippedAccessoryId, isNull);
      c.select('treat');
      expect(await c.use(h.content.item('treat')!), true);
      expect(await h.quantity('item:treat'), 0);
      expect(c.selectedId, isNull);
      expect(await h.xp(), 5);
      expect(await c.use(h.content.item('treat')!), false);
      expect(await h.xp(), 5);
      expect(await c.use(h.content.item('ball')!), true);
      expect(await h.xp(), 15);
      expect(await c.use(h.content.item('ball')!), true);
      expect(await h.xp(), 15);
      expect((await h.read((r) => r.pets.pet()))!.activeToyId, 'ball');
      c.dispose();
    },
  );
  test('ownership and equipped appearance survive database restart', () async {
    final dir = await Directory.systemTemp.createTemp('store-test');
    final path = '${dir.path}/store.db';
    final first = await Harness.create(path: path);
    await first.start();
    success(await first.game.store.buyItem('scarf', operationId: 'persist'));
    success(await first.game.pet.equipAccessory('scarf'));
    await first.db.close();
    final reopened = await Harness.create(path: path);
    final state = success(await reopened.game.store.snapshot());
    expect(state.wallet.firaAmount, 85);
    expect(state.pet!.equippedAccessoryId, 'scarf');
    expect(state.quantity(reopened.content.item('scarf')!), 1);
    rejected(
      await reopened.game.store.buyItem('scarf', operationId: 'another'),
      Failure.alreadyOwned,
    );
    await reopened.db.close();
    await dir.delete(recursive: true);
  });
  test(
    'unavailable and XP-locked catalog items cannot be purchased or previewed',
    () async {
      final json = jsonDecode(
        File('lib/content/seed/development.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final items = json['items'] as List;
      items.first['requiredXp'] = 100;
      final dir = await Directory.systemTemp.createTemp('store-locked');
      final locked = await Harness.create(
        path: '${dir.path}/locked.db',
        contentSource: jsonEncode(json),
      );
      await locked.start();
      final c = StoreController(locked.game);
      await c.load();
      c.select('scarf');
      expect(c.locked(c.selected!), true);
      expect(c.previewAccessory, isNull);
      rejected(
        await locked.game.store.buyItem('scarf', operationId: 'locked'),
        Failure.locked,
      );
      expect(await locked.balance(), 30);
      c.dispose();
      await locked.db.close();
      await dir.delete(recursive: true);
    },
  );
}
