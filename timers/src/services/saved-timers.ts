import { Effect, Context, Layer } from "effect";
import { ATProtoService, ATProtoError } from "./atproto.js";

export class SavedTimersError extends Error {
  readonly _tag = "SavedTimersError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface SavedTimerRecord {
  uri: string;
  timerUri: string;
  savedAt: string;
}

export interface TimerDetails {
  uri: string;
  did: string;
  handle: string | null;
  name: string;
  vessel: string;
  brewType: string;
  ratio: number | null;
  steps: Array<{
    action: string;
    stepType: "timed" | "indeterminate";
    durationSeconds?: number;
  }>;
  createdAt: string;
}

export interface SavedTimerWithDetails {
  saveUri: string;
  savedAt: string;
  timer: TimerDetails;
}

const SAVED_TIMER_COLLECTION = "app.brew-haiku.savedTimer";
const TIMER_COLLECTION = "app.brew-haiku.timer";

export class SavedTimersService extends Context.Tag("SavedTimersService")<
  SavedTimersService,
  {
    readonly getSavedTimers: (
      did: string
    ) => Effect.Effect<SavedTimerWithDetails[], SavedTimersError | ATProtoError>;
  }
>() {}

// Fetch a single record from a PDS
const fetchRecord = async (
  pdsUrl: string,
  did: string,
  collection: string,
  rkey: string
): Promise<unknown | null> => {
  const url = `${pdsUrl}/xrpc/com.atproto.repo.getRecord?repo=${encodeURIComponent(did)}&collection=${encodeURIComponent(collection)}&rkey=${encodeURIComponent(rkey)}`;
  const response = await fetch(url);
  if (!response.ok) return null;
  const data = await response.json();
  return data.value;
};

// List records from a collection
const listRecords = async (
  pdsUrl: string,
  did: string,
  collection: string,
  limit = 100
): Promise<Array<{ uri: string; value: unknown }>> => {
  const url = `${pdsUrl}/xrpc/com.atproto.repo.listRecords?repo=${encodeURIComponent(did)}&collection=${encodeURIComponent(collection)}&limit=${limit}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new SavedTimersError(`Failed to list records: ${response.status}`);
  }
  const data = await response.json();
  return data.records || [];
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

// Resolve DID to PDS URL
const resolvePdsUrl = async (did: string): Promise<string> => {
  if (did.startsWith("did:plc:")) {
    const response = await fetch(`https://plc.directory/${did}`);
    if (response.ok) {
      const doc = await response.json();
      const service = doc.service?.find(
        (s: { type: string; serviceEndpoint: string }) =>
          s.type === "AtprotoPersonalDataServer"
      );
      if (service?.serviceEndpoint) {
        return service.serviceEndpoint;
      }
    }
  }
  return "https://bsky.social";
};

// Get handle from DID document
const resolveHandle = async (did: string): Promise<string | null> => {
  if (did.startsWith("did:plc:")) {
    try {
      const response = await fetch(`https://plc.directory/${did}`);
      if (response.ok) {
        const doc = await response.json();
        const handleAlias = doc.alsoKnownAs?.find((a: string) =>
          a.startsWith("at://")
        );
        if (handleAlias) {
          return handleAlias.replace("at://", "");
        }
      }
    } catch {
      // Ignore
    }
  }
  return null;
};

export const makeSavedTimersService = Effect.gen(function* () {
  const getSavedTimers = (
    did: string
  ): Effect.Effect<SavedTimerWithDetails[], SavedTimersError | ATProtoError> =>
    Effect.gen(function* () {
      // Resolve the user's PDS
      const pdsUrl = yield* Effect.tryPromise({
        try: () => resolvePdsUrl(did),
        catch: (e) => new SavedTimersError("Failed to resolve PDS URL", e),
      });

      // List all savedTimer records
      const savedTimerRecords = yield* Effect.tryPromise({
        try: () => listRecords(pdsUrl, did, SAVED_TIMER_COLLECTION),
        catch: (e) => new SavedTimersError("Failed to list saved timers", e),
      });

      // Fetch timer details for each saved timer
      const results: SavedTimerWithDetails[] = [];

      for (const record of savedTimerRecords) {
        const savedTimer = record.value as {
          timerUri?: string;
          createdAt?: string;
        };

        if (!savedTimer.timerUri) continue;

        const parsed = parseAtUri(savedTimer.timerUri);
        if (!parsed) continue;

        // Resolve the timer creator's PDS
        const timerPdsUrl = yield* Effect.tryPromise({
          try: () => resolvePdsUrl(parsed.did),
          catch: () => new SavedTimersError("Failed to resolve timer PDS"),
        });

        // Fetch the timer record
        const timerRecord = yield* Effect.tryPromise({
          try: () =>
            fetchRecord(timerPdsUrl, parsed.did, TIMER_COLLECTION, parsed.rkey),
          catch: () => new SavedTimersError("Failed to fetch timer"),
        });

        if (!timerRecord) continue;

        const timer = timerRecord as {
          name?: string;
          vessel?: string;
          brewType?: string;
          ratio?: number;
          steps?: Array<{
            action: string;
            stepType: "timed" | "indeterminate";
            durationSeconds?: number;
          }>;
          createdAt?: string;
        };

        // Get handle for the timer creator
        const handle = yield* Effect.tryPromise({
          try: () => resolveHandle(parsed.did),
          catch: () => new SavedTimersError("Failed to resolve handle"),
        });

        results.push({
          saveUri: record.uri,
          savedAt: savedTimer.createdAt || new Date().toISOString(),
          timer: {
            uri: savedTimer.timerUri,
            did: parsed.did,
            handle,
            name: timer.name || "Untitled Timer",
            vessel: timer.vessel || "Unknown",
            brewType: timer.brewType || "coffee",
            ratio: timer.ratio ?? null,
            steps: timer.steps || [],
            createdAt: timer.createdAt || new Date().toISOString(),
          },
        });
      }

      return results;
    });

  return { getSavedTimers };
});

export const SavedTimersServiceLive = Layer.effect(
  SavedTimersService,
  makeSavedTimersService
);
