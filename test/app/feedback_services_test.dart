import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/app/feedback/feedback_services.dart';
import 'package:strannik/data/repositories/sqlite_feedback_settings_store.dart';

import '../support/harness.dart';

class RecordingSfx implements SfxOutput {
  final calls = <SfxType>[];
  @override
  Future<void> play(SfxType type) async {
    calls.add(type);
  }
}

class RecordingMusic implements MusicOutput {
  final calls = <String>[];
  @override
  Future<void> play(MusicScene scene) async {
    calls.add(scene.name);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }
}

class RecordingHaptics implements HapticsOutput {
  final calls = <HapticsType>[];
  @override
  Future<void> feedback(HapticsType type) async {
    calls.add(type);
  }
}

void main() {
  late Harness h;
  late FeedbackServices feedback;
  late RecordingSfx sfx;
  late RecordingMusic music;
  late RecordingHaptics haptics;
  setUp(() async {
    h = await Harness.create();
    sfx = RecordingSfx();
    music = RecordingMusic();
    haptics = RecordingHaptics();
    feedback = FeedbackServices(
      store: SqliteFeedbackSettingsStore(h.db.database),
      sfxOutput: sfx,
      musicOutput: music,
      hapticsOutput: haptics,
    );
  });
  tearDown(() => h.db.close());

  test(
    'disabled SFX ignores requests and does not affect haptics or music',
    () async {
      success(await feedback.settings.setSoundEnabled(false));
      success(await feedback.sfx.play(SfxType.success));
      expect(sfx.calls, isEmpty);
      success(await feedback.haptics.feedback(HapticsType.success));
      success(await feedback.music.play(MusicScene.earth));
      expect(haptics.calls, [HapticsType.success]);
      expect(music.calls, ['earth']);
      success(await feedback.settings.setSoundEnabled(true));
      success(await feedback.sfx.play(SfxType.success));
      expect(sfx.calls, [SfxType.success]);
    },
  );

  test(
    'music checks settings on play and resume; stop/pause always available',
    () async {
      success(await feedback.settings.setMusicEnabled(false));
      success(await feedback.music.play(MusicScene.space));
      success(await feedback.music.resume());
      expect(music.calls, isEmpty);
      await feedback.music.stop();
      await feedback.music.pause();
      expect(music.calls, ['stop', 'pause']);
      success(await feedback.settings.setMusicEnabled(true));
      success(await feedback.music.play(MusicScene.homePlanet));
      success(await feedback.music.resume());
      expect(music.calls, ['stop', 'pause', 'homePlanet', 'resume']);
    },
  );

  test(
    'disabled haptics ignores feedback and no feedback occurs automatically',
    () async {
      await h.start();
      success(await h.game.store.buyItem('scarf'));
      expect(sfx.calls, isEmpty);
      expect(music.calls, isEmpty);
      expect(haptics.calls, isEmpty);
      success(await feedback.settings.setHapticsEnabled(false));
      success(await feedback.haptics.feedback(HapticsType.stageCompleted));
      expect(haptics.calls, isEmpty);
      success(await feedback.settings.setHapticsEnabled(true));
      success(await feedback.haptics.feedback(HapticsType.selection));
      expect(haptics.calls, [HapticsType.selection]);
    },
  );

  test('default no-op outputs need no platform player or assets', () async {
    final silent = FeedbackServices(
      store: SqliteFeedbackSettingsStore(h.db.database),
    );
    success(await silent.sfx.play(SfxType.tap));
    success(await silent.music.play(MusicScene.earth));
    await silent.music.pause();
    success(await silent.music.resume());
    await silent.music.stop();
    success(await silent.haptics.feedback(HapticsType.light));
  });
}
