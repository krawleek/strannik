import 'models.dart';

/// Expense intent only: budget allocations are not separate money accounts.
enum PurchasePurpose { need, want }

class StoreSnapshot {
  const StoreSnapshot({
    required this.pet,
    required this.wallet,
    required this.budget,
    required this.savings,
    required this.appState,
    required this.inventory,
    required this.bigGoal,
  });
  final Pet? pet;
  final Wallet wallet;
  final BudgetAllocation? budget;
  final SavingsGoal? savings;
  final AppState appState;
  final List<InventoryEntry> inventory;
  final BigGoal? bigGoal;
  int quantity(StoreItem item) {
    for (final entry in inventory) {
      if (entry.id == item.inventoryId) return entry.quantity;
    }
    return 0;
  }
}
