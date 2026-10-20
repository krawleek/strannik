import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/presentation/components/pet_appearance.dart';
import 'package:strannik/presentation/store/store_controller.dart';
import 'package:strannik/presentation/store/store_screen.dart';

import '../support/harness.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf'));
    await fonts.load();
  });
  for (final size in [
    const Size(360, 800),
    const Size(412, 915),
    const Size(320, 640),
  ]) {
    testWidgets('Store and Closet purchase/equipment at $size', (tester) async {
      final h = (await tester.runAsync(Harness.create))!;
      await tester.runAsync(h.start);
      await tester.runAsync(() async {
        final pet = (await h.read((r) => r.pets.pet()))!;
        success(
          await h.db.run((r) => r.pets.savePet(pet.copyWith(skinId: 'orange'))),
        );
        success(
          await h.game.economy.allocateBudget(
            mandatory: 50,
            optional: 10,
            remainder: 40,
          ),
        );
      });
      final c = StoreController(h.game);
      await tester.runAsync(c.load);
      addTearDown(() async {
        c.dispose();
        await tester.runAsync(h.db.close);
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      bool home = false, learning = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Manrope'),
          home: RepaintBoundary(
            key: const ValueKey('store-capture'),
            child: StoreScreen(
              controller: c,
              onHome: () => home = true,
              onLearning: () => learning = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> snap(String state) async {
        if (size.width != 360) return;
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('store-capture')),
              )
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/store-qa/widgets').create(recursive: true);
          await File('build/store-qa/widgets/$state.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.runAsync(() async {
          await tester.tap(finder);
          while (c.busy) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
      }

      await snap('store');
      await tap(find.bySemanticsLabel('Шкаф'));
      expect(
        find.text('Шкаф пока пуст. Но скоро тут появится твоя первая покупка!'),
        findsOneWidget,
      );
      await snap('empty-closet');
      await tap(find.bySemanticsLabel('Магазин'));
      await tap(find.bySemanticsLabel(RegExp(r'^Шарфик\.')));
      expect(c.previewAccessory, 'scarf');
      expect(c.snapshot!.pet!.equippedAccessoryId, isNull);
      expect(c.snapshot!.wallet.firaAmount, 100);
      await snap('preview');
      await tap(find.bySemanticsLabel('Корзина'));
      expect(find.text('Корзина'), findsOneWidget);
      await snap('cart');
      await tap(find.text('Купить'));
      expect(find.text('Выбери счет'), findsOneWidget);
      await snap('accounts');
      await tap(find.text('Хочу'));
      expect(find.textContaining('Покупка выше плана'), findsOneWidget);
      await tap(find.text('Оплатить 15 фир'));
      expect(find.text('Ура! Покупка твоя!'), findsOneWidget);
      expect(c.snapshot!.wallet.firaAmount, 85);
      await snap('success');
      await tap(find.text('Назад в магазин'));
      await tap(find.bySemanticsLabel('Шкаф'));
      await snap('populated-closet');
      await tap(find.bySemanticsLabel(RegExp(r'^Шарфик\.')));
      expect(c.snapshot!.pet!.equippedAccessoryId, 'scarf');
      await snap('equipped');
      expect(
        tester.widget<PetAppearance>(find.byType(PetAppearance)).accessoryId,
        'scarf',
      );
      await tap(find.bySemanticsLabel(RegExp(r'^Шарфик\.')));
      expect(c.snapshot!.pet!.equippedAccessoryId, isNull);
      await tap(find.bySemanticsLabel('Магазин'));
      await tester.runAsync(() async {
        success(await h.game.store.buyItem('treat', quantity: 17));
        await c.load();
      });
      await tester.pumpAndSettle();
      await tap(find.bySemanticsLabel(RegExp(r'^Мяч\.')));
      await tap(find.bySemanticsLabel('Корзина'));
      await tap(find.text('Купить'));
      expect(find.text('Ой, фир не хватает!'), findsOneWidget);
      expect(find.text('10 ₣'), findsWidgets);
      await snap('insufficient');
      await tap(find.text('Накопить и вернуться позже'));
      expect(learning, false);
      expect(home, false);
      await tap(find.bySemanticsLabel(RegExp(r'^Мяч\.')));
      await tap(find.bySemanticsLabel('Корзина'));
      await tap(find.text('Купить'));
      await tap(find.text('Заработать в заданиях'));
      expect(learning, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
