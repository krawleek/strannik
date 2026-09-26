import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';

import '../support/harness.dart';

void main() {
  late Directory directory;
  late Harness h;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('strannik-test-');
    path = '${directory.path}/game.db';
    h = await Harness.create(path: path);
    await h.start();
  });
  tearDown(() async {
    await h.db.close();
    await directory.delete(recursive: true);
  });

  test('all state survives closing and reopening SQLite', () async {
    await h.unlockSavings();
    success(await h.game.savings.createSavingsGoal('Цель', 100));
    success(await h.game.savings.depositToSavings(30));
    success(await h.game.economy.giveParentReward('1234', 20));
    success(
      await h.game.economy.allocateBudget(
        mandatory: 80,
        optional: 10,
        remainder: 0,
      ),
    );
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
    success(await h.game.store.buyItem('scarf'));
    success(await h.game.pet.equipAccessory('scarf'));
    success(await h.game.store.buyItem('treat', quantity: 2));
    success(await h.game.store.buyItem('titanium', quantity: 3));
    success(await h.game.progression.selectBigGoal(BigGoalType.repairShip));
    success(await h.game.progression.confirmBigGoal());
    success(await h.game.demo.setEnabled('1234', true));
    success(await h.game.demo.changeDemoStage('1234', Stage.space));
    await h.read((r) => r.system.markTooltipShown('wallet'));
    final open = success(await h.game.learning.beginTask('practice'));
    rejected(await h.game.parentAccess.verifyPin('0000'), Failure.invalidPin);
    final balance = await h.balance();
    final historyLength = (await h.read((r) => r.economy.transactions()))
        .length;
    await h.db.close();
    h = await Harness.create(path: path);
    expect(await h.balance(), balance);
    expect(await h.xp(), 10);
    final pet = (await h.read((r) => r.pets.pet()))!;
    expect(pet.childGivenName, 'Кот');
    expect(pet.skinId, 'blue');
    expect(pet.activeToyId, 'ball');
    expect(pet.equippedAccessoryId, 'scarf');
    expect(
      (await h.read((r) => r.profiles.profile()))!.onboardingCompleted,
      true,
    );
    expect((await h.read((r) => r.parents.parentSettings())).failedAttempts, 1);
    expect((await h.read((r) => r.economy.budget()))!.mandatory, 80);
    expect((await h.read((r) => r.economy.savings()))!.savedAmount, 30);
    expect(await h.quantity('resource:titanium'), 3);
    expect(await h.quantity('item:treat'), 2);
    expect((await h.read((r) => r.progress.bigGoal()))!.isConfirmed, true);
    expect(
      (await h.read((r) => r.learning.learningProgress('theme2_task')))
          .completed,
      true,
    );
    expect(
      (await h.read((r) => r.learning.openAttempt('practice')))!.id,
      open.id,
    );
    expect((await h.read((r) => r.progress.periods())).length, 3);
    expect(
      (await h.read((r) => r.economy.transactions())).length,
      historyLength,
    );
    expect((await h.read((r) => r.system.appState())).demoStage, Stage.space);
    expect(await h.read((r) => r.system.shownTooltips()), contains('wallet'));
    rejected(await h.game.onboarding.complete(), Failure.alreadyCompleted);
    expect(success(await h.game.pet.playWithToy('ball')), 0);
    success(await h.game.parentAccess.verifyPin('1234'));
  });
  test(
    'purchase rolls back balance and history if inventory write fails',
    () async {
      await h.db.database.execute(
        "CREATE TRIGGER fail_inventory BEFORE INSERT ON inventory_entries BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      rejected(await h.game.store.buyItem('scarf'), Failure.persistenceFailure);
      expect(await h.balance(), 100);
      expect(await h.quantity('item:scarf'), 0);
      expect((await h.read((r) => r.economy.transactions())).length, 1);
    },
  );
  test(
    'final reward, completion, summary and new period all roll back on failure',
    () async {
      final attempt = success(await h.game.learning.beginTask('theme1_task'));
      await h.db.database.execute(
        "CREATE TRIGGER fail_summary BEFORE INSERT ON period_summaries BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      rejected(
        await h.game.learning.completeLearningTask(
          attempt.id,
          successful: true,
        ),
        Failure.persistenceFailure,
      );
      expect(await h.balance(), 100);
      expect(
        (await h.read((r) => r.learning.learningProgress('theme1_task')))
            .completed,
        false,
      );
      expect(
        (await h.read((r) => r.learning.attempt(attempt.id)))!.completedAt,
        isNull,
      );
      expect((await h.read((r) => r.progress.periods())).length, 1);
      await h.db.database.execute('DROP TRIGGER fail_summary');
      success(
        await h.game.learning.completeLearningTask(
          attempt.id,
          successful: true,
        ),
      );
      expect(await h.balance(), 120);
      expect((await h.read((r) => r.progress.periods())).length, 2);
    },
  );
  test('lockout is persistent across restart', () async {
    for (var i = 0; i < 5; i++) {
      await h.game.parentAccess.verifyPin('0000');
    }
    await h.db.close();
    h = await Harness.create(path: path);
    rejected(await h.game.parentAccess.verifyPin('1234'), Failure.pinLocked);
    h.clock.advance(const Duration(seconds: 30));
    success(await h.game.parentAccess.verifyPin('1234'));
  });
  test(
    'schema version, foreign keys, constraints and unique grant are enforced',
    () async {
      expect(await h.db.database.getVersion(), LocalDatabase.schemaVersion);
      expect(
        (await h.db.database.rawQuery('PRAGMA foreign_keys'))
            .first
            .values
            .single,
        1,
      );
      await expectLater(
        h.db.database.rawUpdate('UPDATE wallet SET amount=-1'),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        h.db.database.rawInsert(
          "INSERT INTO inventory_entries VALUES ('bad','shipMaterial',-1)",
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        h.db.database.rawInsert(
          "INSERT INTO inventory_entries VALUES ('bad','toy',2)",
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        h.db.database.execute(
          "INSERT INTO transactions(id,amount,type,source,created_at,period_id) SELECT 'duplicate',amount,type,source,created_at,period_id FROM transactions WHERE type='initialGrant'",
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await h.db.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test(
    'reopening the migrated database does not recreate or erase it',
    () async {
      success(await h.game.economy.giveParentReward('1234', 7));
      await h.db.close();
      h = await Harness.create(path: path);
      expect(await h.balance(), 107);
      expect(await h.db.database.getVersion(), LocalDatabase.schemaVersion);
      expect(
        (await h.db.database.rawQuery('PRAGMA integrity_check'))
            .first
            .values
            .single,
        'ok',
      );
    },
  );
}
