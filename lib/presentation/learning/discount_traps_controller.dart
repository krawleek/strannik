import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/discount_traps_lesson.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';

class DiscountTrapsController extends ChangeNotifier {
  DiscountTrapsController(
    this.game,
    this.attempt, {
    required this.rewardClaimed,
  }) : progress = DiscountProgress.restore(attempt.lessonState);
  final GameServices game;
  final LearningAttempt attempt;
  final bool rewardClaimed;
  DiscountProgress progress;
  bool busy = false, completed = false, _disposed = false;
  String? error;
  LearningTask get task =>
      game.context.content.task(DiscountTrapsLesson.taskId)!;
  int get step => completed ? DiscountTrapsLesson.rewardStep : progress.step;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> dispatch(String event) async {
    if (busy || completed) return;
    final next = DiscountProgress.restore(progress.state);
    if (!next.apply(event)) return;
    busy = true;
    error = null;
    _notify();
    final result = await game.learning.saveLessonState(attempt.id, next.state);
    if (result is Success<void>) {
      progress = next;
    } else {
      error = 'Не удалось сохранить шаг. Попробуй ещё раз.';
    }
    busy = false;
    _notify();
  }

  Future<void> advance() async {
    if (progress.ready) {
      await finish();
    } else {
      await dispatch('next');
    }
  }

  Future<void> resolve(int round, {required bool caught}) =>
      dispatch('${caught ? 'catch' : 'skip'}:$round');
  Future<void> retry() => dispatch('retry');

  Future<void> finish() async {
    if (busy || completed || !progress.ready) return;
    busy = true;
    error = null;
    _notify();
    final result = await game.learning.completeLearningTask(
      attempt.id,
      successful: true,
    );
    completed = result is Success<void>;
    if (!completed) error = 'Не удалось сохранить результат. Попробуй ещё раз.';
    busy = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
