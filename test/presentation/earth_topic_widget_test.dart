import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/earth_topic_one.dart';
import 'package:strannik/presentation/learning/earth_topic_screen.dart';

import '../support/harness.dart';
import '../support/earth_lessons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final weight in ['Bold', 'ExtraBold', 'SemiBold']) {
      final loader = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
      await loader.load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(360, 960),
    const Size(320, 640),
  ]) {
    testWidgets(
      'Earth lessons all major states at $size, keyboard and text scaling',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final h = await t.runAsync(
          () => Harness.create(
            contentSource: File('lib/content/seed/development.json')
                .readAsStringSync(),
          ),
        );
        await t.runAsync(h!.start);
        final boundary = GlobalKey();
        Future<void> show(dynamic c, String name) async {
          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Manrope'),
              home: RepaintBoundary(
                key: boundary,
                child: EarthTopicScreen(
                  controller: c,
                  onClose: () async {},
                  onNext: () async {},
                  onHome: () async {},
                ),
              ),
            ),
          );
          await t.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          });
          await t.pumpAndSettle();
          for (final image in t.widgetList<Image>(find.byType(Image))) {
            await t.runAsync(
              () => precacheImage(
                image.image,
                t.element(find.byType(EarthTopicScreen)),
              ),
            );
          }
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: name);
          if (size.height == 800) {
            await t.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final f = File('build/stage1-qa/widgets/$name.png');
              await f.parent.create(recursive: true);
              await f.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }

        var c = await t.runAsync(
          () => earthController(h, EarthTopicOne.needsId),
        );
        await show(c, '01-intro');
        await t.runAsync(
          () => c!.change(() {
            c!.step = 1;
          }),
        );
        await show(c, '02-classification');
        for (var i = 0; i < 6; i++) {
          await t.runAsync(() => c!.classify(true));
        }
        await show(c, '03-basket');
        await t.runAsync(
          () => c!.change(() {
            c!.step = 3;
          }),
        );
        await show(c, '04-selection-grid');
        for (final id in ['clip', 'ball', 'glasses']) {
          await t.runAsync(() => c!.toggle(id));
        }
        await t.runAsync(c!.confirmBasket);
        await show(c, '05-total');
        await t.runAsync(() => c!.check('140'));
        await show(c, '06-wrong');
        t.view.viewInsets = const FakeViewPadding(bottom: 280);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        t.view.resetViewInsets();
        await t.runAsync(() => c!.check('150'));
        await show(c, '07-needs-complete');
        c.dispose();
        c = await t.runAsync(() => earthController(h, EarthTopicOne.weeklyId));
        await show(c, '08-weekly');
        await t.runAsync(() => c!.check('180'));
        await show(c, '09-income');
        await t.runAsync(c!.advanceWeekly);
        await show(c, '10-allocation');
        for (var i = 0; i < 6; i++) {
          await t.runAsync(() => c!.change(() => c!.simulation.allocate(true)));
        }
        for (var i = 0; i < 2; i++) {
          await t.runAsync(
            () => c!.change(() => c!.simulation.allocate(false)),
          );
        }
        await t.runAsync(c.advanceWeekly);
        await show(c, '11-shop');
        await t.runAsync(
          () => c!.change(() => c!.simulation.choose(WeeklyBranch.wait)),
        );
        await show(c, '12-next-income');
        await t.runAsync(c.advanceWeekly);
        await show(c, '13-summary');
        await t.runAsync(c.advanceWeekly);
        await show(c, '14-second-shop');
        await t.runAsync(c.advanceWeekly);
        await show(c, '15-weekly-complete');
        c.dispose();
        c = await t.runAsync(() => earthController(h, EarthTopicOne.goalId));
        await show(c, '16-dream');
        await t.runAsync(
          () => c!.change(() {
            c!.step = 1;
          }),
        );
        await show(c, '17-goals');
        await t.runAsync(
          () => c!.chooseGoal(h.content.stageRequirements.first.bigGoal),
        );
        await t.runAsync(c!.confirmGoal);
        await show(c, '18-initial-plan');
        await t.runAsync(() => c!.initialPlan(70, 40));
        await show(c, '19-goal-allocation');
        await t.runAsync(() => c!.allocateGoal(20));
        await show(c, '20-goal-complete');
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await t.runAsync(h.db.close);
      },
    );
  }
}
