import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/app/profile_playtime.dart';
import 'package:strannik/app/settings/notification_settings.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/presentation/profile/profile_controller.dart';

import '../support/harness.dart';

class FakeDeviceNotifications implements DeviceNotifications {
  bool permission = false;
  int sent = 0, cleared = 0;
  @override
  Future<bool> allowed() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> reward(int amount, String operationId) async {
    sent++;
  }

  @override
  Future<void> clear() async {
    cleared++;
  }
}

void main() {
  late Harness h;
  late FakeDeviceNotifications device;
  late NotificationSettingsService settings;
  setUp(() async {
    h = await Harness.create();
    await h.start();
    device = FakeDeviceNotifications();
    settings = NotificationSettingsService(h.db.database, device: device);
  });
  tearDown(() => h.db.close());
  test('denied system permission never produces an enabled switch', () async {
    rejected(await settings.setEnabled(true), Failure.locked);
    expect(await settings.enabled(), false);
    expect(
      (await h.db.database.query('app_state')).single['notifications_enabled'],
      0,
    );
  });
  test('preference persists, respects revoked permission, and disabling clears notifications', () async {
    device.permission = true;
    success(await settings.setEnabled(true));
    expect(
      await NotificationSettingsService(
        h.db.database,
        device: device,
      ).enabled(),
      true,
    );
    device.permission = false;
    expect(await settings.enabled(), false);
    device.permission = true;
    success(await settings.setEnabled(false));
    expect(device.cleared, 1);
    expect(await settings.enabled(), false);
  });
  test(
    'duplicate transfer sends only one notification after atomic credit',
    () async {
      device.permission = true;
      success(await settings.setEnabled(true));
      success(await h.game.parentAccess.authenticate('1234'));
      final c = ProfileController(
        h.game,
        createFeedbackServices(h.db),
        PlaytimeService(h.db.database, clock: h.clock),
        notifications: settings,
      );
      final results = await Future.wait([
        c.reward(50, 'duplicate'),
        c.reward(50, 'duplicate'),
      ]);
      expect(results.where((value) => value).length, 1);
      expect(await h.balance(), 150);
      expect(device.sent, 1);
      expect(await c.reward(50, 'duplicate'), false);
      expect(device.sent, 1);
      c.dispose();
    },
  );
}
