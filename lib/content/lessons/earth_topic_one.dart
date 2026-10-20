/// Educational amounts never enter Wallet, Inventory or SavingsGoal.
abstract final class EarthTopicOne {
  static const needsId = 'earth_theme1_needs';
  static const weeklyId = 'earth_theme1_weekly_budget';
  static const goalId = 'earth_theme1_goal';
  static const ids = [needsId, weeklyId, goalId];
  static const items = [
    EarthItem('clip', 'Заколка'),
    EarthItem('milk', 'Молоко'),
    EarthItem('ball', 'Мячик'),
    EarthItem('sausage', 'Сосиска'),
    EarthItem('glasses', 'Очки'),
    EarthItem('tin', 'Консерва'),
  ];
  static const necessary = {'milk', 'sausage', 'tin'};
  static const itemCost = 50;
  static const basketTotal = itemCost * 3;
  static const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const foodPrices = [20, 30, 10, 20, 20, 40, 40];
  static int get weeklyFood => foodPrices.reduce((a, b) => a + b);
  static const weeklyIncome = 240;
  static const coin = 30;
  static const mouseCost = 60;
  static const rocketCost = 120;
}

class EarthItem {
  const EarthItem(this.id, this.title);
  final String id, title;
}

enum WeeklyBranch { mouse, expensive, wait }

enum WeeklyStep {
  calculate,
  income,
  allocate,
  shop,
  nextIncome,
  summary,
  secondShop,
  ready,
}

class WeeklySimulation {
  WeeklySimulation();
  int week = 1, food = 0, savings = 0;
  WeeklyStep step = WeeklyStep.calculate;
  WeeklyBranch? branch;
  final List<String> purchases = [];
  int get income => EarthTopicOne.weeklyIncome;
  int get unallocated => income - food - savings;
  bool get allocationValid =>
      food == EarthTopicOne.weeklyFood && savings == income - food;
  void allocate(bool forFood) {
    if (step != WeeklyStep.allocate || unallocated < EarthTopicOne.coin) return;
    if (forFood) {
      food += EarthTopicOne.coin;
    } else {
      savings += EarthTopicOne.coin;
    }
  }

  void choose(WeeklyBranch choice) {
    if (step != WeeklyStep.shop || !allocationValid) return;
    branch = choice;
    switch (choice) {
      case WeeklyBranch.mouse:
        savings -= EarthTopicOne.mouseCost;
        purchases.add('mouse');
      case WeeklyBranch.expensive:
        food -= EarthTopicOne.rocketCost - savings;
        savings = 0;
        purchases.add('rocket');
      case WeeklyBranch.wait:
        break;
    }
    step = WeeklyStep.nextIncome;
  }

  void nextWeek() {
    if (step != WeeklyStep.nextIncome || branch == null) return;
    week = 2;
    food = branch == WeeklyBranch.expensive ? income : EarthTopicOne.weeklyFood;
    savings += income - food;
    step = WeeklyStep.summary;
  }

  void buySecond() {
    if (step != WeeklyStep.secondShop) return;
    final cost = branch == WeeklyBranch.wait
        ? EarthTopicOne.rocketCost
        : EarthTopicOne.mouseCost;
    if (savings >= cost) {
      savings -= cost;
      purchases.add(branch == WeeklyBranch.wait ? 'rocket' : 'mouse');
    }
    step = WeeklyStep.ready;
  }

  Map<String, Object?> toJson() => {
    'week': week,
    'income': income,
    'food': food,
    'savings': savings,
    'step': step.name,
    'branch': branch?.name,
    'purchases': purchases.toList(),
  };
  static WeeklySimulation restore(Object? raw) {
    final s = WeeklySimulation();
    if (raw is! Map) return s;
    try {
      s.week = raw['week'] as int;
      s.food = raw['food'] as int;
      s.savings = raw['savings'] as int;
      s.step = WeeklyStep.values.byName(raw['step'] as String);
      s.branch = raw['branch'] == null
          ? null
          : WeeklyBranch.values.byName(raw['branch'] as String);
      s.purchases.addAll((raw['purchases'] as List).cast<String>());
      if (s.week < 1 ||
          s.week > 2 ||
          s.food < 0 ||
          s.food > s.income ||
          s.savings < 0 ||
          s.savings > EarthTopicOne.rocketCost ||
          s.food % 30 != 0 ||
          s.savings % 30 != 0 ||
          s.purchases.any((p) => p != 'mouse' && p != 'rocket') ||
          s.purchases.length > 2 ||
          (s.step.index >= WeeklyStep.nextIncome.index && s.branch == null) ||
          (s.step.index >= WeeklyStep.summary.index && s.week != 2)) {
        return WeeklySimulation();
      }
      return s;
    } catch (_) {
      return WeeklySimulation();
    }
  }

  bool get ready =>
      step == WeeklyStep.ready &&
      week == 2 &&
      branch != null &&
      switch (branch!) {
        WeeklyBranch.mouse =>
          food == 180 && savings == 0 && purchases.join(',') == 'mouse,mouse',
        WeeklyBranch.expensive =>
          food == 240 && savings == 0 && purchases.join(',') == 'rocket',
        WeeklyBranch.wait =>
          food == 180 && savings == 0 && purchases.join(',') == 'rocket',
      };
}

bool earthLessonReady(String id, Map<String, Object?> state) {
  if (id == EarthTopicOne.needsId) {
    final selected = (state['selected'] as List? ?? [])
        .whereType<String>()
        .toSet();
    return state['step'] == 5 &&
        state['confirmed'] == true &&
        state['answer'] == EarthTopicOne.basketTotal.toString() &&
        selected.length == 3 &&
        selected.containsAll(EarthTopicOne.necessary);
  }
  if (id == EarthTopicOne.weeklyId) {
    return WeeklySimulation.restore(state['simulation']).ready &&
        state['answer'] == EarthTopicOne.weeklyFood.toString();
  }
  return id == EarthTopicOne.goalId && state['step'] == 3;
}
