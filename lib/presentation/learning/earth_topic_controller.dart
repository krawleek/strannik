import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../content/lessons/earth_topic_one.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../../domain/models/budget_category.dart';

class EarthTopicController extends ChangeNotifier {
  EarthTopicController(this.game, this.attempt, {required this.rewardClaimed}) {
    _restore(attempt.lessonState);
  }
  final GameServices game;
  final LearningAttempt attempt;
  final bool rewardClaimed;
  LearningTask get task => game.context.content.task(attempt.taskId)!;
  int step = 0, card = 0;
  String answer = '';
  bool confirmed = false,
      busy = false,
      done = false,
      wrong = false,
      _disposed = false;
  String? error;
  Set<String> selected = {};
  WeeklySimulation simulation = WeeklySimulation();
  BigGoalType? goalType;
  BigGoal? persistedGoal;
  BudgetAllocation plan = BudgetAllocation(
    mandatory: 0,
    optional: 0,
    remainder: 0,
  );
  int wallet = 0;
  BudgetCategory source = BudgetCategory.need;
  bool get needs => task.id == EarthTopicOne.needsId;
  bool get weekly => task.id == EarthTopicOne.weeklyId;
  Map<String, Object?> get state => {
    'step': step,
    'card': card,
    'answer': answer,
    'confirmed': confirmed,
    'selected': selected.toList(),
    'simulation': simulation.toJson(),
    'goalType': goalType?.name,
  };
  void _restore(Map<String, Object?> s) {
    step = (s['step'] as int? ?? 0).clamp(0, 5);
    card = (s['card'] as int? ?? 0).clamp(0, 6);
    answer = s['answer'] as String? ?? '';
    confirmed = s['confirmed'] == true;
    selected = (s['selected'] as List? ?? [])
        .whereType<String>()
        .where((id) => EarthTopicOne.items.any((i) => i.id == id))
        .toSet();
    simulation = WeeklySimulation.restore(s['simulation']);
    goalType = BigGoalType.values
        .where((g) => g.name == s['goalType'])
        .firstOrNull;
  }

  void publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> change(void Function() action) async {
    if (busy || done) return;
    final previous = state;
    busy = true;
    error = null;
    action();
    publish();
    final result = await game.learning.saveLessonState(attempt.id, state);
    if (result is Rejected) {
      _restore(previous);
      error = 'Не удалось сохранить шаг. Попробуй ещё раз.';
    }
    busy = false;
    publish();
  }

  Future<void> refreshGoal() async {
    final result = await game.context.run(
      (r) async => (
        goal: await r.progress.bigGoal(),
        plan: await r.economy.budget(),
        wallet: (await r.economy.wallet()).firaAmount,
      ),
    );
    if (result case Success(value: final v)) {
      persistedGoal = v.goal;
      goalType = v.goal?.type ?? goalType;
      plan =
          v.plan ?? BudgetAllocation(mandatory: 0, optional: 0, remainder: 0);
      wallet = v.wallet;
    } else {
      error = 'Не удалось загрузить цель.';
    }
    publish();
  }

  Future<void> classify(bool necessary) => change(() {
    if (step != 1 || card >= 6) return;
    if (necessary) selected.add(EarthTopicOne.items[card].id);
    card++;
    if (card == 6) step = 2;
  });
  Future<void> toggle(String id) => change(() {
    if (!selected.remove(id)) selected.add(id);
    confirmed = false;
  });
  Future<void> confirmBasket() async {
    if (selected.length != 3 ||
        !selected.containsAll(EarthTopicOne.necessary)) {
      error =
          'Для еды нужны молоко, консерва и сосиска. Проверь корзину ещё раз.';
      publish();
      return;
    }
    await change(() {
      confirmed = true;
      step = 4;
    });
  }

  Future<void> check(String value) async {
    await change(() {
      answer = value.trim();
      final expected = needs
          ? EarthTopicOne.basketTotal
          : EarthTopicOne.weeklyFood;
      wrong = int.tryParse(answer) != expected;
      if (!wrong) {
        answer = expected.toString();
        if (needs) {
          step = 5;
        } else {
          simulation.step = WeeklyStep.income;
        }
      }
    });
    if (needs && step == 5) await finish();
  }

  Future<void> advanceWeekly() async {
    await change(() {
      switch (simulation.step) {
        case WeeklyStep.income:
          simulation.step = WeeklyStep.allocate;
        case WeeklyStep.allocate:
          if (simulation.allocationValid) {
            simulation.step = WeeklyStep.shop;
          } else {
            error = 'На еду нужно 180 ₣, в копилку — оставшиеся 60 ₣.';
          }
        case WeeklyStep.nextIncome:
          simulation.nextWeek();
        case WeeklyStep.summary:
          simulation.step = WeeklyStep.secondShop;
        case WeeklyStep.secondShop:
          simulation.buySecond();
        default:
          break;
      }
    });
    if (simulation.ready) await finish();
  }

  Future<void> chooseGoal(BigGoalType type) async {
    if (persistedGoal?.isConfirmed == true) {
      goalType = persistedGoal!.type;
      publish();
      return;
    }
    await change(() {
      goalType = type;
    });
  }

  Future<void> confirmGoal() async {
    if (busy || goalType == null) return;
    busy = true;
    publish();
    final result = await game.context.run((r) async {
      final old = await r.progress.bigGoal();
      if (old?.isConfirmed == true) {
        require(old!.type == goalType, Failure.immutableSelection);
        return;
      }
      await r.progress.saveBigGoal(
        BigGoal(goalType!, confirmedAt: game.context.clock.now()),
      );
      await game.context.event(
        r,
        ProgressEventType.bigGoalConfirmed,
        bigGoal: goalType,
      );
    });
    busy = false;
    if (result is Success) {
      await refreshGoal();
      await change(() {
        step = 2;
      });
    } else {
      error = 'Не удалось сохранить цель. Попробуй ещё раз.';
      publish();
    }
  }

  Future<void> initialPlan(int need, int want) async {
    if (busy) return;
    busy = true;
    publish();
    final result = await game.economy.allocateBudget(
      mandatory: need,
      optional: want,
      remainder: plan.remainder,
    );
    busy = false;
    if (result is Rejected) {
      error = 'Проверь суммы: план не должен превышать баланс.';
    }
    await refreshGoal();
  }

  Future<void> allocateGoal(int amount) async {
    if (busy || amount <= 0) return;
    busy = true;
    publish();
    final result = await game.economy.reallocateBudget(
      source: source,
      destination: BudgetCategory.save,
      amount: amount,
    );
    busy = false;
    if (result is Rejected) {
      error = 'В выбранной категории недостаточно фир. Проверь план.';
      await refreshGoal();
      return;
    }
    await refreshGoal();
    await change(() {
      step = 3;
    });
    await finish();
  }

  Future<void> finish() async {
    if (busy || done) return;
    busy = true;
    publish();
    final result = await game.learning.completeLearningTask(
      attempt.id,
      successful: true,
    );
    busy = false;
    if (result is Success) {
      done = true;
    } else {
      error = 'Не удалось сохранить результат. Попробуй ещё раз.';
    }
    publish();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
