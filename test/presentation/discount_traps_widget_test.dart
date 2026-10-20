import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/lessons/discount_traps_lesson.dart';
import 'package:strannik/presentation/learning/discount_traps_screen.dart';

import '../domain/discount_traps_test.dart' as fixture;
import '../support/harness.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [const Size(360, 800), const Size(320, 640)]) {
    testWidgets(
      'discount states, real basket gesture, retry, return at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = (await tester.runAsync(() async {
          final h = await Harness.create(contentSource: fixture.source);
          await h.start();
          await fixture.unlockDiscounts(h);
          return h;
        }))!;
        final c = (await tester.runAsync(() => fixture.begin(h)))!;
        addTearDown(() async {
          c.dispose();
          await h.db.close();
        });
        var closed = false;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(size.width == 320 ? 1.4 : 1),
              ),
              child: RepaintBoundary(
                key: boundary,
                child: DiscountTrapsScreen(
                  controller: c,
                  onClose: () async {
                    closed = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        Future<void> action(Future<void> Function() fn) async {
          await tester.runAsync(fn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 30));
          expect(tester.takeException(), isNull);
        }

        Future<void> capture(String name) async {
          if (size.width != 360) return;
          await tester.pump();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final d = Directory('build/stage2-qa/widgets');
            await d.create(recursive: true);
            await File('${d.path}/$name.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.runAsync(() async {
          final names = [
            'discount_store',
            'discount_cat',
            'discount_reward_cat',
            'discount_gummy_big',
            'discount_gummy_small',
            'discount_two_chips',
            'discount_dialogue_juice',
            'discount_basket',
            'discount_popcorn',
            'discount_juice',
            'discount_apples',
            'discount_chips',
            'discount_milk',
            'discount_fish',
            'discount_can',
            'discount_sausage',
            'glasses',
            'cat_shadow',
            'learning_background',
          ];
          await Future.wait(
            names.map(
              (n) => precacheImage(
                AssetImage('assets/learning/$n.png'),
                boundary.currentContext!,
              ),
            ),
          );
        });
        await tester.pumpAndSettle();
        await capture('intro');
        for (var step = 0; step < DiscountTrapsLesson.rulesStep; step++) {
          expect(c.step, step);
          if (step == 14) await capture('quantity');
          await action(c.advance);
        }
        await capture('rules');
        await action(c.advance);
        expect(find.text(DiscountTrapsLesson.rule), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 30));
        final field = find.byKey(const ValueKey('discount-field'));
        final rect = tester.getRect(field);
        await tester.tapAt(
          Offset(rect.left + 56 + .1 * (rect.width - 112), rect.bottom - 55),
        );
        for (var frame = 0; frame < 93; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        expect(
          c.progress.caught,
          1,
          reason: 'basket gesture catches the falling yellow popcorn',
        );
        await action(() => c.resolve(c.progress.round, caught: true));
        expect(c.progress.feedback, true);
        await capture('incorrect');
        await action(c.retry);
        for (var frame = 0; frame < 55; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await capture('game');
        await action(() => fixture.win(c));
        await capture('reward');
        expect(find.text('Задание\nвыполнено!'), findsOneWidget);
        await tester.ensureVisible(find.text('Ура!'));
        await tester.tap(find.text('Ура!'));
        await tester.pump();
        expect(closed, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
