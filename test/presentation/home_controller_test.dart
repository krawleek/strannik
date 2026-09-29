import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/presentation/assets/presentation_assets.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/home/home_view_state.dart';

import '../support/harness.dart';

void main() {
  late Harness h;
  late HomeController controller;
  setUp(() async {
    h = await Harness.create();
    controller = HomeController(
      unitOfWork: h.db,
      allowDevelopmentPreview: true,
      content: h.content,
      interactions: h.game.pet,
    );
  });
  tearDown(() async {
    controller.dispose();
    await h.db.close();
  });

  test('preview interactions leave every SQLite table unchanged', () async {
    Future<Map<String, Object?>> snapshot() async {
      final tables = await h.db.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      return {
        for (final table in tables)
          table['name']! as String: await h.db.database.query(
            table['name']! as String,
          ),
      };
    }

    final before = await snapshot();
    await controller.load();
    expect(controller.state.status, HomeLoadStatus.preview);
    expect(controller.state.snapshot, isNull);
    controller.toggleActions();
    await controller.giveTreat();
    await controller.play();
    controller.strokePet();
    await controller.load();
    expect(await snapshot(), before);
  });

  test('preview can be disabled on an empty database', () async {
    final normal = HomeController(
      unitOfWork: h.db,
      allowDevelopmentPreview: false,
    );
    addTearDown(normal.dispose);
    await normal.load();
    expect(normal.state.status, HomeLoadStatus.needsOnboarding);
  });

  test(
    'effective stage follows demo override; fallback leaves IDs intact',
    () async {
      await h.start();
      success(await h.game.demo.setEnabled('1234', true));
      success(await h.game.demo.changeDemoStage('1234', Stage.homePlanet));
      await controller.load();
      expect(controller.state.effectiveStage, Stage.homePlanet);
      expect(controller.state.snapshot!.pet!.currentStage, Stage.earth);
      expect(PresentationAssets.skin('blue').isFallback, true);
      expect(PresentationAssets.avatar('cat').isFallback, true);
      expect((await h.read((r) => r.pets.pet()))!.skinId, 'blue');
      expect((await h.read((r) => r.profiles.profile()))!.avatarId, 'cat');
      success(await h.game.demo.setEnabled('1234', false));
      await controller.load();
      expect(controller.state.effectiveStage, Stage.earth);
    },
  );

  test('missing items and petting give no currency, items or XP', () async {
    await h.start();
    await controller.load();
    await controller.giveTreat();
    expect(controller.state.reaction, contains('нет вкусняшек'));
    await controller.play();
    expect(controller.state.reaction, contains('активная игрушка'));
    controller.strokePet();
    expect(await h.balance(), 100);
    expect(await h.xp(), 0);
    expect(await h.read((r) => r.items.inventory()), isEmpty);
  });

  test(
    'treat and active toy use existing domain rules; busy guards repeated taps',
    () async {
      await h.start();
      success(await h.game.store.buyItem('treat', quantity: 2));
      success(await h.game.store.buyItem('ball'));
      await controller.load();
      await controller.play();
      expect(await h.xp(), 0); // Owning a toy does not activate it.
      success(await h.game.pet.activateToy('ball'));
      await controller.load();
      final balance = await h.balance();
      final first = controller.giveTreat();
      expect(controller.state.busy, true);
      controller
          .dismissReaction(); // Navigation cannot unlock an in-flight action.
      await controller.giveTreat();
      await first;
      expect(await h.quantity('item:treat'), 1);
      expect(await h.xp(), h.content.item('treat')!.interactionXp);
      await controller.play();
      final xp = await h.xp();
      expect(
        xp,
        h.content.item('treat')!.interactionXp +
            h.content.item('ball')!.interactionXp,
      );
      await controller.play();
      controller.strokePet();
      expect(await h.xp(), xp);
      expect(await h.balance(), balance);
    },
  );
}
