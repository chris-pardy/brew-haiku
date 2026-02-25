import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect, Layer, Stream, Chunk } from "effect";
import { Database } from "bun:sqlite";
import {
  DatabaseService,
  makeDatabaseService,
  type HaikuPostRecord,
  type TimerRecord,
} from "../src/services/database.js";
import {
  FirehoseService,
  makeFirehoseService,
  FirehoseError,
  HAIKU_SIGNATURE,
  SAVED_TIMER_COLLECTION,
  TIMER_COLLECTION,
  type FirehoseEvent,
} from "../src/services/firehose.js";
import {
  JetstreamService,
  type JetstreamEvent,
  type JetstreamCommitEvent,
} from "../src/services/jetstream.js";
import {
  createHaikuIndexer,
  createTimerIndexer,
  createLikeIndexer,
  filterHaikuPosts,
  filterPostDeletes,
  filterSavedTimerEvents,
  filterLikeEvents,
} from "../src/services/firehose-indexers.js";

// Mock JetstreamService for testing
const MockJetstreamService = (events: JetstreamEvent[] = []) =>
  Layer.succeed(JetstreamService, {
    config: {
      url: "wss://test.example.com/subscribe",
      queueBufferSize: 100,
      reconnectMaxDelay: { _tag: "Duration", millis: 60000 } as any,
    },
    createEventStream: () => Stream.fromIterable(events),
  });

describe("FirehoseService", () => {
  test("service is properly typed", () => {
    expect(FirehoseService).toBeDefined();
  });

  test("FirehoseError has correct tag", () => {
    const error = new FirehoseError("test error");
    expect(error._tag).toBe("FirehoseError");
    expect(error.message).toBe("test error");
  });

  test("HAIKU_SIGNATURE is correct", () => {
    expect(HAIKU_SIGNATURE).toBe("via @brew-haiku.app");
  });
});

describe("Haiku Post Detection", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  test("isHaikuPost detects posts with signature", async () => {
    const TestDbLayer = Layer.succeed(DatabaseService, dbService);
    const TestLayer = TestDbLayer.pipe(
      Layer.provideMerge(MockJetstreamService())
    );

    const program = Effect.gen(function* () {
      const service = yield* makeFirehoseService;
      return {
        validHaiku: service.isHaikuPost(
          "Steam rises slowly\nPatience rewards the waiting\nFirst sip is pure bliss"
        ),
        notHaiku: service.isHaikuPost(
          "Just a regular post without haiku structure"
        ),
        haikuWithSignature: service.isHaikuPost(
          "Steam rises slowly\nPatience rewards the waiting\nFirst sip is pure bliss\n\nvia @brew-haiku.app"
        ),
      };
    }).pipe(Effect.provide(TestLayer));

    const results = await Effect.runPromise(program);

    expect(results.validHaiku).toBe(true);
    expect(results.notHaiku).toBe(false);
    expect(results.haikuWithSignature).toBe(true);
  });
});

describe("Haiku Indexer", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  test("indexPost creates database record", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);

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

    const { db } = dbService;
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
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    // First create
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

    // Then delete
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

    const { db } = dbService;
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

describe("SavedTimer Event Detection", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  test("SAVED_TIMER_COLLECTION is correct", () => {
    expect(SAVED_TIMER_COLLECTION).toBe("app.brew-haiku.savedTimer");
  });

  test("TIMER_COLLECTION is correct", () => {
    expect(TIMER_COLLECTION).toBe("app.brew-haiku.timer");
  });

  test("isSavedTimerEvent detects savedTimer collection", async () => {
    const TestDbLayer = Layer.succeed(DatabaseService, dbService);
    const TestLayer = TestDbLayer.pipe(
      Layer.provideMerge(MockJetstreamService())
    );

    const program = Effect.gen(function* () {
      const service = yield* makeFirehoseService;
      return {
        savedTimer: service.isSavedTimerEvent("app.brew-haiku.savedTimer"),
        timer: service.isSavedTimerEvent("app.brew-haiku.timer"),
        post: service.isSavedTimerEvent("app.bsky.feed.post"),
        like: service.isSavedTimerEvent("app.bsky.feed.like"),
      };
    }).pipe(Effect.provide(TestLayer));

    const results = await Effect.runPromise(program);

    expect(results.savedTimer).toBe(true);
    expect(results.timer).toBe(false);
    expect(results.post).toBe(false);
    expect(results.like).toBe(false);
  });
});

describe("Timer Indexer - Save Count Management", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  const insertTestTimer = (
    overrides: Partial<TimerRecord> = {}
  ): TimerRecord => {
    const { db } = dbService;
    const timer: TimerRecord = {
      uri: overrides.uri || `at://did:plc:test/app.brew-haiku.timer/${Date.now()}`,
      did: overrides.did || "did:plc:test",
      cid: overrides.cid || "bafytest",
      handle: overrides.handle ?? "test.bsky.social",
      name: overrides.name || "Test V60 Recipe",
      vessel: overrides.vessel || "Hario V60",
      brew_type: overrides.brew_type || "coffee",
      ratio: overrides.ratio ?? 16,
      steps: overrides.steps || JSON.stringify([
        { action: "Bloom with 50ml", stepType: "timed", durationSeconds: 30 },
      ]),
      save_count: overrides.save_count ?? 1,
      created_at: overrides.created_at || Date.now(),
      indexed_at: overrides.indexed_at || Date.now(),
    };

    db.run(
      `INSERT INTO timer_index
       (uri, did, cid, handle, name, vessel, brew_type, ratio, steps, save_count, created_at, indexed_at)
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

    return timer;
  };

  test("updateSaveCount increments save count", async () => {
    const testTimer = insertTestTimer({ uri: "at://test/timer/1", save_count: 5 });
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const indexer = yield* createTimerIndexer;
      yield* indexer.updateSaveCount(testTimer.uri, 3);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const { db } = dbService;
    const result = db
      .query<{ save_count: number }, [string]>(
        "SELECT save_count FROM timer_index WHERE uri = ?"
      )
      .get(testTimer.uri);

    expect(result?.save_count).toBe(8);
  });

  test("updateSaveCount decrements save count", async () => {
    const testTimer = insertTestTimer({ uri: "at://test/timer/2", save_count: 10 });
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const indexer = yield* createTimerIndexer;
      yield* indexer.updateSaveCount(testTimer.uri, -3);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const { db } = dbService;
    const result = db
      .query<{ save_count: number }, [string]>(
        "SELECT save_count FROM timer_index WHERE uri = ?"
      )
      .get(testTimer.uri);

    expect(result?.save_count).toBe(7);
  });

  test("updateSaveCount does not go below zero", async () => {
    const testTimer = insertTestTimer({ uri: "at://test/timer/3", save_count: 2 });
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const indexer = yield* createTimerIndexer;
      yield* indexer.updateSaveCount(testTimer.uri, -10);
    }).pipe(Effect.provide(TestLayer));

    await Effect.runPromise(program);

    const { db } = dbService;
    const result = db
      .query<{ save_count: number }, [string]>(
        "SELECT save_count FROM timer_index WHERE uri = ?"
      )
      .get(testTimer.uri);

    expect(result?.save_count).toBe(0);
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

  test("filterHaikuPosts does not pass through delete events", async () => {
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

    expect(Chunk.size(filtered)).toBe(1);
    const first = Chunk.get(filtered, 0);
    expect(first._tag).toBe("Some");
    if (first._tag === "Some") {
      expect((first.value as JetstreamCommitEvent).commit.operation).toBe("create");
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

describe("Like Indexer", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  const insertTestHaiku = (uri: string): void => {
    const { db } = dbService;
    db.run(
      `INSERT INTO haiku_posts (uri, did, cid, text, like_count, created_at, indexed_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [uri, "did:plc:author", "bafytest", "test haiku\n\nvia @brew-haiku.app", 0, Date.now(), Date.now()]
    );
  };

  test("processLike increments like count for indexed haiku", async () => {
    const postUri = "at://did:plc:author/app.bsky.feed.post/post123";
    insertTestHaiku(postUri);
    const TestLayer = Layer.succeed(DatabaseService, dbService);

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

    const { db } = dbService;
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
    const TestLayer = Layer.succeed(DatabaseService, dbService);

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

    const { db } = dbService;
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
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    // First create the like
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

    // Then delete the like
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

    const { db } = dbService;
    const result = db
      .query<{ like_count: number }, [string]>(
        "SELECT like_count FROM haiku_posts WHERE uri = ?"
      )
      .get(postUri);

    expect(result?.like_count).toBe(0);

    // Verify like was removed from tracking table
    const likeResult = db
      .query<{ like_uri: string }, []>("SELECT like_uri FROM haiku_likes")
      .get();
    expect(likeResult).toBeNull();
  });

  test("processLike ignores likes on non-indexed posts", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);

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

    const { db } = dbService;
    const result = db
      .query<{ like_uri: string }, []>("SELECT like_uri FROM haiku_likes")
      .get();

    expect(result).toBeNull();
  });
});

describe("Post Deletion Cascades", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  test("deleting a post removes associated likes", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);
    const postUri = "at://did:plc:author/app.bsky.feed.post/post123";

    // Create a haiku post
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

    // Add a like to it
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

    // Delete the post
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

    const { db } = dbService;

    // Post should be deleted
    const postResult = db
      .query<{ uri: string }, []>("SELECT uri FROM haiku_posts")
      .get();
    expect(postResult).toBeNull();

    // Likes should be cascade deleted
    const likeResult = db
      .query<{ like_uri: string }, []>("SELECT like_uri FROM haiku_likes")
      .get();
    expect(likeResult).toBeNull();
  });
});

describe("filterPostDeletes", () => {
  test("passes post delete events", async () => {
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
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterPostDeletes(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(1);
  });

  test("rejects post create events", async () => {
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
          record: { text: "some post" },
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterPostDeletes(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(0);
  });

  test("rejects non-post delete events", async () => {
    const events: JetstreamEvent[] = [
      {
        did: "did:plc:1",
        time_us: 1,
        kind: "commit",
        commit: {
          rev: "a",
          operation: "delete",
          collection: "app.bsky.feed.like",
          rkey: "1",
        },
      },
    ];

    const stream = Stream.fromIterable(events);
    const filtered = await Effect.runPromise(
      filterPostDeletes(stream).pipe(Stream.runCollect)
    );

    expect(Chunk.size(filtered)).toBe(0);
  });
});

describe("filterLikeEvents", () => {
  test("filters for like events only", async () => {
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
          collection: "app.bsky.feed.like",
          rkey: "2",
          record: { subject: { uri: "at://test/post/1" } },
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
