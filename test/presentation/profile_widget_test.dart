import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/app/profile_playtime.dart';
import 'package:strannik/presentation/profile/profile_controller.dart';
import 'package:strannik/presentation/profile/profile_screen.dart';

import '../support/harness.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf'));
    await loader.load();
  });
  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    testWidgets(
      'profile at $size edits name, persists switch and protects reset',
      (tester) async {
        ProfileController? cForCleanup;
        final h = (await tester.runAsync(Harness.create))!;
        await tester.runAsync(h.start);
        addTearDown(() async {
          cForCleanup?.dispose();
          await tester.runAsync(h.db.close);
        });
        await tester.runAsync(() async {
          success(await h.game.profile.rename('Карина'));
          success(await h.game.profile.avatar('girl'));
        });
        final c = ProfileController(
          h.game,
          createFeedbackServices(h.db),
          PlaytimeService(h.db.database, clock: h.clock),
        );
        cForCleanup = c;
        await tester.runAsync(c.load);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: Scaffold(
                backgroundColor: const Color(0xFFD3E4FB),
                body: SafeArea(
                  child: ProfileScreen(
                    controller: c,
                    onBack: () {},
                    onReset: () async {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(c.load);
        await tester.pumpAndSettle();
        expect(find.text('Профиль'), findsOneWidget);
        expect(find.text('Карина'), findsOneWidget);
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/profile-qa').create(recursive: true);
          await File('build/profile-qa/profile-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.runAsync(() async {
          await tester.tap(find.text('Звуковые эффекты'));
          while (c.busy) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(c.settings.soundEnabled, false);
        await tester.tap(find.byTooltip('Изменить имя'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Аня');
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.text('Сохранить'));
          while (c.busy) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(c.overview!.profile!.nickname, 'Аня');
        await tester.ensureVisible(find.text('Сбросить прогресс'));
        await tester.tap(find.text('Сбросить прогресс'));
        await tester.pumpAndSettle();
        expect(find.text('Введите PIN-код'), findsOneWidget);
        expect(await tester.runAsync(h.balance), 100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
