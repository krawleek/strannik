import 'package:sqflite/sqflite.dart';

import '../../app/settings/feedback_settings.dart';
import '../../core/result.dart';

/// Shares the existing database. Does not cache values across resets/restarts.
class SqliteFeedbackSettingsStore implements FeedbackSettingsStore {
  const SqliteFeedbackSettingsStore(this.database);
  final Database database;

  @override
  Future<Result<FeedbackSettings>> read() async {
    try {
      final rows = await database.query('app_state', where: 'id = 1');
      if (rows.isEmpty) return const Rejected(Failure.persistenceFailure);
      final row = rows.single;
      return Success(
        FeedbackSettings(
          soundEnabled: row['sound_enabled'] == 1,
          musicEnabled: row['music_enabled'] == 1,
          hapticsEnabled: row['haptics_enabled'] == 1,
        ),
      );
    } on DatabaseException {
      return const Rejected(Failure.persistenceFailure);
    }
  }

  @override
  Future<Result<void>> update({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
  }) async {
    final values = <String, Object?>{
      if (soundEnabled != null) 'sound_enabled': soundEnabled ? 1 : 0,
      if (musicEnabled != null) 'music_enabled': musicEnabled ? 1 : 0,
      if (hapticsEnabled != null) 'haptics_enabled': hapticsEnabled ? 1 : 0,
    };
    if (values.isEmpty) return const Success(null);
    try {
      final count = await database.transaction(
        (tx) => tx.update('app_state', values, where: 'id = 1'),
      );
      return count == 1
          ? const Success(null)
          : const Rejected(Failure.persistenceFailure);
    } on DatabaseException {
      return const Rejected(Failure.persistenceFailure);
    }
  }
}
