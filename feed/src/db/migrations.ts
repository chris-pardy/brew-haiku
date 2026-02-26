import type { Migration } from "@brew-haiku/shared";

export const feedMigrations: Migration[] = [
  {
    version: 1,
    name: "initial_schema",
    up: (db) => {
      // Haiku posts table - stores indexed haiku posts for the feed
      db.run(`
        CREATE TABLE IF NOT EXISTS haiku_posts (
          uri TEXT PRIMARY KEY,
          did TEXT NOT NULL,
          cid TEXT NOT NULL,
          text TEXT NOT NULL,
          has_signature INTEGER DEFAULT 0,
          like_count INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          indexed_at INTEGER NOT NULL
        )
      `);

      db.run(`CREATE INDEX IF NOT EXISTS idx_haiku_did ON haiku_posts(did)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_haiku_created_at ON haiku_posts(created_at)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_haiku_like_count ON haiku_posts(like_count)`);

      // Schema version table
      db.run(`
        CREATE TABLE IF NOT EXISTS schema_version (
          version INTEGER PRIMARY KEY,
          applied_at INTEGER NOT NULL
        )
      `);
    },
  },
  {
    version: 2,
    name: "add_firehose_cursor",
    up: (db) => {
      db.run(`
        CREATE TABLE IF NOT EXISTS firehose_cursor (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          cursor_us INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      `);
    },
  },
  {
    version: 3,
    name: "add_haiku_likes",
    up: (db) => {
      db.run(`
        CREATE TABLE IF NOT EXISTS haiku_likes (
          like_uri TEXT PRIMARY KEY,
          post_uri TEXT NOT NULL,
          liker_did TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      `);

      db.run(`CREATE INDEX IF NOT EXISTS idx_haiku_likes_post ON haiku_likes(post_uri)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_haiku_likes_liker ON haiku_likes(liker_did)`);
    },
  },
  {
    version: 4,
    name: "add_category_scores",
    up: (db) => {
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_coffee REAL DEFAULT 0`);
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_tea REAL DEFAULT 0`);
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_morning REAL DEFAULT 0`);
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_afternoon REAL DEFAULT 0`);
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_evening REAL DEFAULT 0`);
    },
  },
  {
    version: 5,
    name: "add_nature_relaxation_scores",
    up: (db) => {
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_nature REAL DEFAULT 0`);
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_relaxation REAL DEFAULT 0`);
    },
  },
];
