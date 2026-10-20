import 'package:flutter/services.dart';

import 'feedback_services.dart';

/// Platform click respects the device's sound settings. No downloaded audio.
class PlatformSfxOutput implements SfxOutput {
  const PlatformSfxOutput();
  @override
  Future<void> play(SfxType type) async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } on PlatformException {
      // A device without system feedback must not block gameplay.
    } on MissingPluginException {
      // Non-mobile previews have no platform output.
    }
  }
}

class PlatformHapticsOutput implements HapticsOutput {
  const PlatformHapticsOutput();
  @override
  Future<void> feedback(HapticsType type) async {
    try {
      switch (type) {
        case HapticsType.selection:
          await HapticFeedback.selectionClick();
        case HapticsType.light:
          await HapticFeedback.lightImpact();
        case HapticsType.success:
        case HapticsType.stageCompleted:
          await HapticFeedback.mediumImpact();
        case HapticsType.warning:
          await HapticFeedback.heavyImpact();
      }
    } on PlatformException {
      // No vibration motor, disabled system feedback, or unsupported platform.
    } on MissingPluginException {
      // Keep tests/previews usable without a native host.
    }
  }
}
