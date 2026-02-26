import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Effect, Layer } from "effect";
import { Database } from "bun:sqlite";
import {
  DatabaseService,
  makeDatabaseService,
  type TimerRecord,
} from "@brew-haiku/shared";
import {
  TimerService,
  makeTimerService,
  TimerError,
  TimerNotFoundError,
  type Timer,
} from "../src/services/timer.js";
import { timerRoutes } from "../src/routes/timers.js";
import { timersMigrations } from "../src/db/migrations.js";

describe("TimerService", () => {
  test("service is properly typed", () => {
    expect(TimerService).toBeDefined();
  });

  test("TimerError has correct tag", () => {
    const error = new TimerError("test error");
    expect(error._tag).toBe("TimerError");
    expect(error.message).toBe("test error");
  });

  test("TimerNotFoundError has correct tag", () => {
    const error = new TimerNotFoundError("at://test/timer/123");
    expect(error._tag).toBe("TimerNotFoundError");
    expect(error.uri).toBe("at://test/timer/123");
  });
});

describe("TimerService with Database", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:", timersMigrations));
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
        { action: "Pour remaining water", stepType: "timed", durationSeconds: 90 },
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

  test("getTimer returns timer by URI", async () => {
    const testTimer = insertTestTimer({ uri: "at://did:plc:test/app.brew-haiku.timer/abc123" });
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.getTimer(testTimer.uri);
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.uri).toBe(testTimer.uri);
    expect(result.name).toBe("Test V60 Recipe");
    expect(result.vessel).toBe("Hario V60");
    expect(result.brewType).toBe("coffee");
    expect(result.ratio).toBe(16);
    expect(result.steps.length).toBe(2);
  });

  test("getTimer fails with TimerNotFoundError for missing timer", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.getTimer("at://nonexistent/timer/123");
    }).pipe(Effect.provide(TestLayer));

    const exit = await Effect.runPromiseExit(program);
    expect(exit._tag).toBe("Failure");
  });

  test("listTimers returns paginated results", async () => {
    insertTestTimer({ uri: "at://test/timer/1", save_count: 10 });
    insertTestTimer({ uri: "at://test/timer/2", save_count: 5 });
    insertTestTimer({ uri: "at://test/timer/3", save_count: 20 });
    insertTestTimer({ uri: "at://test/timer/4", save_count: 0 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.listTimers({ limit: 2, offset: 0 });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(3);
    expect(result.timers.length).toBe(2);
    expect(result.timers[0].saveCount).toBe(20);
    expect(result.timers[1].saveCount).toBe(10);
  });

  test("listTimers filters by brewType", async () => {
    insertTestTimer({ uri: "at://test/timer/1", brew_type: "coffee", save_count: 1 });
    insertTestTimer({ uri: "at://test/timer/2", brew_type: "tea", save_count: 1 });
    insertTestTimer({ uri: "at://test/timer/3", brew_type: "coffee", save_count: 1 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.listTimers({ brewType: "tea" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].brewType).toBe("tea");
  });

  test("listTimers filters by vessel", async () => {
    insertTestTimer({ uri: "at://test/timer/1", vessel: "Hario V60", save_count: 1 });
    insertTestTimer({ uri: "at://test/timer/2", vessel: "Chemex", save_count: 1 });
    insertTestTimer({ uri: "at://test/timer/3", vessel: "Gaiwan", save_count: 1 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.listTimers({ vessel: "Chemex" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].vessel).toBe("Chemex");
  });

  test("indexTimer creates new timer", async () => {
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const newTimer: TimerRecord = {
      uri: "at://did:plc:new/app.brew-haiku.timer/new123",
      did: "did:plc:new",
      cid: "bafynew",
      handle: "new.bsky.social",
      name: "New Timer",
      vessel: "AeroPress",
      brew_type: "coffee",
      ratio: 15,
      steps: JSON.stringify([{ action: "Press", stepType: "timed", durationSeconds: 60 }]),
      save_count: 1,
      created_at: Date.now(),
      indexed_at: Date.now(),
    };

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      yield* service.indexTimer(newTimer);
      return yield* service.getTimer(newTimer.uri);
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.uri).toBe(newTimer.uri);
    expect(result.name).toBe("New Timer");
  });

  test("updateSaveCount increments and decrements", async () => {
    const testTimer = insertTestTimer({ save_count: 5 });
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      yield* service.updateSaveCount(testTimer.uri, 3);
      const after1 = yield* service.getTimer(testTimer.uri);
      yield* service.updateSaveCount(testTimer.uri, -2);
      const after2 = yield* service.getTimer(testTimer.uri);
      return { after1, after2 };
    }).pipe(Effect.provide(TestLayer));

    const { after1, after2 } = await Effect.runPromise(program);

    expect(after1.saveCount).toBe(8);
    expect(after2.saveCount).toBe(6);
  });

  test("updateSaveCount does not go below zero", async () => {
    const testTimer = insertTestTimer({ save_count: 2 });
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      yield* service.updateSaveCount(testTimer.uri, -10);
      return yield* service.getTimer(testTimer.uri);
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.saveCount).toBe(0);
  });

  test("deleteTimer removes timer", async () => {
    const testTimer = insertTestTimer();
    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      yield* service.deleteTimer(testTimer.uri);
      return yield* service.getTimer(testTimer.uri);
    }).pipe(Effect.provide(TestLayer));

    const exit = await Effect.runPromiseExit(program);
    expect(exit._tag).toBe("Failure");
  });
});

describe("TimerService Search", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:", timersMigrations));
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
        { action: "Pour remaining water", stepType: "timed", durationSeconds: 90 },
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

  test("searchTimers finds timers by name", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Morning Kalita Pour Over", vessel: "Kalita Wave", save_count: 5 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Evening French Press", vessel: "French Press", save_count: 3 });
    insertTestTimer({ uri: "at://test/timer/3", name: "Quick AeroPress", vessel: "AeroPress", save_count: 10 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Kalita" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].name).toBe("Morning Kalita Pour Over");
  });

  test("searchTimers finds timers by vessel", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Coffee Recipe", vessel: "Chemex", save_count: 5 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Tea Recipe", vessel: "Gaiwan", save_count: 3 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Chemex" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].vessel).toBe("Chemex");
  });

  test("searchTimers ranks by save_count and text relevance", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Pour Over Classic", save_count: 100 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Pour Over Premium", save_count: 5 });
    insertTestTimer({ uri: "at://test/timer/3", name: "Pour Over Basic", save_count: 50 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Pour Over", saveWeight: 1.0, textWeight: 0.0 });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(3);
    expect(result.timers[0].saveCount).toBe(100);
    expect(result.timers[1].saveCount).toBe(50);
    expect(result.timers[2].saveCount).toBe(5);
  });

  test("searchTimers filters by brewType", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Morning Brew", brew_type: "coffee", save_count: 5 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Morning Tea Brew", brew_type: "tea", save_count: 3 });
    insertTestTimer({ uri: "at://test/timer/3", name: "Evening Brew", brew_type: "coffee", save_count: 10 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Brew", brewType: "tea" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].brewType).toBe("tea");
  });

  test("searchTimers filters by vessel", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Recipe One", vessel: "V60", save_count: 5 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Recipe Two", vessel: "Chemex", save_count: 3 });
    insertTestTimer({ uri: "at://test/timer/3", name: "Recipe Three", vessel: "V60", save_count: 10 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Recipe", vessel: "Chemex" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].vessel).toBe("Chemex");
  });

  test("searchTimers excludes zero save_count timers", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Popular Recipe", save_count: 10 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Unpopular Recipe", save_count: 0 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Recipe" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
    expect(result.timers[0].name).toBe("Popular Recipe");
  });

  test("searchTimers supports pagination", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Recipe Alpha", save_count: 30 });
    insertTestTimer({ uri: "at://test/timer/2", name: "Recipe Beta", save_count: 20 });
    insertTestTimer({ uri: "at://test/timer/3", name: "Recipe Gamma", save_count: 10 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      const page1 = yield* service.searchTimers({ query: "Recipe", limit: 2, offset: 0 });
      const page2 = yield* service.searchTimers({ query: "Recipe", limit: 2, offset: 2 });
      return { page1, page2 };
    }).pipe(Effect.provide(TestLayer));

    const { page1, page2 } = await Effect.runPromise(program);

    expect(page1.total).toBe(3);
    expect(page1.timers.length).toBe(2);
    expect(page2.timers.length).toBe(1);
  });

  test("searchTimers returns empty for no matches", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Coffee Recipe", save_count: 5 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "nonexistent" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(0);
    expect(result.timers.length).toBe(0);
  });

  test("searchTimers handles special characters in query", async () => {
    insertTestTimer({ uri: "at://test/timer/1", name: "Coffee & Tea Recipe", save_count: 5 });

    const TestLayer = Layer.succeed(DatabaseService, dbService);

    const program = Effect.gen(function* () {
      const service = yield* makeTimerService;
      return yield* service.searchTimers({ query: "Coffee" });
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.total).toBe(1);
  });
});

describe("Timer Routes", () => {
  test("timerRoutes is a valid router", () => {
    expect(timerRoutes).toBeDefined();
  });
});
