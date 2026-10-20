import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../../domain/models/store_snapshot.dart';

class StoreController extends ChangeNotifier {
  StoreController(this.game);
  final GameServices game;
  StoreSnapshot? snapshot;
  bool closet = false, busy = false, loading = false;
  String? selectedId, error;
  Failure? failure;
  bool _disposed = false;
  int _loadVersion = 0;
  List<StoreItem> get catalog => game.context.content.storeItems;
  List<StoreItem> get visibleItems =>
      closet ? catalog.where((item) => quantity(item) > 0).toList() : catalog;
  StoreItem? get selected =>
      selectedId == null ? null : game.context.content.item(selectedId!);
  int quantity(StoreItem item) => snapshot?.quantity(item) ?? 0;
  bool owned(StoreItem item) => quantity(item) > 0;
  bool locked(StoreItem item) {
    final state = snapshot, pet = state?.pet;
    return state == null ||
        pet == null ||
        !item.available ||
        pet.xp < item.requiredXp ||
        state.appState.effectiveStage(pet).index < item.requiredStage.index;
  }

  String? get previewAccessory =>
      !closet &&
          selected?.category == ItemCategory.accessory &&
          !locked(selected!)
      ? selected!.id
      : null;
  String? get shownAccessory =>
      previewAccessory ?? snapshot?.pet?.equippedAccessoryId;
  Stage get stage => snapshot?.pet == null
      ? Stage.earth
      : snapshot!.appState.effectiveStage(snapshot!.pet!);
  int? get requiredXp {
    final matches = game.context.content.stageRequirements.where(
      (r) =>
          r.from == stage &&
          (snapshot?.bigGoal == null || r.bigGoal == snapshot!.bigGoal!.type),
    );
    if (matches.isEmpty) return null;
    return matches.first.requiredXp;
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final version = ++_loadVersion;
    if (!busy) {
      error = null;
      failure = null;
    }
    loading = snapshot == null;
    _publish();
    final result = await game.store.snapshot();
    if (_disposed || version != _loadVersion) return;
    loading = false;
    switch (result) {
      case Success(value: final value):
        snapshot = value;
        if (selected != null && closet && !owned(selected!)) selectedId = null;
      case Rejected(reason: final reason):
        failure = reason;
        error = message(reason);
    }
    _publish();
  }

  void select(String? id) {
    if (busy) return;
    selectedId = id;
    error = null;
    failure = null;
    _publish();
  }

  void showCloset(bool value) {
    if (busy) return;
    closet = value;
    selectedId = null;
    error = null;
    failure = null;
    _publish();
  }

  Future<bool> _perform(Future<Result<void>> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    failure = null;
    _publish();
    try {
      final result = await action();
      if (result case Rejected(reason: final reason)) {
        failure = reason;
        error = message(reason);
        await load();
        return false;
      }
      await load();
      return true;
    } catch (_) {
      failure = Failure.persistenceFailure;
      error = message(failure!);
      return false;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<bool> buy(
    StoreItem item,
    String operationId, {
    PurchasePurpose? purpose,
  }) => _perform(
    () =>
        game.store.buyItem(item.id, operationId: operationId, purpose: purpose),
  );
  Future<bool> use(StoreItem item) => _perform(() async {
    if (!owned(item)) return const Rejected(Failure.notFound);
    switch (item.category) {
      case ItemCategory.accessory:
        return game.pet.equipAccessory(
          snapshot?.pet?.equippedAccessoryId == item.id ? null : item.id,
        );
      case ItemCategory.treat:
        return game.pet.useTreat(item.id);
      case ItemCategory.toy:
        final activation = await game.pet.activateToy(item.id);
        if (activation is Rejected<void>) return activation;
        final result = await game.pet.playWithToy(item.id);
        return switch (result) {
          Success() => const Success(null),
          Rejected(reason: final reason) => Rejected(reason),
        };
      case ItemCategory.shipMaterial:
        return const Rejected(Failure.invalidState);
    }
  });
  String useLabel(StoreItem item) => switch (item.category) {
    ItemCategory.accessory =>
      snapshot?.pet?.equippedAccessoryId == item.id ? 'Снять' : 'Надеть',
    ItemCategory.treat => 'Угостить',
    ItemCategory.toy => 'Поиграть',
    ItemCategory.shipMaterial => 'Материал для большой цели',
  };
  static String message(Failure reason) => switch (reason) {
    Failure.insufficientFunds => 'Ой, фир не хватает!',
    Failure.alreadyOwned => 'Этот предмет уже есть в шкафу.',
    Failure.alreadyCompleted => 'Эта покупка уже выполнена.',
    Failure.locked => 'Предмет пока недоступен. Продолжай обучение.',
    Failure.notFound => 'Предмет закончился или больше недоступен.',
    _ => 'Не получилось сохранить действие. Попробуй ещё раз.',
  };
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
