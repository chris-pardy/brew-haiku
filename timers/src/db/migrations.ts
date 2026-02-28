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
  {
    version: 2,
    name: "add_notes_column",
    up: (db) => {
      db.run(`ALTER TABLE timer_index ADD COLUMN notes TEXT`);
    },
  },
  {
    version: 3,
    name: "expand_fts5_search",
    up: (db) => {
      // Drop old triggers and FTS5 table
      db.run(`DROP TRIGGER IF EXISTS timer_ai`);
      db.run(`DROP TRIGGER IF EXISTS timer_ad`);
      db.run(`DROP TRIGGER IF EXISTS timer_au`);
      db.run(`DROP TABLE IF EXISTS timer_search`);

      // Recreate FTS5 with brew_type, steps, and notes columns
      db.run(`
        CREATE VIRTUAL TABLE timer_search USING fts5(
          uri,
          name,
          vessel,
          brew_type,
          steps,
          notes,
          content=timer_index,
          content_rowid=rowid
        )
      `);

      // Recreate triggers
      db.run(`
        CREATE TRIGGER timer_ai AFTER INSERT ON timer_index BEGIN
          INSERT INTO timer_search(rowid, uri, name, vessel, brew_type, steps, notes)
          VALUES (NEW.rowid, NEW.uri, NEW.name, NEW.vessel, NEW.brew_type, NEW.steps, NEW.notes);
        END
      `);

      db.run(`
        CREATE TRIGGER timer_ad AFTER DELETE ON timer_index BEGIN
          INSERT INTO timer_search(timer_search, rowid, uri, name, vessel, brew_type, steps, notes)
          VALUES ('delete', OLD.rowid, OLD.uri, OLD.name, OLD.vessel, OLD.brew_type, OLD.steps, OLD.notes);
        END
      `);

      db.run(`
        CREATE TRIGGER timer_au AFTER UPDATE ON timer_index BEGIN
          INSERT INTO timer_search(timer_search, rowid, uri, name, vessel, brew_type, steps, notes)
          VALUES ('delete', OLD.rowid, OLD.uri, OLD.name, OLD.vessel, OLD.brew_type, OLD.steps, OLD.notes);
          INSERT INTO timer_search(rowid, uri, name, vessel, brew_type, steps, notes)
          VALUES (NEW.rowid, NEW.uri, NEW.name, NEW.vessel, NEW.brew_type, NEW.steps, NEW.notes);
        END
      `);

      // Rebuild index from existing data
      db.run(`INSERT INTO timer_search(timer_search) VALUES('rebuild')`);
    },
  },
  {
    version: 4,
    name: "add_timer_saves_and_brew_index",
    up: (db) => {
      // Timer saves — tracks which user saved which timer
      db.run(`
        CREATE TABLE IF NOT EXISTS timer_saves (
          saver_did TEXT NOT NULL,
          timer_uri TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (saver_did, timer_uri)
        )
      `);
      db.run(`CREATE INDEX IF NOT EXISTS idx_timer_saves_timer ON timer_saves(timer_uri)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_timer_saves_saver ON timer_saves(saver_did)`);

      // Brew index — records brew sessions
      db.run(`
        CREATE TABLE IF NOT EXISTS brew_index (
          uri TEXT PRIMARY KEY,
          did TEXT NOT NULL,
          timer_uri TEXT NOT NULL,
          post_uri TEXT,
          step_values TEXT,
          created_at INTEGER NOT NULL,
          indexed_at INTEGER NOT NULL
        )
      `);
      db.run(`CREATE INDEX IF NOT EXISTS idx_brew_did ON brew_index(did)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_brew_timer ON brew_index(timer_uri)`);
      db.run(`CREATE INDEX IF NOT EXISTS idx_brew_created ON brew_index(created_at)`);
    },
  },
];
