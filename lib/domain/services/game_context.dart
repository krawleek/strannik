import '../../core/clock.dart';
import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class GameContext {
  GameContext({
    required this.unitOfWork,
    required this.content,
    this.clock = const SystemClock(),
    IdGenerator? ids,
  }) : ids = ids ?? IdGenerator();
  final UnitOfWork unitOfWork;
  final ContentRepository content;
  final Clock clock;
  final IdGenerator ids;
  Future<Result<T>> run<T>(Future<T> Function(Repositories) body) =>
      unitOfWork.run(body);
  Future<Pet> pet(Repositories r) async {
    final value = await r.pets.pet();
    require(value != null, Failure.invalidState);
    return value!;
  }

  Future<GamePeriod> period(Repositories r) async {
    final value = await r.progress.currentPeriod();
    require(value != null, Failure.invalidState);
    return value!;
  }

  Future<bool> themeCompleted(Repositories r, String themeId) async {
    final tasks = content.tasks
        .where(
          (t) => t.themeId == themeId && t.rewardPolicy == RewardPolicy.oneTime,
        )
        .toList();
    if (tasks.isEmpty) return false;
    for (final task in tasks) {
      if (!(await r.learning.learningProgress(task.id)).completed) return false;
    }
    return true;
  }

  Future<void> money(
    Repositories r, {
    required int amount,
    required TransactionType type,
    required TransactionSource source,
    String? key,
    String? relatedId,
    String? title,
    String? category,
  }) async {
    validAmount(amount, allowZero: true);
    if (key != null) {
      require(
        !await r.economy.hasTransactionKey(key),
        Failure.alreadyCompleted,
      );
    }
    final tx = Transaction(
      id: ids.next(),
      amount: amount,
      type: type,
      source: source,
      createdAt: clock.now(),
      periodId: (await period(r)).id,
      operationKey: key,
      relatedEntityId: relatedId,
      title: title,
      category: category,
    );
    final balance = (await r.economy.wallet()).firaAmount;
    require(balance + tx.availableDelta >= 0, Failure.insufficientFunds);
    await r.economy.saveWallet(Wallet(addAmount(balance, tx.availableDelta)));
    await r.economy.recordTransaction(tx);
  }

  Future<void> event(
    Repositories r,
    ProgressEventType type, {
    int amount = 0,
    String? resourceId,
    Stage? stage,
    BigGoalType? bigGoal,
    String? key,
  }) async {
    await r.progress.recordEvent(
      ProgressEvent(
        id: ids.next(),
        periodId: (await period(r)).id,
        type: type,
        createdAt: clock.now(),
        amount: amount,
        resourceId: resourceId,
        stage: stage,
        bigGoal: bigGoal,
        operationKey: key,
      ),
    );
  }

  Future<void> earnXp(Repositories r, int amount, {String? key}) async {
    validAmount(amount, allowZero: true);
    final current = await pet(r);
    await r.pets.savePet(current.withXp(addAmount(current.xp, amount)));
    await event(r, ProgressEventType.xpEarned, amount: amount, key: key);
  }
}
