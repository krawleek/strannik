import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/content/localization/fira_format.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/domain/models/models.dart';

void main() {
  test('negative monetary values, XP and quantities cannot enter models', () {
    expect(() => Wallet(-1), throwsA(isA<DomainRejection>()));
    expect(
      () => Pet(
        id: 'p',
        childGivenName: 'Кот',
        alienName: 'Зор',
        skinId: 'skin',
        xp: -1,
      ),
      throwsA(isA<DomainRejection>()),
    );
    expect(
      () => InventoryEntry(
        id: 'treat',
        category: ItemCategory.treat,
        quantity: -1,
      ),
      throwsA(isA<DomainRejection>()),
    );
    expect(
      () => InventoryEntry(
        id: 'titanium',
        category: ItemCategory.shipMaterial,
        quantity: -1,
      ),
      throwsA(isA<DomainRejection>()),
    );
    expect(
      () => InventoryEntry(
        id: 'scarf',
        category: ItemCategory.accessory,
        quantity: 2,
      ),
      throwsA(isA<DomainRejection>()),
    );
    expect(
      () => SavingsGoal(
        id: 's',
        title: 'Цель',
        targetAmount: 10,
        savedAmount: -1,
        createdAt: DateTime.utc(2026),
      ),
      throwsA(isA<DomainRejection>()),
    );
    expect(
      () => BudgetAllocation(mandatory: -1, optional: 0, remainder: 0),
      throwsA(isA<DomainRejection>()),
    );
  });
  test('negative catalog price is rejected before a purchase can exist', () {
    final json = jsonDecode(
      File('lib/content/seed/development.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    json['items'][0]['price'] = -50;
    expect(
      () => LocalContentRepository.fromJson(jsonEncode(json)),
      throwsA(isA<DomainRejection>()),
    );
  });
  test('content validates references, duplicate IDs and reward rules', () {
    final source = File('lib/content/seed/development.json').readAsStringSync();
    final json = jsonDecode(source) as Map<String, dynamic>;
    json['tasks'][0]['themeId'] = 'missing';
    expect(
      () => LocalContentRepository.fromJson(jsonEncode(json)),
      throwsFormatException,
    );
    final duplicate = jsonDecode(source) as Map<String, dynamic>;
    duplicate['items'].add(duplicate['items'][0]);
    expect(
      () => LocalContentRepository.fromJson(jsonEncode(duplicate)),
      throwsFormatException,
    );
    final rule = jsonDecode(source) as Map<String, dynamic>;
    rule['tasks'][0]['repeatRule'] = 'daily';
    expect(
      () => LocalContentRepository.fromJson(jsonEncode(rule)),
      throwsArgumentError,
    );
  });
  test('materials and learning task types are content identifiers, not closed enums', () {
    final json = jsonDecode(
      File('lib/content/seed/development.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    json['resources'].add({'id': 'crystal', 'title': 'Кристалл'});
    json['items'].add({
      'id': 'crystal',
      'title': 'Кристалл',
      'category': 'shipMaterial',
      'price': 3,
      'resourceId': 'crystal',
      'assetId': 'placeholder',
      'description': 'Тест',
    });
    json['tasks'][0]['type'] = 'futureTaskType';
    final content = LocalContentRepository.fromJson(jsonEncode(json));
    expect(content.item('crystal')!.resourceId, 'crystal');
    expect(content.tasks.first.type, 'futureTaskType');
  });
  test(
    'Russian fira inflection never renders English currency identifiers',
    () {
      expect(formatFira(1), '1 фира');
      expect(formatFira(2), '2 фиры');
      expect(formatFira(5), '5 фир');
      expect(formatFira(11), '11 фир');
      expect(formatFira(21), '21 фира');
      expect(formatFira(100), '100 фир');
      expect(formatFira(-20), '-20 фир');
      expect(formatFira(114), '114 фир');
    },
  );
}
