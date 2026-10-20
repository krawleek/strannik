import 'package:strannik/content/lessons/earth_topic_one.dart';
import 'package:strannik/presentation/learning/earth_topic_controller.dart';

import 'harness.dart';

Future<EarthTopicController> earthController(
  Harness h,
  String id, {
  bool replay = false,
}) async => EarthTopicController(
  h.game,
  success(await h.game.learning.beginTask(id, replay: replay)),
  rewardClaimed: (await h.read((r) => r.learning.learningProgress(id)))
      .completed,
);
Future<void> finishNeeds(EarthTopicController c) async {
  await c.change(() {
    c.step = 1;
  });
  for (final item in EarthTopicOne.items) {
    await c.classify(EarthTopicOne.necessary.contains(item.id));
  }
  await c.confirmBasket();
  await c.check('150');
}

Future<void> finishWeekly(EarthTopicController c, WeeklyBranch branch) async {
  await c.check('180');
  await c.advanceWeekly();
  for (var i = 0; i < 6; i++) {
    await c.change(() => c.simulation.allocate(true));
  }
  for (var i = 0; i < 2; i++) {
    await c.change(() => c.simulation.allocate(false));
  }
  await c.advanceWeekly();
  await c.change(() => c.simulation.choose(branch));
  await c.advanceWeekly();
  await c.advanceWeekly();
  await c.advanceWeekly();
}
