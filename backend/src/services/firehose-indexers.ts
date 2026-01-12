import { Effect, Stream, Ref, Duration, pipe } from "effect";
import { DatabaseService, type TimerRecord } from "./database.js";
import {
  type JetstreamEvent,
  type JetstreamCommitEvent,
  isCommitEvent,
  filterByCollection,
} from "./jetstream.js";
import { detectHaiku } from "./haiku-detector.js";

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

// Check if a post is a valid haiku
const isHaikuPost = (text: string): boolean => {
  return detectHaiku(text).isHaiku;
};

// Parse AT-URI format: at://did/collection/rkey
const parseAtUri = (
  uri: string
): { did: string; collection: string; rkey: string } | null => {
  const match = uri.match(/^at:\/\/([^/]+)\/([^/]+)\/([^/]+)$/);
  if (!match) return null;
  return {
    did: match[1],
    collection: match[2],
    rkey: match[3],
  };
};

// Fetch timer record from user's PDS
const fetchTimerFromPDS = async (
  timerUri: string
): Promise<TimerRecord | null> => {
  const parsed = parseAtUri(timerUri);
  if (!parsed) return null;

  const { did, collection, rkey } = parsed;

  // First resolve DID to get PDS URL
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

  // Fetch the record
  try {
    const url = `${pdsUrl}/xrpc/com.atproto.repo.getRecord?repo=${encodeURIComponent(did)}&collection=${encodeURIComponent(collection)}&rkey=${encodeURIComponent(rkey)}`;
    const response = await fetch(url);
    if (!response.ok) return null;

    const data = await response.json();
    const record = data.value;

    if (!record) return null;

    // Also try to get handle from DID document
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
      save_count: 1, // First save
      created_at: record.createdAt
        ? new Date(record.createdAt).getTime()
        : Date.now(),
      indexed_at: Date.now(),
    };
  } catch {
    return null;
  }
};

// Filter stream for haiku posts (creates/updates only)
export const filterHaikuPosts = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(
    filterByCollection(POST_COLLECTION),
    Stream.filter((e) => {
      const text = e.commit.record?.text;
      return typeof text === "string" && isHaikuPost(text);
    })
  );

// Filter stream for post delete events
export const filterPostDeletes = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(
    filterByCollection(POST_COLLECTION),
    Stream.filter((e) => e.commit.operation === "delete")
  );

// Filter stream for savedTimer events
export const filterSavedTimerEvents = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(filterByCollection(SAVED_TIMER_COLLECTION));

// Filter stream for like events
export const filterLikeEvents = <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(filterByCollection(LIKE_COLLECTION));

// Haiku indexer - processes haiku post events
export const createHaikuIndexer = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  const indexPost = (event: JetstreamCommitEvent): Effect.Effect<void, IndexerError> =>
    Effect.try({
      try: () => {
        const { did, commit } = event;
        const { rkey, record, cid } = commit;
        const uri = `at://${did}/${commit.collection}/${rkey}`;

        if (commit.operation === "delete") {
          // Delete the post and cascade delete associated likes
          // This properly handles deletion of objectionable content
          db.run("DELETE FROM haiku_likes WHERE post_uri = ?", [uri]);
          db.run("DELETE FROM haiku_posts WHERE uri = ?", [uri]);
          return;
        }

        if (!record?.text || !cid) {
          return;
        }

        const haikuResult = detectHaiku(record.text as string);
        const hasSignature = haikuResult.hasSignature ? 1 : 0;

        const createdAt =
          typeof record.createdAt === "string"
            ? new Date(record.createdAt).getTime()
            : Date.now();

        // For updates, preserve the existing like_count
        // For creates, initialize to 0
        const existing = db
          .query<{ like_count: number }, [string]>(
            "SELECT like_count FROM haiku_posts WHERE uri = ?"
          )
          .get(uri);
        const likeCount = existing?.like_count ?? 0;

        db.run(
          `INSERT OR REPLACE INTO haiku_posts (uri, did, cid, text, has_signature, like_count, created_at, indexed_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [uri, did, cid, record.text as string, hasSignature, likeCount, createdAt, Date.now()]
        );
      },
      catch: (error) => new IndexerError("Failed to index haiku post", error),
    });

  return { indexPost };
});

// Like indexer - tracks likes on haiku posts
export const createLikeIndexer = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  // Check if a post exists in our haiku_posts table
  const isIndexedHaiku = (postUri: string): boolean => {
    const result = db
      .query<{ uri: string }, [string]>(
        "SELECT uri FROM haiku_posts WHERE uri = ?"
      )
      .get(postUri);
    return result !== null;
  };

  // Update like count for a haiku post
  const updateLikeCount = (postUri: string, delta: number): void => {
    db.run(
      `UPDATE haiku_posts SET like_count = MAX(0, like_count + ?) WHERE uri = ?`,
      [delta, postUri]
    );
  };

  // Track a like in our database
  const trackLike = (likeUri: string, postUri: string, likerDid: string): void => {
    db.run(
      `INSERT OR IGNORE INTO haiku_likes (like_uri, post_uri, liker_did, created_at)
       VALUES (?, ?, ?, ?)`,
      [likeUri, postUri, likerDid, Date.now()]
    );
  };

  // Remove a tracked like and return the post URI
  const untrackLike = (likeUri: string): string | null => {
    const result = db
      .query<{ post_uri: string }, [string]>(
        "SELECT post_uri FROM haiku_likes WHERE like_uri = ?"
      )
      .get(likeUri);

    if (result) {
      db.run("DELETE FROM haiku_likes WHERE like_uri = ?", [likeUri]);
    }

    return result?.post_uri ?? null;
  };

  const processLike = (event: JetstreamCommitEvent): Effect.Effect<void, IndexerError> =>
    Effect.try({
      try: () => {
        const { did, commit } = event;
        const likeUri = `at://${did}/${commit.collection}/${commit.rkey}`;

        if (commit.operation === "create") {
          // Extract the subject URI from the like record
          // Like record structure: { subject: { uri: "at://...", cid: "..." }, createdAt: "..." }
          const subject = commit.record?.subject as { uri?: string; cid?: string } | undefined;
          const postUri = subject?.uri;

          if (!postUri || typeof postUri !== "string") {
            return;
          }

          // Only process likes for posts we're tracking
          if (!isIndexedHaiku(postUri)) {
            return;
          }

          // Track this like and increment the count
          trackLike(likeUri, postUri, did);
          updateLikeCount(postUri, 1);
        } else if (commit.operation === "delete") {
          // Look up which post this like was for
          const postUri = untrackLike(likeUri);
          if (postUri) {
            updateLikeCount(postUri, -1);
          }
        }
      },
      catch: (error) => new IndexerError("Failed to process like", error),
    });

  return { processLike, isIndexedHaiku };
});

// Timer indexer - processes savedTimer events
export const createTimerIndexer = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  const timerExists = (timerUri: string): boolean => {
    const result = db
      .query<{ uri: string }, [string]>(
        "SELECT uri FROM timer_index WHERE uri = ?"
      )
      .get(timerUri);
    return result !== null;
  };

  const updateSaveCount = (
    timerUri: string,
    delta: number
  ): Effect.Effect<void, IndexerError> =>
    Effect.try({
      try: () => {
        db.run(
          `UPDATE timer_index SET save_count = MAX(0, save_count + ?) WHERE uri = ?`,
          [delta, timerUri]
        );
      },
      catch: (error) => new IndexerError("Failed to update timer save count", error),
    });

  const removeIfZeroSaves = (timerUri: string): Effect.Effect<void, IndexerError> =>
    Effect.try({
      try: () => {
        db.run(
          "DELETE FROM timer_index WHERE uri = ? AND save_count <= 0",
          [timerUri]
        );
      },
      catch: (error) => new IndexerError("Failed to remove timer", error),
    });

  const fetchAndIndex = (timerUri: string): Effect.Effect<void, IndexerError> =>
    Effect.gen(function* () {
      if (timerExists(timerUri)) {
        return;
      }

      const timer = yield* Effect.tryPromise({
        try: () => fetchTimerFromPDS(timerUri),
        catch: (e) => new IndexerError("Failed to fetch timer from PDS", e),
      });

      if (!timer) {
        return;
      }

      yield* Effect.try({
        try: () => {
          db.run(
            `INSERT OR REPLACE INTO timer_index
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
        },
        catch: (e) => new IndexerError("Failed to index timer", e),
      });
    });

  const handleCreate = (event: JetstreamCommitEvent): Effect.Effect<void, IndexerError> =>
    Effect.gen(function* () {
      const timerUri = event.commit.record?.timerUri;

      if (!timerUri || typeof timerUri !== "string") {
        return;
      }

      if (timerExists(timerUri)) {
        yield* updateSaveCount(timerUri, 1);
      } else {
        yield* fetchAndIndex(timerUri);
      }
    });

  const handleDelete = (event: JetstreamCommitEvent): Effect.Effect<void, IndexerError> =>
    Effect.gen(function* () {
      const rkey = event.commit.rkey;

      // Look for timer with matching rkey pattern
      const result = db
        .query<{ uri: string }, [string]>(
          "SELECT uri FROM timer_index WHERE uri LIKE ?"
        )
        .get(`%/${rkey}`);

      if (result) {
        yield* updateSaveCount(result.uri, -1);
        yield* removeIfZeroSaves(result.uri);
      }
    });

  const processEvent = (event: JetstreamCommitEvent): Effect.Effect<void, IndexerError> => {
    if (event.commit.operation === "create") {
      return handleCreate(event);
    } else if (event.commit.operation === "delete") {
      return handleDelete(event);
    }
    return Effect.void;
  };

  return { processEvent, fetchAndIndex, updateSaveCount };
});

// Cursor persistence - saves cursor periodically
export const createCursorPersister = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  const saveCursor = (cursorUs: number): Effect.Effect<void, IndexerError> =>
    Effect.try({
      try: () => {
        db.run(
          `INSERT OR REPLACE INTO firehose_cursor (id, cursor_us, updated_at)
           VALUES (1, ?, ?)`,
          [cursorUs, Date.now()]
        );
      },
      catch: (error) => new IndexerError("Failed to save cursor", error),
    });

  const loadCursor = (): Effect.Effect<number | null, IndexerError> =>
    Effect.try({
      try: () => {
        const result = db
          .query<{ cursor_us: number }, []>(
            "SELECT cursor_us FROM firehose_cursor WHERE id = 1"
          )
          .get();
        return result?.cursor_us ?? null;
      },
      catch: (error) => new IndexerError("Failed to load cursor", error),
    });

  return { saveCursor, loadCursor };
});

// Run haiku indexer as a stream consumer
export const runHaikuIndexer = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>
): Effect.Effect<void, E | IndexerError, DatabaseService> =>
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

// Run timer indexer as a stream consumer
export const runTimerIndexer = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>
): Effect.Effect<void, E | IndexerError, DatabaseService> =>
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

// Run cursor persister - samples stream and saves cursor periodically
export const runCursorPersister = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>,
  interval: Duration.Duration = Duration.seconds(30)
): Effect.Effect<void, E | IndexerError, DatabaseService> =>
  Effect.gen(function* () {
    const persister = yield* createCursorPersister;
    const lastCursorRef = yield* Ref.make<number | null>(null);

    // Sample every interval and save
    yield* eventStream.pipe(
      Stream.tap((event) => Ref.set(lastCursorRef, event.time_us)),
      Stream.throttle({
        cost: () => 1,
        duration: interval,
        units: 1,
        strategy: "enforce",
      }),
      Stream.mapEffect(() =>
        Effect.gen(function* () {
          const cursor = yield* Ref.get(lastCursorRef);
          if (cursor !== null) {
            yield* persister.saveCursor(cursor);
            yield* Effect.log(`Saved cursor: ${cursor}`);
          }
        })
      ),
      Stream.runDrain
    );
  });

// Run like indexer as a stream consumer
export const runLikeIndexer = <E>(
  eventStream: Stream.Stream<JetstreamEvent, E>
): Effect.Effect<void, E | IndexerError, DatabaseService> =>
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

export { HAIKU_SIGNATURE, SAVED_TIMER_COLLECTION, TIMER_COLLECTION, POST_COLLECTION, LIKE_COLLECTION };
