import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class ParentAccessService {
  ParentAccessService(this.game, this.hasher);
  final GameContext game;
  final PinHasher hasher;
  bool _validPin(String pin) => RegExp(r'^[0-9]{4}$').hasMatch(pin);
  Future<Result<void>> setPin(String pin) => game.run((r) async {
    require(_validPin(pin), Failure.invalidPin);
    require(!(await r.parents.parentSettings()).hasPin, Failure.invalidState);
    await r.parents.saveParentSettings(
      ParentSettings(credential: await hasher.hash(pin)),
    );
  });

  /// Failed checks are returned, not thrown: attempts and lockout must commit.
  Future<Result<T>> perform<T>(
    String pin,
    Future<T> Function(Repositories) action,
  ) async {
    final outer = await game.run<Result<T>>((r) async {
      final settings = await r.parents.parentSettings();
      if (!settings.hasPin) return const Rejected(Failure.unauthorized);
      final now = game.clock.now();
      if (settings.lockUntil != null && now.isBefore(settings.lockUntil!)) {
        return const Rejected(Failure.pinLocked);
      }
      final valid =
          _validPin(pin) && await hasher.verify(pin, settings.credential!);
      if (!valid) {
        final attempts =
            (settings.lockUntil == null ? settings.failedAttempts : 0) + 1;
        await r.parents.saveParentSettings(
          ParentSettings(
            credential: settings.credential,
            failedAttempts: attempts,
            lockUntil: attempts >= 5
                ? now.add(const Duration(seconds: 30))
                : null,
          ),
        );
        return Rejected(attempts >= 5 ? Failure.pinLocked : Failure.invalidPin);
      }
      await r.parents.saveParentSettings(
        ParentSettings(credential: settings.credential),
      );
      return Success(await action(r));
    });
    return switch (outer) {
      Success(value: final result) => result,
      Rejected(reason: final reason) => Rejected(reason),
    };
  }

  Future<Result<void>> verifyPin(String pin) => perform(pin, (_) async {});
  Future<Result<void>> changePin(String oldPin, String newPin) =>
      perform(oldPin, (r) async {
        require(_validPin(newPin), Failure.invalidPin);
        await r.parents.saveParentSettings(
          ParentSettings(credential: await hasher.hash(newPin)),
        );
      });
}
