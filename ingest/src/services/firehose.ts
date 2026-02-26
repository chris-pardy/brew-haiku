import { Effect, Stream, Fiber, Ref, Duration } from "effect";
import {
  JetstreamService,
  type JetstreamOptions,
  filterByCollection,
} from "@brew-haiku/shared";
import {
  createHaikuIndexer,
  createLikeIndexer,
  filterLikeEvents,
  POST_COLLECTION,
  LIKE_COLLECTION,
} from "./firehose-indexers.js";
import { detectHaiku } from "./haiku-detector.js";
import { FeedIngestClient, TimerIngestClient } from "./ingestion-client.js";
import { loadCursor, saveCursor } from "./cursor-file.js";

export class FirehoseError extends Error {
  readonly _tag = "FirehoseError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface FirehoseStatus {
  running: boolean;
  lastCursor: number | null;
  eventsProcessed: number;
  haikuDetected: number;
  haikuIndexed: number;
  likesProcessed: number;
}

/**
 * Run the firehose pipeline: connect to Jetstream, detect haikus, classify,
 * and send events to feed + timers servers via their respective IngestClients.
 *
 * Returns an Effect that runs forever (until interrupted).
 */
export const runFirehosePipeline = (
  cursorPath: string,
  options: JetstreamOptions = {}
) =>
  Effect.gen(function* () {
    const jetstreamService = yield* JetstreamService;

    // State
    const eventsProcessedRef = yield* Ref.make(0);
    const haikuDetectedRef = yield* Ref.make(0);
    const haikuIndexedRef = yield* Ref.make(0);
    const likesProcessedRef = yield* Ref.make(0);
    const lastCursorRef = yield* Ref.make<number | null>(null);
    const runningRef = yield* Ref.make(true);

    // Load cursor from file
    const savedCursor = loadCursor(cursorPath);
    const cursor = options.cursor ?? savedCursor;

    const effectiveOptions: JetstreamOptions = {
      ...options,
      cursor: cursor ?? undefined,
      wantedCollections: options.wantedCollections ?? [
        POST_COLLECTION,
        LIKE_COLLECTION,
      ],
    };

    yield* Effect.log(`Starting firehose from cursor: ${cursor ?? "beginning"}`);

    // Create indexers
    const haikuIndexer = yield* createHaikuIndexer;
    const likeIndexer = yield* createLikeIndexer;

    // Create the event stream
    const eventStream = jetstreamService.createEventStream(effectiveOptions);

    // Status getter — called by the worker-main stats loop
    const getStatus = (): Effect.Effect<FirehoseStatus> =>
      Effect.gen(function* () {
        return {
          running: yield* Ref.get(runningRef),
          lastCursor: yield* Ref.get(lastCursorRef),
          eventsProcessed: yield* Ref.get(eventsProcessedRef),
          haikuDetected: yield* Ref.get(haikuDetectedRef),
          haikuIndexed: yield* Ref.get(haikuIndexedRef),
          likesProcessed: yield* Ref.get(likesProcessedRef),
        };
      });

    // Process events
    yield* Effect.scoped(
      Effect.gen(function* () {
        const trackedStream = eventStream.pipe(
          Stream.tap((event) =>
            Effect.gen(function* () {
              yield* Ref.update(eventsProcessedRef, (n) => n + 1);
              yield* Ref.set(lastCursorRef, event.time_us);
            })
          )
        );

        // Fan out to 2 consumers: posts (haiku + deletes), likes
        const [postStream, likeStream] = yield* trackedStream.pipe(
          Stream.broadcast(2, 100)
        );

        // Cursor persister loop — save to file every 30s
        const cursorLoop: Effect.Effect<never, never, never> = Effect.gen(
          function* () {
            const cur = yield* Ref.get(lastCursorRef);
            if (cur !== null) {
              saveCursor(cursorPath, cur);
              yield* Effect.log(`Saved cursor: ${cur}`);
            }
          }
        ).pipe(
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
                return typeof text === "string" && detectHaiku(text).isHaiku;
              }),
              Stream.tap(() => Ref.update(haikuDetectedRef, (n) => n + 1)),
              Stream.mapEffect((event) =>
                haikuIndexer.indexPost(event).pipe(
                  Effect.tap(() =>
                    Ref.update(haikuIndexedRef, (n) => n + 1)
                  ),
                  Effect.catchAll((error) =>
                    Effect.logError(
                      `Haiku indexer error: ${error.message}`
                    )
                  )
                )
              ),
              Stream.runDrain
            ),

            // Like indexer
            filterLikeEvents(likeStream).pipe(
              Stream.mapEffect((event) =>
                likeIndexer.processLike(event).pipe(
                  Effect.tap(() =>
                    Ref.update(likesProcessedRef, (n) => n + 1)
                  ),
                  Effect.catchAll((error) =>
                    Effect.logError(
                      `Like indexer error: ${error.message}`
                    )
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

    return { getStatus };
  });

export { POST_COLLECTION, LIKE_COLLECTION };
