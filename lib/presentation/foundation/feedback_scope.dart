import 'package:flutter/widgets.dart';

import '../../app/feedback/feedback_services.dart';

class FeedbackScope extends InheritedWidget {
  const FeedbackScope({
    super.key,
    required this.services,
    required super.child,
  });
  final FeedbackServices services;
  static FeedbackServices? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeedbackScope>()?.services;
  static Future<void> tap(BuildContext context) async {
    final feedback = of(context);
    if (feedback == null) return;
    try {
      await Future.wait([
        feedback.sfx.play(SfxType.tap),
        feedback.haptics.feedback(HapticsType.selection),
      ]);
    } catch (_) {
      // Feedback failure never prevents the action itself.
    }
  }

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) =>
      oldWidget.services != services;
}
