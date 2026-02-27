import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect, Layer, Stream, Chunk } from "effect";
import { Database } from "bun:sqlite";
import {
  type HaikuPostRecord,
  type TimerRecord,
  type IngestEvent,
} from "@brew-haiku/shared";
import {
  FirehoseError,
  type FirehoseStatus,
} from "../src/services/firehose.js";
import type {
  JetstreamEvent,
  JetstreamCommitEvent,
} from "@brew-haiku/shared";
import {
  createHaikuIndexer,
  createTimerIndexer,
  createLikeIndexer,
  filterHaikuPosts,
  filterPostDeletes,
  filterSavedTimerEvents,
  filterLikeEvents,
  HAIKU_SIGNATURE,
  SAVED_TIMER_COLLECTION,
  TIMER_COLLECTION,
} from "../src/services/firehose-indexers.js";
import { ClassifierServiceTest } from "../src/services/classifier.js";
import { FeedIngestClient, TimerIngestClient } from "../src/services/ingestion-client.js";
import { feedMigrations } from "../../feed/src/db/migrations.js";
import { timersMigrations } from "../../timers/src/db/migrations.js";

/**
 * Create a test DB with both feed and timer tables.
 * We can't combine migration lists (both start at version 1),
 * so we run each set's up() functions directly.
 */
function createTestDb(): Database {
  const db = new Database(":memory:");
  db.run("PRAGMA journal_mode = WAL");
  db.run("PRAGMA foreign_keys = ON");
  for (const m of feedMigrations) m.up(db);
  for (const m of timersMigrations) m.up(db);
  return db;
}

/**
 * Test IngestClient that applies events directly to a test database,
 * mimicking what the ingestion servers do over WebSocket.
 */
function makeTestIngestClients(db: Database): {
  feedLayer: Layer.Layer<FeedIngestClient>;
  timerLayer: Layer.Layer<TimerIngestClient>;
  events: IngestEvent[];
} {
  const events: IngestEvent[] = [];

  function applyEvent(event: IngestEvent): void {
    events.push(event);

    switch (event.type) {
      case "haiku:create": {
        const existing = db
          .query<{ like_count: number }, [string]>(
            "SELECT like_count FROM haiku_posts WHERE uri = ?"
          )
          .get(event.uri);
        const likeCount = existing?.like_count ?? 0;
        db.run(
          `INSERT OR REPLACE INTO haiku_posts
           (uri, did, cid, text, has_signature, like_count, created_at, indexed_at,
            score_coffee, score_tea, score_morning, score_afternoon, score_evening,
            score_nature, score_relaxation)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            event.uri, event.did, event.cid, event.text,
            event.hasSignature ? 1 : 0, likeCount,
            event.createdAt, Date.now(),
            event.scores.coffee, event.scores.tea,
            event.scores.morning, event.scores.afternoon, event.scores.evening,
            event.scores.nature, event.scores.relaxation,
          ]
        );
        break;
      }
      case "haiku:delete": {
        db.run("DELETE FROM haiku_likes WHERE post_uri = ?", [event.uri]);
        db.run("DELETE FROM haiku_posts WHERE uri = ?", [event.uri]);
        break;
      }
      case "like:create": {
        const post = db
          .query<{ uri: string }, [string]>(
            "SELECT uri FROM haiku_posts WHERE uri = ?"
          )
          .get(event.postUri);
        if (!post) break;
        db.run(
          `INSERT OR IGNORE INTO haiku_likes (like_uri, post_uri, liker_did, created_at)
           VALUES (?, ?, ?, ?)`,
          [event.likeUri, event.postUri, event.likerDid, event.createdAt]
        );
        db.run(
          `UPDATE haiku_posts SET like_count = like_count + 1 WHERE uri = ?`,
          [event.postUri]
        );
        break;
      }
      case "like:delete": {
        const like = db
          .query<{ post_uri: string }, [string]>(
            "SELECT post_uri FROM haiku_likes WHERE like_uri = ?"
          )
          .get(event.likeUri);
        if (!like) break;
        db.run("DELETE FROM haiku_likes WHERE like_uri = ?", [event.likeUri]);
        db.run(
          `UPDATE haiku_posts SET like_count = MAX(0, like_count - 1) WHERE uri = ?`,
          [like.post_uri]
        );
        break;
      }
      case "timer:save": {
        const existing = db
          .query<{ uri: string }, [string]>(
            "SELECT uri FROM timer_index WHERE uri = ?"
          )
          .get(event.uri);
        if (existing) {
          db.run(
            `UPDATE timer_index SET save_count = save_count + 1 WHERE uri = ?`,
            [event.uri]
          );
        } else {
          db.run(
            `INSERT INTO timer_index
             (uri, did, cid, handle, name, vessel, brew_type, ratio, steps, save_count, created_at, indexed_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`,
            [
              event.uri, event.did, event.cid, event.handle,
              event.name, event.vessel, event.brewType, event.ratio,
              event.steps, event.createdAt, Date.now(),
            ]
          );
        }
        break;
      }
      case "timer:unsave": {
        const result = db
          .query<{ uri: string }, [string]>(
            "SELECT uri FROM timer_index WHERE uri LIKE ?"
          )
          .get(`%/${event.rkey}`);
        if (result) {
          db.run(
            `UPDATE timer_index SET save_count = MAX(0, save_count - 1) WHERE uri = ?`,
            [result.uri]
          );
          db.run(
            "DELETE FROM timer_index WHERE uri = ? AND save_count <= 0",
            [result.uri]
          );
        }
        break;
      }
    }
  }

  const feedLayer = Layer.succeed(FeedIngestClient, {
    send: (event: IngestEvent) =>
      Effect.sync(() => applyEvent(event)),
  });

  const timerLayer = Layer.succeed(TimerIngestClient, {
    send: (event: IngestEvent) =>
      Effect.sync(() => applyEvent(event)),
  });

  return { feedLayer, timerLayer, events };
}

describe("FirehoseError", () => {
  test("FirehoseError has correct tag", () => {
    const error = new FirehoseError("test error");
    expect(error._tag).toBe("FirehoseError");
    expect(error.message).toBe("test error");
  });
});

describe("Constants", () => {
  test("HAIKU_SIGNATURE is correct", () => {
    expect(HAIKU_SIGNATURE).toBe("via @brew-haiku.app");
  });

  test("SAVED_TIMER_COLLECTION is correct", () => {
    expect(SAVED_TIMER_COLLECTION).toBe("app.brew-haiku.savedTimer");
  });

  test("TIMER_COLLECTION is correct", () => {
    expect(TIMER_COLLECTION).toBe("app.brew-haiku.timer");
  });
});

describe("Haiku Indexer", () => {
  let db: Database;

  beforeEach(() => {
    db = createTestDb();
  });

  afterEach(() => {
    db.close();
  });

  test("indexPost creates database record", async () => {
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);

    const event: JetstreamCommitEvent = {
      did: "did:plc:test123",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.post",
        rkey: "abc123",
        cid: "bafytest",
        record: {
          text: "Beautiful haiku\nSteaming cup of morning tea\nPeace in every sip\n\nvia @brew-haiku.app",
          createdAt: new Date().toISOString(),
        },
      },
    };

    const program = Effect.gen(function* () {
      const indexer = yield* createHaikuIndexer;
      yield* indexer.indexPost(event);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const result = db
      .query<HaikuPostRecord, []>("SELECT * FROM haiku_posts")
      .get();

    expect(result).toBeDefined();
    expect(result?.uri).toBe("at://did:plc:test123/app.bsky.feed.post/abc123");
    expect(result?.did).toBe("did:plc:test123");
    expect(result?.cid).toBe("bafytest");
    expect(result?.text).toContain("Beautiful haiku");
    expect(result?.like_count).toBe(0);
  });

  test("indexPost handles delete operation", async () => {
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);

    const createEvent: JetstreamCommitEvent = {
      did: "did:plc:test123",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.post",
        rkey: "abc123",
        cid: "bafytest",
        record: {
          text: "Test haiku\n\nvia @brew-haiku.app",
          createdAt: new Date().toISOString(),
        },
      },
    };

    const deleteEvent: JetstreamCommitEvent = {
      did: "did:plc:test123",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "def",
        operation: "delete",
        collection: "app.bsky.feed.post",
        rkey: "abc123",
      },
    };

    const program = Effect.gen(function* () {
      const indexer = yield* createHaikuIndexer;
      yield* indexer.indexPost(createEvent);
      yield* indexer.indexPost(deleteEvent);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const result = db
      .query<HaikuPostRecord, []>("SELECT * FROM haiku_posts")
      .get();

    expect(result).toBeNull();
  });
});

describe("Firehose Event Processing", () => {
  test("only processes app.bsky.feed.post collection", () => {
    const collections = [
      "app.bsky.feed.post",
      "app.bsky.feed.like",
      "app.bsky.graph.follow",
      "app.brew-haiku.timer",
    ];

    const isPostCollection = (collection: string) =>
      collection === "app.bsky.feed.post";

    expect(isPostCollection(collections[0])).toBe(true);
    expect(isPostCollection(collections[1])).toBe(false);
    expect(isPostCollection(collections[2])).toBe(false);
    expect(isPostCollection(collections[3])).toBe(false);
  });
});

describe("Like Indexer", () => {
  let db: Database;

  beforeEach(() => {
    db = createTestDb();
  });

  afterEach(() => {
    db.close();
  });

  const insertTestHaiku = (uri: string): void => {
    db.run(
      `INSERT INTO haiku_posts (uri, did, cid, text, like_count, created_at, indexed_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [uri, "did:plc:author", "bafytest", "test haiku\n\nvia @brew-haiku.app", 0, Date.now(), Date.now()]
    );
  };

  test("processLike increments like count for indexed haiku", async () => {
    const postUri = "at://did:plc:author/app.bsky.feed.post/post123";
    insertTestHaiku(postUri);
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);

    const likeEvent: JetstreamCommitEvent = {
      did: "did:plc:liker",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.like",
        rkey: "like123",
        record: {
          subject: { uri: postUri, cid: "bafypost" },
          createdAt: new Date().toISOString(),
        },
      },
    };

    const program = Effect.gen(function* () {
      const indexer = yield* createLikeIndexer;
      yield* indexer.processLike(likeEvent);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const result = db
      .query<{ like_count: number }, [string]>(
        "SELECT like_count FROM haiku_posts WHERE uri = ?"
      )
      .get(postUri);

    expect(result?.like_count).toBe(1);
  });

  test("processLike tracks like in haiku_likes table", async () => {
    const postUri = "at://did:plc:author/app.bsky.feed.post/post123";
    insertTestHaiku(postUri);
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);

    const likeEvent: JetstreamCommitEvent = {
      did: "did:plc:liker",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.like",
        rkey: "like123",
        record: {
          subject: { uri: postUri, cid: "bafypost" },
          createdAt: new Date().toISOString(),
        },
      },
    };

    const program = Effect.gen(function* () {
      const indexer = yield* createLikeIndexer;
      yield* indexer.processLike(likeEvent);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const result = db
      .query<{ post_uri: string; liker_did: string }, []>(
        "SELECT post_uri, liker_did FROM haiku_likes"
      )
      .get();

    expect(result?.post_uri).toBe(postUri);
    expect(result?.liker_did).toBe("did:plc:liker");
  });

  test("processLike decrements like count on unlike", async () => {
    const postUri = "at://did:plc:author/app.bsky.feed.post/post123";
    insertTestHaiku(postUri);
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);

    const createEvent: JetstreamCommitEvent = {
      did: "did:plc:liker",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.like",
        rkey: "like123",
        record: {
          subject: { uri: postUri, cid: "bafypost" },
          createdAt: new Date().toISOString(),
        },
      },
    };

    const deleteEvent: JetstreamCommitEvent = {
      did: "did:plc:liker",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "def",
        operation: "delete",
        collection: "app.bsky.feed.like",
        rkey: "like123",
      },
    };

    const program = Effect.gen(function* () {
      const indexer = yield* createLikeIndexer;
      yield* indexer.processLike(createEvent);
      yield* indexer.processLike(deleteEvent);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const result = db
      .query<{ like_count: number }, [string]>(
        "SELECT like_count FROM haiku_posts WHERE uri = ?"
      )
      .get(postUri);

    expect(result?.like_count).toBe(0);

    const likeResult = db
      .query<{ like_uri: string }, []>("SELECT like_uri FROM haiku_likes")
      .get();
    expect(likeResult).toBeNull();
  });

  test("processLike ignores likes on non-indexed posts", async () => {
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);

    const likeEvent: JetstreamCommitEvent = {
      did: "did:plc:liker",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.like",
        rkey: "like123",
        record: {
          subject: { uri: "at://did:plc:other/app.bsky.feed.post/notindexed", cid: "bafypost" },
          createdAt: new Date().toISOString(),
        },
      },
    };

    const program = Effect.gen(function* () {
      const indexer = yield* createLikeIndexer;
      yield* indexer.processLike(likeEvent);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const result = db
      .query<{ like_uri: string }, []>("SELECT like_uri FROM haiku_likes")
      .get();

    expect(result).toBeNull();
  });
});

describe("Post Deletion Cascades", () => {
  let db: Database;

  beforeEach(() => {
    db = createTestDb();
  });

  afterEach(() => {
    db.close();
  });

  test("deleting a post removes associated likes", async () => {
    const { feedLayer, timerLayer } = makeTestIngestClients(db);
    const TestLayer = Layer.mergeAll(feedLayer, timerLayer, ClassifierServiceTest);
    const postUri = "at://did:plc:author/app.bsky.feed.post/post123";

    const createEvent: JetstreamCommitEvent = {
      did: "did:plc:author",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "abc",
        operation: "create",
        collection: "app.bsky.feed.post",
        rkey: "post123",
        cid: "bafypost",
        record: {
          text: "test haiku\n\nvia @brew-haiku.app",
          createdAt: new Date().toISOString(),
        },
      },
    };

    const likeEvent: JetstreamCommitEvent = {
      did: "did:plc:liker",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "def",
        operation: "create",
        collection: "app.bsky.feed.like",
        rkey: "like123",
        record: {
          subject: { uri: postUri, cid: "bafypost" },
          createdAt: new Date().toISOString(),
        },
      },
    };

    const deleteEvent: JetstreamCommitEvent = {
      did: "did:plc:author",
      time_us: Date.now() * 1000,
      kind: "commit",
      commit: {
        rev: "ghi",
        operation: "delete",
        collection: "app.bsky.feed.post",
        rkey: "post123",
      },
    };

    const program = Effect.gen(function* () {
      const haikuIndexer = yield* createHaikuIndexer;
      const likeIndexer = yield* createLikeIndexer;

      yield* haikuIndexer.indexPost(createEvent);
      yield* likeIndexer.processLike(likeEvent);
      yield* haikuIndexer.indexPost(deleteEvent);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const postResult = db
      .query<{ uri: string }, []>("SELECT uri FROM haiku_posts")
      .get();
    expect(postResult).toBeNull();

    const likeResult = db
      .query<{ like_uri: string }, []>("SELECT like_uri FROM haiku_likes")
      .get();
    expect(likeResult).toBeNull();
  });
});

describe("Stream Filters", () => {
  test("filterHaikuPosts filters for haiku posts", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: {
          rev: "a",
          operation: "create",
          collection: "app.bsky.feed.post",
          rkey: "1",
          record: { text: "Regular post" },
        },
      },
      {
        did: "did:plc:2",
        time_us: 2,
        kind: "commit",
        commit: {
          rev: "b",
          operation: "create",
          collection: "app.bsky.feed.post",
          rkey: "2",
          record: { text: "An old silent pond\nA frog jumps into the pond\nSplash silence again\n\nvia @brew-haiku.app" },
        },
      },
      {
        did: "did:plc:3",
        time_us: 3,
        kind: "commit",
        commit: {
          rev: "c",
          operation: "create",
          collection: "app.bsky.feed.like",
          rkey: "3",
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterHaikuPosts(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(1);
    const first = Chunk.get(filtered, 0);
    expect(first._tag).toBe("Some");
    if (first._tag === "Some") {
      expect((first.value as JetstreamCommitEvent).commit.rkey).toBe("2");
    }
  });

  test("filterHaikuPosts passes through delete events for downstream handling", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: {
          rev: "a",
          operation: "delete",
          collection: "app.bsky.feed.post",
          rkey: "1",
        },
      },
      {
        did: "did:plc:2",
        time_us: 2,
        kind: "commit",
        commit: {
          rev: "b",
          operation: "create",
          collection: "app.bsky.feed.post",
          rkey: "2",
          record: { text: "An old silent pond\nA frog jumps into the pond\nSplash silence again\n\nvia @brew-haiku.app" },
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterHaikuPosts(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(2);
    const first = Chunk.get(filtered, 0);
    expect(first._tag).toBe("Some");
    if (first._tag === "Some") {
      expect((first.value as JetstreamCommitEvent).commit.operation).toBe("delete");
    }
    const second = Chunk.get(filtered, 1);
    expect(second._tag).toBe("Some");
    if (second._tag === "Some") {
      expect((second.value as JetstreamCommitEvent).commit.operation).toBe("create");
    }
  });

  test("filterSavedTimerEvents filters for savedTimer events", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: {
          rev: "a",
          operation: "create",
          collection: "app.bsky.feed.post",
          rkey: "1",
        },
      },
      {
        did: "did:plc:2",
        time_us: 2,
        kind: "commit",
        commit: {
          rev: "b",
          operation: "create",
          collection: "app.brew-haiku.savedTimer",
          rkey: "2",
          record: { timerUri: "at://test/timer/1" },
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterSavedTimerEvents(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(1);
    const first = Chunk.get(filtered, 0);
    expect(first._tag).toBe("Some");
    if (first._tag === "Some") {
      expect((first.value as JetstreamCommitEvent).commit.rkey).toBe("2");
    }
  });

  test("filterPostDeletes passes post delete events", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: { rev: "a", operation: "delete", collection: "app.bsky.feed.post", rkey: "1" },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterPostDeletes(stream).pipe(Stream.runCollect)
    );
    expect(Chunk.size(filtered)).toBe(1);
  });

  test("filterPostDeletes rejects create events", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: {
          rev: "a", operation: "create", collection: "app.bsky.feed.post",
          rkey: "1", record: { text: "some post" },
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterPostDeletes(stream).pipe(Stream.runCollect)
    );
    expect(Chunk.size(filtered)).toBe(0);
  });

  test("filterLikeEvents filters for like events only", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: { rev: "a", operation: "create", collection: "app.bsky.feed.post", rkey: "1" },
      },
      {
        did: "did:plc:2",
        time_us: 2,
        kind: "commit",
        commit: {
          rev: "b", operation: "create", collection: "app.bsky.feed.like",
          rkey: "2", record: { subject: { uri: "at://test/post/1" } },
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterLikeEvents(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(1);
    const first = Chunk.get(filtered, 0);
    expect(first._tag).toBe("Some");
    if (first._tag === "Some") {
      expect((first.value as JetstreamCommitEvent).commit.collection).toBe("app.bsky.feed.like");
    }
  });
});

describe("Jetstream Event Types", () => {
  test("JetstreamCommitEvent structure is correct", () => {
    const event: JetstreamCommitEvent = {
      did: "did:plc:test",
      time_us: 1725911162329308,
      kind: "commit",
      commit: {
        rev: "3l3qo2vutsw2b",
        operation: "create",
        collection: "app.bsky.feed.post",
        rkey: "abc123",
        record: { text: "test" },
        cid: "bafytest",
      },
    };

    expect(event.kind).toBe("commit");
    expect(event.commit.operation).toBe("create");
    expect(event.commit.collection).toBe("app.bsky.feed.post");
  });
});
