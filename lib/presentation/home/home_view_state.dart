import '../../domain/models/models.dart';

enum HomeLoadStatus { loading, ready, preview, needsOnboarding, failed }

/// References existing models; there are no duplicated balances or XP counters.
class HomeSnapshot {
  const HomeSnapshot({
    required this.profile,
    required this.pet,
    required this.appState,
    required this.inventory,
    required this.period,
  });
  final ChildProfile? profile;
  final Pet? pet;
  final AppState appState;
  final List<InventoryEntry> inventory;
  final GamePeriod? period;
}

class HomeViewState {
  const HomeViewState({
    this.status = HomeLoadStatus.loading,
    this.snapshot,
    this.busy = false,
    this.actionsOpen = false,
    this.reaction,
  });
  final HomeLoadStatus status;
  final HomeSnapshot? snapshot;
  final bool busy, actionsOpen;
  final String? reaction;
  bool get isPreview => status == HomeLoadStatus.preview;
  Stage get effectiveStage {
    final pet = snapshot?.pet;
    return pet == null ? Stage.earth : snapshot!.appState.effectiveStage(pet);
  }
}

/// Only view defaults. Never passed to repositories or onboarding services.
abstract final class DevelopmentHomePreview {
  static const petName = 'Странник';
  static const stageProgress = '0/3';
}
