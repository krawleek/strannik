import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/pet_interaction_service.dart';
import 'home_view_state.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    required this.unitOfWork,
    required this.allowDevelopmentPreview,
    this.interactions,
    this.content,
  });
  final UnitOfWork unitOfWork;
  final bool allowDevelopmentPreview;
  final PetInteractionService? interactions;
  final ContentRepository? content;
  HomeViewState _state = const HomeViewState();
  HomeViewState get state => _state;
  bool _disposed = false;
  int _loadVersion = 0;

  void _publish(HomeViewState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  Future<void> load() async {
    if (_state.busy) return;
    final version = ++_loadVersion;
    _publish(const HomeViewState());
    final result = await unitOfWork.run(
      (r) async => HomeSnapshot(
        profile: await r.profiles.profile(),
        pet: await r.pets.pet(),
        appState: await r.system.appState(),
        inventory: List.unmodifiable(await r.items.inventory()),
        period: await r.progress.currentPeriod(),
      ),
    );
    if (_disposed || version != _loadVersion) return;
    switch (result) {
      case Rejected():
        _publish(const HomeViewState(status: HomeLoadStatus.failed));
      case Success(value: final snapshot):
        final complete =
            snapshot.profile?.onboardingCompleted == true &&
            snapshot.pet != null &&
            snapshot.period != null;
        _publish(
          HomeViewState(
            status: complete
                ? HomeLoadStatus.ready
                : allowDevelopmentPreview
                ? HomeLoadStatus.preview
                : HomeLoadStatus.needsOnboarding,
            snapshot: complete ? snapshot : null,
          ),
        );
    }
  }

  void toggleActions() {
    if (_state.busy) return;
    _publish(
      HomeViewState(
        status: _state.status,
        snapshot: _state.snapshot,
        actionsOpen: !_state.actionsOpen,
      ),
    );
  }

  void dismissReaction() {
    if (_state.busy) return;
    _publish(HomeViewState(status: _state.status, snapshot: _state.snapshot));
  }

  void _react(String text) => _publish(
    HomeViewState(
      status: _state.status,
      snapshot: _state.snapshot,
      reaction: text,
    ),
  );
  void strokePet() {
    if (!_state.busy) _react('Мур-р-р! Как приятно!');
  }

  Future<void> giveTreat() async {
    if (_state.busy) return;
    StoreItem? treat;
    for (final item in content?.storeItems ?? <StoreItem>[]) {
      if (item.category == ItemCategory.treat && _owns(item.inventoryId)) {
        treat = item;
        break;
      }
    }
    if (_state.isPreview || treat == null || interactions == null) {
      _react('Пока нет вкусняшек. Их можно найти в магазине.');
      return;
    }
    await _perform(
      () => interactions!.useTreat(treat!.id),
      (_) => 'Спасибо за угощение!',
    );
  }

  Future<void> play() async {
    if (_state.busy) return;
    final toyId = _state.snapshot?.pet?.activeToyId;
    final toy = toyId == null ? null : content?.item(toyId);
    if (toy == null ||
        toy.category != ItemCategory.toy ||
        !_owns(toy.inventoryId) ||
        interactions == null) {
      _react('Для игры нужна активная игрушка.');
      return;
    }
    await _perform(
      () => interactions!.playWithToy(toy.id),
      (xp) => xp > 0 ? 'Здорово поиграли!' : 'Рад поиграть с тобой ещё!',
    );
  }

  bool _owns(String id) =>
      _state.snapshot?.inventory.any((e) => e.id == id && e.quantity > 0) ??
      false;

  Future<void> _perform<T>(
    Future<Result<T>> Function() action,
    String Function(T) message,
  ) async {
    _publish(
      HomeViewState(
        status: _state.status,
        snapshot: _state.snapshot,
        busy: true,
        actionsOpen: true,
      ),
    );
    final result = await action();
    if (_disposed) return;
    // Clear busy before refreshing; the domain service has already committed.
    _publish(HomeViewState(status: _state.status, snapshot: _state.snapshot));
    await load();
    if (_disposed || _state.status == HomeLoadStatus.failed) return;
    switch (result) {
      case Success(value: final value):
        _react(message(value));
      case Rejected(reason: final reason):
        _react(switch (reason) {
          Failure.notFound ||
          Failure.invalidState => 'Нужный предмет сейчас недоступен.',
          Failure.persistenceFailure =>
            'Не получилось сохранить действие. Попробуй ещё раз.',
          _ => 'Сейчас не получилось. Попробуй ещё раз.',
        });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
