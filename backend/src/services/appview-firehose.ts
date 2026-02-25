import { Effect, Context, Layer, Stream, Fiber, Ref, Duration } from "effect";
import { DatabaseService } from "./database.js";
import {
  JetstreamService,
  type JetstreamOptions,
  JetstreamServiceLive,
} from "./jetstream.js";
import {
  createTimerIndexer,
  filterSavedTimerEvents,
  SAVED_TIMER_COLLECTION,
} from "./firehose-indexers.js";

export class AppViewFirehoseError extends Error {
  readonly _tag = "AppViewFirehoseError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface AppViewFirehoseStatus {
  running: boolean;
  lastCursor: number | null;
  eventsProcessed: number;
}

export class AppViewFirehoseService extends Context.Tag("AppViewFirehoseService")<
  AppViewFirehoseService,
  {
    readonly start: (options?: JetstreamOptions) => Effect.Effect<void, AppViewFirehoseError>;
    readonly stop: () => Effect.Effect<void>;
    readonly status: () => Effect.Effect<AppViewFirehoseStatus>;
  }
>() {}

const CURSOR_ID = 2; // Separate from feed generator cursor (id=1)

export const makeAppViewFirehoseService = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const jetstreamService = yield* JetstreamService;
  const { db } = dbService;

  // State
  const runningRef = yield* Ref.make(false);
  const fiberRef = yield* Ref.make<Fiber.RuntimeFiber<void, AppViewFirehoseError> | null>(null);
  const eventsProcessedRef = yield* Ref.make(0);
  const lastCursorRef = yield* Ref.make<number | null>(null);

  // Cursor persistence with separate cursor id
  const loadLastCursor = (): Effect.Effect<number | null, AppViewFirehoseError> =>
    Effect.try({
      try: () => {
        const result = db
          .query<{ cursor_us: number }, []>(
            `SELECT cursor_us FROM firehose_cursor WHERE id = ${CURSOR_ID}`
          )
          .get();
        return result?.cursor_us ?? null;
      },
      catch: (error) => new AppViewFirehoseError("Failed to load cursor", error),
    });

  const saveCursor = (cursorUs: number): Effect.Effect<void, AppViewFirehoseError> =>
    Effect.try({
      try: () => {
        db.run(
          `INSERT OR REPLACE INTO firehose_cursor (id, cursor_us, updated_at)
           VALUES (${CURSOR_ID}, ?, ?)`,
          [cursorUs, Date.now()]
        );
      },
      catch: (error) => new AppViewFirehoseError("Failed to save cursor", error),
    });

  // Create timer indexer
  const timerIndexer = yield* createTimerIndexer;

  // Main firehose runner — timer events only
  const runFirehose = (options: JetstreamOptions): Effect.Effect<void, AppViewFirehoseError> =>
    Effect.gen(function* () {
      yield* Effect.log("Starting appview firehose (timer events only)...");

      const cursor = options.cursor ?? (yield* loadLastCursor());
      const effectiveOptions: JetstreamOptions = {
        ...options,
        cursor: cursor ?? undefined,
        wantedCollections: [SAVED_TIMER_COLLECTION],
      };

      yield* Effect.log(`Starting from cursor: ${cursor ?? "beginning"}`);

      const eventStream = jetstreamService.createEventStream(effectiveOptions);

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

          // Cursor persister loop
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

          // Run timer indexer + cursor persister concurrently
          yield* Effect.all(
            [
              // Timer indexer: savedTimer creates/deletes
              filterSavedTimerEvents(trackedStream).pipe(
                Stream.mapEffect((event) =>
                  timerIndexer.processEvent(event).pipe(
                    Effect.catchAll((error) =>
                      Effect.logError(`Timer indexer error: ${error.message}`)
                    )
                  )
                ),
                Stream.runDrain
              ),

              // Cursor persister
              cursorLoop,
            ],
            { concurrency: "unbounded" }
          );
        })
      );
    });

  const start = (options: JetstreamOptions = {}): Effect.Effect<void, AppViewFirehoseError> =>
    Effect.gen(function* () {
      const isRunning = yield* Ref.get(runningRef);
      if (isRunning) {
        yield* Effect.log("Appview firehose is already running");
        return;
      }

      yield* Ref.set(runningRef, true);
      yield* Ref.set(eventsProcessedRef, 0);

      const fiber = yield* runFirehose(options).pipe(
        Effect.catchAll((error) =>
          Effect.gen(function* () {
            yield* Effect.logError(`Appview firehose error: ${error.message}`);
            yield* Ref.set(runningRef, false);
          })
        ),
        Effect.fork
      );

      yield* Ref.set(fiberRef, fiber);
      yield* Effect.log("Appview firehose started");
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

      yield* Effect.log("Appview firehose stopped");
    });

  const status = (): Effect.Effect<AppViewFirehoseStatus> =>
    Effect.gen(function* () {
      const running = yield* Ref.get(runningRef);
      const lastCursor = yield* Ref.get(lastCursorRef);
      const eventsProcessed = yield* Ref.get(eventsProcessedRef);
      return { running, lastCursor, eventsProcessed };
    });

  return { start, stop, status };
});

export const AppViewFirehoseServiceLive = Layer.effect(
  AppViewFirehoseService,
  makeAppViewFirehoseService
).pipe(
  Layer.provide(JetstreamServiceLive())
);
