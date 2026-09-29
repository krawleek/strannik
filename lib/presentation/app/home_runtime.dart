import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap.dart';
import '../../app/feedback/feedback_services.dart';
import '../../content/local_content_repository.dart';
import '../../data/local/database.dart';
import '../../domain/repositories/repositories.dart';
import '../home/home_controller.dart';
import '../onboarding/onboarding_controller.dart';

class HomeRuntime {
  HomeRuntime._(this.database, this.controller, this.feedback, this.onboarding);
  final LocalDatabase database;
  final HomeController controller;
  final FeedbackServices feedback;
  final OnboardingController? onboarding;

  static const developmentPreviewEnabled =
      kDebugMode &&
      bool.fromEnvironment('STRANNIK_DEVELOPMENT_PREVIEW', defaultValue: false);

  static Future<HomeRuntime> open({
    bool allowDevelopmentPreview = developmentPreviewEnabled,
    ContentRepository? content,
  }) async {
    // Existing local catalog definitions; loading them never seeds player state.
    // Product content may replace this catalog by injection without UI changes.
    final catalog =
        content ??
        LocalContentRepository.fromJson(
          await rootBundle.loadString('lib/content/seed/development.json'),
        );
    final database = await openGameDatabase();
    final game = GameServices(unitOfWork: database, content: catalog);
    final preview = kDebugMode && allowDevelopmentPreview;
    final controller = HomeController(
      unitOfWork: database,
      allowDevelopmentPreview: preview,
      content: catalog,
      interactions: game.pet,
    );
    final onboarding = preview ? null : OnboardingController(game);
    if (onboarding != null) await onboarding.load();
    return HomeRuntime._(
      database,
      controller,
      createFeedbackServices(database),
      onboarding,
    );
  }

  Future<void> close() async {
    onboarding?.dispose();
    controller.dispose();
    await database.close();
  }
}
