import 'dart:convert';

import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';

/// Reads an explicitly provided bundled document; no networking or user state.
class LocalContentRepository implements ContentRepository {
  LocalContentRepository.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported content version');
    }
    resources = List.unmodifiable(
      (json['resources'] as List).map(
        (r) => ResourceDefinition(r['id'] as String, r['title'] as String),
      ),
    );
    storeItems = List.unmodifiable(
      (json['items'] as List).map(
        (r) => StoreItem(
          id: r['id'],
          title: r['title'],
          category: ItemCategory.values.byName(r['category']),
          price: r['price'],
          assetId: r['assetId'],
          description: r['description'],
          requiredXp: r['requiredXp'] ?? 0,
          requiredStage: Stage.values.byName(r['requiredStage'] ?? 'earth'),
          interactionXp: r['interactionXp'] ?? 0,
          resourceId: r['resourceId'],
          available: r['available'] ?? true,
        ),
      ),
    );
    themes = List.unmodifiable(
      (json['themes'] as List).map(
        (r) => LearningTheme(id: r['id'], title: r['title'], order: r['order']),
      ),
    );
    tasks = List.unmodifiable(
      (json['tasks'] as List).map(
        (r) => LearningTask(
          id: r['id'],
          themeId: r['themeId'],
          title: r['title'],
          type: r['type'],
          rewardFira: r['rewardFira'],
          order: r['order'],
          contentReference: r['contentReference'],
          rewardPolicy: RewardPolicy.values.byName(r['rewardPolicy']),
          repeatRule: RepeatRule.values.byName(
            r['repeatRule'] ?? 'newCompletedAttempt',
          ),
        ),
      ),
    );
    stageRequirements = List.unmodifiable(
      (json['stageRequirements'] as List).map(
        (r) => StageRequirements(
          from: Stage.values.byName(r['from']),
          to: Stage.values.byName(r['to']),
          bigGoal: BigGoalType.values.byName(r['bigGoal']),
          requiredXp: r['requiredXp'],
          workXp: r['workXp'] ?? 0,
          resources: (r['resources'] as List)
              .map((v) => ResourceRequirement(v['resourceId'], v['amount']))
              .toList(),
        ),
      ),
    );
    savingsUnlockThemeId = json['savingsUnlockThemeId'];
    _validate();
  }
  @override
  late final List<StoreItem> storeItems;
  @override
  late final List<ResourceDefinition> resources;
  @override
  late final List<LearningTheme> themes;
  @override
  late final List<LearningTask> tasks;
  @override
  late final List<StageRequirements> stageRequirements;
  @override
  late final String savingsUnlockThemeId;
  @override
  StoreItem? item(String id) {
    for (final v in storeItems) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  LearningTask? task(String id) {
    for (final v in tasks) {
      if (v.id == id) return v;
    }
    return null;
  }

  void _validate() {
    void check(bool value) {
      if (!value) {
        throw const FormatException('Invalid content references or duplicates');
      }
    }

    bool unique(Iterable<Object> ids) => ids.toSet().length == ids.length;
    check(
      unique(storeItems.map((v) => v.id)) &&
          unique(resources.map((v) => v.id)) &&
          unique(themes.map((v) => v.id)) &&
          unique(tasks.map((v) => v.id)),
    );
    check(themes.length == 4 && unique(themes.map((v) => v.order)));
    final themeIds = themes.map((v) => v.id).toSet();
    final resourceIds = resources.map((v) => v.id).toSet();
    check(themeIds.contains(savingsUnlockThemeId));
    for (final task in tasks) {
      check(
        themeIds.contains(task.themeId) &&
            task.type.isNotEmpty &&
            task.contentReference.isNotEmpty,
      );
    }
    for (final theme in themes) {
      final ordered = tasks.where(
        (t) => t.themeId == theme.id && t.rewardPolicy == RewardPolicy.oneTime,
      );
      check(ordered.isNotEmpty && unique(ordered.map((t) => t.order)));
    }
    for (final item in storeItems) {
      check(
        item.resourceId == null ||
            (item.category == ItemCategory.shipMaterial &&
                resourceIds.contains(item.resourceId)),
      );
    }
    check(
      unique(stageRequirements.map((v) => '${v.from.name}:${v.bigGoal.name}')),
    );
    for (final requirements in stageRequirements) {
      check(unique(requirements.resources.map((v) => v.resourceId)));
      for (final resource in requirements.resources) {
        check(resourceIds.contains(resource.resourceId));
      }
    }
  }
}
