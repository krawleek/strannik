import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create();
    await h.start();
  });
  tearDown(() => h.db.close());
  test(
    'treat purchase gives no XP, consuming gives XP exactly once per unit',
    () async {
      success(await h.game.store.buyItem('treat'));
      expect(await h.xp(), 0);
      success(await h.game.pet.useTreat('treat'));
      expect(await h.xp(), 5);
      expect(await h.quantity('item:treat'), 0);
      rejected(await h.game.pet.useTreat('treat'), Failure.notFound);
      expect(await h.xp(), 5);
    },
  );
  test('toy XP once per toy per period, purchase gives none', () async {
    success(await h.game.store.buyItem('ball'));
    expect(await h.xp(), 0);
    success(await h.game.pet.activateToy('ball'));
    expect(success(await h.game.pet.playWithToy('ball')), 10);
    expect(success(await h.game.pet.playWithToy('ball')), 0);
    success(await h.game.pet.activateToy(null));
    success(await h.game.pet.activateToy('ball'));
    expect(success(await h.game.pet.playWithToy('ball')), 0);
    await h.complete('theme1_task');
    expect(success(await h.game.pet.playWithToy('ball')), 10);
    expect(await h.xp(), 20);
  });
  test('equipment requires ownership and can be cleared', () async {
    rejected(await h.game.pet.equipAccessory('scarf'), Failure.notFound);
    success(await h.game.store.buyItem('scarf'));
    success(await h.game.pet.equipAccessory('scarf'));
    expect((await h.read((r) => r.pets.pet()))!.equippedAccessoryId, 'scarf');
    success(await h.game.pet.equipAccessory(null));
    expect((await h.read((r) => r.pets.pet()))!.equippedAccessoryId, isNull);
  });
  test('confirmed goal immutable; XP alone never advances stage', () async {
    success(await h.game.progression.selectBigGoal(BigGoalType.contactHome));
    success(await h.game.progression.selectBigGoal(BigGoalType.repairShip));
    success(await h.game.progression.confirmBigGoal());
    rejected(
      await h.game.progression.selectBigGoal(BigGoalType.adaptOnEarth),
      Failure.immutableSelection,
    );
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
    expect(success(await h.game.progression.checkStageRequirements()), false);
    rejected(
      await h.game.progression.advanceStage(),
      Failure.requirementsNotMet,
    );
    expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.earth);
  });
  test(
    'stage transition requires resources and XP, consumes resources atomically',
    () async {
      success(await h.game.progression.selectBigGoal(BigGoalType.repairShip));
      success(await h.game.progression.confirmBigGoal());
      success(await h.game.store.buyItem('titanium', quantity: 2));
      success(await h.game.store.buyItem('fuel'));
      rejected(
        await h.game.progression.advanceStage(),
        Failure.requirementsNotMet,
      );
      expect(await h.quantity('resource:titanium'), 2);
      success(await h.game.store.buyItem('ball'));
      success(await h.game.pet.activateToy('ball'));
      success(await h.game.pet.playWithToy('ball'));
      expect(success(await h.game.progression.checkStageRequirements()), true);
      success(await h.game.progression.advanceStage());
      expect(await h.quantity('resource:titanium'), 0);
      expect(await h.quantity('resource:fuel'), 0);
      expect(await h.xp(), 11);
      expect((await h.read((r) => r.pets.pet()))!.currentStage, Stage.space);
      rejected(
        await h.game.progression.advanceStage(),
        Failure.requirementsNotMet,
      );
      final period = (await h.read((r) => r.progress.currentPeriod()))!;
      final events = await h.read((r) => r.progress.events(period.id));
      expect(
        events.where((e) => e.type == ProgressEventType.stageChanged).length,
        1,
      );
      expect(
        events.where((e) => e.type == ProgressEventType.materialUsed).length,
        2,
      );
    },
  );
  test('period boundary includes final reward and persists summary', () async {
    final first = (await h.read((r) => r.progress.currentPeriod()))!;
    success(await h.game.store.buyItem('ball'));
    success(await h.game.pet.activateToy('ball'));
    success(await h.game.pet.playWithToy('ball'));
    success(await h.game.store.buyItem('titanium', quantity: 2));
    h.clock.advance(const Duration(minutes: 1));
    await h.complete('theme1_task');
    final summary = success(await h.game.periods.summary(first.id));
    expect(summary.receivedFira, 120);
    expect(summary.spentFira, 14);
    expect(summary.remainingFira, 106);
    expect(summary.xpEarned, 10);
    expect(summary.materialsGained['titanium'], 2);
    expect(summary.goalResources['titanium'], 2);
    final periods = await h.read((r) => r.progress.periods());
    expect(periods.length, 2);
    expect(periods.first.endedAt, h.clock.now());
    expect(periods.last.kind, PeriodKind.afterTheme1);
    await h.complete('practice');
    expect(success(await h.game.periods.summary(first.id)).remainingFira, 106);
  });
  test('five sequential periods and last remains current', () async {
    rejected(await h.game.learning.beginTask('theme2_task'), Failure.locked);
    for (final id in [
      'theme1_task',
      'theme2_task',
      'theme3_task',
      'fraud_task',
    ]) {
      await h.complete(id);
    }
    final periods = await h.read((r) => r.progress.periods());
    expect(periods.length, 5);
    expect(periods.last.kind, PeriodKind.afterFraudTheme);
    expect(periods.last.completed, false);
    await h.complete('practice');
    expect((await h.read((r) => r.progress.periods())).length, 5);
  });
  test(
    'pet identity immutable after onboarding but child nickname editable',
    () async {
      rejected(
        await h.game.onboarding.saveDraft(
          nickname: 'Друг',
          avatarId: 'cat',
          petName: 'Другой',
          alienName: 'Зор',
          skinId: 'red',
        ),
        Failure.immutableSelection,
      );
      success(await h.game.onboarding.changeNickname('Путешественник'));
      expect(
        (await h.read((r) => r.profiles.profile()))!.nickname,
        'Путешественник',
      );
      expect((await h.read((r) => r.pets.pet()))!.childGivenName, 'Кот');
    },
  );
}
