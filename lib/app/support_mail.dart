import 'package:flutter/services.dart';

class SupportMail {
  static const channel = MethodChannel('strannik/support');
  Future<bool> open({bool recovery = false}) async {
    try {
      return await channel.invokeMethod<bool>('email', {
            'subject': recovery
                ? 'Восстановление доступа к родительскому разделу'
                : 'Вопросы и предложения — Странник',
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
