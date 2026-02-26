import { Effect, Stream, Ref, Duration } from "effect";
import type { TimerRecord } from "@brew-haiku/shared";
import {
  type JetstreamEvent,
  type JetstreamCommitEvent,
  isCommitEvent,
  filterByCollection,
} from "@brew-haiku/shared";
import { detectHaiku } from "./haiku-detector.js";
import { ClassifierService, type CategoryScores } from "./classifier.js";
import { FeedIngestClient, TimerIngestClient } from "./ingestion-client.js";
import { saveCursor } from "./cursor-file.js";

export class IndexerError extends Error {
  readonly _tag = "IndexerError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

const HAIKU_SIGNATURE = "via @brew-haiku.app";
const SAVED_TIMER_COLLECTION = "app.brew-haiku.savedTimer";
const TIMER_COLLECTION = "app.brew-haiku.timer";
const POST_COLLECTION = "app.bsky.feed.post";
const LIKE_COLLECTION = "app.bsky.feed.like";

const isHaikuPost = (text: string): boolean => {
  return detectHaiku(text).isHaiku;
};

// Parse AT-URI format: at://did/collection/rkey
const parseAtUri = (
  uri: string
): { did: string; collection: string; rkey: string } | null => {
  const match = uri.match(/^at:\/\/([^/]+)\/([^/]+)\/([^/]+)$/);
  if (!match) return null;
  return { did: match[1], collection: match[2], rkey: match[3] };
};

// Fetch timer record from user's PDS
const fetchTimerFromPDS = async (
  timerUri: string
): Promise<TimerRecord | null> => {
  const parsed = parseAtUri(timerUri);
  if (!parsed) return null;

  const { did, collection, rkey } = parsed;

  // Resolve DID to get PDS URL
  let pdsUrl = "https://bsky.social";
  if (did.startsWith("did:plc:")) {
    try {
      const plcResponse = await fetch(`https://plc.directory/${did}`);
      if (plcResponse.ok) {
        const doc = await plcResponse.json();
        const service = doc.service?.find(
          (s: { type: string; serviceEndpoint: string }) =>
            s.type === "AtprotoPersonalDataServer"
        );
        if (service?.serviceEndpoint) {
          pdsUrl = service.serviceEndpoint;
        }
      }
    } catch {
      // Fall back to default
    }
  }

  try {
    const url = `${pdsUrl}/xrpc/com.atproto.repo.getRecord?repo=${encodeURIComponent(did)}&collection=${encodeURIComponent(collection)}&rkey=${encodeURIComponent(rkey)}`;
    const response = await fetch(url);
    if (!response.ok) return null;

    const data = await response.json();
    const record = data.value;
    if (!record) return null;

    // Try to get handle from DID document
    let handle: string | null = null;
    try {
      const plcResponse = await fetch(`https://plc.directory/${did}`);
      if (plcResponse.ok) {
        const doc = await plcResponse.json();
        const handleAlias = doc.alsoKnownAs?.find((a: string) =>
          a.startsWith("at://")
        );
        if (handleAlias) {
          handle = handleAlias.replace("at://", "");
        }
      }
    } catch {
      // Ignore handle fetch errors
    }

    return {
      uri: timerUri,
      did,
      cid: data.cid || "",
      handle,
      name: record.name || "Untitled Timer",
      vessel: record.vessel || "Unknown",
      brew_type: record.brewType || "coffee",
      ratio: record.ratio ?? null,
      steps: JSON.stringify(record.steps || []),
      save_count: 1,
      created_at: record.createdAt
        ? new Date(record.createdAt).getTime()
        : Date.now(),
      indexed_at: Date.now(),
    };
  } catch {
    return null;
  }
};

// ---------------------------------------------------------------------------
// Stream filters
// ---------------------------------------------------------------------------

export const filterHaikuPosts = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(
    filterByCollection(POST_COLLECTION),
    Stream.filter((e) => {
      if (e.commit.operation === "delete") return true;
      const { record } = e.commit;
      const text = record?.text;
      if (typeof text !== "string") return false;

      // Use the post's langs field to reject non-English posts early
      const langs = record?.langs;
      if (Array.isArray(langs) && langs.length > 0) {
        const hasEnglish = langs.some(
          (l: unknown) => typeof l === "string" && l.startsWith("en")
        );
        if (!hasEnglish) return false;
      }

      return isHaikuPost(text);
    })
  );

export const filterPostDeletes = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(
    filterByCollection(POST_COLLECTION),
    Stream.filter((e) => e.commit.operation === "delete")
  );

export const filterSavedTimerEvents = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(filterByCollection(SAVED_TIMER_COLLECTION));

export const filterLikeEvents = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(filterByCollection(LIKE_COLLECTION));

// ---------------------------------------------------------------------------
// Haiku indexer — detect, classify, send to feed server
// ---------------------------------------------------------------------------

export const createHaikuIndexer = Effect.gen(function* () {
  const client = yield* FeedIngestClient;
  const classifierService = yield* ClassifierService;

  const indexPost = (
    event: JetstreamCommitEvent
  ): Effect.Effect<void, IndexerError> =>
    Effect.gen(function* () {
      const { did, commit } = event;
      const { rkey, record, cid } = commit;
      const uri = `at://${did}/${commit.collection}/${rkey}`;

      if (commit.operation === "delete") {
        yield* client.send({ type: "haiku:delete", uri });
        return;
      }

      if (!record?.text || !cid) return;

      const text = record.text as string;
      const haikuResult = detectHaiku(text);
      const hasSignature = haikuResult.hasSignature;

      const createdAt =
        typeof record.createdAt === "string"
          ? new Date(record.createdAt).getTime()
          : Date.now();

      // Classify the haiku text into categories
      const scores = yield* classifierService.classify(text).pipe(
        Effect.catchAll(() => {
          return Effect.succeed({
            coffee: 0,
            tea: 0,
            nature: 0,
            relaxation: 0,
            morning: 0,
            evening: 0,
          } as CategoryScores);
        })
      );
      // Yield CPU after inference on shared-cpu machines
      yield* Effect.sleep(Duration.millis(200));

      yield* client.send({
        type: "haiku:create",
        uri,
        did,
        cid,
        text,
        hasSignature,
        scores,
        createdAt,
      });
    });

  return { indexPost };
});

// ---------------------------------------------------------------------------
// Like indexer — forward like events to feed server
// ---------------------------------------------------------------------------

export const createLikeIndexer = Effect.gen(function* () {
  const client = yield* FeedIngestClient;

  const processLike = (
    event: JetstreamCommitEvent
  ): Effect.Effect<void, IndexerError> =>
    Effect.try({
      try: () => {
        const { did, commit } = event;
        const likeUri = `at://${did}/${commit.collection}/${commit.rkey}`;

        if (commit.operation === "create") {
          const subject = commit.record?.subject as
            | { uri?: string; cid?: string }
            | undefined;
          const postUri = subject?.uri;
          if (!postUri || typeof postUri !== "string") return;

          Effect.runSync(
            client.send({
              type: "like:create",
              likeUri,
              postUri,
              likerDid: did,
              createdAt: Date.now(),
            })
          );
        } else if (commit.operation === "delete") {
          Effect.runSync(client.send({ type: "like:delete", likeUri }));
        }
      },
      catch: (error) => new IndexerError("Failed to process like", error),
    });

  return { processLike };
});

// ---------------------------------------------------------------------------
// Timer indexer — fetch from PDS, send to timers server
// ---------------------------------------------------------------------------

export const createTimerIndexer = Effect.gen(function* () {
  const client = yield* TimerIngestClient;

  const handleCreate = (
    event: JetstreamCommitEvent
  ): Effect.Effect<void, IndexerError> =>
    Effect.gen(function* () {
      const timerUri = event.commit.record?.timerUri;
      if (!timerUri || typeof timerUri !== "string") return;

      // Always fetch from PDS and send full data; server handles dedup
      const timer = yield* Effect.tryPromise({
        try: () => fetchTimerFromPDS(timerUri),
        catch: (e) => new IndexerError("Failed to fetch timer from PDS", e),
      });

      if (!timer) return;

      yield* client.send({
        type: "timer:save",
        uri: timer.uri,
        did: timer.did,
        cid: timer.cid,
        handle: timer.handle,
        name: timer.name,
        vessel: timer.vessel,
        brewType: timer.brew_type,
        ratio: timer.ratio,
        steps: timer.steps,
        createdAt: timer.created_at,
      });
    });

  const handleDelete = (
    event: JetstreamCommitEvent
  ): Effect.Effect<void, IndexerError> =>
    Effect.gen(function* () {
      yield* client.send({
        type: "timer:unsave",
        rkey: event.commit.rkey,
        did: event.did,
      });
    });

  const processEvent = (
    event: JetstreamCommitEvent
  ): Effect.Effect<void, IndexerError> => {
    if (event.commit.operation === "create") return handleCreate(event);
    if (event.commit.operation === "delete") return handleDelete(event);
    return Effect.void;
  };

  return { processEvent };
});

// ---------------------------------------------------------------------------
// Cursor persister — saves cursor to a local file
// ---------------------------------------------------------------------------

export const createCursorPersister = (cursorPath: string) =>
  Effect.succeed({
    saveCursor: (cursorUs: number): Effect.Effect<void, IndexerError> =>
      Effect.try({
        try: () => saveCursor(cursorPath, cursorUs),
        catch: (error) => new IndexerError("Failed to save cursor", error),
      }),
  });

// ---------------------------------------------------------------------------
// Stream runners
// ---------------------------------------------------------------------------

export const runHaikuIndexer = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>
): Effect.Effect<void, E | IndexerError, FeedIngestClient | ClassifierService> =>
  Effect.gen(function* () {
    const indexer = yield* createHaikuIndexer;

    yield* filterHaikuPosts(eventStream).pipe(
      Stream.mapEffect((event) =>
        indexer.indexPost(event).pipe(
          Effect.catchAll((error) =>
            Effect.logError(`Haiku indexer error: ${error.message}`)
          )
        )
      ),
      Stream.runDrain
    );
  });

export const runTimerIndexer = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>
): Effect.Effect<void, E | IndexerError, TimerIngestClient> =>
  Effect.gen(function* () {
    const indexer = yield* createTimerIndexer;

    yield* filterSavedTimerEvents(eventStream).pipe(
      Stream.mapEffect((event) =>
        indexer.processEvent(event).pipe(
          Effect.catchAll((error) =>
            Effect.logError(`Timer indexer error: ${error.message}`)
          )
        )
      ),
      Stream.runDrain
    );
  });

export const runLikeIndexer = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>
): Effect.Effect<void, E | IndexerError, FeedIngestClient> =>
  Effect.gen(function* () {
    const indexer = yield* createLikeIndexer;

    yield* filterLikeEvents(eventStream).pipe(
      Stream.mapEffect((event) =>
        indexer.processLike(event).pipe(
          Effect.catchAll((error) =>
            Effect.logError(`Like indexer error: ${error.message}`)
          )
        )
      ),
      Stream.runDrain
    );
  });

export {
  HAIKU_SIGNATURE,
  SAVED_TIMER_COLLECTION,
  TIMER_COLLECTION,
  POST_COLLECTION,
  LIKE_COLLECTION,
};
