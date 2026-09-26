enum Failure {
  invalidAmount,
  insufficientFunds,
  insufficientSavings,
  invalidState,
  notFound,
  locked,
  alreadyOwned,
  alreadyCompleted,
  immutableSelection,
  requirementsNotMet,
  targetExceeded,
  savingsGoalExists,
  unauthorized,
  invalidPin,
  pinLocked,
  persistenceFailure,
}

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Rejected<T> extends Result<T> {
  const Rejected(this.reason);
  final Failure reason;
}

/// Internal control flow: the transaction runner rolls back before returning it.
final class DomainRejection implements Exception {
  const DomainRejection(this.reason);
  final Failure reason;
}

void require(bool condition, Failure reason) {
  if (!condition) throw DomainRejection(reason);
}

// Keep arithmetic inside the exact positive range supported by the application.
const maxGameValue = 9007199254740991;
void validAmount(int value, {bool allowZero = false}) => require(
  value >= (allowZero ? 0 : 1) && value <= maxGameValue,
  Failure.invalidAmount,
);
int addAmount(int current, int delta) {
  final next = current + delta;
  validAmount(next, allowZero: true);
  return next;
}
