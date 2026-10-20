import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/result.dart';

abstract interface class DeviceNotifications {
  Future<bool> allowed();
  Future<bool> requestPermission();
  Future<void> reward(int amount, String operationId);
  Future<void> clear();
}

class AndroidNotifications implements DeviceNotifications {
  const AndroidNotifications();
  static const channel = MethodChannel('strannik/notifications');
  Future<bool> _bool(String method) async {
    try {
      return await channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> allowed() => _bool('allowed');
  @override
  Future<bool> requestPermission() => _bool('requestPermission');
  @override
  Future<void> reward(int amount, String operationId) async {
    await channel.invokeMethod<void>('reward', {
      'amount': amount,
      'operationId': operationId,
    });
  }

  @override
  Future<void> clear() async {
    await channel.invokeMethod<void>('clear');
  }
}

/// Shares app_state with the existing settings, without caching across resets.
class NotificationSettingsService {
  NotificationSettingsService(
    this.database, {
    this.device = const AndroidNotifications(),
  });
  final Database database;
  final DeviceNotifications device;
  Future<bool> enabled() async {
    final row = (await database.query(
      'app_state',
      columns: ['notifications_enabled'],
      where: 'id = 1',
    )).single;
    return row['notifications_enabled'] == 1 && await device.allowed();
  }

  Future<Result<void>> setEnabled(bool value) async {
    try {
      if (value && !await device.requestPermission()) {
        return const Rejected(Failure.locked);
      }
      final count = await database.update('app_state', {
        'notifications_enabled': value ? 1 : 0,
      }, where: 'id = 1');
      if (count != 1) return const Rejected(Failure.persistenceFailure);
      if (!value) await clear();
      return const Success(null);
    } on DatabaseException {
      return const Rejected(Failure.persistenceFailure);
    }
  }

  Future<void> celebrate(int amount, String operationId) async {
    // Notification delivery is secondary to an already committed virtual reward.
    try {
      if (await enabled()) await device.reward(amount, operationId);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await device.clear();
    } catch (_) {}
  }
}
