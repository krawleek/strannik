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
  test('PIN hash salted, fifth failed attempt locks 30 seconds', () async {
    final settings = await h.read((r) => r.parents.parentSettings());
    expect(settings.credential!.hash, isNot('1234'));
    expect(settings.credential!.salt, isNotEmpty);
    for (var i = 0; i < 4; i++) {
      rejected(await h.game.parentAccess.verifyPin('0000'), Failure.invalidPin);
    }
    rejected(await h.game.parentAccess.verifyPin('0000'), Failure.pinLocked);
    rejected(await h.game.parentAccess.verifyPin('1234'), Failure.pinLocked);
    h.clock.advance(const Duration(seconds: 29));
    rejected(await h.game.parentAccess.verifyPin('1234'), Failure.pinLocked);
    h.clock.advance(const Duration(seconds: 1));
    success(await h.game.parentAccess.verifyPin('1234'));
    expect((await h.read((r) => r.parents.parentSettings())).failedAttempts, 0);
    success(await h.game.parentAccess.changePin('1234', '4321'));
    expect(
      (await h.read((r) => r.parents.parentSettings())).credential!.salt,
      isNot(settings.credential!.salt),
    );
    rejected(await h.game.parentAccess.verifyPin('1234'), Failure.invalidPin);
    success(await h.game.parentAccess.verifyPin('4321'));
  });
  test(
    'demo overrides stage without consuming normal resources or XP',
    () async {
      rejected(
        await h.game.demo.changeDemoStage('1234', Stage.homePlanet),
        Failure.locked,
      );
      success(await h.game.store.buyItem('titanium'));
      success(await h.game.demo.setEnabled('1234', true));
      success(await h.game.demo.changeDemoStage('1234', Stage.homePlanet));
      final pet = (await h.read((r) => r.pets.pet()))!;
      expect(pet.currentStage, Stage.earth);
      expect(await h.xp(), 0);
      expect(await h.quantity('resource:titanium'), 1);
      expect(
        (await h.read((r) => r.system.appState())).effectiveStage(pet),
        Stage.homePlanet,
      );
      success(await h.game.savings.createSavingsGoal('Цель', 50));
      success(await h.game.savings.depositToSavings(20));
      rejected(
        await h.game.store.buyItem('treat', quantity: 100),
        Failure.insufficientFunds,
      );
      expect(
        success(await h.game.learning.availableTasks()).length,
        h.content.tasks.length,
      );
      await h.complete('fraud_task');
      rejected(
        await h.game.learning.beginTask('fraud_task'),
        Failure.alreadyCompleted,
      );
      success(await h.game.demo.setEnabled('1234', false));
      expect(
        (await h.read((r) => r.system.appState())).effectiveStage(pet),
        Stage.earth,
      );
      success(await h.game.savings.withdrawFromSavings(20));
    },
  );
  test(
    'reset preserves PIN and profile, resets onboarding and all gameplay',
    () async {
      success(await h.game.economy.giveParentReward('1234', 20));
      success(await h.game.store.buyItem('ball'));
      await h.complete('theme1_task');
      success(await h.game.demo.setEnabled('1234', true));
      success(await h.game.localData.resetDemoProgress('1234'));
      expect(await h.balance(), 0);
      expect(await h.read((r) => r.pets.pet()), isNull);
      expect(await h.read((r) => r.items.inventory()), isEmpty);
      expect(await h.read((r) => r.economy.transactions()), isEmpty);
      expect(await h.read((r) => r.progress.periods()), isEmpty);
      expect((await h.read((r) => r.profiles.profile()))!.nickname, 'Путник');
      expect(
        (await h.read((r) => r.profiles.profile()))!.onboardingCompleted,
        false,
      );
      expect((await h.read((r) => r.system.appState())).demoMode, false);
      success(await h.game.parentAccess.verifyPin('1234'));
      success(
        await h.game.onboarding.saveDraft(
          nickname: 'Путник',
          avatarId: 'cat',
          petName: 'Новый',
          alienName: 'Зор',
          skinId: 'green',
        ),
      );
      success(await h.game.onboarding.complete());
      expect(await h.balance(), 100);
    },
  );
  test('delete requires PIN and clears profile, PIN and gameplay', () async {
    rejected(await h.game.localData.deleteAllData('0000'), Failure.invalidPin);
    expect(await h.balance(), 100);
    success(await h.game.localData.deleteAllData('1234'));
    expect(await h.read((r) => r.profiles.profile()), isNull);
    expect((await h.read((r) => r.parents.parentSettings())).hasPin, false);
    expect(await h.balance(), 0);
    success(await h.game.parentAccess.setPin('4321'));
  });
}
