import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/bank/bank_controller.dart';
import 'package:strannik/presentation/bank/bank_screen.dart';
import 'package:strannik/presentation/home/home_controller.dart';

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
  for (final size in [
    const Size(360, 800),
    const Size(360, 960),
    const Size(320, 640),
  ]) {
    testWidgets(
      'Bank allocate, reallocate, actual history and spending at $size',
      (t) async {
        final h = (await t.runAsync(Harness.create))!;
        await t.runAsync(() async {
          await h.start();
          success(await h.game.economy.giveParentReward('1234', 100));
          success(
            await h.db.run(
              (r) => r.system.markTooltipShown(BankController.tooltipId),
            ),
          );
        });
        final c = BankController(h.game);
        await t.runAsync(c.load);
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.view.padding = const FakeViewPadding(top: 40, bottom: 24);
        if (size.width == 320) {
          t.platformDispatcher.textScaleFactorTestValue = 1.3;
        }
        addTearDown(() async {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          t.view.resetPadding();
          t.view.resetViewInsets();
          t.platformDispatcher.clearTextScaleFactorTestValue();
          c.dispose();
          await t.runAsync(h.db.close);
        });
        await t.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('bank-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Manrope'),
              home: BankScreen(
                game: h.game,
                controller: c,
                onHome: () {},
                onStore: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final context = t.element(find.byType(BankScreen));
          for (final file in Directory(
            'assets/bank',
          ).listSync().whereType<File>()) {
            if (file.path.endsWith('.png')) {
              await precacheImage(AssetImage(file.path), context);
            }
          }
        });
        await t.pumpAndSettle();
        Future<void> snap(String name) async {
          if (size != const Size(360, 800)) return;
          await t.pumpAndSettle();
          await t.runAsync(() async {
            final image = await t
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('bank-capture')),
                )
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('build/bank-qa/widgets');
            await dir.create(recursive: true);
            await File('${dir.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        Future<void> tap(Finder f) async {
          await t.ensureVisible(f);
          await t.runAsync(() async {
            await t.tap(f);
            while (c.busy) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          });
          await t.pumpAndSettle();
        }

        Future<void> enter(String label, String value) async {
          final field = find.byKey(ValueKey('amount-$label'));
          await t.ensureVisible(field);
          await t.enterText(field, value);
          await t.pumpAndSettle();
        }

        expect(find.text('Денежный счёт'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Доступный баланс: 200 фир'),
          findsOneWidget,
        );
        expect(find.text('Подарок от родителей'), findsOneWidget);
        expect(find.text('Подарок за знакомство'), findsOneWidget);
        expect(find.text('Распределить 200 фир'), findsOneWidget);
        await snap('01-initial-bank');
        await tap(find.text('Распределить 200 фир'));
        for (final name in ['Нужно', 'Хочу', 'Коплю']) {
          await enter(name, '50');
        }
        expect(find.text('Осталось распределить: 50 фир'), findsOneWidget);
        await snap('02-allocation-editor');
        await enter('Нужно', '-1');
        expect(c.validDraft, false);
        await snap('03-invalid-amount');
        await enter('Нужно', '50');
        await tap(find.text('Сохранить'));
        expect(find.text('Готово! Фиры распределены'), findsOneWidget);
        await snap('04-success');
        await tap(find.text('Отлично'));
        expect(find.text('Распределить 50 фир'), findsOneWidget);
        await snap('05-allocated-bank');
        await tap(find.bySemanticsLabel('Нужно: 50 фир. Изменить план'));
        await tap(find.bySemanticsLabel('Хочу: 50 фир. Выбрать источник'));
        await enter('Сумма перераспределения', '20');
        await snap('06-reallocation-editor');
        await tap(find.text('Сохранить'));
        expect(c.snapshot!.plan.mandatory, 70);
        expect(c.snapshot!.plan.optional, 30);
        expect(c.available, 200);
        expect(c.snapshot!.history, hasLength(2));
        await tap(find.text('Отлично'));
        await tap(find.text('Вся история'));
        expect(find.text('+100 фир'), findsNWidgets(2));
        await tap(find.byKey(const ValueKey('bank-back')));
        await t.runAsync(() async {
          success(await h.game.store.buyItem('treat', quantity: 11));
          await c.load();
        });
        await t.pumpAndSettle();
        expect(find.text('Исправить план'), findsOneWidget);
        expect(find.textContaining('на 5 фир больше'), findsOneWidget);
        expect(c.snapshot!.plan.total, 150);
        await snap('07-plan-exceeds-wallet');
        await tap(find.text('Исправить план'));
        await enter('Коплю', '45');
        // Simulated Android keyboard and enlarged text keep CTA accessible.
        t.view.viewInsets = const FakeViewPadding(bottom: 250);
        await t.pumpAndSettle();
        expect(
          t.getBottomRight(find.text('Сохранить')).dy,
          lessThanOrEqualTo(size.height - 250),
        );
        await tap(find.text('Сохранить'));
        t.view.resetViewInsets();
        await t.pumpAndSettle();
        expect(c.snapshot!.plan.total, 145);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'production Bank route and ordered dismissible tooltip use persistent flags',
    (t) async {
      final h = (await t.runAsync(Harness.create))!;
      await t.runAsync(h.start);
      final home = HomeController(
        unitOfWork: h.db,
        allowDevelopmentPreview: false,
        content: h.content,
      );
      await t.runAsync(home.load);
      await t.pumpWidget(StrannikApp(controller: home));
      await t.runAsync(home.load);
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Банк'));
      // FFI runs on a real isolate; wait for actual DB reads, not virtual frames.
      for (
        var i = 0;
        i < 100 && find.textContaining('У нас есть фиры!').evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.byType(BankScreen), findsOneWidget);
      for (final text in ['У нас есть фиры!', 'Нужно —', 'Хочу —', 'Коплю —']) {
        expect(find.textContaining(text), findsOneWidget);
        await t.tap(find.text(text == 'Коплю —' ? 'Всё понятно' : 'Далее'));
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await t.pumpAndSettle();
      }
      expect(
        await t.runAsync(() => h.read((r) => r.system.shownTooltips())),
        contains(BankController.tooltipId),
      );
      await t.tap(find.byKey(const ValueKey('bank-back')));
      await t.runAsync(home.load);
      await t.pumpAndSettle();
      expect(find.byType(BankScreen), findsNothing);
      await t.pumpWidget(const SizedBox());
      home.dispose();
      await t.runAsync(h.db.close);
    },
  );
}
