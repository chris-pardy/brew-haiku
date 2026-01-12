import { describe, test, expect, mock, beforeEach, afterEach } from "bun:test";
import { Effect, Layer } from "effect";
import {
  SavedTimersService,
  SavedTimersError,
  makeSavedTimersService,
  type SavedTimerWithDetails,
} from "../src/services/saved-timers.js";
import { savedTimersRoutes } from "../src/routes/saved-timers.js";

describe("SavedTimersService", () => {
  test("service is properly typed", () => {
    expect(SavedTimersService).toBeDefined();
  });

  test("SavedTimersError has correct tag", () => {
    const error = new SavedTimersError("test error");
    expect(error._tag).toBe("SavedTimersError");
    expect(error.message).toBe("test error");
  });
});

describe("SavedTimersService with mocked fetch", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  test("getSavedTimers fetches and resolves timer details", async () => {
    const testDid = "did:plc:testuser123";
    const timerCreatorDid = "did:plc:timercreator";
    const timerRkey = "timer123";
    const timerUri = `at://${timerCreatorDid}/app.brew-haiku.timer/${timerRkey}`;

    // Mock fetch to return appropriate responses
    globalThis.fetch = mock((url: string) => {
      const urlStr = url.toString();

      // PLC directory lookup for test user
      if (urlStr === `https://plc.directory/${testDid}`) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              service: [
                {
                  type: "AtprotoPersonalDataServer",
                  serviceEndpoint: "https://test.pds.example",
                },
              ],
              alsoKnownAs: ["at://testuser.bsky.social"],
            }),
        });
      }

      // PLC directory lookup for timer creator
      if (urlStr === `https://plc.directory/${timerCreatorDid}`) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              service: [
                {
                  type: "AtprotoPersonalDataServer",
                  serviceEndpoint: "https://creator.pds.example",
                },
              ],
              alsoKnownAs: ["at://creator.bsky.social"],
            }),
        });
      }

      // List saved timer records
      if (urlStr.includes("listRecords") && urlStr.includes("savedTimer")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              records: [
                {
                  uri: `at://${testDid}/app.brew-haiku.savedTimer/save1`,
                  value: {
                    timerUri,
                    createdAt: "2024-01-15T10:00:00Z",
                  },
                },
              ],
            }),
        });
      }

      // Get timer record
      if (urlStr.includes("getRecord") && urlStr.includes("timer")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              uri: timerUri,
              cid: "bafytest",
              value: {
                name: "Morning V60",
                vessel: "Hario V60",
                brewType: "pour-over",
                ratio: 16,
                steps: [
                  { action: "Bloom", stepType: "timed", durationSeconds: 30 },
                  { action: "Pour", stepType: "timed", durationSeconds: 120 },
                ],
                createdAt: "2024-01-01T08:00:00Z",
              },
            }),
        });
      }

      return Promise.resolve({ ok: false, status: 404 });
    }) as typeof fetch;

    const program = Effect.gen(function* () {
      const service = yield* makeSavedTimersService;
      return yield* service.getSavedTimers(testDid);
    });

    const result = await Effect.runPromise(program);

    expect(result.length).toBe(1);
    expect(result[0].saveUri).toBe(`at://${testDid}/app.brew-haiku.savedTimer/save1`);
    expect(result[0].savedAt).toBe("2024-01-15T10:00:00Z");
    expect(result[0].timer.uri).toBe(timerUri);
    expect(result[0].timer.name).toBe("Morning V60");
    expect(result[0].timer.vessel).toBe("Hario V60");
    expect(result[0].timer.brewType).toBe("pour-over");
    expect(result[0].timer.ratio).toBe(16);
    expect(result[0].timer.handle).toBe("creator.bsky.social");
    expect(result[0].timer.steps.length).toBe(2);
  });

  test("getSavedTimers returns empty array when no saved timers", async () => {
    const testDid = "did:plc:emptyuser";

    globalThis.fetch = mock((url: string) => {
      const urlStr = url.toString();

      if (urlStr.includes("plc.directory")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              service: [
                {
                  type: "AtprotoPersonalDataServer",
                  serviceEndpoint: "https://test.pds.example",
                },
              ],
            }),
        });
      }

      if (urlStr.includes("listRecords")) {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ records: [] }),
        });
      }

      return Promise.resolve({ ok: false, status: 404 });
    }) as typeof fetch;

    const program = Effect.gen(function* () {
      const service = yield* makeSavedTimersService;
      return yield* service.getSavedTimers(testDid);
    });

    const result = await Effect.runPromise(program);

    expect(result.length).toBe(0);
  });

  test("getSavedTimers skips timers that fail to fetch", async () => {
    const testDid = "did:plc:testuser";

    globalThis.fetch = mock((url: string) => {
      const urlStr = url.toString();

      if (urlStr.includes("plc.directory")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              service: [
                {
                  type: "AtprotoPersonalDataServer",
                  serviceEndpoint: "https://test.pds.example",
                },
              ],
              alsoKnownAs: ["at://test.bsky.social"],
            }),
        });
      }

      if (urlStr.includes("listRecords")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              records: [
                {
                  uri: `at://${testDid}/app.brew-haiku.savedTimer/save1`,
                  value: {
                    timerUri: "at://did:plc:deleted/app.brew-haiku.timer/gone",
                    createdAt: "2024-01-15T10:00:00Z",
                  },
                },
              ],
            }),
        });
      }

      // Timer fetch fails
      if (urlStr.includes("getRecord")) {
        return Promise.resolve({ ok: false, status: 404 });
      }

      return Promise.resolve({ ok: false, status: 404 });
    }) as typeof fetch;

    const program = Effect.gen(function* () {
      const service = yield* makeSavedTimersService;
      return yield* service.getSavedTimers(testDid);
    });

    const result = await Effect.runPromise(program);

    // Should return empty since the timer fetch failed
    expect(result.length).toBe(0);
  });

  test("getSavedTimers handles multiple saved timers", async () => {
    const testDid = "did:plc:multiuser";

    globalThis.fetch = mock((url: string) => {
      const urlStr = url.toString();

      if (urlStr.includes("plc.directory")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              service: [
                {
                  type: "AtprotoPersonalDataServer",
                  serviceEndpoint: "https://test.pds.example",
                },
              ],
              alsoKnownAs: ["at://multi.bsky.social"],
            }),
        });
      }

      if (urlStr.includes("listRecords")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              records: [
                {
                  uri: `at://${testDid}/app.brew-haiku.savedTimer/save1`,
                  value: {
                    timerUri: `at://${testDid}/app.brew-haiku.timer/timer1`,
                    createdAt: "2024-01-15T10:00:00Z",
                  },
                },
                {
                  uri: `at://${testDid}/app.brew-haiku.savedTimer/save2`,
                  value: {
                    timerUri: `at://${testDid}/app.brew-haiku.timer/timer2`,
                    createdAt: "2024-01-16T10:00:00Z",
                  },
                },
              ],
            }),
        });
      }

      if (urlStr.includes("getRecord") && urlStr.includes("timer1")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              value: {
                name: "Timer One",
                vessel: "V60",
                brewType: "pour-over",
                steps: [],
                createdAt: "2024-01-01T08:00:00Z",
              },
            }),
        });
      }

      if (urlStr.includes("getRecord") && urlStr.includes("timer2")) {
        return Promise.resolve({
          ok: true,
          json: () =>
            Promise.resolve({
              value: {
                name: "Timer Two",
                vessel: "Chemex",
                brewType: "pour-over",
                steps: [],
                createdAt: "2024-01-02T08:00:00Z",
              },
            }),
        });
      }

      return Promise.resolve({ ok: false, status: 404 });
    }) as typeof fetch;

    const program = Effect.gen(function* () {
      const service = yield* makeSavedTimersService;
      return yield* service.getSavedTimers(testDid);
    });

    const result = await Effect.runPromise(program);

    expect(result.length).toBe(2);
    expect(result[0].timer.name).toBe("Timer One");
    expect(result[1].timer.name).toBe("Timer Two");
  });

  test("getSavedTimers falls back to bsky.social when PLC lookup fails", async () => {
    const testDid = "did:plc:fallbackuser";

    globalThis.fetch = mock((url: string) => {
      const urlStr = url.toString();

      // PLC lookup fails
      if (urlStr.includes("plc.directory")) {
        return Promise.resolve({ ok: false, status: 500 });
      }

      // Should fall back to bsky.social
      if (urlStr.includes("bsky.social") && urlStr.includes("listRecords")) {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ records: [] }),
        });
      }

      return Promise.resolve({ ok: false, status: 404 });
    }) as typeof fetch;

    const program = Effect.gen(function* () {
      const service = yield* makeSavedTimersService;
      return yield* service.getSavedTimers(testDid);
    });

    const result = await Effect.runPromise(program);

    expect(result.length).toBe(0);
  });
});

describe("Saved Timers Routes", () => {
  test("savedTimersRoutes is a valid router", () => {
    expect(savedTimersRoutes).toBeDefined();
  });
});
