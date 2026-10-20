import '../../core/result.dart';
import '../models/models.dart';
import 'game_context.dart';
import 'parent_access_service.dart';

class ProfileOverview {
  const ProfileOverview(
    this.profile,
    this.pet,
    this.demo,
    this.completedTasks,
    this.startedTasks,
    this.completedThemes,
  );
  final ChildProfile? profile;
  final Pet? pet;
  final bool demo;
  final Set<String> completedTasks, startedTasks, completedThemes;
}

class ProfileService {
  ProfileService(this.game, this.parentAccess);
  final GameContext game;
  final ParentAccessService parentAccess;
  Future<Result<ProfileOverview>> load() => game.run((r) async {
    final completed = <String>{}, started = <String>{}, themes = <String>{};
    for (final t in game.content.tasks) {
      if ((await r.learning.learningProgress(t.id)).completed) {
        completed.add(t.id);
      }
      if (completed.contains(t.id) ||
          await r.learning.openAttempt(t.id) != null) {
        started.add(t.id);
      }
    }
    for (final theme in game.content.themes) {
      if (await game.themeCompleted(r, theme.id)) themes.add(theme.id);
    }
    return ProfileOverview(
      await r.profiles.profile(),
      await r.pets.pet(),
      (await r.system.appState()).demoMode,
      completed,
      started,
      themes,
    );
  });
  Future<Result<void>> rename(String name) => game.run((r) async {
    final value = name.trim();
    require(value.isNotEmpty && value.runes.length <= 24, Failure.invalidState);
    final child = await r.profiles.profile();
    require(child != null, Failure.notFound);
    await r.profiles.saveProfile(child!.copyWith(nickname: value));
  });
  Future<Result<void>> avatar(String id) => game.run((r) async {
    require({'girl', 'boy', 'cap'}.contains(id), Failure.invalidState);
    final child = await r.profiles.profile();
    require(child != null, Failure.notFound);
    await r.profiles.saveProfile(child!.copyWith(avatarId: id));
  });
  Future<Result<void>> demo(Object? token, bool enabled) =>
      parentAccess.authorized(
        token,
        (r) => r.system.saveAppState(AppState(demoMode: enabled)),
      );
  Future<Result<void>> reset(Object? token) =>
      parentAccess.authorized(token, (r) => r.system.resetProgress());
  Future<Result<void>> delete(Object? token) async {
    final result = await parentAccess.authorized(
      token,
      (r) => r.system.deleteAllData(),
    );
    if (result is Success<void>) parentAccess.endSession();
    return result;
  }
}
