import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/components/strannik_button.dart';
import 'package:strannik/presentation/stages/stage_progress_screen.dart';

import '../support/harness.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf')))
        .load();
  });
  for (final ready in [false, true]) {
    testWidgets(
      'Stage 2 requirements, navigation and confirmation ready=$ready',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = (await tester.runAsync(() async {
          final h = await Harness.create(
            contentSource: File('lib/content/seed/development.json')
                .readAsStringSync(),
          );
          await h.start();
          success(
            await h.game.progression.selectBigGoal(BigGoalType.spaceTaxi),
          );
          success(await h.game.progression.confirmBigGoal());
          await h.read(
            (r) async => r.pets.savePet(
              (await r.pets.pet())!.copyWith(
                currentStage: Stage.space,
                xp: ready ? 20 : 0,
              ),
            ),
          );
          if (ready) {
            success(await h.game.store.buyItem('titanium', quantity: 2));
            success(await h.game.store.buyItem('fuel'));
          }
          return h;
        }))!;
        addTearDown(h.db.close);
        var home = false, store = false, learning = false, bank = false;
        await tester.pumpWidget(
          MaterialApp(
            home: StageProgressScreen(
              game: h.game,
              onHome: () => home = true,
              onLearning: () => learning = true,
              onStore: () => store = true,
              onBank: () => bank = true,
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Этап 2 · Ракета'), findsOneWidget);
        expect(find.text('Дальше: этап 3 · Родная планета'), findsOneWidget);
        final transition = tester
            .widgetList<StrannikButton>(find.byType(StrannikButton))
            .singleWhere((b) => b.label == 'Перейти на стадию 3');
        expect(transition.onPressed != null, ready);
        Future<void> press(String text) async {
          await tester.ensureVisible(find.text(text));
          await tester.runAsync(() async {
            await tester.tap(find.text(text));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
        }

        await press('Задания этапа');
        expect(learning, true);
        await press('Моя цель в Банке');
        expect(bank, true);
        if (!ready) {
          await press('В магазин');
          expect(store, true);
        } else {
          await press('Перейти на стадию 3');
          expect(find.text('Подтвердить переход'), findsOneWidget);
          expect(home, false);
          await press('Подтвердить переход');
          expect(home, true);
          expect(
            (await tester.runAsync(() => h.read((r) => r.pets.pet())))!
                .currentStage,
            Stage.homePlanet,
          );
          final second = await tester.runAsync(
            () => h.game.progression.advanceStage(fromStage: Stage.space),
          );
          rejected(second!, Failure.alreadyCompleted);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
