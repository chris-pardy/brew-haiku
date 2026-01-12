import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect } from "effect";
import { Database } from "bun:sqlite";
import { runMigrations, migrations } from "../src/db/migrations.js";
import {
  makeDatabaseService,
  DatabaseService,
  type TimerRecord,
  type DIDCacheRecord,
  type HaikuPostRecord,
} from "../src/services/database.js";

describe("Database Migrations", () => {
  let db: Database;

  beforeEach(() => {
    db = new Database(":memory:");
  });

  afterEach(() => {
    db.close();
  });

  test("runMigrations creates all tables", () => {
    runMigrations(db);

    const tables = db
      .query<{ name: string }, []>(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
      )
      .all();

    const tableNames = tables.map((t) => t.name);
    expect(tableNames).toContain("timer_index");
    expect(tableNames).toContain("timer_search");
    expect(tableNames).toContain("did_cache");
    expect(tableNames).toContain("haiku_posts");
    expect(tableNames).toContain("schema_version");
  });

  test("runMigrations is idempotent", () => {
    runMigrations(db);
    runMigrations(db);
    runMigrations(db);

    const versions = db
      .query<{ version: number }, []>("SELECT version FROM schema_version ORDER BY version")
      .all();
    expect(versions.length).toBe(migrations.length);
    expect(versions[versions.length - 1].version).toBe(migrations.length);
  });

  test("timer_index table has correct schema", () => {
    runMigrations(db);

    const columns = db
      .query<{ name: string; type: string }, []>(
        "PRAGMA table_info(timer_index)"
      )
      .all();

    const columnNames = columns.map((c) => c.name);
    expect(columnNames).toContain("uri");
    expect(columnNames).toContain("did");
    expect(columnNames).toContain("cid");
    expect(columnNames).toContain("handle");
    expect(columnNames).toContain("name");
    expect(columnNames).toContain("vessel");
    expect(columnNames).toContain("brew_type");
    expect(columnNames).toContain("ratio");
    expect(columnNames).toContain("steps");
    expect(columnNames).toContain("save_count");
    expect(columnNames).toContain("created_at");
    expect(columnNames).toContain("indexed_at");
  });

  test("did_cache table has correct schema", () => {
    runMigrations(db);

    const columns = db
      .query<{ name: string; type: string }, []>("PRAGMA table_info(did_cache)")
      .all();

    const columnNames = columns.map((c) => c.name);
    expect(columnNames).toContain("did");
    expect(columnNames).toContain("handle");
    expect(columnNames).toContain("pds_url");
    expect(columnNames).toContain("public_key");
    expect(columnNames).toContain("cached_at");
  });

  test("haiku_posts table has correct schema", () => {
    runMigrations(db);

    const columns = db
      .query<{ name: string; type: string }, []>(
        "PRAGMA table_info(haiku_posts)"
      )
      .all();

    const columnNames = columns.map((c) => c.name);
    expect(columnNames).toContain("uri");
    expect(columnNames).toContain("did");
    expect(columnNames).toContain("cid");
    expect(columnNames).toContain("text");
    expect(columnNames).toContain("has_signature");
    expect(columnNames).toContain("like_count");
    expect(columnNames).toContain("created_at");
    expect(columnNames).toContain("indexed_at");
  });
});

describe("DatabaseService", () => {
  test("makeDatabaseService creates in-memory database", async () => {
    const result = await Effect.runPromise(makeDatabaseService(":memory:"));

    expect(result.db).toBeDefined();
    expect(typeof result.close).toBe("function");

    await Effect.runPromise(result.close());
  });

  test("database service can insert and query timer_index", async () => {
    const result = await Effect.runPromise(makeDatabaseService(":memory:"));
    const { db } = result;

    const timer: TimerRecord = {
      uri: "at://did:plc:test/app.brew-haiku.timer/123",
      did: "did:plc:test",
      cid: "bafytest",
      handle: "test.bsky.social",
      name: "My V60 Recipe",
      vessel: "Hario V60",
      brew_type: "coffee",
      ratio: 16,
      steps: JSON.stringify([{ action: "Pour water", stepType: "timed", durationSeconds: 30 }]),
      save_count: 1,
      created_at: Date.now(),
      indexed_at: Date.now(),
    };

    db.run(
      `INSERT INTO timer_index (uri, did, cid, handle, name, vessel, brew_type, ratio, steps, save_count, created_at, indexed_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        timer.uri,
        timer.did,
        timer.cid,
        timer.handle,
        timer.name,
        timer.vessel,
        timer.brew_type,
        timer.ratio,
        timer.steps,
        timer.save_count,
        timer.created_at,
        timer.indexed_at,
      ]
    );

    const fetched = db
      .query<TimerRecord, [string]>("SELECT * FROM timer_index WHERE uri = ?")
      .get(timer.uri);

    expect(fetched).toBeDefined();
    expect(fetched?.name).toBe("My V60 Recipe");
    expect(fetched?.vessel).toBe("Hario V60");

    await Effect.runPromise(result.close());
  });

  test("FTS5 search works on timer_index", async () => {
    const result = await Effect.runPromise(makeDatabaseService(":memory:"));
    const { db } = result;

    const timers = [
      { name: "V60 Pour Over", vessel: "Hario V60", handle: "coffee.lover" },
      { name: "Chemex Morning", vessel: "Chemex", handle: "barista.pro" },
      { name: "French Press Bold", vessel: "French Press", handle: "coffee.lover" },
    ];

    for (const t of timers) {
      db.run(
        `INSERT INTO timer_index (uri, did, cid, handle, name, vessel, brew_type, steps, save_count, created_at, indexed_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          `at://did:plc:test/app.brew-haiku.timer/${t.name.replace(/\s/g, "")}`,
          "did:plc:test",
          "bafytest",
          t.handle,
          t.name,
          t.vessel,
          "coffee",
          "[]",
          1,
          Date.now(),
          Date.now(),
        ]
      );
    }

    // Search for V60
    const v60Results = db
      .query<{ uri: string; name: string }, [string]>(
        `SELECT t.uri, t.name FROM timer_search ts
         JOIN timer_index t ON ts.uri = t.uri
         WHERE timer_search MATCH ?`
      )
      .all("V60");

    expect(v60Results.length).toBe(1);
    expect(v60Results[0].name).toBe("V60 Pour Over");

    // Search for coffee (part of handle coffee.lover)
    const handleResults = db
      .query<{ uri: string; name: string }, [string]>(
        `SELECT t.uri, t.name FROM timer_search ts
         JOIN timer_index t ON ts.uri = t.uri
         WHERE timer_search MATCH ?`
      )
      .all('"coffee.lover"');

    expect(handleResults.length).toBe(2);

    await Effect.runPromise(result.close());
  });

  test("database service can insert and query did_cache", async () => {
    const result = await Effect.runPromise(makeDatabaseService(":memory:"));
    const { db } = result;

    const didRecord: DIDCacheRecord = {
      did: "did:plc:test123",
      handle: "test.bsky.social",
      pds_url: "https://bsky.social",
      public_key: "did:key:test",
      cached_at: Date.now(),
    };

    db.run(
      `INSERT INTO did_cache (did, handle, pds_url, public_key, cached_at)
       VALUES (?, ?, ?, ?, ?)`,
      [didRecord.did, didRecord.handle, didRecord.pds_url, didRecord.public_key, didRecord.cached_at]
    );

    const fetched = db
      .query<DIDCacheRecord, [string]>("SELECT * FROM did_cache WHERE did = ?")
      .get(didRecord.did);

    expect(fetched).toBeDefined();
    expect(fetched?.handle).toBe("test.bsky.social");
    expect(fetched?.pds_url).toBe("https://bsky.social");

    await Effect.runPromise(result.close());
  });

  test("database service can insert and query haiku_posts", async () => {
    const result = await Effect.runPromise(makeDatabaseService(":memory:"));
    const { db } = result;

    const haiku: HaikuPostRecord = {
      uri: "at://did:plc:test/app.bsky.feed.post/123",
      did: "did:plc:test",
      cid: "bafytest",
      text: "Steam rises slowly\nPatience rewards the waiting\nFirst sip, pure bliss now\n\nvia @brew-haiku.app",
      like_count: 5,
      created_at: Date.now(),
      indexed_at: Date.now(),
    };

    db.run(
      `INSERT INTO haiku_posts (uri, did, cid, text, like_count, created_at, indexed_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [haiku.uri, haiku.did, haiku.cid, haiku.text, haiku.like_count, haiku.created_at, haiku.indexed_at]
    );

    const fetched = db
      .query<HaikuPostRecord, [string]>("SELECT * FROM haiku_posts WHERE uri = ?")
      .get(haiku.uri);

    expect(fetched).toBeDefined();
    expect(fetched?.text).toContain("Steam rises slowly");
    expect(fetched?.like_count).toBe(5);

    await Effect.runPromise(result.close());
  });
});
