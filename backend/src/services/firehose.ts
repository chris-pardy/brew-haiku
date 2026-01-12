import { Effect, Context, Layer, Stream, Fiber, Ref, Duration, Scope } from "effect";
import { DatabaseService, type HaikuPostRecord, type TimerRecord } from "./database.js";
import { type FeedConfig, scoreSql } from "./feed-generator.js";
import {
  JetstreamService,
  type JetstreamEvent,
  type JetstreamOptions,
  JetstreamServiceLive,
  defaultJetstreamConfig,
  filterByCollection,
} from "./jetstream.js";
import {
  createHaikuIndexer,
  createTimerIndexer,
  createLikeIndexer,
  createCursorPersister,
  filterSavedTimerEvents,
  filterLikeEvents,
  HAIKU_SIGNATURE,
  SAVED_TIMER_COLLECTION,
  TIMER_COLLECTION,
  POST_COLLECTION,
  LIKE_COLLECTION,
} from "./firehose-indexers.js";
import { detectHaiku } from "./haiku-detector.js";

export class FirehoseError extends Error {
  readonly _tag = "FirehoseError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface FirehoseEvent {
  did: string;
  commit: {
    collection: string;
    rkey: string;
    record?: {
      text?: string;
      createdAt?: string;
      timerUri?: string;
      savedAt?: string;
      [key: string]: unknown;
    };
    cid?: string;
  };
  operation: "create" | "update" | "delete";
}

export interface SavedTimerEvent {
  did: string;
  timerUri: string;
  savedAt: string;
  operation: "create" | "delete";
}

export interface FirehoseStatus {
  running: boolean;
  lastCursor: number | null;
  eventsProcessed: number;
}

export class FirehoseService extends Context.Tag("FirehoseService")<
  FirehoseService,
  {
    // Legacy interface for backward compatibility
    readonly isHaikuPost: (text: string) => boolean;
    readonly isSavedTimerEvent: (collection: string) => boolean;
    // New stream-based API
    readonly start: (options?: JetstreamOptions) => Effect.Effect<void, FirehoseError>;
    readonly stop: () => Effect.Effect<void>;
    readonly status: () => Effect.Effect<FirehoseStatus>;
    readonly getLastCursor: () => Effect.Effect<number | null, FirehoseError>;
  }
>() {}

export const makeFirehoseService = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const jetstreamService = yield* JetstreamService;
  const { db } = dbService;

  // State
  const runningRef = yield* Ref.make(false);
  const fiberRef = yield* Ref.make<Fiber.RuntimeFiber<void, FirehoseError> | null>(null);
  const eventsProcessedRef = yield* Ref.make(0);
  const lastCursorRef = yield* Ref.make<number | null>(null);

  // Legacy helper functions
  const isHaikuPost = (text: string): boolean => {
    return text.trim().endsWith(HAIKU_SIGNATURE);
  };

  const isSavedTimerEvent = (collection: string): boolean => {
    return collection === SAVED_TIMER_COLLECTION;
  };

  // Load last cursor from database
  const loadLastCursor = (): Effect.Effect<number | null, FirehoseError> =>
    Effect.try({
      try: () => {
        const result = db
          .query<{ cursor_us: number }, []>(
            "SELECT cursor_us FROM firehose_cursor WHERE id = 1"
          )
          .get();
        return result?.cursor_us ?? null;
      },
      catch: (error) => new FirehoseError("Failed to load cursor", error),
    });

  // Save cursor to database
  const saveCursor = (cursorUs: number): Effect.Effect<void, FirehoseError> =>
    Effect.try({
      try: () => {
        db.run(
          `INSERT OR REPLACE INTO firehose_cursor (id, cursor_us, updated_at)
           VALUES (1, ?, ?)`,
          [cursorUs, Date.now()]
        );
      },
      catch: (error) => new FirehoseError("Failed to save cursor", error),
    });

  // Create indexers
  const haikuIndexer = yield* createHaikuIndexer;
  const timerIndexer = yield* createTimerIndexer;
  const likeIndexer = yield* createLikeIndexer;

  const RETENTION_HOURS = parseInt(process.env.RETENTION_HOURS || "6", 10);
  const TOP_N = parseInt(process.env.RETENTION_TOP_N || "40", 10);
  const CLEANUP_INTERVAL_MS = 10 * 60 * 1000; // every 10 minutes
  const cleanupConfig: FeedConfig = {
    likeWeight: parseFloat(process.env.LIKE_WEIGHT || "1.0"),
    recencyWeight: parseFloat(process.env.RECENCY_WEIGHT || "2.0"),
    recencyHalfLifeHours: parseFloat(process.env.RECENCY_HALF_LIFE_HOURS || "24"),
    signatureBonus: parseFloat(process.env.SIGNATURE_BONUS || "50.0"),
  };

  // Periodic cleanup: keep top N by score + anything under RETENTION_HOURS old
  const runCleanup = Effect.gen(function* () {
    const now = Date.now();
    const cutoff = now - RETENTION_HOURS * 60 * 60 * 1000;
    const score = scoreSql(cleanupConfig, String(now));
    yield* Effect.try({
      try: () => {
        // Delete likes for posts we're about to remove
        db.run(
          `DELETE FROM haiku_likes WHERE post_uri IN (
            SELECT uri FROM haiku_posts
            WHERE created_at < ?
              AND uri NOT IN (
                SELECT uri FROM haiku_posts
                ORDER BY ${score} DESC
                LIMIT ?
              )
          )`,
          [cutoff, TOP_N]
        );
        // Delete old posts that aren't in the top N
        const result = db.run(
          `DELETE FROM haiku_posts
           WHERE created_at < ?
             AND uri NOT IN (
               SELECT uri FROM haiku_posts
               ORDER BY ${score} DESC
               LIMIT ?
             )`,
          [cutoff, TOP_N]
        );
        return result.changes;
      },
      catch: (error) => new FirehoseError("Cleanup failed", error),
    }).pipe(
      Effect.tap((deleted) =>
        deleted > 0
          ? Effect.log(`Cleanup: pruned ${deleted} posts (keeping top ${TOP_N} + <${RETENTION_HOURS}h)`)
          : Effect.void
      ),
      Effect.catchAll((error) => Effect.logError(`Cleanup error: ${error.message}`))
    );
  });

  const runCleanupLoop: Effect.Effect<never, never, never> = runCleanup.pipe(
    Effect.andThen(Effect.sleep(Duration.millis(CLEANUP_INTERVAL_MS))),
    Effect.forever
  );

  // Main firehose runner
  const runFirehose = (options: JetstreamOptions): Effect.Effect<void, FirehoseError> =>
    Effect.gen(function* () {
      yield* Effect.log("Starting firehose with stream architecture...");

      // Load cursor if not provided
      const cursor = options.cursor ?? (yield* loadLastCursor());
      const effectiveOptions: JetstreamOptions = {
        ...options,
        cursor: cursor ?? undefined,
        wantedCollections: options.wantedCollections ?? [
          POST_COLLECTION,
          SAVED_TIMER_COLLECTION,
          LIKE_COLLECTION,
        ],
      };

      yield* Effect.log(`Starting from cursor: ${cursor ?? "beginning"}`);

      // Create the event stream
      const eventStream = jetstreamService.createEventStream(effectiveOptions);

      // Process events in parallel with different consumers
      yield* Effect.scoped(
        Effect.gen(function* () {
          // Track events and cursor
          const trackedStream = eventStream.pipe(
            Stream.tap((event) =>
              Effect.gen(function* () {
                yield* Ref.update(eventsProcessedRef, (n) => n + 1);
                yield* Ref.set(lastCursorRef, event.time_us);
              })
            )
          );

          // Fan out to 3 consumers: posts (haiku + deletes), timers, likes
          const [postStream, timerStream, likeStream] = yield* trackedStream.pipe(
            Stream.broadcast(3, 100)
          );

          // Cursor persister loop — reads from lastCursorRef every 30s
          const cursorLoop: Effect.Effect<never, never, never> = Effect.gen(function* () {
            const cursor = yield* Ref.get(lastCursorRef);
            if (cursor !== null) {
              yield* saveCursor(cursor).pipe(
                Effect.tap(() => Effect.log(`Saved cursor: ${cursor}`)),
                Effect.catchAll((error) =>
                  Effect.logError(`Cursor save error: ${error.message}`)
                )
              );
            }
          }).pipe(
            Effect.andThen(Effect.sleep(Duration.seconds(30))),
            Effect.forever
          );

          // Run all consumers concurrently
          yield* Effect.all(
            [
              // Post indexer: handles haiku creates/updates AND deletes
              postStream.pipe(
                filterByCollection(POST_COLLECTION),
                Stream.filter((e) => {
                  if (e.commit.operation === "delete") return true;
                  const text = e.commit.record?.text;
                  return typeof text === "string" && isHaikuPost(text);
                }),
                Stream.mapEffect((event) =>
                  haikuIndexer.indexPost(event).pipe(
                    Effect.catchAll((error) =>
                      Effect.logError(`Haiku indexer error: ${error.message}`)
                    )
                  )
                ),
                Stream.runDrain
              ),

              // Timer indexer
              filterSavedTimerEvents(timerStream).pipe(
                Stream.mapEffect((event) =>
                  timerIndexer.processEvent(event).pipe(
                    Effect.catchAll((error) =>
                      Effect.logError(`Timer indexer error: ${error.message}`)
                    )
                  )
                ),
                Stream.runDrain
              ),

              // Like indexer
              filterLikeEvents(likeStream).pipe(
                Stream.mapEffect((event) =>
                  likeIndexer.processLike(event).pipe(
                    Effect.catchAll((error) =>
                      Effect.logError(`Like indexer error: ${error.message}`)
                    )
                  )
                ),
                Stream.runDrain
              ),

              // Cursor persister (timer-based, not stream-based)
              cursorLoop,
            ],
            { concurrency: "unbounded" }
          );
        })
      );
    });

  const start = (options: JetstreamOptions = {}): Effect.Effect<void, FirehoseError> =>
    Effect.gen(function* () {
      const isRunning = yield* Ref.get(runningRef);
      if (isRunning) {
        yield* Effect.log("Firehose is already running");
        return;
      }

      yield* Ref.set(runningRef, true);
      yield* Ref.set(eventsProcessedRef, 0);

      // Fork the firehose runner and cleanup loop
      const fiber = yield* Effect.all(
        [
          runFirehose(options),
          runCleanupLoop,
        ],
        { concurrency: "unbounded" }
      ).pipe(
        Effect.catchAll((error) =>
          Effect.gen(function* () {
            yield* Effect.logError(`Firehose error: ${error.message}`);
            yield* Ref.set(runningRef, false);
          })
        ),
        Effect.fork
      );

      yield* Ref.set(fiberRef, fiber);
      yield* Effect.log("Firehose started");
    });

  const stop = (): Effect.Effect<void> =>
    Effect.gen(function* () {
      const fiber = yield* Ref.get(fiberRef);
      if (fiber) {
        yield* Fiber.interrupt(fiber);
        yield* Ref.set(fiberRef, null);
      }
      yield* Ref.set(runningRef, false);

      // Save final cursor
      const lastCursor = yield* Ref.get(lastCursorRef);
      if (lastCursor !== null) {
        yield* saveCursor(lastCursor).pipe(Effect.ignore);
      }

      yield* Effect.log("Firehose stopped");
    });

  const status = (): Effect.Effect<FirehoseStatus> =>
    Effect.gen(function* () {
      const running = yield* Ref.get(runningRef);
      const lastCursor = yield* Ref.get(lastCursorRef);
      const eventsProcessed = yield* Ref.get(eventsProcessedRef);
      return { running, lastCursor, eventsProcessed };
    });

  const getLastCursor = (): Effect.Effect<number | null, FirehoseError> =>
    Effect.gen(function* () {
      // First check in-memory
      const memCursor = yield* Ref.get(lastCursorRef);
      if (memCursor !== null) return memCursor;
      // Fall back to database
      return yield* loadLastCursor();
    });

  return {
    isHaikuPost,
    isSavedTimerEvent,
    start,
    stop,
    status,
    getLastCursor,
  };
});

export const FirehoseServiceLive = Layer.effect(
  FirehoseService,
  makeFirehoseService
).pipe(
  Layer.provide(JetstreamServiceLive())
);

export { HAIKU_SIGNATURE, SAVED_TIMER_COLLECTION, TIMER_COLLECTION };
