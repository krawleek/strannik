import 'package:flutter/foundation.dart';

import '../../app/bootstrap.dart';
import '../../app/feedback/feedback_services.dart';
import '../../app/profile_playtime.dart';
import '../../app/settings/feedback_settings.dart';
import '../../app/settings/notification_settings.dart';
import '../../core/result.dart';
import '../../domain/services/profile_service.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(
    this.game,
    this.feedback,
    this.playtime, {
    NotificationSettingsService? notifications,
  }) : notificationSettings =
           notifications ?? NotificationSettingsService(playtime.database);
  final NotificationSettingsService notificationSettings;
  final GameServices game;
  final FeedbackServices feedback;
  final PlaytimeService playtime;
  ProfileOverview? overview;
  FeedbackSettings settings = const FeedbackSettings();
  List<Duration> week = List.filled(7, Duration.zero);
  bool notifications = false, busy = false;
  String? error;
  bool _disposed = false;
  bool get parent => game.parentAccess.isAuthenticated;
  Object? get token => game.parentAccess.session;
  void publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final data = await game.profile.load();
    final prefs = await feedback.settings.read();
    if (data case Success(value: final value)) overview = value;
    if (prefs case Success(value: final value)) settings = value;
    if (data is Rejected || prefs is Rejected) {
      error = 'Не получилось загрузить профиль. Попробуйте ещё раз.';
    }
    try {
      week = await playtime.week();
      notifications = await notificationSettings.enabled();
    } catch (_) {
      error = 'Не получилось загрузить настройки и статистику.';
    }
    publish();
  }

  Future<bool> perform(Future<Result<void>> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    publish();
    try {
      final result = await action();
      if (result case Rejected(reason: final reason)) {
        error = switch (reason) {
          Failure.pinLocked => 'Три неверных попытки. Повторите через 5 минут или обратитесь в поддержку.',
          Failure.invalidPin => 'Неверный код! Попробуйте снова',
          Failure.locked => 'Android не разрешил уведомления. Разрешите их в настройках приложения и попробуйте снова.',
          Failure.unauthorized => 'Войдите как родитель ещё раз.',
          Failure.invalidAmount =>
            'Введите целое положительное количество фир.',
          _ => 'Не получилось сохранить изменения. Попробуйте ещё раз.',
        };
        return false;
      }
      await load();
      return true;
    } catch (_) {
      error = 'Не получилось сохранить изменения. Попробуйте ещё раз.';
      return false;
    } finally {
      busy = false;
      publish();
    }
  }

  Future<bool> setting(int index, bool enabled) => perform(() async {
    switch (index) {
      case 0:
        return feedback.settings.setSoundEnabled(enabled);
      case 1:
        final result = await feedback.settings.setMusicEnabled(enabled);
        if (result is Success<void>) {
          if (enabled) {
            await feedback.music.resume();
          } else {
            await feedback.music.stop();
          }
        }
        return result;
      case 2:
        return feedback.settings.setHapticsEnabled(enabled);
      case 3:
        return notificationSettings.setEnabled(enabled);
      default:
        return game.profile.demo(token, enabled);
    }
  });
  Future<bool> reward(int amount, String operationId) async {
    final success = await perform(
      () => game.economy.rewardInSession(token, amount, operationId),
    );
    if (success) {
      await notificationSettings.celebrate(amount, operationId);
      await feedback.haptics.feedback(HapticsType.success);
    }
    return success;
  }

  void logout() {
    game.parentAccess.endSession();
    publish();
  }

  @override
  void dispose() {
    _disposed = true;
    game.parentAccess.endSession();
    super.dispose();
  }
}
