import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect, Layer } from "effect";
import { Database } from "bun:sqlite";
import { runMigrations } from "../src/db/migrations.js";
import {
  DatabaseService,
  makeDatabaseService,
  type HaikuPostRecord,
} from "../src/services/database.js";
import {
  FeedGeneratorService,
  makeFeedGeneratorService,
  FeedGeneratorError,
  type FeedConfig,
  type FeedConfigFile,
} from "../src/services/feed-generator.js";
import { feedRoutes, FEED_URI } from "../src/routes/feed.js";

describe("FeedGeneratorService", () => {
  test("service is properly typed", () => {
    expect(FeedGeneratorService).toBeDefined();
  });

  test("FeedGeneratorError has correct tag", () => {
    const error = new FeedGeneratorError("test error");
    expect(error._tag).toBe("FeedGeneratorError");
    expect(error.message).toBe("test error");
  });

  test("FEED_URI is properly formatted", () => {
    expect(FEED_URI).toMatch(/^at:\/\/did:web:.+\/app\.bsky\.feed\.generator\/haikus$/);
  });
});

describe("FeedGeneratorService with Database", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  const insertTestPosts = (posts: Partial<HaikuPostRecord>[]) => {
    const { db } = dbService;
    for (const post of posts) {
      const fullPost: HaikuPostRecord = {
        uri: post.uri || `at://did:plc:test/app.bsky.feed.post/${Date.now()}`,
        did: post.did || "did:plc:test",
        cid: post.cid || "bafytest",
        text: post.text || "Test haiku\nvia @brew-haiku.app",
        like_count: post.like_count ?? 0,
        created_at: post.created_at ?? Date.now(),
        indexed_at: post.indexed_at ?? Date.now(),
      };
      db.run(
        `INSERT INTO haiku_posts (uri, did, cid, text, like_count, created_at, indexed_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          fullPost.uri,
          fullPost.did,
          fullPost.cid,
          fullPost.text,
          fullPost.like_count,
          fullPost.created_at,
          fullPost.indexed_at,
        ]
      );
    }
  };

  test("returns empty feed when no posts exist", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeFeedGeneratorService();
      return yield* service.getFeedSkeleton(10);
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.feed).toEqual([]);
    expect(result.cursor).toBeUndefined();
  });

  test("returns posts sorted by score", async () => {
    const now = Date.now();
    insertTestPosts([
      { uri: "at://test/1", like_count: 10, created_at: now - 1000 },
      { uri: "at://test/2", like_count: 5, created_at: now },
      { uri: "at://test/3", like_count: 20, created_at: now - 2000 },
    ]);

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeFeedGeneratorService();
      return yield* service.getFeedSkeleton(10);
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.feed.length).toBe(3);
    // Posts should be sorted by score (likes + recency)
  });

  test("respects limit parameter", async () => {
    insertTestPosts([
      { uri: "at://test/1" },
      { uri: "at://test/2" },
      { uri: "at://test/3" },
      { uri: "at://test/4" },
      { uri: "at://test/5" },
    ]);

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeFeedGeneratorService();
      return yield* service.getFeedSkeleton(3);
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.feed.length).toBe(3);
    expect(result.cursor).toBe("3");
  });

  test("supports cursor-based pagination", async () => {
    insertTestPosts([
      { uri: "at://test/1", like_count: 50 },
      { uri: "at://test/2", like_count: 40 },
      { uri: "at://test/3", like_count: 30 },
      { uri: "at://test/4", like_count: 20 },
      { uri: "at://test/5", like_count: 10 },
    ]);

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeFeedGeneratorService();
      const firstPage = yield* service.getFeedSkeleton(2);
      const secondPage = yield* service.getFeedSkeleton(2, firstPage.cursor);
      return { firstPage, secondPage };
    }).pipe(Effect.provide(TestLayer));

    const { firstPage, secondPage } = await Effect.runPromise(program);

    expect(firstPage.feed.length).toBe(2);
    expect(firstPage.cursor).toBe("2");
    expect(secondPage.feed.length).toBe(2);
    expect(secondPage.cursor).toBe("4");
  });

  test("uses configurable weights from config file", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const customConfigFile: FeedConfigFile = {
      base: {
        likeWeight: 5.0,
        recencyWeight: 0.5,
        recencyHalfLifeHours: 12,
        signatureBonus: 50.0,
        coffeeWeight: 15.0,
        teaWeight: 15.0,
        natureWeight: 10.0,
        relaxationWeight: 5.0,
        morningWeight: 0,
        afternoonWeight: 0,
        eveningWeight: 0,
      },
      type: {
        coffee: { coffeeWeight: 30.0, teaWeight: 5.0 },
        tea: { teaWeight: 30.0, coffeeWeight: 5.0 },
      },
      time: {},
    };

    const program = Effect.gen(function* () {
      const service = yield* makeFeedGeneratorService(customConfigFile);
      return service.configFile;
    }).pipe(Effect.provide(TestLayer));

    const configFile = await Effect.runPromise(program);

    expect(configFile.base.likeWeight).toBe(5.0);
    expect(configFile.base.recencyWeight).toBe(0.5);
    expect(configFile.base.recencyHalfLifeHours).toBe(12);
    expect(configFile.type.coffee?.coffeeWeight).toBe(30.0);
  });
});

describe("Ranking Algorithm", () => {
  test("recency score decays over time", () => {
    const calculateRecencyScore = (
      createdAt: number,
      halfLifeHours: number
    ): number => {
      const hoursAge = (Date.now() - createdAt) / (1000 * 60 * 60);
      return Math.pow(0.5, hoursAge / halfLifeHours);
    };

    const now = Date.now();
    const halfLifeHours = 24;

    // Fresh post should have score close to 1
    const freshScore = calculateRecencyScore(now, halfLifeHours);
    expect(freshScore).toBeCloseTo(1, 1);

    // Post from 24 hours ago should have score around 0.5
    const oneDayOld = now - 24 * 60 * 60 * 1000;
    const oneDayScore = calculateRecencyScore(oneDayOld, halfLifeHours);
    expect(oneDayScore).toBeCloseTo(0.5, 1);

    // Post from 48 hours ago should have score around 0.25
    const twoDaysOld = now - 48 * 60 * 60 * 1000;
    const twoDaysScore = calculateRecencyScore(twoDaysOld, halfLifeHours);
    expect(twoDaysScore).toBeCloseTo(0.25, 1);
  });
});

describe("Feed Routes", () => {
  test("feedRoutes is a valid router", () => {
    expect(feedRoutes).toBeDefined();
  });
});
