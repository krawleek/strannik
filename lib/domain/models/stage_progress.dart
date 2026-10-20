import 'models.dart';

class StageProgress {
  const StageProgress({
    required this.pet,
    required this.goal,
    required this.requirements,
    required this.inventory,
    required this.completedLessons,
    required this.requiredLessons,
    this.budget,
  });
  final Pet pet;
  final BigGoal? goal;
  final BudgetAllocation? budget;
  final StageRequirements? requirements;
  final List<InventoryEntry> inventory;
  final int completedLessons, requiredLessons;
  int owned(String resourceId) =>
      inventory
          .where((e) => e.id == 'resource:$resourceId')
          .firstOrNull
          ?.quantity ??
      0;
  bool get goalMet => goal?.isConfirmed == true;
  bool get xpMet => requirements != null && pet.xp >= requirements!.requiredXp;
  bool get materialsMet =>
      requirements != null &&
      requirements!.resources.every((r) => owned(r.resourceId) >= r.amount);
  bool get eligible => goalMet && xpMet && materialsMet;
}
