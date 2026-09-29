import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/app/onboarding/onboarding_flow_service.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/onboarding/onboarding_controller.dart';

import '../support/harness.dart';

void toStep(OnboardingController c, OnboardingStep target) {
  while (c.step != target) {
    final before = c.step;
    c.next();
    expect(c.step, isNot(before), reason: 'Cannot advance from $before');
  }
}

void main() {
  late Harness h;
  late OnboardingController c;
  setUp(() async {
    h = await Harness.create();
    c = OnboardingController(h.game);
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await h.db.close();
  });

  test('new installation opens onboarding, rejects empty names, keeps reversible draft', () async {
    expect(c.completed, false);
    toStep(c, OnboardingStep.childName);
    c.setChildName('  ');
    c.next();
    expect(c.step, OnboardingStep.childName);
    c.setChildName('  Алиса  ');
    toStep(c, OnboardingStep.skin);
    c.changeSkin(2);
    expect(c.skinId, 'cream');
    c.next();
    c.setPetName(' ');
    c.next();
    expect(c.step, OnboardingStep.petName);
    c.back();
    expect(c.step, OnboardingStep.skin);
    expect(c.skinId, 'cream');
    expect(c.childName, 'Алиса');
    expect(await h.read((r) => r.profiles.profile()), isNull);
    expect(await h.balance(), 0);
    expect(await h.read((r) => r.progress.currentPeriod()), isNull);
  });

  Future<void> prepare() async {
    c.setChildName('  Алиса  ');
    c.setPetName('  Лучик  ');
    toStep(c, OnboardingStep.skin);
    c.changeSkin(2);
    toStep(c, OnboardingStep.permission);
  }

  test('declining consent creates no progress; PIN uses existing hash infrastructure', () async {
    await prepare();
    c.decline();
    expect(c.parentConsent, false);
    await c.submitPin('1234');
    expect((await h.read((r) => r.parents.parentSettings())).hasPin, false);
    expect(await h.balance(), 0);
    c.explainAgain();
    toStep(c, OnboardingStep.permission);
    c.consent();
    await c.submitPin('12');
    expect(c.step, OnboardingStep.pin);
    await c.submitPin('1234');
    expect(c.step, OnboardingStep.parentReady);
    final settings = await h.read((r) => r.parents.parentSettings());
    expect(settings.credential!.hash, isNot('1234'));
    expect(settings.credential!.salt, isNotEmpty);
    success(await h.game.parentAccess.verifyPin('1234'));
    expect(await h.balance(), 0);
    expect(await h.read((r) => r.progress.currentPeriod()), isNull);
    c.back();
    expect(c.step, OnboardingStep.parentReady);
  });

  test('completion creates selected profile/pet, one period and exactly one grant across restart', () async {
    await prepare();
    c.consent();
    await c.submitPin('1234');
    c.next();
    await Future.wait([c.finish(), c.finish()]);
    expect(c.completed, true);
    final profile = (await h.read((r) => r.profiles.profile()))!;
    final pet = (await h.read((r) => r.pets.pet()))!;
    expect(profile.nickname, 'Алиса');
    expect(profile.onboardingCompleted, true);
    expect(pet.childGivenName, 'Лучик');
    expect(pet.skinId, 'cream');
    expect(pet.currentStage, Stage.earth);
    expect(pet.xp, 0);
    expect(await h.balance(), 100);
    expect(await h.read((r) => r.economy.budget()), isNull);
    expect((await h.read((r) => r.progress.periods())).length, 1);
    expect(
      (await h.read((r) => r.economy.transactions())).single.type,
      TransactionType.initialGrant,
    );
    final reopened = OnboardingController(h.game);
    await reopened.load();
    expect(reopened.completed, true);
    await reopened.finish();
    expect(await h.balance(), 100);
    reopened.dispose();
  });

  test('restart after PIN requires existing PIN; does not overwrite it or dead-end', () async {
    await prepare();
    c.consent();
    await c.submitPin('1234');
    c.dispose();
    c = OnboardingController(h.game);
    await c.load();
    expect(c.existingPin, true);
    await prepare();
    c.consent();
    await c.submitPin('9999');
    expect(c.step, OnboardingStep.pin);
    await c.submitPin('1234');
    c.next();
    await c.finish();
    expect(c.completed, true);
    expect(await h.balance(), 100);
  });

  test(
    'failed finalization rolls back profile, pet, period and grant together',
    () async {
      final flow = OnboardingFlowService(h.game);
      success(await flow.acceptPin('1234'));
      await h.db.database.execute(
        "CREATE TRIGGER fail_grant BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      rejected(
        await flow.complete(
          childName: 'Алиса',
          petName: 'Кот',
          skinId: 'gray',
          parentConsent: true,
        ),
        Failure.persistenceFailure,
      );
      expect(await h.read((r) => r.profiles.profile()), isNull);
      expect(await h.read((r) => r.pets.pet()), isNull);
      expect(await h.read((r) => r.progress.currentPeriod()), isNull);
      expect(await h.balance(), 0);
      await h.db.database.execute('DROP TRIGGER fail_grant');
      success(
        await flow.complete(
          childName: 'Алиса',
          petName: 'Кот',
          skinId: 'gray',
          parentConsent: true,
        ),
      );
      success(
        await flow.complete(
          childName: 'Другой',
          petName: 'Другой',
          skinId: 'cream',
          parentConsent: true,
        ),
      );
      expect(await h.balance(), 100);
      expect((await h.read((r) => r.pets.pet()))!.skinId, 'gray');
    },
  );
}
