import '../../core/result.dart';
import '../models/models.dart';
import 'game_context.dart';

class StoreService {
  StoreService(this.game);
  final GameContext game;
  Future<Result<void>> buyItem(String id, {int quantity = 1}) =>
      game.run((r) async {
        validAmount(quantity);
        final item = game.content.item(id);
        require(item != null, Failure.notFound);
        final pet = await game.pet(r);
        final state = await r.system.appState();
        require(
          item!.available &&
              pet.xp >= item.requiredXp &&
              state.effectiveStage(pet).index >= item.requiredStage.index,
          Failure.locked,
        );
        final owned = await r.items.inventoryEntry(item.inventoryId);
        require(
          !item.permanent || (owned?.quantity ?? 0) == 0,
          Failure.alreadyOwned,
        );
        require(!item.permanent || quantity == 1, Failure.invalidAmount);
        validAmount(item.price, allowZero: true);
        require(
          item.price == 0 || quantity <= maxGameValue ~/ item.price,
          Failure.invalidAmount,
        );
        final cost = item.price * quantity;
        await game.money(
          r,
          amount: cost,
          type: TransactionType.purchase,
          source: TransactionSource.store,
          relatedId: item.id,
          title: item.title,
          category: item.category.name,
        );
        await r.items.saveInventoryEntry(
          InventoryEntry(
            id: item.inventoryId,
            category: item.category,
            quantity: addAmount(owned?.quantity ?? 0, quantity),
          ),
        );
        if (item.category == ItemCategory.shipMaterial) {
          await game.event(
            r,
            ProgressEventType.materialGained,
            amount: quantity,
            resourceId: item.resourceId,
          );
        }
      });
}
