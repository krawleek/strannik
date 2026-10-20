import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class ParentAccessService {
  ParentAccessService(this.game, this.hasher);
  final GameContext game;
  final PinHasher hasher;
  Object? _session;
  int _sessionGeneration = 0;
  DateTime? _expires;
  Object? get session => isAuthenticated ? _session : null;
  bool get isAuthenticated =>
      _session != null &&
      _expires != null &&
      game.clock.now().isBefore(_expires!);
  void endSession() {
    _sessionGeneration++;
    _session = null;
    _expires = null;
  }

  Future<Result<void>> authenticate(String pin) async {
    endSession();
    final generation = _sessionGeneration;
    final result = await verifyPin(pin);
    if (generation != _sessionGeneration) {
      return const Rejected(Failure.unauthorized);
    }
    if (result is Success<void>) {
      _session = Object();
      _expires = game.clock.now().add(const Duration(minutes: 10));
    }
    return result;
  }

  Future<Result<T>> authorized<T>(
    Object? token,
    Future<T> Function(Repositories) action,
  ) => game.run((r) async {
    require(
      isAuthenticated && identical(token, _session),
      Failure.unauthorized,
    );
    return action(r);
  });
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
            lockUntil: attempts >= 3
                ? now.add(const Duration(minutes: 5))
                : null,
          ),
        );
        return Rejected(attempts >= 3 ? Failure.pinLocked : Failure.invalidPin);
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
