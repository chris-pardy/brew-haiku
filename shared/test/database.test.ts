import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect } from "effect";
import { Database } from "bun:sqlite";
import { runMigrations, type Migration, makeDatabaseService } from "../src/index.js";

const testMigrations: Migration[] = [
  {
    version: 1,
    name: "test_table",
    up: (db) => {
      db.run(`CREATE TABLE test_items (id INTEGER PRIMARY KEY, name TEXT NOT NULL)`);
    },
  },
  {
    version: 2,
    name: "test_table_v2",
    up: (db) => {
      db.run(`ALTER TABLE test_items ADD COLUMN value TEXT`);
    },
  },
];

describe("runMigrations", () => {
  let db: Database;

  beforeEach(() => {
    db = new Database(":memory:");
  });

  afterEach(() => {
    db.close();
  });

  test("creates schema_version table and runs migrations", () => {
    runMigrations(db, testMigrations);

    const tables = db
      .query<{ name: string }, []>(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      )
      .all();
    const tableNames = tables.map((t) => t.name);
    expect(tableNames).toContain("schema_version");
    expect(tableNames).toContain("test_items");
  });

  test("is idempotent", () => {
    runMigrations(db, testMigrations);
    runMigrations(db, testMigrations);
    runMigrations(db, testMigrations);

    const versions = db
      .query<{ version: number }, []>("SELECT version FROM schema_version ORDER BY version")
      .all();
    expect(versions.length).toBe(testMigrations.length);
    expect(versions[versions.length - 1].version).toBe(testMigrations.length);
  });

  test("runs no migrations for empty list", () => {
    runMigrations(db, []);

    const tables = db
      .query<{ name: string }, []>(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      )
      .all();
    const tableNames = tables.map((t) => t.name);
    expect(tableNames).toContain("schema_version");
    expect(tableNames.length).toBe(1);
  });
});

describe("makeDatabaseService", () => {
  test("creates in-memory database with migrations", async () => {
    const result = await Effect.runPromise(makeDatabaseService(":memory:", testMigrations));

    expect(result.db).toBeDefined();
    expect(typeof result.close).toBe("function");

    // Verify migrations ran
    const tables = result.db
      .query<{ name: string }, []>(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      )
      .all();
    expect(tables.map((t) => t.name)).toContain("test_items");

    await Effect.runPromise(result.close());
  });
});
