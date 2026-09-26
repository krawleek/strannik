import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/app/feedback/feedback_services.dart';
import 'package:strannik/app/settings/feedback_settings.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';

import '../support/harness.dart';

void main() {
  late Directory directory;
  late String path;
  late Harness h;
  late FeedbackServices feedback;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('strannik-feedback-');
    path = '${directory.path}/game.db';
    h = await Harness.create(path: path);
    feedback = createFeedbackServices(h.db);
  });
  tearDown(() async {
    await h.db.close();
    await directory.delete(recursive: true);
  });

  Future<FeedbackSettings> read() async =>
      success(await feedback.settings.read());

  test(
    'all three defaults are enabled in model and fresh local storage',
    () async {
      const defaults = FeedbackSettings();
      expect(defaults.soundEnabled, true);
      expect(defaults.musicEnabled, true);
      expect(defaults.hapticsEnabled, true);
      final stored = await read();
      expect(stored.soundEnabled, true);
      expect(stored.musicEnabled, true);
      expect(stored.hapticsEnabled, true);
    },
  );

  test(
    'each switch persists independently, including concurrent updates',
    () async {
      success(await feedback.settings.setSoundEnabled(false));
      expect((await read()).soundEnabled, false);
      expect((await read()).musicEnabled, true);
      expect((await read()).hapticsEnabled, true);
      success(await feedback.settings.setMusicEnabled(false));
      expect((await read()).soundEnabled, false);
      expect((await read()).musicEnabled, false);
      expect((await read()).hapticsEnabled, true);
      success(await feedback.settings.setHapticsEnabled(false));
      expect((await read()).hapticsEnabled, false);
      success(await feedback.settings.setSoundEnabled(true));
      expect((await read()).soundEnabled, true);
      expect((await read()).musicEnabled, false);
      expect((await read()).hapticsEnabled, false);
      for (final result in await Future.wait([
        feedback.settings.setSoundEnabled(false),
        feedback.settings.setMusicEnabled(true),
        feedback.settings.setHapticsEnabled(true),
      ])) {
        success(result);
      }
      final result = await read();
      expect(result.soundEnabled, false);
      expect(result.musicEnabled, true);
      expect(result.hapticsEnabled, true);
    },
  );

  test('all settings survive database close and reopen', () async {
    success(await feedback.settings.setSoundEnabled(false));
    success(await feedback.settings.setMusicEnabled(false));
    success(await feedback.settings.setHapticsEnabled(false));
    await h.db.close();
    h = await Harness.create(path: path);
    feedback = createFeedbackServices(h.db);
    final stored = await read();
    expect(stored.soundEnabled, false);
    expect(stored.musicEnabled, false);
    expect(stored.hapticsEnabled, false);
  });

  test('demo changes and progress reset preserve settings', () async {
    await h.start();
    success(await feedback.settings.setSoundEnabled(false));
    success(await feedback.settings.setMusicEnabled(false));
    success(await feedback.settings.setHapticsEnabled(false));
    success(await h.game.demo.setEnabled('1234', true));
    success(await h.game.demo.changeDemoStage('1234', Stage.space));
    success(await h.game.localData.resetProgress('1234'));
    final stored = await read();
    expect(stored.soundEnabled, false);
    expect(stored.musicEnabled, false);
    expect(stored.hapticsEnabled, false);
    expect(await h.balance(), 0);
    expect((await h.read((r) => r.parents.parentSettings())).hasPin, true);
  });

  test(
    'delete all data restores enabled defaults after reopening too',
    () async {
      await h.start();
      success(await feedback.settings.setSoundEnabled(false));
      success(await feedback.settings.setMusicEnabled(false));
      success(await feedback.settings.setHapticsEnabled(false));
      success(await h.game.localData.deleteAllData('1234'));
      final defaults = await read();
      expect(defaults.soundEnabled, true);
      expect(defaults.musicEnabled, true);
      expect(defaults.hapticsEnabled, true);
      await h.db.close();
      h = await Harness.create(path: path);
      feedback = createFeedbackServices(h.db);
      final reopened = await read();
      expect(reopened.soundEnabled, true);
      expect(reopened.musicEnabled, true);
      expect(reopened.hapticsEnabled, true);
    },
  );

  test(
    'v1 migration preserves prior game state and adds enabled defaults',
    () async {
      await h.db.close();
      await databaseFactoryFfi.deleteDatabase(path);
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
        ),
      );
      await old.update('wallet', {'amount': 77});
      await old.update('app_state', {'demo_mode': 1, 'demo_stage': 'space'});
      await old.insert('child_profile', {
        'id': 'existing',
        'nickname': 'Путник',
        'avatar_id': 'cat',
        'onboarding_completed': 0,
        'created_at': 123,
      });
      await old.close();
      h = await Harness.create(path: path);
      feedback = createFeedbackServices(h.db);
      expect(await h.db.database.getVersion(), 2);
      expect(await h.balance(), 77);
      expect((await h.read((r) => r.profiles.profile()))!.nickname, 'Путник');
      expect((await h.read((r) => r.system.appState())).demoStage, Stage.space);
      final stored = await read();
      expect(stored.soundEnabled, true);
      expect(stored.musicEnabled, true);
      expect(stored.hapticsEnabled, true);
    },
  );

  test(
    'write failure is reported and does not change other settings',
    () async {
      await h.db.database.execute(
        "CREATE TRIGGER fail_settings BEFORE UPDATE OF sound_enabled ON app_state BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      rejected(
        await feedback.settings.setSoundEnabled(false),
        Failure.persistenceFailure,
      );
      expect((await read()).soundEnabled, true);
      success(await feedback.settings.setMusicEnabled(false));
      expect((await read()).musicEnabled, false);
    },
  );
}
