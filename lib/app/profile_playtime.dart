import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';

String calendarDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Checkpoints only foreground child usage. Splits intervals at local midnight.
class PlaytimeService {
  PlaytimeService(this.database, {this.clock = const SystemClock()});
  final Database database;
  final Clock clock;
  DateTime? _since;
  Future<void>? _queue;
  void start() {
    _since ??= clock.now();
  }

  Future<void> checkpoint({bool stop = false}) {
    final end = clock.now(), start = _since;
    _since = stop ? null : (_since == null ? null : end);
    if (start == null || !end.isAfter(start)) return _queue ?? Future.value();
    final pending = (_queue ?? Future<void>.value()).then(
      (_) => database.transaction((tx) async {
        var cursor = start;
        while (cursor.isBefore(end)) {
          final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
          final next = midnight.isBefore(end) ? midnight : end;
          final milliseconds = next.difference(cursor).inMilliseconds;
          await tx.rawInsert(
            'INSERT INTO playtime(day,milliseconds) VALUES(?,?) ON CONFLICT(day) DO UPDATE SET milliseconds=milliseconds+excluded.milliseconds',
            [calendarDay(cursor), milliseconds],
          );
          cursor = next;
        }
      }),
    );
    _queue = pending.catchError((Object _) {});
    return pending;
  }

  Future<List<Duration>> week() async {
    await checkpoint();
    final now = clock.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final rows = await database.query(
      'playtime',
      where: 'day >= ? AND day <= ?',
      whereArgs: [
        calendarDay(monday),
        calendarDay(DateTime(monday.year, monday.month, monday.day + 6)),
      ],
    );
    final data = {
      for (final row in rows) row['day']: row['milliseconds'] as int,
    };
    return List.generate(
      7,
      (i) => Duration(
        milliseconds:
            data[calendarDay(
              DateTime(monday.year, monday.month, monday.day + i),
            )] ??
            0,
      ),
    );
  }

  double averageMinutes(List<Duration> week) =>
      week.fold<int>(0, (a, b) => a + b.inMilliseconds) /
      Duration.millisecondsPerMinute /
      clock.now().weekday;
}
