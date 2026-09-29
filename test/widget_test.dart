import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/home/home_controller.dart';

import 'support/harness.dart';

void main() {
  for (final height in [800.0, 960.0]) {
    testWidgets(
      'Home at 360 x $height: navigation, overlays and accessibility',
      (tester) async {
        tester.view.physicalSize = Size(360, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final h = (await tester.runAsync(Harness.create))!;
        final controller = HomeController(
          unitOfWork: h.db,
          allowDevelopmentPreview: true,
        );
        await tester.pumpWidget(StrannikApp(controller: controller));
        await tester.runAsync(controller.load);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Дом', 'Магазин', 'Банк', 'Обучение']) {
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
        expect(find.text('0/3'), findsOneWidget);
        await tester.tap(
          find.bySemanticsLabel('Странник. Действия с питомцем'),
        );
        await tester.pumpAndSettle();
        for (final label in ['Угостить', 'Поиграть', 'Погладить']) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text('Погладить'));
        await tester.pumpAndSettle();
        expect(find.text('Мур-р-р! Как приятно!'), findsOneWidget);
        await tester.tap(find.text('Хорошо'));
        await tester.pumpAndSettle();
        for (final label in [
          'Магазин',
          'Банк',
          'Обучение',
          'Профиль питомца',
          'Профиль ребёнка',
        ]) {
          // Profiles are in the Home header; return home between destinations.
          await tester.tap(find.bySemanticsLabel(label));
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget);
          await tester.tap(find.bySemanticsLabel('Дом'));
          await tester.runAsync(controller.load);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.bySemanticsLabel(RegExp('Стадия 1')));
        await tester.pumpAndSettle();
        expect(find.text('Стадии'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await tester.runAsync(h.db.close);
        semantics.dispose();
      },
    );
  }
}
