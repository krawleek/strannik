/// Preserve the selected alternative and every existing financial/progress row.
const schemaV5 = <String>[
  '''ALTER TABLE big_goal RENAME TO big_goal_v4''',
  '''CREATE TABLE big_goal(id INTEGER PRIMARY KEY CHECK(id=1), type TEXT NOT NULL CHECK(type IN ('repairShip','contactHome','spaceTaxi')), confirmed_at INTEGER, completed_at INTEGER)''',
  '''INSERT INTO big_goal(id,type,confirmed_at) SELECT id, CASE WHEN type='adaptOnEarth' THEN 'spaceTaxi' ELSE type END, confirmed_at FROM big_goal_v4''',
  '''DROP TABLE big_goal_v4''',
  '''UPDATE progress_events SET big_goal='spaceTaxi' WHERE big_goal='adaptOnEarth' ''',
  '''UPDATE period_summaries SET big_goal='spaceTaxi' WHERE big_goal='adaptOnEarth' ''',
];
