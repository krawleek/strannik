import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show getDatabasesPath, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/content/lessons/financial_safety_lesson.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/learning/financial_safety_screen.dart';
import 'package:strannik/presentation/learning/learning_screen.dart';
import 'package:strannik/presentation/learning/financial_safety_topic_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android Stage 3 calls, email, rewards, restart and replay', (
    tester,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final filename = path.join(await getDatabasesPath(), 'safety_qa.db');
    await deleteDatabase(filename);
    var db = await LocalDatabase.open(filename);
    final catalog = LocalContentRepository.fromJson(
      await rootBundle.loadString('lib/content/seed/development.json'),
    );
    var game = GameServices(unitOfWork: db, content: catalog);
    // Dedicated QA database, never the player's production save.

    void ok(Result<void> r) => expect(r, isA<Success<void>>());
    ok(
      await game.onboarding.saveDraft(
        nickname: 'Карина',
        avatarId: 'girl',
        petName: 'Веня',
        alienName: 'Зор',
        skinId: 'gray',
      ),
    );
    ok(await game.parentAccess.setPin('1234'));
    ok(await game.onboarding.complete());
    // Native navigation fixture only: permanent stage is seeded explicitly.
    await db.run(
      (r) async => r.pets.savePet(
        (await r.pets.pet())!.copyWith(currentStage: Stage.homePlanet),
      ),
    );
    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Manrope'),
          home: LearningScreen(
            unitOfWork: db,
            content: catalog,
            onBack: () {},
            onChanged: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> waitForLesson() async {
      for (
        var i = 0;
        i < 100 && find.byType(FinancialSafetyScreen).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(find.byType(FinancialSafetyScreen), findsOneWidget);
    }

    Future<void> tap(String text) async {
      final f = find.text(text);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      if (find.byType(FinancialSafetyScreen).evaluate().isNotEmpty) {
        final c = tester
            .widget<FinancialSafetyScreen>(find.byType(FinancialSafetyScreen))
            .controller;
        while (c.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      debugPrint('SAFETY_CAPTURE:$name');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }

    Future<void> configure(String name) async {
      debugPrint('SAFETY_CONFIG:$name');
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await show();

    await tester.pumpAndSettle();
    await capture('stage3-map');
    for (final title in ['Секретный звонок', 'Поздравляем, ты выиграл!']) {
      await tap(title);
      await waitForLesson();
      final c = tester
          .widget<FinancialSafetyScreen>(find.byType(FinancialSafetyScreen))
          .controller;
      await capture(
        c.lesson.taskId == FinancialSafetyLesson.callId
            ? 'call-incoming'
            : 'email-entry',
      );
      while (!c.completed) {
        final p = c.progress;
        if (p.node.view == SafetyView.question && !p.feedback) {
          // Exercise an incorrect branch, then recover through its explanation.
          final a = p.node.answers.firstWhere((a) => !a.correct);
          await tap(a.text);
          await tap('Проверить');
          await capture('${p.nodeId}-wrong');
        } else if (p.node.view == SafetyView.clues && p.clues.length < 3) {
          for (final id in ['sender', 'prize', 'link']) {
            final f = find.bySemanticsLabel(
              'Проверить: ${FinancialSafetyLesson.clueLabels[id]}',
            );
            await tester.ensureVisible(f);
            await tester.tap(f);
            await tester.pumpAndSettle();
          }
          await capture('email-clues');
        } else {
          if (p.node.view == SafetyView.prize) await capture('email-prize');
          if (p.nodeId == 'decision') await capture('call-choice');
          if (p.nodeId == 'demand') await capture('call-demand');
          if (p.node.view == SafetyView.card) {
            expect(find.byType(EditableText), findsNothing);
            await capture('mock-card');
            for (final variant in [
              'font130',
              'normal',
              'dark',
              'normal',
              'narrow',
            ]) {
              await configure(variant);
              if (variant != 'normal') await capture('mock-card-$variant');
            }
            await tester.ensureVisible(find.text('Далее'));
            await tester.pumpAndSettle();
            await capture('mock-card-narrow-cta');
            await configure('normal');
          }
          final a = p.node.actions.first;
          await tap(a.label);
        }
        expect(c.error, isNull);
      }
      await capture(
        c.lesson.taskId == FinancialSafetyLesson.callId
            ? 'call-reward'
            : 'email-reward',
      );
      await tap(c.lesson.exitLabel);
    }
    expect(find.byType(FinancialSafetyFinale), findsOneWidget);
    await capture('topic-reward');
    await tap('К Страннику');
    await capture('topic-detective');
    await tap('Продолжить приключение');
    await tap('Узнать больше');
    expect(find.byType(FinancialSafetyGuide), findsOneWidget);
    await capture('guide-top');
    await tester.ensureVisible(find.text('Вернуться к теме'));
    await capture('guide-bottom');
    await tap('Вернуться к теме');
    final money = await db.run((r) => r.economy.wallet());
    expect((money as Success).value.firaAmount, 610);
    await tester.pumpWidget(const SizedBox());
    await db.close();
    // Reopen the on-device SQLite save and recreate the navigation tree.
    db = await LocalDatabase.open(filename);
    game = GameServices(unitOfWork: db, content: catalog);
    final progress = await game.learning.stageProgress(Stage.homePlanet);
    expect((progress as Success).value, (completed: 2, required: 2));
    await show();
    await capture('stage3-restored');
    for (final title in ['Секретный звонок', 'Поздравляем, ты выиграл!']) {
      await tap(title);
      await waitForLesson();
      final c = tester
          .widget<FinancialSafetyScreen>(find.byType(FinancialSafetyScreen))
          .controller;
      expect(c.rewardClaimed, true);
      while (!c.completed) {
        final p = c.progress;
        if (p.node.view == SafetyView.question && !p.feedback) {
          await c.send(
            'answer:${p.node.answers.firstWhere((a) => a.correct).id}',
          );
          await c.send('check_answer');
        } else if (p.node.view == SafetyView.clues && p.clues.length < 3) {
          for (final id in ['link', 'prize', 'sender']) {
            await c.send('inspect:$id');
          }
        } else {
          await c.send(
            p.nodeId == 'decision' ? 'hang_up' : p.node.actions.first.id,
          );
        }
        await tester.pumpAndSettle();
      }
      await capture(
        c.lesson.taskId == FinancialSafetyLesson.callId
            ? 'call-replay'
            : 'email-replay',
      );
      await tap(c.lesson.exitLabel);
    }
    final wallet = await db.run((r) => r.economy.wallet());
    final pet = await db.run((r) => r.pets.pet());
    expect((wallet as Success).value.firaAmount, 610);
    expect((pet as Success).value.xp, 60);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
