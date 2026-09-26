/// Existing users receive enabled defaults without modifying game state.
const schemaV2 = <String>[
  'ALTER TABLE app_state ADD COLUMN sound_enabled INTEGER NOT NULL DEFAULT 1 CHECK(sound_enabled IN (0,1))',
  'ALTER TABLE app_state ADD COLUMN music_enabled INTEGER NOT NULL DEFAULT 1 CHECK(music_enabled IN (0,1))',
  'ALTER TABLE app_state ADD COLUMN haptics_enabled INTEGER NOT NULL DEFAULT 1 CHECK(haptics_enabled IN (0,1))',
];
