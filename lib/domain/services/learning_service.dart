import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';
import 'period_service.dart';

class LearningService {
  LearningService(this.game, this.periods);
  final GameContext game;
  final PeriodService periods;
  Future<bool> _available(Repositories r, LearningTask task) async {
    if ((await r.system.appState()).demoMode) return true;
    // Supplemental repeatable exercises stay available for recovery of funds.
    if (task.rewardPolicy == RewardPolicy.repeatable) return true;
    final theme = game.content.themes.firstWhere((t) => t.id == task.themeId);
    for (final previous in game.content.themes.where(
      (t) => t.order < theme.order,
    )) {
      if (!await game.themeCompleted(r, previous.id)) return false;
    }
    for (final previous in game.content.tasks.where(
      (t) =>
          t.themeId == task.themeId &&
          t.order < task.order &&
          t.rewardPolicy == RewardPolicy.oneTime,
    )) {
      if (!(await r.learning.learningProgress(previous.id)).completed) {
        return false;
      }
    }
    return true;
  }

  Future<Result<List<LearningTask>>> availableTasks() => game.run((r) async {
    final result = <LearningTask>[];
    for (final task in game.content.tasks) {
      if (await _available(r, task)) result.add(task);
    }
    return result;
  });
  Future<Result<LearningAttempt>> beginTask(String taskId) =>
      game.run((r) async {
        await game.period(r);
        final task = game.content.task(taskId);
        require(task != null, Failure.notFound);
        require(await _available(r, task!), Failure.locked);
        final progress = await r.learning.learningProgress(taskId);
        require(
          task.rewardPolicy != RewardPolicy.oneTime || !progress.completed,
          Failure.alreadyCompleted,
        );
        final existing = await r.learning.openAttempt(taskId);
        if (existing != null) return existing;
        final attempt = LearningAttempt(
          id: game.ids.next(),
          taskId: taskId,
          startedAt: game.clock.now(),
        );
        await r.learning.saveAttempt(attempt);
        return attempt;
      });

  /// Lesson evaluators supply success; full lesson evaluation/UI is a later stage.
  Future<Result<void>> completeLearningTask(
    String attemptId, {
    required bool successful,
  }) => game.run((r) async {
    final attempt = await r.learning.attempt(attemptId);
    require(attempt != null, Failure.notFound);
    require(attempt!.completedAt == null, Failure.alreadyCompleted);
    final task = game.content.task(attempt.taskId);
    require(task != null, Failure.notFound);
    require(await _available(r, task!), Failure.locked);
    if (!successful) return; // No penalty, and the same attempt can be retried.
    final progress = await r.learning.learningProgress(task.id);
    require(
      task.rewardPolicy != RewardPolicy.oneTime || !progress.completed,
      Failure.alreadyCompleted,
    );
    final key = task.rewardPolicy == RewardPolicy.oneTime
        ? 'learning:${task.id}'
        : 'learningAttempt:${attempt.id}';
    await game.money(
      r,
      amount: task.rewardFira,
      type: TransactionType.learningReward,
      source: TransactionSource.learning,
      key: key,
      relatedId: task.id,
      title: task.title,
    );
    final now = game.clock.now();
    await r.learning.saveAttempt(
      LearningAttempt(
        id: attempt.id,
        taskId: task.id,
        startedAt: attempt.startedAt,
        completedAt: now,
      ),
    );
    await r.learning.saveLearningProgress(
      LearningProgress(
        taskId: task.id,
        completionCount: addAmount(progress.completionCount, 1),
        completedAt: now,
      ),
    );
    await periods.advanceCompletedThemes(r);
  });
}
