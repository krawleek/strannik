import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/content/economy_config.dart';
import 'package:strannik/core/clock.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/data/security/pbkdf2_pin_hasher.dart';
import 'package:strannik/domain/repositories/repositories.dart';

class FakeClock implements Clock {
  DateTime value = DateTime.utc(2026, 1, 1);
  @override
  DateTime now() => value;
  void advance(Duration duration) {
    value = value.add(duration);
  }
}

T success<T>(Result<T> result) {
  expect(result, isA<Success<T>>());
  return (result as Success<T>).value;
}

void rejected<T>(Result<T> result, Failure reason) {
  expect(result, isA<Rejected<T>>());
  expect((result as Rejected<T>).reason, reason);
}

class Harness {
  Harness(this.db, this.game, this.clock, this.content);
  final LocalDatabase db;
  final GameServices game;
  final FakeClock clock;
  final LocalContentRepository content;
  static Future<Harness> create({String? path, String? contentSource}) async {
    sqfliteFfiInit();
    final db = await LocalDatabase.open(
      path ?? inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final clock = FakeClock();
    final source =
        contentSource ??
        File('lib/content/seed/development.json').readAsStringSync();
    final fixture = jsonDecode(source) as Map<String, dynamic>;
    if (contentSource == null) {
      // Preserve the deliberately isolated legacy evaluator/economy fixture.
      fixture['tasks'].removeWhere((t) => t['type'] == 'earthTopicOne');
      for (final item in fixture['items']) {
        if (item['id'] == 'scarf') item['price'] = 15;
        if (item['id'] == 'ball') item['price'] = 10;
      }
      for (final task in fixture['tasks']) {
        if (['theme2_task', 'theme3_task', 'fraud_task'].contains(task['id'])) {
          task['rewardFira'] = 20;
          task['type'] = 'choice';
          task['implemented'] = true;
          task['enabled'] = true;
          task['rewardPolicy'] = 'oneTime';
        }
        if (task['id'] == 'practice') {
          task['implemented'] = true;
          task['rewardFira'] = 5;
        }
      }
      // Legacy service tests use their original 20-fira, zero-XP evaluator fixture.
      fixture['tasks'][0]['rewardFira'] = 20;
      fixture['tasks'][0]['rewardXp'] = 0;
      fixture['tasks'][0]['type'] = 'choice';
      fixture['tasks'][0]['themeId'] = 'theme1';
      fixture['themes'].removeWhere((t) => t['id'] == 'space_theme1');
      fixture['tasks'].removeWhere((t) => t['themeId'] == 'space_theme1');
    }
    final content = LocalContentRepository.fromJson(
      jsonEncode(fixture),
      economy: EconomyRules(
        startingBalance: contentSource == null
            ? 100
            : EconomyConfig.startingBalance,
      ),
    );
    final game = GameServices(
      unitOfWork: db,
      content: content,
      clock: clock,
      pinHasher: Pbkdf2PinHasher(iterations: 1000),
    );
    return Harness(db, game, clock, content);
  }

  Future<T> read<T>(Future<T> Function(Repositories) fn) async =>
      success(await db.run(fn));
  Future<void> start() async {
    success(
      await game.onboarding.saveDraft(
        nickname: 'Путник',
        avatarId: 'cat',
        petName: 'Кот',
        alienName: 'Зор',
        skinId: 'blue',
      ),
    );
    success(await game.parentAccess.setPin('1234'));
    success(await game.onboarding.complete());
  }

  Future<int> balance() async =>
      (await read((r) => r.economy.wallet())).firaAmount;
  Future<int> xp() async => (await read((r) => r.pets.pet()))!.xp;
  Future<int> quantity(String id) async =>
      (await read((r) => r.items.inventoryEntry(id)))?.quantity ?? 0;
  Future<void> complete(String taskId) async {
    final attempt = success(await game.learning.beginTask(taskId));
    success(
      await game.learning.completeLearningTask(attempt.id, successful: true),
    );
  }

  Future<void> unlockSavings() async {
    await complete('theme1_task');
    await complete('theme2_task');
  }
}
