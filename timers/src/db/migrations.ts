import type { Migration } from "@brew-haiku/shared";

export const timersMigrations: Migration[] = [
  {
    version: 1,
    name: "initial_schema",
    up: (db) => {
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

      // Schema version table
      db.run(`
        CREATE TABLE IF NOT EXISTS schema_version (
          version INTEGER PRIMARY KEY,
          applied_at INTEGER NOT NULL
        )
      `);
    },
  },
];
