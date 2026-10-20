import '../domain/models/models.dart';

class EconomyRules {
  const EconomyRules({this.startingBalance = EconomyConfig.startingBalance});
  final int startingBalance;
}

/// Product-approved real economy. Lesson simulations keep separate amounts.
abstract final class EconomyConfig {
  static const startingBalance = 30;
  static const firstCompletionReward = 40;
  static const dailyBonusStart = 5;
  static const dailyBonusIncrement = 1;
  static const dailyBonusMaximum = 10;
  static int dailyBonus(int consecutiveDay) =>
      (dailyBonusStart + (consecutiveDay - 1).clamp(0, 5)).toInt();
  static const goals = {
    BigGoalType.spaceTaxi: GoalDefinition(
      'Космо-такси',
      'Заказать межпланетный трансфер',
      100,
      'taxi',
    ),
    BigGoalType.contactHome: GoalDefinition(
      'Приёмник для друзей',
      'Купить приёмник, чтобы позвать на помощь',
      150,
      'receiver',
    ),
    BigGoalType.repairShip: GoalDefinition(
      'Ремонт ракеты',
      'Полететь на своём собственном корабле',
      300,
      'rocket',
    ),
  };
}

class GoalDefinition {
  const GoalDefinition(this.title, this.description, this.target, this.art);
  final String title, description, art;
  final int target;
}
