import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import { TimerService, TimerError, TimerNotFoundError } from "../services/timer.js";
import { PDSProxyService, PDSProxyError, RecordAlreadyExistsError, RecordNotFoundError } from "../services/pds-proxy.js";
import { ATProtoService } from "../services/atproto.js";
import { getAuth, getOptionalAuth, AuthError, type AuthInfo } from "../services/auth-middleware.js";
import type { TimerRecord } from "@brew-haiku/shared";

const TIMER_COLLECTION = "app.brew-haiku.timer";
const SAVED_TIMER_COLLECTION = "app.brew-haiku.savedTimer";
const DEFAULT_ACCOUNT_DID = process.env.DEFAULT_ACCOUNT_DID;

/** Generate a TID (timestamp-based ID) for ATProto rkeys */
const generateTid = (): string => {
  const now = BigInt(Date.now()) * 1000n; // microseconds
  const clockId = BigInt(Math.floor(Math.random() * 1024));
  const tid = (now << 10n) | clockId;
  // Encode as base32-sortable (ATProto TID format)
  const chars = "234567abcdefghijklmnopqrstuvwxyz";
  let result = "";
  let val = tid;
  for (let i = 0; i < 13; i++) {
    result = chars[Number(val & 31n)] + result;
    val >>= 5n;
  }
  return result;
};

/** Parse AT-URI → { did, collection, rkey } */
const parseAtUri = (
  uri: string
): { did: string; collection: string; rkey: string } | null => {
  const match = uri.match(/^at:\/\/([^/]+)\/([^/]+)\/([^/]+)$/);
  if (!match) return null;
  return { did: match[1], collection: match[2], rkey: match[3] };
};

/** Build a timerView response object from a Timer */
const toTimerView = (
  timer: {
    uri: string;
    did: string;
    handle: string | null;
    name: string;
    vessel: string;
    brewType: string;
    ratio: number | null;
    steps: Array<{ action: string; stepType: string; durationSeconds?: number }>;
    notes: string | null;
    saveCount: number;
    createdAt: Date;
  },
  cid: string,
  indexedAt: Date,
  saved?: boolean
) => {
  const view: Record<string, unknown> = {
    uri: timer.uri,
    cid,
    author: timer.did,
    name: timer.name,
    vessel: timer.vessel,
    brewType: timer.brewType,
    steps: timer.steps,
    saveCount: timer.saveCount,
    createdAt: timer.createdAt.toISOString(),
    indexedAt: indexedAt.toISOString(),
  };
  if (timer.notes) view.notes = timer.notes;
  if (timer.ratio != null) view.ratio = timer.ratio;
  if (saved !== undefined) view.saved = saved;
  return view;
};

interface SavedTimerInfo {
  rkeys: Set<string>;
  timerUris: string[];
}

/** Fetch user's saved timer rkeys and timer URIs from PDS */
const fetchSavedTimerInfo = (
  pdsUrl: string,
  did: string
): Effect.Effect<SavedTimerInfo, never> =>
  Effect.tryPromise({
    try: async () => {
      const url = `${pdsUrl}/xrpc/com.atproto.repo.listRecords?repo=${encodeURIComponent(did)}&collection=${encodeURIComponent(SAVED_TIMER_COLLECTION)}&limit=100`;
      const response = await fetch(url);
      if (!response.ok) return { rkeys: new Set<string>(), timerUris: [] };
      const data = await response.json();
      const rkeys = new Set<string>();
      const timerUris: string[] = [];
      for (const record of data.records || []) {
        const parsed = parseAtUri(record.uri);
        if (parsed) rkeys.add(parsed.rkey);
        const value = record.value as { timerUri?: string };
        if (value.timerUri) timerUris.push(value.timerUri);
      }
      return { rkeys, timerUris };
    },
    catch: () => ({ rkeys: new Set<string>(), timerUris: [] as string[] }),
  }).pipe(
    Effect.catchAll(() =>
      Effect.succeed({ rkeys: new Set<string>(), timerUris: [] as string[] })
    )
  );

/** Decode cursor (base64-encoded offset) */
const decodeCursor = (cursor: string | null): number => {
  if (!cursor) return 0;
  try {
    const decoded = atob(cursor);
    const offset = parseInt(decoded, 10);
    return isNaN(offset) ? 0 : Math.max(0, offset);
  } catch {
    return 0;
  }
};

/** Encode cursor */
const encodeCursor = (offset: number): string => btoa(String(offset));

// ─── Write Procedures ───────────────────────────────────────────────────────

const createTimerRoute = HttpRouter.empty.pipe(HttpRouter.post(
  "/xrpc/app.brew-haiku.createTimer",
  Effect.gen(function* () {
    const auth = yield* getAuth.pipe(
      Effect.catchTag("AuthError", (e) =>
        Effect.fail({ status: 401 as const, error: "AuthRequired", message: e.message })
      ),
      Effect.catchTag("ATProtoError", (e) =>
        Effect.fail({ status: 401 as const, error: "AuthRequired", message: e.message })
      )
    );

    const request = yield* HttpServerRequest.HttpServerRequest;
    const body = yield* (request.json as Effect.Effect<{
        name: string;
        vessel: string;
        brewType: string;
        steps: Array<{ action: string; stepType: string; durationSeconds?: number; unit?: string; ratioOfStep?: number; ratio?: number }>;
        notes?: string;
      }>).pipe(
      Effect.mapError(() => ({ status: 400 as const, error: "InvalidRequest", message: "Invalid JSON body" }))
    );

    if (!body.name || !body.vessel || !body.brewType || !body.steps) {
      return yield* Effect.fail({
        status: 400 as const,
        error: "InvalidRequest",
        message: "Missing required fields: name, vessel, brewType, steps",
      });
    }

    const pdsProxy = yield* PDSProxyService;
    const timerService = yield* TimerService;

    const rkey = generateTid();
    const now = new Date().toISOString();

    // Build timer record for PDS
    const timerRecord: Record<string, unknown> = {
      $type: TIMER_COLLECTION,
      name: body.name,
      vessel: body.vessel,
      brewType: body.brewType,
      steps: body.steps,
      createdAt: now,
    };
    if (body.notes) timerRecord.notes = body.notes;

    // 1. Create timer record on user's PDS
    const { uri, cid } = yield* pdsProxy.createRecord(auth, TIMER_COLLECTION, timerRecord, rkey).pipe(
      Effect.catchTag("RecordAlreadyExistsError", () =>
        Effect.fail({ status: 409 as const, error: "Conflict", message: "Timer record already exists" })
      ),
      Effect.catchTag("PDSProxyError", (e) =>
        Effect.fail({ status: 502 as const, error: "PDSError", message: e.message })
      )
    );

    // 2. Create savedTimer record on user's PDS (rkey = timer's rkey)
    yield* pdsProxy
      .createRecord(
        auth,
        SAVED_TIMER_COLLECTION,
        { $type: SAVED_TIMER_COLLECTION, timerUri: uri, createdAt: now },
        rkey
      )
      .pipe(
        Effect.catchTag("RecordAlreadyExistsError", () => Effect.void),
        Effect.catchTag("PDSProxyError", (e) =>
          Effect.fail({ status: 502 as const, error: "PDSError", message: e.message })
        )
      );

    // 3. Write-through: INSERT OR IGNORE into local index
    const localRecord: TimerRecord = {
      uri,
      did: auth.did,
      cid,
      handle: auth.handle,
      name: body.name,
      vessel: body.vessel,
      brew_type: body.brewType,
      ratio: null,
      steps: JSON.stringify(body.steps),
      notes: body.notes || null,
      save_count: 0,
      created_at: Date.now(),
      indexed_at: Date.now(),
    };
    yield* timerService.ensureTimer(localRecord).pipe(
      Effect.catchTag("TimerError", () => Effect.void) // non-fatal
    );

    return yield* HttpServerResponse.json({ uri, cid });
  }).pipe(
    Effect.catchAll((e) => {
      if ("status" in e && "error" in e) {
        return HttpServerResponse.json(
          { error: e.error, message: e.message },
          { status: e.status }
        );
      }
      return HttpServerResponse.json(
        { error: "InternalError", message: "Unexpected error" },
        { status: 500 }
      );
    })
  )
));

const saveTimerRoute = HttpRouter.empty.pipe(HttpRouter.post(
  "/xrpc/app.brew-haiku.saveTimer",
  Effect.gen(function* () {
    const auth = yield* getAuth.pipe(
      Effect.catchTag("AuthError", (e) =>
        Effect.fail({ status: 401 as const, error: "AuthRequired", message: e.message })
      ),
      Effect.catchTag("ATProtoError", (e) =>
        Effect.fail({ status: 401 as const, error: "AuthRequired", message: e.message })
      )
    );

    const request = yield* HttpServerRequest.HttpServerRequest;
    const body = yield* (request.json as Effect.Effect<{ timerUri: string }>).pipe(
      Effect.mapError(() => ({ status: 400 as const, error: "InvalidRequest", message: "Invalid JSON body" }))
    );

    if (!body.timerUri) {
      return yield* Effect.fail({
        status: 400 as const,
        error: "InvalidRequest",
        message: "Missing required field: timerUri",
      });
    }

    const parsed = parseAtUri(body.timerUri);
    if (!parsed || parsed.collection !== TIMER_COLLECTION) {
      return yield* Effect.fail({
        status: 400 as const,
        error: "InvalidRequest",
        message: "Invalid timer URI",
      });
    }

    const pdsProxy = yield* PDSProxyService;
    const timerService = yield* TimerService;

    // Create savedTimer on user's PDS (rkey = timer's rkey)
    const { uri } = yield* pdsProxy
      .createRecord(
        auth,
        SAVED_TIMER_COLLECTION,
        {
          $type: SAVED_TIMER_COLLECTION,
          timerUri: body.timerUri,
          createdAt: new Date().toISOString(),
        },
        parsed.rkey
      )
      .pipe(
        Effect.catchTag("RecordAlreadyExistsError", () =>
          Effect.fail({ status: 409 as const, error: "AlreadySaved", message: "The user has already saved this timer" })
        ),
        Effect.catchTag("PDSProxyError", (e) =>
          Effect.fail({ status: 502 as const, error: "PDSError", message: e.message })
        )
      );

    // Update local save count
    yield* timerService.updateSaveCount(body.timerUri, 1).pipe(
      Effect.catchTag("TimerError", () => Effect.void)
    );

    return yield* HttpServerResponse.json({ uri });
  }).pipe(
    Effect.catchAll((e) => {
      if ("status" in e && "error" in e) {
        return HttpServerResponse.json(
          { error: e.error, message: e.message },
          { status: e.status }
        );
      }
      return HttpServerResponse.json(
        { error: "InternalError", message: "Unexpected error" },
        { status: 500 }
      );
    })
  )
));

const forgetTimerRoute = HttpRouter.empty.pipe(HttpRouter.post(
  "/xrpc/app.brew-haiku.forgetTimer",
  Effect.gen(function* () {
    const auth = yield* getAuth.pipe(
      Effect.catchTag("AuthError", (e) =>
        Effect.fail({ status: 401 as const, error: "AuthRequired", message: e.message })
      ),
      Effect.catchTag("ATProtoError", (e) =>
        Effect.fail({ status: 401 as const, error: "AuthRequired", message: e.message })
      )
    );

    const request = yield* HttpServerRequest.HttpServerRequest;
    const body = yield* (request.json as Effect.Effect<{ timerUri: string }>).pipe(
      Effect.mapError(() => ({ status: 400 as const, error: "InvalidRequest", message: "Invalid JSON body" }))
    );

    if (!body.timerUri) {
      return yield* Effect.fail({
        status: 400 as const,
        error: "InvalidRequest",
        message: "Missing required field: timerUri",
      });
    }

    const parsed = parseAtUri(body.timerUri);
    if (!parsed || parsed.collection !== TIMER_COLLECTION) {
      return yield* Effect.fail({
        status: 400 as const,
        error: "InvalidRequest",
        message: "Invalid timer URI",
      });
    }

    const pdsProxy = yield* PDSProxyService;
    const timerService = yield* TimerService;

    // Delete savedTimer from user's PDS
    yield* pdsProxy.deleteRecord(auth, SAVED_TIMER_COLLECTION, parsed.rkey).pipe(
      Effect.catchTag("RecordNotFoundError", () =>
        Effect.fail({ status: 404 as const, error: "NotSaved", message: "The user has not saved this timer" })
      ),
      Effect.catchTag("PDSProxyError", (e) =>
        Effect.fail({ status: 502 as const, error: "PDSError", message: e.message })
      )
    );

    // Update local save count
    yield* timerService.updateSaveCount(body.timerUri, -1).pipe(
      Effect.catchTag("TimerError", () => Effect.void)
    );

    return yield* HttpServerResponse.json({}, { status: 200 });
  }).pipe(
    Effect.catchAll((e) => {
      if ("status" in e && "error" in e) {
        return HttpServerResponse.json(
          { error: e.error, message: e.message },
          { status: e.status }
        );
      }
      return HttpServerResponse.json(
        { error: "InternalError", message: "Unexpected error" },
        { status: 500 }
      );
    })
  )
));

// ─── Read Queries ───────────────────────────────────────────────────────────

const getTimerRoute = HttpRouter.empty.pipe(HttpRouter.get(
  "/xrpc/app.brew-haiku.getTimer",
  Effect.gen(function* () {
    const request = yield* HttpServerRequest.HttpServerRequest;
    const url = new URL(request.url, "http://localhost");
    const uri = url.searchParams.get("uri");

    if (!uri) {
      return yield* HttpServerResponse.json(
        { error: "InvalidRequest", message: "Missing required parameter: uri" },
        { status: 400 }
      );
    }

    const timerService = yield* TimerService;
    const timer = yield* timerService.getTimer(uri).pipe(
      Effect.catchTag("TimerNotFoundError", (e) =>
        Effect.fail({ status: 404 as const, error: "NotFound", message: e.message })
      ),
      Effect.catchTag("TimerError", (e) =>
        Effect.fail({ status: 500 as const, error: "InternalError", message: e.message })
      )
    );

    const auth = yield* getOptionalAuth;

    let saved: boolean | undefined;
    if (auth) {
      const parsed = parseAtUri(uri);
      if (parsed) {
        const info = yield* fetchSavedTimerInfo(auth.pdsUrl, auth.did);
        saved = info.rkeys.has(parsed.rkey);
      }
    }

    // We don't store cid separately in the view, use empty string as fallback
    const view = toTimerView(timer, "", new Date(), saved);
    return yield* HttpServerResponse.json(view);
  }).pipe(
    Effect.catchAll((e) => {
      if ("status" in e && "error" in e) {
        return HttpServerResponse.json(
          { error: e.error, message: e.message },
          { status: e.status }
        );
      }
      return HttpServerResponse.json(
        { error: "InternalError", message: "Unexpected error" },
        { status: 500 }
      );
    })
  )
));

/** Resolve a DID to its PDS URL via ATProtoService */
const resolvePdsUrl = (
  did: string
): Effect.Effect<string, never, ATProtoService> =>
  Effect.gen(function* () {
    const atproto = yield* ATProtoService;
    const resolved = yield* atproto.resolveDID(did).pipe(
      Effect.catchAll(() => Effect.succeed({ pdsUrl: "https://bsky.social" } as { pdsUrl: string }))
    );
    return resolved.pdsUrl;
  });

/** Shared logic for listing saved timers by DID */
const listSavedTimersForDid = (
  did: string,
  pdsUrl: string,
  limit: number,
  offset: number,
  isSelf: boolean
): Effect.Effect<
  { timers: Array<Record<string, unknown>>; cursor?: string },
  { status: number; error: string; message: string },
  TimerService
> =>
  Effect.gen(function* () {
    const timerService = yield* TimerService;
    const info = yield* fetchSavedTimerInfo(pdsUrl, did);

    if (info.timerUris.length === 0) {
      return { timers: [] };
    }

    // Page the URI list
    const pagedUris = info.timerUris.slice(offset, offset + limit);
    const timers = yield* timerService.getTimersByUris(pagedUris).pipe(
      Effect.catchTag("TimerError", () => Effect.succeed([] as Array<import("../services/timer.js").Timer>))
    );

    // Build a set of saved rkeys for the saved flag
    const timerViews = timers.map((t) => {
      const parsed = parseAtUri(t.uri);
      const saved = parsed ? info.rkeys.has(parsed.rkey) : false;
      return toTimerView(t, "", new Date(), isSelf ? true : saved);
    });

    const nextOffset = offset + limit;
    const cursor = nextOffset < info.timerUris.length ? encodeCursor(nextOffset) : undefined;
    return { timers: timerViews, cursor };
  });

const listTimersRoute = HttpRouter.empty.pipe(HttpRouter.get(
  "/xrpc/app.brew-haiku.listTimers",
  Effect.gen(function* () {
    const request = yield* HttpServerRequest.HttpServerRequest;
    const url = new URL(request.url, "http://localhost");

    const limitParam = url.searchParams.get("limit");
    const cursorParam = url.searchParams.get("cursor");
    const limit = Math.min(Math.max(1, limitParam ? parseInt(limitParam, 10) : 50), 100);
    const offset = decodeCursor(cursorParam);

    const auth = yield* getOptionalAuth;

    if (auth) {
      // Authenticated: list user's saved timers
      const result = yield* listSavedTimersForDid(auth.did, auth.pdsUrl, limit, offset, true);
      return yield* HttpServerResponse.json(result);
    }

    // Unauthenticated: fall back to DEFAULT_ACCOUNT_DID
    if (DEFAULT_ACCOUNT_DID) {
      const pdsUrl = yield* resolvePdsUrl(DEFAULT_ACCOUNT_DID);
      const result = yield* listSavedTimersForDid(DEFAULT_ACCOUNT_DID, pdsUrl, limit, offset, false);
      return yield* HttpServerResponse.json(result);
    }

    // No fallback DID configured: return popular timers
    const timerService = yield* TimerService;
    const result = yield* timerService.listTimers({ limit, offset }).pipe(
      Effect.catchTag("TimerError", (e) =>
        Effect.fail({ status: 500 as const, error: "InternalError", message: e.message })
      )
    );

    const timerViews = result.timers.map((t) => toTimerView(t, "", new Date()));
    const nextOffset = offset + limit;
    const cursor = nextOffset < result.total ? encodeCursor(nextOffset) : undefined;

    return yield* HttpServerResponse.json({ timers: timerViews, cursor });
  }).pipe(
    Effect.catchAll((e) => {
      if ("status" in e && "error" in e) {
        return HttpServerResponse.json(
          { error: e.error, message: e.message },
          { status: e.status }
        );
      }
      return HttpServerResponse.json(
        { error: "InternalError", message: "Unexpected error" },
        { status: 500 }
      );
    })
  )
));

const searchTimersRoute = HttpRouter.empty.pipe(HttpRouter.get(
  "/xrpc/app.brew-haiku.searchTimers",
  Effect.gen(function* () {
    const request = yield* HttpServerRequest.HttpServerRequest;
    const url = new URL(request.url, "http://localhost");

    const query = url.searchParams.get("q");
    if (!query || query.trim().length === 0) {
      return yield* HttpServerResponse.json(
        { error: "InvalidRequest", message: "Missing required parameter: q" },
        { status: 400 }
      );
    }

    const limitParam = url.searchParams.get("limit");
    const cursorParam = url.searchParams.get("cursor");
    const brewType = url.searchParams.get("brewType") || undefined;
    const limit = Math.min(Math.max(1, limitParam ? parseInt(limitParam, 10) : 25), 100);
    const offset = decodeCursor(cursorParam);

    const timerService = yield* TimerService;
    const result = yield* timerService
      .searchTimers({ query: query.trim(), limit, offset, brewType })
      .pipe(
        Effect.catchTag("TimerError", (e) =>
          Effect.fail({ status: 500 as const, error: "InternalError", message: e.message })
        )
      );

    const auth = yield* getOptionalAuth;

    let savedRkeys: Set<string> | null = null;
    if (auth) {
      const info = yield* fetchSavedTimerInfo(auth.pdsUrl, auth.did);
      savedRkeys = info.rkeys;
    }

    const timerViews = result.timers.map((t) => {
      let saved: boolean | undefined;
      if (savedRkeys) {
        const parsed = parseAtUri(t.uri);
        if (parsed) saved = savedRkeys.has(parsed.rkey);
      }
      return toTimerView(t, "", new Date(), saved);
    });

    const nextOffset = offset + limit;
    const cursor = nextOffset < result.total ? encodeCursor(nextOffset) : undefined;

    return yield* HttpServerResponse.json({ timers: timerViews, cursor });
  }).pipe(
    Effect.catchAll((e) => {
      if ("status" in e && "error" in e) {
        return HttpServerResponse.json(
          { error: e.error, message: e.message },
          { status: e.status }
        );
      }
      return HttpServerResponse.json(
        { error: "InternalError", message: "Unexpected error" },
        { status: 500 }
      );
    })
  )
));

// ─── Combined Router ────────────────────────────────────────────────────────

export const xrpcRoutes = HttpRouter.empty.pipe(
  HttpRouter.concat(createTimerRoute),
  HttpRouter.concat(saveTimerRoute),
  HttpRouter.concat(forgetTimerRoute),
  HttpRouter.concat(getTimerRoute),
  HttpRouter.concat(listTimersRoute),
  HttpRouter.concat(searchTimersRoute)
);
