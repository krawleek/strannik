import '../../core/result.dart';
import '../../content/lessons/discount_traps_lesson.dart';
import '../../content/lessons/earth_topic_one.dart';
import '../../content/lessons/financial_safety_lesson.dart';
import '../../content/lessons/financial_safety_topic.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';
import 'period_service.dart';

class LearningService {
  LearningService(this.game, this.periods);
  final GameContext game;
  final PeriodService periods;

  /// Opening a finale cannot bypass persisted required-task validation.
  /// Bonus, XP and topic marker commit in the same SQLite transaction.
  Future<Result<LearningTopicProgress>> beginSafetyFinale() => game.run((
    r,
  ) async {
    final required = FinancialSafetyTopic.requiredTasks(game.content);
    require(required.isNotEmpty, Failure.requirementsNotMet);
    for (final task in required) {
      require(task.implemented && await _available(r, task), Failure.locked);
      require(
        (await r.learning.learningProgress(task.id)).completed,
        Failure.requirementsNotMet,
      );
    }
    final old = await r.learning.topicProgress(FinancialSafetyTopic.id);
    if (old.completed) return old;
    const key = 'learningTopic:home_planet_safety';
    await game.money(
      r,
      amount: FinancialSafetyTopic.rewardFira,
      type: TransactionType.learningReward,
      source: TransactionSource.learning,
      key: key,
      relatedId: FinancialSafetyTopic.id,
      title: FinancialSafetyTopic.title,
    );
    await game.earnXp(r, FinancialSafetyTopic.rewardXp, key: '$key:xp');
    final value = LearningTopicProgress(
      topicId: FinancialSafetyTopic.id,
      completedAt: game.clock.now(),
    );
    await r.learning.saveTopicProgress(value);
    return value;
  });

  Future<Result<LearningTopicProgress>> advanceSafetyFinale() =>
      game.run((r) async {
        final old = await r.learning.topicProgress(FinancialSafetyTopic.id);
        require(old.completed, Failure.requirementsNotMet);
        final value = LearningTopicProgress(
          topicId: old.topicId,
          completedAt: old.completedAt,
          finaleStep: (old.finaleStep + 1).clamp(0, 2),
        );
        await r.learning.saveTopicProgress(value);
        return value;
      });

  Future<bool> _available(Repositories r, LearningTask task) async {
    if (!task.enabled) return false;
    final state = await r.system.appState();
    final pet = await game.pet(r);
    if (state.effectiveStage(pet).index < task.stage.index) return false;
    if (state.demoMode) return true;
    // Supplemental repeatable exercises stay available for recovery of funds.
    if (task.rewardPolicy == RewardPolicy.repeatable) return true;
    final theme = game.content.themes.firstWhere((t) => t.id == task.themeId);
    for (final previous in game.content.themes.where(
      (t) => t.stage == task.stage && t.order < theme.order,
    )) {
      final required = game.content.tasks.where(
        (t) =>
            t.themeId == previous.id &&
            t.enabled &&
            t.rewardPolicy == RewardPolicy.oneTime,
      );
      if (required.isNotEmpty && !await game.themeCompleted(r, previous.id)) {
        return false;
      }
    }
    // Stage 3 investigations can be taken independently within their topic.
    if (FinancialSafetyLesson.forTask(task.id) != null) return true;
    for (final previous in game.content.tasks.where(
      (t) =>
          t.themeId == task.themeId &&
          t.order < task.order &&
          t.enabled &&
          t.rewardPolicy == RewardPolicy.oneTime,
    )) {
      if (!(await r.learning.learningProgress(previous.id)).completed) {
        return false;
      }
    }
    return true;
  }

  /// Required lessons are attributed by stable content ownership, never by
  /// the stage where an old completion happened to be recorded.
  Future<Result<({int completed, int required})>> stageProgress(Stage stage) =>
      game.run((r) async {
        final tasks = game.content.tasks.where(
          (t) =>
              t.stage == stage &&
              t.enabled &&
              t.rewardPolicy == RewardPolicy.oneTime,
        );
        var completed = 0;
        for (final task in tasks) {
          if ((await r.learning.learningProgress(task.id)).completed) {
            completed++;
          }
        }
        return (completed: completed, required: tasks.length);
      });

  Future<Result<List<LearningTask>>> availableTasks() => game.run((r) async {
    final result = <LearningTask>[];
    for (final task in game.content.tasks) {
      if (await _available(r, task)) result.add(task);
    }
    return result;
  });
  Future<Result<LearningAttempt>> beginTask(
    String taskId, {
    bool replay = false,
  }) => game.run((r) async {
    await game.period(r);
    final task = game.content.task(taskId);
    require(task != null, Failure.notFound);
    require(await _available(r, task!), Failure.locked);
    require(task.implemented, Failure.notFound);
    final progress = await r.learning.learningProgress(taskId);
    require(
      task.rewardPolicy != RewardPolicy.oneTime ||
          !progress.completed ||
          replay,
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

  Future<Result<void>> saveLessonState(
    String attemptId,
    Map<String, Object?> state,
  ) => game.run((r) async {
    final old = await r.learning.attempt(attemptId);
    require(old != null && old.completedAt == null, Failure.invalidState);
    await r.learning.saveAttempt(
      LearningAttempt(
        id: old!.id,
        taskId: old.taskId,
        startedAt: old.startedAt,
        lessonState: Map.unmodifiable(state),
      ),
    );
  });

  /// Awards and completion share the existing UnitOfWork transaction.
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
    require(task.implemented, Failure.notFound);
    if (!successful) return; // No penalty, and the same attempt can be retried.
    final progress = await r.learning.learningProgress(task.id);
    if (task.type == 'earthTopicOne') {
      require(
        earthLessonReady(task.id, attempt.lessonState),
        Failure.requirementsNotMet,
      );
      if (task.id == EarthTopicOne.goalId) {
        require(
          (await r.progress.bigGoal())?.isConfirmed == true,
          Failure.requirementsNotMet,
        );
      }
    }
    if (task.type == 'financialSafety') {
      final lesson = FinancialSafetyLesson.forTask(task.id);
      require(
        lesson != null &&
            SafetyProgress.restore(lesson, attempt.lessonState).ready,
        Failure.requirementsNotMet,
      );
    }
    if (task.type == 'discountTraps') {
      require(
        task.id == DiscountTrapsLesson.taskId &&
            DiscountProgress.restore(attempt.lessonState).ready,
        Failure.requirementsNotMet,
      );
    }
    if (task.type == 'shoppingList') {
      final selected = (attempt.lessonState['selected'] as List? ?? [])
          .whereType<String>();
      final budget = LessonBudget(task.exerciseBudget, task.products, selected);
      require(
        budget.valid && attempt.lessonState['confirmed'] == true,
        Failure.requirementsNotMet,
      );
    }
    // A replay closes its attempt but never grants rewards or advances themes.
    if (progress.completed) {
      await r.learning.saveAttempt(
        LearningAttempt(
          id: attempt.id,
          taskId: task.id,
          startedAt: attempt.startedAt,
          completedAt: game.clock.now(),
          lessonState: attempt.lessonState,
        ),
      );
      return;
    }
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
    if (task.rewardXp > 0) await game.earnXp(r, task.rewardXp, key: '$key:xp');
    final now = game.clock.now();
    await r.learning.saveAttempt(
      LearningAttempt(
        id: attempt.id,
        taskId: task.id,
        startedAt: attempt.startedAt,
        completedAt: now,
        lessonState: attempt.lessonState,
      ),
    );
    await r.learning.saveLearningProgress(
      LearningProgress(
        taskId: task.id,
        completionCount: addAmount(progress.completionCount, 1),
        completedAt: now,
      ),
    );
    // Existing financial periods belong to the Earth curriculum. Stage 2
    // completion must never advance those legacy Stage 1 checkpoints.
    if (task.stage == Stage.earth) await periods.advanceCompletedThemes(r);
  });
}
