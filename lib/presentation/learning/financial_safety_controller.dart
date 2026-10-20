import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/financial_safety_lesson.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';

class FinancialSafetyController extends ChangeNotifier {
  FinancialSafetyController(
    this.game,
    this.attempt, {
    required this.rewardClaimed,
  }) : lesson = FinancialSafetyLesson.forTask(attempt.taskId)! {
    progress = SafetyProgress.restore(lesson, attempt.lessonState);
  }
  final GameServices game;
  final LearningAttempt attempt;
  final FinancialSafetyLesson lesson;
  final bool rewardClaimed;
  late SafetyProgress progress;
  bool busy = false, completed = false, _disposed = false;
  String? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> send(String event) async {
    if (busy || completed) return;
    final next = SafetyProgress.restore(lesson, progress.saved);
    if (!next.apply(event)) return;
    await _save(next);
    if (progress.ready && error == null) await finish();
  }

  Future<void> back() async {
    if (busy || completed || progress.ready || progress.events.isEmpty) return;
    final events = List<String>.of(progress.events)..removeLast();
    await _save(SafetyProgress.restore(lesson, {'events': events}));
  }

  Future<void> _save(SafetyProgress next) async {
    busy = true;
    error = null;
    _notify();
    final result = await game.learning.saveLessonState(attempt.id, next.saved);
    busy = false;
    if (result is Success<void>) {
      progress = next;
    } else {
      error = 'Не удалось сохранить шаг. Попробуй ещё раз.';
    }
    _notify();
  }

  Future<void> finish() async {
    if (busy || completed || !progress.ready) return;
    busy = true;
    error = null;
    _notify();
    final result = await game.learning.completeLearningTask(
      attempt.id,
      successful: true,
    );
    busy = false;
    completed = result is Success<void>;
    if (!completed) error = 'Не удалось сохранить результат. Попробуй ещё раз.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
