import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap.dart';
import '../../app/feedback/feedback_services.dart';
import '../../content/local_content_repository.dart';
import '../../data/local/database.dart';
import '../../domain/repositories/repositories.dart';
import '../home/home_controller.dart';

class HomeRuntime {
  HomeRuntime._(this.database, this.controller, this.feedback);
  final LocalDatabase database;
  final HomeController controller;
  final FeedbackServices feedback;

  static const developmentPreviewEnabled = bool.fromEnvironment(
    'STRANNIK_DEVELOPMENT_PREVIEW',
    defaultValue: kDebugMode,
  );

  static Future<HomeRuntime> open({
    bool allowDevelopmentPreview = developmentPreviewEnabled,
    ContentRepository? content,
  }) async {
    // Seed is definitions only. No grants, profiles, PINs or items are created.
    final catalog =
        content ??
        (allowDevelopmentPreview
            ? LocalContentRepository.fromJson(
                await rootBundle.loadString(
                  'lib/content/seed/development.json',
                ),
              )
            : null);
    final database = await openGameDatabase();
    final game = catalog == null
        ? null
        : GameServices(unitOfWork: database, content: catalog);
    final controller = HomeController(
      unitOfWork: database,
      allowDevelopmentPreview: allowDevelopmentPreview,
      content: catalog,
      interactions: game?.pet,
    );
    return HomeRuntime._(
      database,
      controller,
      createFeedbackServices(database),
    );
  }

  Future<void> close() async {
    controller.dispose();
    await database.close();
  }
}
