import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/app/profile_playtime.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/security/pbkdf2_pin_hasher.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  setUp(() async {
    h = await Harness.create();
    await h.start();
  });
  tearDown(() => h.db.close());
  test('session protects rewards, expires and ends on child return', () async {
    rejected(
      await h.game.economy.rewardInSession(null, 50, 'a'),
      Failure.unauthorized,
    );
    success(await h.game.parentAccess.authenticate('1234'));
    final token = h.game.parentAccess.session;
    rejected(
      await h.game.economy.rewardInSession(Object(), 50, 'a'),
      Failure.unauthorized,
    );
    success(await h.game.economy.rewardInSession(token, 50, 'a'));
    h.game.parentAccess.endSession();
    rejected(
      await h.game.economy.rewardInSession(token, 50, 'b'),
      Failure.unauthorized,
    );
    success(await h.game.parentAccess.authenticate('1234'));
    h.clock.advance(const Duration(minutes: 10));
    expect(h.game.parentAccess.isAuthenticated, false);
    rejected(
      await h.game.profile.delete(h.game.parentAccess.session),
      Failure.unauthorized,
    );
  });
  test(
    'simultaneous duplicate rewards commit wallet and ledger once',
    () async {
      success(await h.game.parentAccess.authenticate('1234'));
      final results = await Future.wait(
        List.generate(
          2,
          (_) => h.game.economy.rewardInSession(
            h.game.parentAccess.session,
            200,
            'same',
          ),
        ),
      );
      expect(results.whereType<Success<void>>().length, 1);
      expect(await h.balance(), 300);
      expect(
        (await h.read((r) => r.economy.transactions()))
            .where((t) => t.operationKey == 'parent:same')
            .length,
        1,
      );
    },
  );
  test(
    'progress is computed from actual content and task completion',
    () async {
      final before = success(await h.game.profile.load());
      expect(before.completedThemes, isEmpty);
      await h.complete('theme1_task');
      final after = success(await h.game.profile.load());
      expect(after.completedTasks, contains('theme1_task'));
      expect(
        after.completedThemes,
        contains(h.content.task('theme1_task')!.themeId),
      );
    },
  );
  test(
    'rename and avatar persist; reset and deletion remain distinct',
    () async {
      success(await h.game.profile.rename('  Карина  '));
      success(await h.game.profile.avatar('girl'));
      rejected(await h.game.profile.rename('  '), Failure.invalidState);
      success(await h.game.parentAccess.authenticate('1234'));
      success(await h.game.profile.reset(h.game.parentAccess.session));
      final profile = await h.read((r) => r.profiles.profile());
      expect(profile!.nickname, 'Карина');
      expect(profile.avatarId, 'girl');
      expect((await h.read((r) => r.parents.parentSettings())).hasPin, true);
      success(await h.game.profile.delete(h.game.parentAccess.session));
      expect(await h.read((r) => r.profiles.profile()), isNull);
      expect(h.game.parentAccess.isAuthenticated, false);
    },
  );
  test(
    'playtime excludes background and splits days at local midnight',
    () async {
      h.clock.value = DateTime(2026, 10, 18, 23, 59);
      final tracking = PlaytimeService(h.db.database, clock: h.clock);
      tracking.start();
      h.clock.advance(const Duration(minutes: 2));
      await tracking.checkpoint(stop: true);
      h.clock.advance(const Duration(hours: 4));
      await tracking.checkpoint(stop: true);
      final rows = await h.db.database.query('playtime', orderBy: 'day');
      expect(rows.map((r) => r['milliseconds']), [60000, 60000]);
      expect((await tracking.week()).map((d) => d.inMinutes), [
        1,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
      expect(tracking.averageMinutes(await tracking.week()), 1);
      success(await h.game.parentAccess.authenticate('1234'));
      success(await h.game.profile.delete(h.game.parentAccess.session));
      expect(await h.db.database.query('playtime'), isEmpty);
    },
  );
  test(
    'profile and playtime survive restart with no surviving session',
    () async {
      final dir = await Directory.systemTemp.createTemp('strannik-profile');
      final path = '${dir.path}/game.db';
      final original = await Harness.create(path: path);
      await original.start();
      success(await original.game.profile.rename('Карина'));
      final tracking = PlaytimeService(
        original.db.database,
        clock: original.clock,
      );
      tracking.start();
      original.clock.advance(const Duration(minutes: 3));
      await tracking.checkpoint(stop: true);
      success(await original.game.parentAccess.authenticate('1234'));
      await original.db.close();
      final reopened = await Harness.create(path: path);
      expect(
        success(await reopened.game.profile.load()).profile!.nickname,
        'Карина',
      );
      expect(
        (await reopened.db.database.query('playtime')).single['milliseconds'],
        180000,
      );
      final recreated = GameServices(
        unitOfWork: reopened.db,
        content: reopened.content,
        pinHasher: Pbkdf2PinHasher(iterations: 1000),
      );
      expect(recreated.parentAccess.isAuthenticated, false);
      await reopened.db.close();
      await dir.delete(recursive: true);
    },
  );
}
