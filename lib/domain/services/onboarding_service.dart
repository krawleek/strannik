import '../../core/result.dart';
import '../models/models.dart';
import 'game_context.dart';

class OnboardingService {
  OnboardingService(this.game);
  final GameContext game;
  Future<Result<void>> saveDraft({
    required String nickname,
    required String avatarId,
    required String petName,
    required String alienName,
    required String skinId,
  }) => game.run((r) async {
    require(
      [
        nickname,
        avatarId,
        petName,
        alienName,
        skinId,
      ].every((s) => s.trim().isNotEmpty),
      Failure.invalidState,
    );
    final old = await r.profiles.profile();
    require(old?.onboardingCompleted != true, Failure.immutableSelection);
    final pet = await r.pets.pet();
    await r.profiles.saveProfile(
      ChildProfile(
        id: old?.id ?? game.ids.next(),
        nickname: nickname,
        avatarId: avatarId,
        onboardingCompleted: false,
        createdAt: old?.createdAt ?? game.clock.now(),
      ),
    );
    await r.pets.savePet(
      Pet(
        id: pet?.id ?? game.ids.next(),
        childGivenName: petName,
        alienName: alienName,
        skinId: skinId,
      ),
    );
  });
  Future<Result<void>> complete() => game.run((r) async {
    final profile = await r.profiles.profile();
    await game.pet(r);
    require(profile != null, Failure.invalidState);
    require(
      !profile!.onboardingCompleted &&
          !await r.economy.hasTransactionKey('initialGrant'),
      Failure.alreadyCompleted,
    );
    final now = game.clock.now();
    await r.progress.savePeriod(
      GamePeriod(
        id: game.ids.next(),
        kind: PeriodKind.firstMoney,
        startedAt: now,
      ),
    );
    await game.money(
      r,
      amount: 100,
      type: TransactionType.initialGrant,
      source: TransactionSource.onboarding,
      key: 'initialGrant',
    );
    await r.profiles.saveProfile(profile.copyWith(onboardingCompleted: true));
  });
  Future<Result<void>> changeNickname(String nickname) => game.run((r) async {
    require(nickname.trim().isNotEmpty, Failure.invalidState);
    final profile = await r.profiles.profile();
    require(profile != null, Failure.invalidState);
    await r.profiles.saveProfile(profile!.copyWith(nickname: nickname));
  });
}
