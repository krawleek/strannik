import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap.dart';
import '../../app/feedback/feedback_services.dart';
import '../../content/local_content_repository.dart';
import '../../data/local/database.dart';
import '../../domain/repositories/repositories.dart';
import '../home/home_controller.dart';
import '../profile/profile_controller.dart';
import '../store/store_controller.dart';
import '../../app/profile_playtime.dart';
import '../onboarding/onboarding_controller.dart';

class HomeRuntime {
  HomeRuntime._(
    this.database,
    this.controller,
    this.feedback,
    this.onboarding,
    this.profile,
    this.store,
  );
  final LocalDatabase database;
  final HomeController controller;
  final FeedbackServices feedback;
  final ProfileController profile;
  final StoreController store;
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
    final feedback = createFeedbackServices(database, platformOutputs: true);
    final profile = ProfileController(
      game,
      feedback,
      PlaytimeService(database.database),
    );
    return HomeRuntime._(
      database,
      controller,
      feedback,
      onboarding,
      profile,
      StoreController(game),
    );
  }

  Future<void> close() async {
    await profile.playtime.checkpoint(stop: true);
    profile.dispose();
    store.dispose();
    onboarding?.dispose();
    controller.dispose();
    await database.close();
  }
}
