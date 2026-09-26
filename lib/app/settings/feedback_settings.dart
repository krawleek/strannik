import '../../core/result.dart';

class FeedbackSettings {
  const FeedbackSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
}

abstract interface class FeedbackSettingsStore {
  Future<Result<FeedbackSettings>> read();

  /// Only supplied fields change, so independent toggles cannot overwrite others.
  Future<Result<void>> update({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
  });
}

class FeedbackSettingsService {
  const FeedbackSettingsService(this.store);
  final FeedbackSettingsStore store;

  Future<Result<FeedbackSettings>> read() => store.read();
  Future<Result<void>> setSoundEnabled(bool enabled) =>
      store.update(soundEnabled: enabled);
  Future<Result<void>> setMusicEnabled(bool enabled) =>
      store.update(musicEnabled: enabled);
  Future<Result<void>> setHapticsEnabled(bool enabled) =>
      store.update(hapticsEnabled: enabled);
}
