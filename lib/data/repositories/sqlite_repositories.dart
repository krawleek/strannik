import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';

/// Transaction-scoped adapters. Never exposed directly to widgets.
class SqliteRepositories
    implements
        Repositories,
        ProfileRepository,
        ParentSettingsRepository,
        PetRepository,
        EconomyRepository,
        InventoryRepository,
        LearningRepository,
        ProgressRepository,
        AppStateRepository {
  SqliteRepositories(this.db);
  final DatabaseExecutor db;
  @override
  ProfileRepository get profiles => this;
  @override
  ParentSettingsRepository get parents => this;
  @override
  PetRepository get pets => this;
  @override
  EconomyRepository get economy => this;
  @override
  InventoryRepository get items => this;
  @override
  LearningRepository get learning => this;
  @override
  ProgressRepository get progress => this;
  @override
  AppStateRepository get system => this;
  DateTime date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
  DateTime? nullableDate(Object? value) => value == null ? null : date(value);
  Future<Map<String, Object?>?> one(
    String table, {
    String? where,
    List<Object?>? args,
  }) async {
    final rows = await db.query(table, where: where, whereArgs: args, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // UPDATE first keeps foreign keys intact (unlike INSERT OR REPLACE).
  Future<void> put(
    String table,
    Map<String, Object?> row, {
    String key = 'id',
  }) async {
    final count = await db.update(
      table,
      row,
      where: '$key = ?',
      whereArgs: [row[key]],
    );
    if (count == 0) await db.insert(table, row);
  }

  @override
  Future<ChildProfile?> profile() async {
    final r = await one('child_profile');
    return r == null
        ? null
        : ChildProfile(
            id: r['id'] as String,
            nickname: r['nickname'] as String,
            avatarId: r['avatar_id'] as String,
            onboardingCompleted: r['onboarding_completed'] == 1,
            createdAt: date(r['created_at']),
          );
  }

  @override
  Future<void> saveProfile(ChildProfile v) => put('child_profile', {
    'id': v.id,
    'nickname': v.nickname,
    'avatar_id': v.avatarId,
    'onboarding_completed': v.onboardingCompleted ? 1 : 0,
    'created_at': v.createdAt.millisecondsSinceEpoch,
  });
  @override
  Future<ParentSettings> parentSettings() async {
    final r = (await one('parent_settings'))!;
    return ParentSettings(
      credential: r['hash'] == null
          ? null
          : PinCredential(
              salt: r['salt'] as String,
              hash: r['hash'] as String,
              algorithm: r['algorithm'] as String,
              iterations: r['iterations'] as int,
            ),
      failedAttempts: r['failed_attempts'] as int,
      lockUntil: nullableDate(r['lock_until']),
    );
  }

  @override
  Future<void> saveParentSettings(ParentSettings v) => put('parent_settings', {
    'id': 1,
    'salt': v.credential?.salt,
    'hash': v.credential?.hash,
    'algorithm': v.credential?.algorithm,
    'iterations': v.credential?.iterations,
    'failed_attempts': v.failedAttempts,
    'lock_until': v.lockUntil?.millisecondsSinceEpoch,
  });
  @override
  Future<Pet?> pet() async {
    final r = await one('pet');
    return r == null
        ? null
        : Pet(
            id: r['id'] as String,
            childGivenName: r['child_given_name'] as String,
            alienName: r['alien_name'] as String,
            skinId: r['skin_id'] as String,
            currentStage: Stage.values.byName(r['stage'] as String),
            xp: r['xp'] as int,
            emotionalState: EmotionalState.values.byName(
              r['emotional_state'] as String,
            ),
            equippedAccessoryId: r['accessory_id'] as String?,
            activeToyId: r['toy_id'] as String?,
          );
  }

  @override
  Future<void> savePet(Pet v) => put('pet', {
    'id': v.id,
    'child_given_name': v.childGivenName,
    'alien_name': v.alienName,
    'skin_id': v.skinId,
    'stage': v.currentStage.name,
    'xp': v.xp,
    'emotional_state': v.emotionalState.name,
    'accessory_id': v.equippedAccessoryId,
    'toy_id': v.activeToyId,
  });
  @override
  Future<Wallet> wallet() async =>
      Wallet((await one('wallet'))!['amount'] as int);
  @override
  Future<void> saveWallet(Wallet v) =>
      put('wallet', {'id': 1, 'amount': v.firaAmount});
  @override
  Future<BudgetAllocation?> budget() async {
    final r = await one('budget_allocation');
    return r == null
        ? null
        : BudgetAllocation(
            mandatory: r['mandatory'] as int,
            optional: r['optional'] as int,
            remainder: r['remainder'] as int,
          );
  }

  @override
  Future<void> saveBudget(BudgetAllocation v) => put('budget_allocation', {
    'id': 1,
    'mandatory': v.mandatory,
    'optional': v.optional,
    'remainder': v.remainder,
  });
  @override
  Future<SavingsGoal?> savings() async {
    final r = await one('savings_goals');
    return r == null
        ? null
        : SavingsGoal(
            id: r['id'] as String,
            title: r['title'] as String,
            targetAmount: r['target'] as int,
            savedAmount: r['saved'] as int,
            createdAt: date(r['created_at']),
          );
  }

  @override
  Future<void> saveSavings(SavingsGoal v) => put('savings_goals', {
    'id': v.id,
    'title': v.title,
    'target': v.targetAmount,
    'saved': v.savedAmount,
    'created_at': v.createdAt.millisecondsSinceEpoch,
  });
  @override
  Future<List<Transaction>> transactions({String? periodId}) async =>
      (await db.query(
            'transactions',
            where: periodId == null ? null : 'period_id=?',
            whereArgs: periodId == null ? null : [periodId],
            orderBy: 'created_at,rowid',
          ))
          .map(
            (r) => Transaction(
              id: r['id'] as String,
              amount: r['amount'] as int,
              type: TransactionType.values.byName(r['type'] as String),
              source: TransactionSource.values.byName(r['source'] as String),
              createdAt: date(r['created_at']),
              periodId: r['period_id'] as String,
              relatedEntityId: r['related_entity_id'] as String?,
              category: r['category'] as String?,
              title: r['title'] as String?,
              description: r['description'] as String?,
              operationKey: r['operation_key'] as String?,
            ),
          )
          .toList();
  @override
  Future<void> recordTransaction(Transaction v) async {
    await db.insert('transactions', {
      'id': v.id,
      'amount': v.amount,
      'type': v.type.name,
      'source': v.source.name,
      'created_at': v.createdAt.millisecondsSinceEpoch,
      'period_id': v.periodId,
      'related_entity_id': v.relatedEntityId,
      'category': v.category,
      'title': v.title,
      'description': v.description,
      'operation_key': v.operationKey,
    });
  }

  @override
  Future<bool> hasTransactionKey(String key) async =>
      await one('transactions', where: 'operation_key=?', args: [key]) != null;
  InventoryEntry inventoryRow(Map<String, Object?> r) => InventoryEntry(
    id: r['id'] as String,
    category: ItemCategory.values.byName(r['category'] as String),
    quantity: r['quantity'] as int,
  );
  @override
  Future<InventoryEntry?> inventoryEntry(String id) async {
    final r = await one('inventory_entries', where: 'id=?', args: [id]);
    return r == null ? null : inventoryRow(r);
  }

  @override
  Future<List<InventoryEntry>> inventory() async =>
      (await db.query('inventory_entries')).map(inventoryRow).toList();
  @override
  Future<void> saveInventoryEntry(InventoryEntry v) => put(
    'inventory_entries',
    {'id': v.id, 'category': v.category.name, 'quantity': v.quantity},
  );
  @override
  Future<LearningProgress> learningProgress(String taskId) async {
    final r = await one(
      'learning_progress',
      where: 'task_id=?',
      args: [taskId],
    );
    return r == null
        ? LearningProgress(taskId: taskId)
        : LearningProgress(
            taskId: taskId,
            completionCount: r['completion_count'] as int,
            completedAt: nullableDate(r['completed_at']),
          );
  }

  @override
  Future<void> saveLearningProgress(LearningProgress v) =>
      put('learning_progress', {
        'task_id': v.taskId,
        'completion_count': v.completionCount,
        'completed_at': v.completedAt?.millisecondsSinceEpoch,
      }, key: 'task_id');
  LearningAttempt attemptRow(Map<String, Object?> r) => LearningAttempt(
    id: r['id'] as String,
    taskId: r['task_id'] as String,
    startedAt: date(r['started_at']),
    completedAt: nullableDate(r['completed_at']),
  );
  @override
  Future<LearningAttempt?> attempt(String id) async {
    final r = await one('learning_attempts', where: 'id=?', args: [id]);
    return r == null ? null : attemptRow(r);
  }

  @override
  Future<LearningAttempt?> openAttempt(String taskId) async {
    final r = await one(
      'learning_attempts',
      where: 'task_id=? AND completed_at IS NULL',
      args: [taskId],
    );
    return r == null ? null : attemptRow(r);
  }

  @override
  Future<void> saveAttempt(LearningAttempt v) => put('learning_attempts', {
    'id': v.id,
    'task_id': v.taskId,
    'started_at': v.startedAt.millisecondsSinceEpoch,
    'completed_at': v.completedAt?.millisecondsSinceEpoch,
  });
  @override
  Future<BigGoal?> bigGoal() async {
    final r = await one('big_goal');
    return r == null
        ? null
        : BigGoal(
            BigGoalType.values.byName(r['type'] as String),
            confirmedAt: nullableDate(r['confirmed_at']),
          );
  }

  @override
  Future<void> saveBigGoal(BigGoal v) => put('big_goal', {
    'id': 1,
    'type': v.type.name,
    'confirmed_at': v.confirmedAt?.millisecondsSinceEpoch,
  });
  GamePeriod periodRow(Map<String, Object?> r) => GamePeriod(
    id: r['id'] as String,
    kind: PeriodKind.values.byName(r['kind'] as String),
    startedAt: date(r['started_at']),
    endedAt: nullableDate(r['ended_at']),
  );
  @override
  Future<GamePeriod?> currentPeriod() async {
    final r = await one('game_periods', where: 'ended_at IS NULL');
    return r == null ? null : periodRow(r);
  }

  @override
  Future<List<GamePeriod>> periods() async => (await db.query(
    'game_periods',
    orderBy: 'started_at,rowid',
  )).map(periodRow).toList();
  @override
  Future<void> savePeriod(GamePeriod v) => put('game_periods', {
    'id': v.id,
    'kind': v.kind.name,
    'started_at': v.startedAt.millisecondsSinceEpoch,
    'ended_at': v.endedAt?.millisecondsSinceEpoch,
  });
  @override
  Future<void> recordEvent(ProgressEvent v) async {
    await db.insert('progress_events', {
      'id': v.id,
      'period_id': v.periodId,
      'type': v.type.name,
      'amount': v.amount,
      'resource_id': v.resourceId,
      'stage': v.stage?.name,
      'big_goal': v.bigGoal?.name,
      'created_at': v.createdAt.millisecondsSinceEpoch,
      'operation_key': v.operationKey,
    });
  }

  @override
  Future<List<ProgressEvent>> events(String periodId) async =>
      (await db.query(
            'progress_events',
            where: 'period_id=?',
            whereArgs: [periodId],
            orderBy: 'created_at,rowid',
          ))
          .map(
            (r) => ProgressEvent(
              id: r['id'] as String,
              periodId: periodId,
              type: ProgressEventType.values.byName(r['type'] as String),
              amount: r['amount'] as int,
              resourceId: r['resource_id'] as String?,
              stage: r['stage'] == null
                  ? null
                  : Stage.values.byName(r['stage'] as String),
              bigGoal: r['big_goal'] == null
                  ? null
                  : BigGoalType.values.byName(r['big_goal'] as String),
              createdAt: date(r['created_at']),
              operationKey: r['operation_key'] as String?,
            ),
          )
          .toList();
  @override
  Future<bool> hasEventKey(String key) async =>
      await one('progress_events', where: 'operation_key=?', args: [key]) !=
      null;
  @override
  Future<GamePeriodSummary?> periodSummary(String periodId) async {
    final r = await one(
      'period_summaries',
      where: 'period_id=?',
      args: [periodId],
    );
    if (r == null) return null;
    final resources = await db.query(
      'period_resource_summaries',
      where: 'period_id=?',
      whereArgs: [periodId],
    );
    return GamePeriodSummary(
      periodId: periodId,
      receivedFira: r['received'] as int,
      spentFira: r['spent'] as int,
      savedFira: r['saved'] as int,
      remainingFira: r['remaining'] as int,
      xpEarned: r['xp'] as int,
      materialsGained: {
        for (final v in resources)
          v['resource_id'] as String: v['gained'] as int,
      },
      goalResources: {
        for (final v in resources)
          v['resource_id'] as String: v['goal_amount'] as int,
      },
      stage: Stage.values.byName(r['stage'] as String),
      bigGoal: r['big_goal'] == null
          ? null
          : BigGoalType.values.byName(r['big_goal'] as String),
    );
  }

  @override
  Future<void> savePeriodSummary(GamePeriodSummary v) async {
    await put('period_summaries', {
      'period_id': v.periodId,
      'received': v.receivedFira,
      'spent': v.spentFira,
      'saved': v.savedFira,
      'remaining': v.remainingFira,
      'xp': v.xpEarned,
      'stage': v.stage.name,
      'big_goal': v.bigGoal?.name,
    }, key: 'period_id');
    await db.delete(
      'period_resource_summaries',
      where: 'period_id=?',
      whereArgs: [v.periodId],
    );
    for (final id in {...v.materialsGained.keys, ...v.goalResources.keys}) {
      await db.insert('period_resource_summaries', {
        'period_id': v.periodId,
        'resource_id': id,
        'gained': v.materialsGained[id] ?? 0,
        'goal_amount': v.goalResources[id] ?? 0,
      });
    }
  }

  @override
  Future<AppState> appState() async {
    final r = (await one('app_state'))!;
    return AppState(
      demoMode: r['demo_mode'] == 1,
      demoStage: r['demo_stage'] == null
          ? null
          : Stage.values.byName(r['demo_stage'] as String),
    );
  }

  @override
  Future<void> saveAppState(AppState v) => put('app_state', {
    'id': 1,
    'demo_mode': v.demoMode ? 1 : 0,
    'demo_stage': v.demoStage?.name,
  });
  @override
  Future<Set<String>> shownTooltips() async =>
      (await db.query('tooltip_flags')).map((r) => r['id'] as String).toSet();
  @override
  Future<void> markTooltipShown(String id) async {
    await db.insert('tooltip_flags', {
      'id': id,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> resetProgress() async {
    for (final table in [
      'period_resource_summaries',
      'period_summaries',
      'transactions',
      'progress_events',
      'learning_attempts',
      'learning_progress',
      'game_periods',
      'inventory_entries',
      'savings_goals',
      'big_goal',
      'budget_allocation',
      'pet',
      'tooltip_flags',
    ]) {
      await db.delete(table);
    }
    await saveWallet(Wallet(0));
    await saveAppState(const AppState());
    final child = await profile();
    if (child != null) {
      await saveProfile(child.copyWith(onboardingCompleted: false));
    }
  }

  @override
  Future<void> deleteAllData() async {
    await resetProgress();
    await db.delete('child_profile');
    await saveParentSettings(const ParentSettings());
    await db.update('app_state', {
      'sound_enabled': 1,
      'music_enabled': 1,
      'haptics_enabled': 1,
    }, where: 'id = 1');
  }
}
