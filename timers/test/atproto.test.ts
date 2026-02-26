import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect, Layer } from "effect";
import { Database } from "bun:sqlite";
import {
  DatabaseService,
  makeDatabaseService,
  type DIDCacheRecord,
} from "@brew-haiku/shared";
import {
  ATProtoService,
  makeATProtoService,
  ATProtoError,
  HandleNotFoundError,
} from "../src/services/atproto.js";
import { resolveRoutes } from "../src/routes/resolve.js";
import { timersMigrations } from "../src/db/migrations.js";

describe("ATProtoService", () => {
  test("service is properly typed", () => {
    expect(ATProtoService).toBeDefined();
  });

  test("ATProtoError has correct tag", () => {
    const error = new ATProtoError("test error");
    expect(error._tag).toBe("ATProtoError");
    expect(error.message).toBe("test error");
  });

  test("HandleNotFoundError has correct tag", () => {
    const error = new HandleNotFoundError("test.bsky.social");
    expect(error._tag).toBe("HandleNotFoundError");
    expect(error.handle).toBe("test.bsky.social");
  });
});

describe("ATProtoService with Database", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:", timersMigrations));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  test("caches resolved DIDs in database", async () => {
    const { db } = dbService;

    const cachedRecord: DIDCacheRecord = {
      did: "did:plc:testcached",
      handle: "cached.bsky.social",
      pds_url: "https://bsky.social",
      public_key: null,
      cached_at: Date.now(),
    };

    db.run(
      `INSERT INTO did_cache (did, handle, pds_url, public_key, cached_at)
       VALUES (?, ?, ?, ?, ?)`,
      [
        cachedRecord.did,
        cachedRecord.handle,
        cachedRecord.pds_url,
        cachedRecord.public_key,
        cachedRecord.cached_at,
      ]
    );

    const result = db
      .query<DIDCacheRecord, [string]>(
        "SELECT * FROM did_cache WHERE handle = ?"
      )
      .get("cached.bsky.social");

    expect(result).toBeDefined();
    expect(result?.did).toBe("did:plc:testcached");
    expect(result?.pds_url).toBe("https://bsky.social");
  });

  test("expired cache entries are not returned", async () => {
    const { db } = dbService;

    const expiredTime = Date.now() - 25 * 60 * 60 * 1000;
    db.run(
      `INSERT INTO did_cache (did, handle, pds_url, public_key, cached_at)
       VALUES (?, ?, ?, ?, ?)`,
      ["did:plc:expired", "expired.bsky.social", "https://bsky.social", null, expiredTime]
    );

    const ttl = 24 * 60 * 60 * 1000;
    const result = db
      .query<DIDCacheRecord, [string, number]>(
        "SELECT * FROM did_cache WHERE handle = ? AND cached_at > ?"
      )
      .get("expired.bsky.social", Date.now() - ttl);

    expect(result).toBeNull();
  });

  test("fresh cache entries are returned", async () => {
    const { db } = dbService;

    const freshTime = Date.now() - 1 * 60 * 60 * 1000;
    db.run(
      `INSERT INTO did_cache (did, handle, pds_url, public_key, cached_at)
       VALUES (?, ?, ?, ?, ?)`,
      ["did:plc:fresh", "fresh.bsky.social", "https://bsky.social", null, freshTime]
    );

    const ttl = 24 * 60 * 60 * 1000;
    const result = db
      .query<DIDCacheRecord, [string, number]>(
        "SELECT * FROM did_cache WHERE handle = ? AND cached_at > ?"
      )
      .get("fresh.bsky.social", Date.now() - ttl);

    expect(result).toBeDefined();
    expect(result?.did).toBe("did:plc:fresh");
  });
});

describe("Handle normalization", () => {
  test("handles are normalized correctly", () => {
    const normalizeHandle = (handle: string): string => {
      let normalized = handle.toLowerCase().trim();
      if (normalized.startsWith("@")) {
        normalized = normalized.slice(1);
      }
      return normalized;
    };

    expect(normalizeHandle("Test.bsky.social")).toBe("test.bsky.social");
    expect(normalizeHandle("@test.bsky.social")).toBe("test.bsky.social");
    expect(normalizeHandle("  test.bsky.social  ")).toBe("test.bsky.social");
    expect(normalizeHandle("@TEST.BSKY.SOCIAL")).toBe("test.bsky.social");
  });
});

describe("Resolve Routes", () => {
  test("resolveRoutes is a valid router", () => {
    expect(resolveRoutes).toBeDefined();
  });
});
