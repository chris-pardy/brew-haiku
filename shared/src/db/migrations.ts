import { Database } from "bun:sqlite";

export interface Migration {
  version: number;
  name: string;
  up: (db: Database) => void;
}

export function runMigrations(db: Database, migrations: Migration[]): void {
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
