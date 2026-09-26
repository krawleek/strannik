import '../../core/result.dart';
import '../settings/feedback_settings.dart';

enum SfxType {
  tap,
  selection,
  success,
  warning,
  purchase,
  taskCompleted,
  itemUnlocked,
  stageCompleted,
}

enum MusicScene { earth, space, homePlanet }

enum HapticsType { selection, light, success, warning, stageCompleted }

/// Future implementations must use local bundled assets, never remote URLs.
abstract interface class SfxOutput {
  Future<void> play(SfxType type);
}

abstract interface class MusicOutput {
  Future<void> play(MusicScene scene);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}

abstract interface class HapticsOutput {
  Future<void> feedback(HapticsType type);
}

class NoOpSfxOutput implements SfxOutput {
  const NoOpSfxOutput();
  @override
  Future<void> play(SfxType type) async {}
}

class NoOpMusicOutput implements MusicOutput {
  const NoOpMusicOutput();
  @override
  Future<void> play(MusicScene scene) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
}

class NoOpHapticsOutput implements HapticsOutput {
  const NoOpHapticsOutput();
  @override
  Future<void> feedback(HapticsType type) async {}
}

Future<Result<void>> _whenEnabled(
  FeedbackSettingsService settings,
  bool Function(FeedbackSettings) enabled,
  Future<void> Function() action,
) async {
  final result = await settings.read();
  switch (result) {
    case Rejected(reason: final reason):
      return Rejected(reason);
    case Success(value: final value):
      if (enabled(value)) await action();
      return const Success(null);
  }
}

/// Explicit presentation requests only; no subscription to economy/progress.
class SfxService {
  const SfxService(this.settings, {this.output = const NoOpSfxOutput()});
  final FeedbackSettingsService settings;
  final SfxOutput output;
  Future<Result<void>> play(SfxType type) =>
      _whenEnabled(settings, (s) => s.soundEnabled, () => output.play(type));
}

class MusicService {
  const MusicService(this.settings, {this.output = const NoOpMusicOutput()});
  final FeedbackSettingsService settings;
  final MusicOutput output;
  Future<Result<void>> play(MusicScene scene) =>
      _whenEnabled(settings, (s) => s.musicEnabled, () => output.play(scene));
  Future<Result<void>> resume() =>
      _whenEnabled(settings, (s) => s.musicEnabled, output.resume);
  // Always allow silencing an existing track, even after disabling music.
  Future<void> stop() => output.stop();
  Future<void> pause() => output.pause();
}

class HapticsService {
  const HapticsService(
    this.settings, {
    this.output = const NoOpHapticsOutput(),
  });
  final FeedbackSettingsService settings;
  final HapticsOutput output;
  Future<Result<void>> feedback(HapticsType type) => _whenEnabled(
    settings,
    (s) => s.hapticsEnabled,
    () => output.feedback(type),
  );
}

/// Separate from GameServices; all outputs are silent placeholders by default.
class FeedbackServices {
  FeedbackServices({
    required FeedbackSettingsStore store,
    SfxOutput sfxOutput = const NoOpSfxOutput(),
    MusicOutput musicOutput = const NoOpMusicOutput(),
    HapticsOutput hapticsOutput = const NoOpHapticsOutput(),
  }) : settings = FeedbackSettingsService(store) {
    sfx = SfxService(settings, output: sfxOutput);
    music = MusicService(settings, output: musicOutput);
    haptics = HapticsService(settings, output: hapticsOutput);
  }
  final FeedbackSettingsService settings;
  late final SfxService sfx;
  late final MusicService music;
  late final HapticsService haptics;
}
