import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/financial_safety_lesson.dart';
import 'package:strannik/presentation/learning/financial_safety_controller.dart';
import 'package:strannik/presentation/learning/financial_safety_screen.dart';
import 'package:strannik/presentation/learning/learning_screen.dart';

import '../support/harness.dart';
import '../domain/financial_safety_test.dart'
    show safetyCatalog, stage3, safetyController;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final style in ['SemiBold', 'Bold', 'ExtraBold']) {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope-$style.ttf'))).load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(412, 915),
    const Size(320, 640),
  ]) {
    testWidgets('Stage 3 scenarios, feedback and safe mock controls at $size', (
      tester,
    ) async {
      final h = (await tester.runAsync(
        () => Harness.create(contentSource: safetyCatalog),
      ))!;
      await tester.runAsync(() async {
        await h.start();
        await stage3(h);
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final controllers = <FinancialSafetyController>[];
      addTearDown(() async {
        for (final c in controllers) {
          c.dispose();
        }
        await tester.runAsync(h.db.close);
      });
      Future<void> show(FinancialSafetyController c) async {
        controllers.add(c);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('safety-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Manrope'),
              home: FinancialSafetyScreen(controller: c, onClose: () {}),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(FinancialSafetyScreen));
          for (final asset in [
            'assets/learning/cat_avatar.png',
            'assets/learning/safety_bubble.png',
            'assets/learning/safety_unknown.png',
            'assets/learning/safety_scammer.png',
            'assets/learning/learning_background.png',
            'assets/learning/reward_cat.png',
            'assets/learning/glasses.png',
            'assets/icons/stage_star.png',
          ]) {
            await precacheImage(AssetImage(asset), context, onError: (_, _) {});
          }
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
      }

      Future<void> snap(String state) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('safety-capture')),
              )
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(
            'build/safety-qa/widgets/${size.width.toInt()}',
          );
          await dir.create(recursive: true);
          await File('${dir.path}/$state.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> event(FinancialSafetyController c, String event) async {
        await tester.runAsync(() => c.send(event));
        await tester.pumpAndSettle();
      }

      final c = (await tester.runAsync(
        () => safetyController(h, FinancialSafetyLesson.callId),
      ))!;
      await show(c);
      expect(find.text('Входящий звонок…'), findsOneWidget);
      await snap('call-incoming');
      for (final e in ['answer_call', 'listen', 'listen', 'listen', 'listen']) {
        await event(c, e);
      }
      expect(c.progress.nodeId, 'decision');
      await snap('call-choice');
      await event(c, 'listen');
      await event(c, 'ask');
      await snap('call-demand');
      await event(c, 'next');
      await tester.ensureVisible(find.text('Он представился полковником'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Он представился полковником'));
        while (c.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(c.progress.selectedId, 'rank');
      await snap('call-selected');
      await event(c, 'check_answer');
      await snap('call-wrong');
      await event(c, 'next');
      await event(c, 'answer:adult');
      await event(c, 'check_answer');
      await snap('call-correct');
      await event(c, 'next');
      await snap('call-conclusion');
      await event(c, 'finish');
      await snap('call-reward');
      expect(find.text('Ты раскрыл обман!'), findsOneWidget);
      final email = (await tester.runAsync(
        () => safetyController(h, FinancialSafetyLesson.emailId),
      ))!;
      await show(email);
      await snap('email-entry');
      await event(email, 'next');
      await event(email, 'answer:check');
      await event(email, 'check_answer');
      await snap('email-feedback');
      await event(email, 'next');
      for (final id in ['sender', 'prize', 'link']) {
        final finder = find.bySemanticsLabel(
          'Проверить: ${FinancialSafetyLesson.clueLabels[id]}',
        );
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          while (email.busy) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        await snap('email-clue-$id');
      }
      expect(email.progress.clues, hasLength(3));
      await event(email, 'next');
      await event(email, 'check_prize');
      await snap('email-prize');
      expect(await tester.runAsync(h.balance), 70);
      await event(email, 'discuss');
      await event(email, 'answer:small');
      await event(email, 'check_answer');
      await snap('email-fee-wrong');
      await event(email, 'next');
      await snap('email-card');
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('0000 0000 0000 0000'), findsOneWidget);
      await event(email, 'next');
      await snap('email-delete');
      await event(email, 'finish');
      await snap('email-reward');
      expect(await tester.runAsync(h.balance), 110);
      expect(await tester.runAsync(h.xp), 30);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Stage 3 navigation opens either task and returns with refreshed progress',
    (tester) async {
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(finder, findsOneWidget);
      }

      final h = (await tester.runAsync(
        () => Harness.create(contentSource: safetyCatalog),
      ))!;
      await tester.runAsync(() async {
        await h.start();
        await stage3(h);
      });
      addTearDown(() => tester.runAsync(h.db.close));
      await tester.pumpWidget(
        MaterialApp(
          home: LearningScreen(
            unitOfWork: h.db,
            content: h.content,
            onBack: () {},
            onChanged: () async {},
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await waitFor(find.text('Этап 3'));
      expect(find.text('Список покупок'), findsNothing);
      await tester.runAsync(
        () => tester.tap(find.text('Поздравляем, ты выиграл!')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      for (
        var i = 0;
        i < 100 && find.byType(FinancialSafetyScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final screen = tester.widget<FinancialSafetyScreen>(
        find.byType(FinancialSafetyScreen),
      );
      expect(screen.controller.lesson.taskId, FinancialSafetyLesson.emailId);
      await tester.runAsync(() async => screen.onClose());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('Этап 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
