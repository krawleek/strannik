import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/financial_safety_topic.dart';
import 'package:strannik/presentation/learning/financial_safety_screen.dart';
import 'package:strannik/presentation/learning/financial_safety_topic_screen.dart';
import 'package:strannik/presentation/learning/learning_screen.dart';

import '../support/harness.dart';
import '../domain/financial_safety_test.dart'
    show safetyCatalog, stage3, finishSafety;

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
  for (final width in [360.0, 320.0]) {
    testWidgets(
      'guide preserves lesson state; actual lesson exits open finale at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final h = (await tester.runAsync(
          () => Harness.create(contentSource: safetyCatalog),
        ))!;
        await tester.runAsync(() async {
          await h.start();
          await stage3(h);
        });
        addTearDown(() => tester.runAsync(h.db.close));
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.pumpAndSettle();
        }

        Future<void> tap(Finder f) async {
          await tester.ensureVisible(f);
          await tester.tap(f);
          await settle();
        }

        Future<void> shot(String name) async {
          await settle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('topic-shot')),
                )
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('build/safety-qa/topic/$width');
            await dir.create(recursive: true);
            await File('${dir.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('topic-shot'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Manrope'),
              home: LearningScreen(
                unitOfWork: h.db,
                content: h.content,
                onBack: () {},
                onChanged: () async {},
              ),
            ),
          ),
        );
        await settle();
        expect(find.text('Финал после всех заданий'), findsOneWidget);
        await tap(find.text('Секретный звонок'));
        final c = tester
            .widget<FinancialSafetyScreen>(find.byType(FinancialSafetyScreen))
            .controller;
        await tester.runAsync(() => c.send('answer_call'));
        await settle();
        final node = c.progress.nodeId;
        final events = c.progress.events.toList();
        final balance = await tester.runAsync(h.balance);
        await tap(find.byTooltip('Справка'));
        expect(find.byType(FinancialSafetyGuide), findsOneWidget);
        await shot('guide-top');
        for (final tip in FinancialSafetyTopic.tips) {
          expect(find.text(tip.$1), findsOneWidget);
          expect(find.text(tip.$2), findsOneWidget);
        }
        await tester.ensureVisible(find.text('Вернуться к теме'));
        await shot('guide-bottom');
        await tap(find.text('Вернуться к теме'));
        expect(c.progress.nodeId, node);
        expect(c.progress.events, events);
        expect(await tester.runAsync(h.balance), balance);
        await tester.runAsync(() => finishSafety(c));
        await settle();
        await tap(find.text(c.lesson.exitLabel));
        await tap(find.text('Поздравляем, ты выиграл!'));
        final email = tester
            .widget<FinancialSafetyScreen>(find.byType(FinancialSafetyScreen))
            .controller;
        await tester.runAsync(() => finishSafety(email));
        await settle();
        await tap(find.text(email.lesson.exitLabel));
        expect(find.byType(FinancialSafetyFinale), findsOneWidget);
        expect(find.text('Ура! Тема пройдена!'), findsOneWidget);
        await shot('finale-reward');
        await tap(find.text('К Страннику'));
        await shot('finale-story');
        await tap(find.text('Продолжить приключение'));
        expect(find.text('2 из 2 заданий завершены'), findsOneWidget);
        await shot('completed-map');
        expect(await tester.runAsync(h.balance), 610);
        expect(await tester.runAsync(h.xp), 60);
        await tap(find.text('Финал темы'));
        await tap(find.text('Продолжить приключение'));
        expect(await tester.runAsync(h.balance), 610);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
