import { Effect, Context, Layer } from "effect";

export class FollowsResolverError extends Error {
  readonly _tag = "FollowsResolverError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export class FollowsResolverService extends Context.Tag("FollowsResolverService")<
  FollowsResolverService,
  {
    readonly getFollowDids: (
      viewerDid: string
    ) => Effect.Effect<Set<string>, FollowsResolverError>;
  }
>() {}

const CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes
const CACHE_MAX_ENTRIES = 1000;
const API_BASE = "https://public.api.bsky.app/xrpc";

interface CacheEntry {
  dids: Set<string>;
  expiresAt: number;
}

export const makeFollowsResolverService = () => {
  const cache = new Map<string, CacheEntry>();

  const evictExpired = () => {
    const now = Date.now();
    for (const [key, entry] of cache) {
      if (entry.expiresAt <= now) {
        cache.delete(key);
      }
    }
  };

  const evictIfFull = () => {
    if (cache.size >= CACHE_MAX_ENTRIES) {
      // Remove oldest entry
      const firstKey = cache.keys().next().value;
      if (firstKey !== undefined) cache.delete(firstKey);
    }
  };

  const fetchAllFollows = async (did: string): Promise<Set<string>> => {
    const dids = new Set<string>();
    let cursor: string | undefined;

    do {
      const url = new URL(`${API_BASE}/app.bsky.graph.getFollows`);
      url.searchParams.set("actor", did);
      url.searchParams.set("limit", "100");
      if (cursor) url.searchParams.set("cursor", cursor);

      const response = await fetch(url.toString());
      if (!response.ok) {
        throw new FollowsResolverError(
          `Failed to fetch follows: ${response.status} ${response.statusText}`
        );
      }

      const data: { follows: { did: string }[]; cursor?: string } =
        await response.json();

      for (const follow of data.follows) {
        dids.add(follow.did);
      }

      cursor = data.cursor;
    } while (cursor);

    return dids;
  };

  const getFollowDids = (
    viewerDid: string
  ): Effect.Effect<Set<string>, FollowsResolverError> =>
    Effect.gen(function* () {
      evictExpired();

      const cached = cache.get(viewerDid);
      if (cached && cached.expiresAt > Date.now()) {
        return cached.dids;
      }

      const dids = yield* Effect.tryPromise({
        try: () => fetchAllFollows(viewerDid),
        catch: (e) =>
          e instanceof FollowsResolverError
            ? e
            : new FollowsResolverError("Failed to resolve follows", e),
      });

      evictIfFull();
      cache.set(viewerDid, {
        dids,
        expiresAt: Date.now() + CACHE_TTL_MS,
      });

      return dids;
    });

  return { getFollowDids };
};

export const FollowsResolverServiceLive = Layer.succeed(
  FollowsResolverService,
  makeFollowsResolverService()
);
