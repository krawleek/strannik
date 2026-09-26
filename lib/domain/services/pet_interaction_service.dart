import '../../core/result.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'game_context.dart';

class PetInteractionService {
  PetInteractionService(this.game);
  final GameContext game;
  Future<StoreItem> _owned(
    Repositories r,
    String id,
    ItemCategory category,
  ) async {
    final item = game.content.item(id);
    require(item != null && item.category == category, Failure.notFound);
    final owned = await r.items.inventoryEntry(item!.inventoryId);
    require((owned?.quantity ?? 0) > 0, Failure.notFound);
    return item;
  }

  Future<Result<void>> useTreat(String id) => game.run((r) async {
    final item = await _owned(r, id, ItemCategory.treat);
    final entry = (await r.items.inventoryEntry(item.inventoryId))!;
    await r.items.saveInventoryEntry(
      InventoryEntry(
        id: entry.id,
        category: entry.category,
        quantity: entry.quantity - 1,
      ),
    );
    await game.earnXp(r, item.interactionXp);
  });
  Future<Result<int>> playWithToy(String id) => game.run((r) async {
    final item = await _owned(r, id, ItemCategory.toy);
    final pet = await game.pet(r);
    require(pet.activeToyId == id, Failure.invalidState);
    final key = 'toy:${(await game.period(r)).id}:$id';
    if (await r.progress.hasEventKey(key)) return 0;
    await game.earnXp(r, item.interactionXp, key: key);
    return item.interactionXp;
  });
  Future<Result<void>> equipAccessory(String? id) => game.run((r) async {
    if (id != null) await _owned(r, id, ItemCategory.accessory);
    await r.pets.savePet(
      (await game.pet(r))
          .copyWith(equippedAccessoryId: id, clearAccessory: id == null),
    );
  });
  Future<Result<void>> activateToy(String? id) => game.run((r) async {
    if (id != null) await _owned(r, id, ItemCategory.toy);
    await r.pets.savePet(
      (await game.pet(r)).copyWith(activeToyId: id, clearToy: id == null),
    );
  });
}
