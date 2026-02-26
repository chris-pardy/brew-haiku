import { Database } from "bun:sqlite";

export interface Migration {
  version: number;
  name: string;
  up: (db: Database) => void;
}

export const migrations: Migration[] = [
  {
    version: 1,
    name: "initial_schema",
    up: (db: Database) => {
      // Timer index table - stores timer recipes
      db.run(`
        CREATE TABLE IF NOT EXISTS timer_index (
          uri TEXT PRIMARY KEY,
          did TEXT NOT NULL,
          cid TEXT NOT NULL,
          handle TEXT,
          name TEXT NOT NULL,
          vessel TEXT NOT NULL,
          brew_type TEXT NOT NULL,
          ratio REAL,
          steps TEXT NOT NULL,
          save_count INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          indexed_at INTEGER NOT NULL
        )
      `);

      db.run(`CREATE INDEX IF NOT EXISTS idx_timer_did ON timer_index(did)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_timer_brew_type ON timer_index(brew_type)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_timer_vessel ON timer_index(vessel)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_timer_save_count ON timer_index(save_count)`);

      // FTS5 virtual table for full-text search on timers
      db.run(`
        CREATE VIRTUAL TABLE IF NOT EXISTS timer_search USING fts5(
          uri,
          name,
          vessel,
          handle,
          content=timer_index,
          content_rowid=rowid
        )
      `);

      // Triggers to keep FTS5 index in sync
      db.run(`
        CREATE TRIGGER IF NOT EXISTS timer_ai AFTER INSERT ON timer_index BEGIN
          INSERT INTO timer_search(rowid, uri, name, vessel, handle)
          VALUES (NEW.rowid, NEW.uri, NEW.name, NEW.vessel, NEW.handle);
        END
      `);

      db.run(`
        CREATE TRIGGER IF NOT EXISTS timer_ad AFTER DELETE ON timer_index BEGIN
          INSERT INTO timer_search(timer_search, rowid, uri, name, vessel, handle)
          VALUES ('delete', OLD.rowid, OLD.uri, OLD.name, OLD.vessel, OLD.handle);
        END
      `);

      db.run(`
        CREATE TRIGGER IF NOT EXISTS timer_au AFTER UPDATE ON timer_index BEGIN
          INSERT INTO timer_search(timer_search, rowid, uri, name, vessel, handle)
          VALUES ('delete', OLD.rowid, OLD.uri, OLD.name, OLD.vessel, OLD.handle);
          INSERT INTO timer_search(rowid, uri, name, vessel, handle)
          VALUES (NEW.rowid, NEW.uri, NEW.name, NEW.vessel, NEW.handle);
        END
      `);

      // DID cache table - caches resolved DIDs
      db.run(`
        CREATE TABLE IF NOT EXISTS did_cache (
          did TEXT PRIMARY KEY,
          handle TEXT NOT NULL,
          pds_url TEXT NOT NULL,
          public_key TEXT,
          cached_at INTEGER NOT NULL
        )
      `);

      db.run(`CREATE INDEX IF NOT EXISTS idx_did_handle ON did_cache(handle)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_did_cached_at ON did_cache(cached_at)`);

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
    up: (db: Database) => {
      // Firehose cursor table - stores the last processed cursor for resume capability
      // Only one row (id=1) to enforce single cursor
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
    up: (db: Database) => {
      // Haiku likes table - tracks individual likes for handling unlikes
      // like_uri: at://liker_did/app.bsky.feed.like/rkey
      // post_uri: at://author_did/app.bsky.feed.post/rkey
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
    up: (db: Database) => {
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
    up: (db: Database) => {
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_nature REAL DEFAULT 0`);
      db.run(`ALTER TABLE haiku_posts ADD COLUMN score_relaxation REAL DEFAULT 0`);
    },
  },
];

export function runMigrations(db: Database): void {
  // Ensure schema_version table exists
  db.run(`
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY,
      applied_at INTEGER NOT NULL
    )
  `);

  // Get current version
  const result = db.query<{ version: number }, []>(
    "SELECT MAX(version) as version FROM schema_version"
  ).get();
  const currentVersion = result?.version ?? 0;

  // Run pending migrations
  for (const migration of migrations) {
    if (migration.version > currentVersion) {
      console.log(`Running migration ${migration.version}: ${migration.name}`);
      migration.up(db);
      db.run(
        "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)",
        [migration.version, Date.now()]
      );
    }
  }
}
