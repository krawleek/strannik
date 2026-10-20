import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/data/local/migrations/schema_v1.dart';
import 'package:strannik/domain/models/models.dart';
import 'package:strannik/data/local/migrations/schema_v2.dart';
import 'package:strannik/data/local/migrations/schema_v3.dart';
import 'package:strannik/presentation/learning/shopping_list_controller.dart';

import '../support/harness.dart';

void main() {
  test('v3 upgrade preserves old data; draft and completion survive actual SQLite reopen', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('strannik-lesson-');
    final path = '${dir.path}/game.db';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          for (final sql in [...schemaV1, ...schemaV2, ...schemaV3]) {
            await db.execute(sql);
          }
        },
      ),
    );
    await old.close();
    final source = File('lib/content/seed/development.json').readAsStringSync();
    var h = await Harness.create(path: path, contentSource: source);
    await h.start();
    await h.read(
      (r) async => r.pets.savePet(
        (await r.pets.pet())!.copyWith(currentStage: Stage.space),
      ),
    );
    var attempt = success(await h.game.learning.beginTask('theme1_task'));
    var c = ShoppingListController(h.game, attempt, rewardClaimed: false);
    while (c.step != 11) {
      await c.advance();
    }
    await c.toggle('chips');
    await c.toggle('juice');
    final id = c.attempt.id;
    c.dispose();
    await h.db.close();
    h = await Harness.create(path: path, contentSource: source);
    attempt = success(await h.game.learning.beginTask('theme1_task'));
    expect(attempt.id, id);
    c = ShoppingListController(h.game, attempt, rewardClaimed: false);
    expect(c.step, 11);
    expect(c.budget.total, 300);
    expect(c.selected, {'chips', 'juice'});
    await c.confirm();
    c.dispose();
    await h.db.close();
    h = await Harness.create(path: path, contentSource: source);
    attempt = success(await h.game.learning.beginTask('theme1_task'));
    c = ShoppingListController(h.game, attempt, rewardClaimed: false);
    expect(c.step, 12);
    await c.finish();
    c.dispose();
    await h.db.close();
    h = await Harness.create(path: path, contentSource: source);
    expect(await h.balance(), 70);
    expect(await h.xp(), 15);
    expect(
      (await h.read((r) => r.learning.learningProgress('theme1_task')))
          .completed,
      true,
    );
    expect(await h.db.database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await h.db.close();
    await dir.delete(recursive: true);
  });
}
