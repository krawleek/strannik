import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart'
    show getDatabasesPath, databaseExists, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/content/lessons/financial_safety_topic.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/learning/financial_safety_topic_screen.dart';

/// Phase 2 runs in a new Android app process against the QA-only copy captured
/// after the full ordinary-UI journey. Never creates/seeds a player or reward.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'OS process restart restores the actual completed Stage 3 journey',
    (t) async {
      final filename =
          '${await getDatabasesPath()}/safety_acceptance_restart.db';
      expect(
        await databaseExists(filename),
        true,
        reason: 'Capture the full-journey QA save before running restart verification.',
      );
      final db = await LocalDatabase.open(filename);
      final content = LocalContentRepository.fromJson(
        await rootBundle.loadString('lib/content/seed/development.json'),
      );
      final game = GameServices(unitOfWork: db, content: content);
      final before = (await db.run(
        (r) async => (
          wallet: (await r.economy.wallet()).firaAmount,
          xp: (await r.pets.pet())!.xp,
          stage: (await r.pets.pet())!.currentStage,
          ledger: await r.economy.transactions(),
          topic: await r.learning.topicProgress(FinancialSafetyTopic.id),
          budget: await r.economy.budget(),
        ),
      )) as Success;
      expect(before.value.stage, Stage.homePlanet);
      expect(before.value.topic.finaleStep, 2);
      expect(before.value.topic.completed, true);
      expect(
        before.value.wallet,
        before.value.ledger.fold<int>(
          0,
          (int n, Transaction tx) => n + tx.availableDelta,
        ),
      );
      expect(
        before.value.ledger.where(
          (tx) => tx.operationKey == 'learningTopic:home_planet_safety',
        ),
        hasLength(1),
      );
      expect(before.value.xp, greaterThan(60));
      expect(before.value.budget, isNotNull);
      for (final stage in Stage.values) {
        final p = (await game.learning.stageProgress(stage)) as Success;
        expect(p.value.completed, p.value.required);
      }
      final home = HomeController(
        unitOfWork: db,
        allowDevelopmentPreview: false,
        content: content,
        interactions: game.pet,
      );
      await home.load();
      await t.pumpWidget(StrannikApp(controller: home));
      Future<void> settle() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await t.pumpAndSettle();
      }

      Future<void> tap(Finder f) async {
        await t.ensureVisible(f);
        await t.tap(f);
        await settle();
      }

      await settle();
      expect(find.bySemanticsLabel(RegExp('^Стадия 3')), findsOneWidget);
      debugPrint('SAFETY_CAPTURE:process-restart-home');
      await Future<void>.delayed(const Duration(seconds: 1));
      await tap(find.bySemanticsLabel('Обучение'));
      expect(find.text('2 из 2 заданий завершены'), findsOneWidget);
      await tap(find.text('Финал темы'));
      expect(find.byType(FinancialSafetyFinale), findsOneWidget);
      expect(find.text('Странник становится детективом'), findsOneWidget);
      await tap(find.text('Продолжить приключение'));
      final after = (await db.run(
        (r) async => (
          wallet: (await r.economy.wallet()).firaAmount,
          xp: (await r.pets.pet())!.xp,
          tx: (await r.economy.transactions()).length,
        ),
      )) as Success;
      expect(after.value.wallet, before.value.wallet);
      expect(after.value.xp, before.value.xp);
      expect(after.value.tx, before.value.ledger.length);
      debugPrint(
        'STAGE3_RESTART_VERIFIED:wallet=${after.value.wallet},xp=${after.value.xp}',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      home.dispose();
      await db.close();
      await deleteDatabase(filename);
    },
  );
}
