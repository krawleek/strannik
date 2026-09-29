import '../../core/result.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/game_context.dart';
import '../../domain/services/onboarding_service.dart';
import '../bootstrap.dart';

/// Coordinates existing domain operations; widgets never write repositories.
class OnboardingFlowService {
  OnboardingFlowService(this.game);
  final GameServices game;
  bool _parentVerified = false;

  Future<Result<bool>> hasPin() =>
      game.context.run((r) async => (await r.parents.parentSettings()).hasPin);

  Future<Result<void>> acceptPin(String pin) async {
    final existing = await hasPin();
    if (existing case Rejected(reason: final reason)) return Rejected(reason);
    final result = (existing as Success<bool>).value
        ? await game.parentAccess.verifyPin(pin)
        : await game.parentAccess.setPin(pin);
    _parentVerified = result is Success<void>;
    return result;
  }

  Future<Result<void>> complete({
    required String childName,
    required String petName,
    required String skinId,
    required bool parentConsent,
  }) => game.context.run((r) async {
    // Retried completion is harmless and never overwrites completed selections.
    if ((await r.profiles.profile())?.onboardingCompleted == true) return;
    require(parentConsent && _parentVerified, Failure.unauthorized);
    require((await r.parents.parentSettings()).hasPin, Failure.unauthorized);
    final context = game.context;
    final onboarding = OnboardingService(
      GameContext(
        unitOfWork: _TransactionScope(r),
        content: context.content,
        clock: context.clock,
        ids: context.ids,
      ),
    );
    await onboarding.saveDraft(
      nickname: childName.trim(),
      avatarId: 'girl',
      petName: petName.trim(),
      alienName: 'XÆLiQЫ',
      skinId: skinId,
    );
    await onboarding.complete();
  });
}

/// Nested service calls share the outer transaction. Rejections propagate to its
/// rollback boundary; this adapter never catches failures or starts another SQL tx.
class _TransactionScope implements UnitOfWork {
  _TransactionScope(this.repositories);
  final Repositories repositories;
  @override
  Future<Result<T>> run<T>(Future<T> Function(Repositories) operation) async =>
      Success(await operation(repositories));
}
