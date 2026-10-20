import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/shopping_list_lesson.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';

class ShoppingListController extends ChangeNotifier {
  ShoppingListController(
    this.game,
    this.attempt, {
    required this.rewardClaimed,
  }) {
    final state = attempt.lessonState;
    step = (state['step'] as int? ?? 0).clamp(0, 12);
    selected.addAll(
      (state['selected'] as List? ?? []).whereType<String>().where(
        (id) => task.products.any((p) => p.id == id),
      ),
    );
    confirmed = state['confirmed'] == true && budget.valid;
    if (step == 12 && !confirmed) step = 11;
    final history = state['history'] as List?;
    if (history != null) {
      backStack.addAll(
        history.whereType<int>().where((i) => i >= 0 && i <= 11),
      );
    }
  }
  final GameServices game;
  final LearningAttempt attempt;
  final bool rewardClaimed;
  LearningTask get task =>
      game.context.content.task(ShoppingListLesson.taskId)!;
  int step = 0;
  bool busy = false, confirmed = false;
  bool _disposed = false;
  String? error;
  final Set<String> selected = {};
  final List<int> backStack = [];
  LessonBudget get budget =>
      LessonBudget(task.exerciseBudget, task.products, selected);
  Map<String, Object?> get _state => {
    'step': step,
    'selected': selected.toList()..sort(),
    'confirmed': confirmed,
    'history': backStack.toList(),
  };
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _change(void Function() change) async {
    if (busy || step == 13) return;
    final previous = _state;
    busy = true;
    error = null;
    change();
    _notify();
    final result = await game.learning.saveLessonState(attempt.id, _state);
    busy = false;
    if (result is Rejected<void>) {
      step = previous['step'] as int;
      selected
        ..clear()
        ..addAll((previous['selected'] as List).cast<String>());
      confirmed = previous['confirmed'] as bool;
      backStack
        ..clear()
        ..addAll((previous['history'] as List).cast<int>());
      error = 'Не удалось сохранить шаг. Попробуй ещё раз.';
    }
    _notify();
  }

  Future<void> advance({bool scared = false}) async {
    if (step == 11 || step == 13) return;
    if (step == 12) {
      await finish();
      return;
    }
    await _change(() {
      backStack.add(step);
      step = ShoppingListLesson.next(step, scared: scared);
    });
  }

  Future<void> back() => _change(() {
    if (backStack.isEmpty) return;
    step = backStack.removeLast();
    if (step <= 11) confirmed = false;
  });
  Future<void> toggle(String id) async {
    if (step != 11 || !task.products.any((p) => p.id == id)) return;
    await _change(() {
      if (!selected.remove(id)) selected.add(id);
      confirmed = false;
    });
  }

  Future<void> confirm() async {
    if (step != 11 || !budget.valid) return;
    await _change(() {
      confirmed = true;
      backStack.add(step);
      step = 12;
    });
  }

  Future<void> finish() async {
    if (busy || step != 12 || !confirmed || !budget.valid) return;
    busy = true;
    error = null;
    _notify();
    final result = await game.learning.completeLearningTask(
      attempt.id,
      successful: true,
    );
    busy = false;
    if (result is Success<void>) {
      step = 13;
    } else {
      error = 'Не удалось сохранить результат. Попробуй ещё раз.';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
