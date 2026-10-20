/// Additive migration: all previous task, wallet, goal and inventory rows survive.
const schemaV6 = <String>[
  'CREATE TABLE learning_topic_progress(topic_id TEXT PRIMARY KEY, completed_at INTEGER, finale_step INTEGER NOT NULL DEFAULT 0 CHECK(finale_step BETWEEN 0 AND 2))',
];
