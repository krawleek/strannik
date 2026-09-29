import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/components/strannik_button.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/onboarding/onboarding_controller.dart';
import 'package:strannik/presentation/onboarding/onboarding_flow.dart';

import '../support/harness.dart';

void main() {
  for (final height in [800.0, 960.0]) {
    testWidgets(
      'onboarding inputs at 360 x $height with keyboard and text scaling',
      (tester) async {
        tester.view.physicalSize = Size(360, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final h = (await tester.runAsync(Harness.create))!;
        final c = OnboardingController(h.game);
        final home = HomeController(
          unitOfWork: h.db,
          allowDevelopmentPreview: false,
        );
        await tester.runAsync(c.load);
        await tester.pumpWidget(StrannikApp(controller: home, onboarding: c));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingFlow), findsOneWidget);
        expect(find.text('Странник'), findsOneWidget);
        for (final step in [
          OnboardingStep.childName,
          OnboardingStep.petName,
          OnboardingStep.pin,
        ]) {
          c.step = step;
          c.parentConsent = step == OnboardingStep.pin;
          for (final keyboard in [0.0, 300.0]) {
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
            await tester.pumpWidget(
              StrannikApp(controller: home, onboarding: c),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final input = find.byType(TextField);
            await tester.ensureVisible(input);
            await tester.enterText(
              input,
              step == OnboardingStep.pin ? '12a34' : '  ',
            );
            await tester.pumpAndSettle();
            if (step == OnboardingStep.pin) {
              expect(tester.widget<TextField>(input).controller!.text, '1234');
              expect(tester.widget<TextField>(input).obscureText, true);
            } else {
              final button = tester.widget<StrannikButton>(
                find.widgetWithText(StrannikButton, 'Отправить'),
              );
              expect(button.onPressed, isNull);
              await tester.enterText(input, 'Алиса');
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<StrannikButton>(
                      find.widgetWithText(StrannikButton, 'Отправить'),
                    )
                    .onPressed,
                isNotNull,
              );
            }
            if (keyboard > 0) {
              final action = find.widgetWithText(
                StrannikButton,
                step == OnboardingStep.pin ? 'Сохранить' : 'Отправить',
              );
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              expect(
                tester.getBottomRight(action).dy,
                lessThanOrEqualTo(height - keyboard),
              );
            }
            expect(tester.takeException(), isNull);
          }
        }
        tester.view.resetViewInsets();
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        for (final step in OnboardingStep.values) {
          c.step = step;
          await tester.pumpWidget(StrannikApp(controller: home, onboarding: c));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$step');
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        home.dispose();
        await tester.runAsync(h.db.close);
      },
    );
  }

  testWidgets(
    'completed startup opens Home and system Back cannot reopen onboarding',
    (tester) async {
      final h = (await tester.runAsync(Harness.create))!;
      await tester.runAsync(h.start);
      final c = OnboardingController(h.game);
      final home = HomeController(
        unitOfWork: h.db,
        allowDevelopmentPreview: false,
      );
      await tester.runAsync(c.load);
      await tester.pumpWidget(StrannikApp(controller: home, onboarding: c));
      await tester.runAsync(home.load);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.text('0/3'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(await tester.runAsync(h.balance), 100);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      home.dispose();
      await tester.runAsync(h.db.close);
    },
  );
}
