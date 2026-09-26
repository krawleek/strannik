import 'package:sqflite/sqflite.dart';

import '../../core/result.dart';
import '../../domain/repositories/repositories.dart';
import '../repositories/sqlite_repositories.dart';
import 'migrations/schema_v1.dart';

class LocalDatabase implements UnitOfWork {
  LocalDatabase._(this.database);
  final Database database;
  static const schemaVersion = 1;

  static Future<LocalDatabase> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA secure_delete = ON');
        },
        onCreate: (db, version) => migrate(db, 0, version),
        onUpgrade: migrate,
        onDowngrade: (db, oldVersion, newVersion) async =>
            throw StateError('Unsupported database downgrade'),
      ),
    );
    return LocalDatabase._(db);
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1 && newVersion >= 1) {
      for (final sql in schemaV1) {
        await db.execute(sql);
      }
    }
  }

  @override
  Future<Result<T>> run<T>(Future<T> Function(Repositories) operation) async {
    try {
      final value = await database.transaction(
        (tx) => operation(SqliteRepositories(tx)),
      );
      return Success(value);
    } on DomainRejection catch (error) {
      return Rejected(error.reason);
    } on DatabaseException {
      return const Rejected(Failure.persistenceFailure);
    }
  }

  Future<void> close() => database.close();
}
