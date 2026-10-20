const schemaV3 = <String>[
  'ALTER TABLE app_state ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 0 CHECK(notifications_enabled IN (0,1))',
  'CREATE TABLE playtime(day TEXT PRIMARY KEY, milliseconds INTEGER NOT NULL CHECK(milliseconds>=0))',
];
