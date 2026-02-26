import { Effect, Context, Layer } from "effect";
import { Database } from "bun:sqlite";
import { DatabaseService, type DIDCacheRecord } from "@brew-haiku/shared";

export class ATProtoError extends Error {
  readonly _tag = "ATProtoError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export class HandleNotFoundError extends Error {
  readonly _tag = "HandleNotFoundError";
  constructor(public readonly handle: string) {
    super(`Handle not found: ${handle}`);
  }
}

export interface ResolvedDID {
  did: string;
  handle: string;
  pdsUrl: string;
  publicKey: string | null;
}

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

export class ATProtoService extends Context.Tag("ATProtoService")<
  ATProtoService,
  {
    readonly resolveHandle: (
      handle: string
    ) => Effect.Effect<ResolvedDID, ATProtoError | HandleNotFoundError>;
    readonly resolveDID: (
      did: string
    ) => Effect.Effect<ResolvedDID, ATProtoError | HandleNotFoundError>;
  }
>() {}

const normalizeHandle = (handle: string): string => {
  let normalized = handle.toLowerCase().trim();
  if (normalized.startsWith("@")) {
    normalized = normalized.slice(1);
  }
  return normalized;
};

const fetchDIDDocument = async (
  did: string
): Promise<{ pdsUrl: string; handle: string; publicKey: string | null }> => {
  if (did.startsWith("did:plc:")) {
    const response = await fetch(`https://plc.directory/${did}`);
    if (!response.ok) {
      throw new ATProtoError(`Failed to fetch DID document: ${response.status}`);
    }
    const doc = await response.json();
    const pdsService = doc.service?.find(
      (s: { id: string; type: string }) => s.type === "AtprotoPersonalDataServer"
    );
    const pdsUrl = pdsService?.serviceEndpoint || "https://bsky.social";
    const handle = doc.alsoKnownAs?.[0]?.replace("at://", "") || "";
    const verificationMethod = doc.verificationMethod?.[0];
    const publicKey = verificationMethod?.publicKeyMultibase || null;
    return { pdsUrl, handle, publicKey };
  } else if (did.startsWith("did:web:")) {
    const domain = did.replace("did:web:", "");
    const response = await fetch(`https://${domain}/.well-known/did.json`);
    if (!response.ok) {
      throw new ATProtoError(`Failed to fetch DID document: ${response.status}`);
    }
    const doc = await response.json();
    const pdsService = doc.service?.find(
      (s: { id: string; type: string }) => s.type === "AtprotoPersonalDataServer"
    );
    const pdsUrl = pdsService?.serviceEndpoint || `https://${domain}`;
    const handle = doc.alsoKnownAs?.[0]?.replace("at://", "") || domain;
    const verificationMethod = doc.verificationMethod?.[0];
    const publicKey = verificationMethod?.publicKeyMultibase || null;
    return { pdsUrl, handle, publicKey };
  }
  throw new ATProtoError(`Unsupported DID method: ${did}`);
};

const resolveHandleViaDNS = async (handle: string): Promise<string | null> => {
  try {
    const response = await fetch(
      `https://dns.google/resolve?name=_atproto.${handle}&type=TXT`
    );
    if (!response.ok) return null;
    const data = await response.json();
    const txtRecord = data.Answer?.find((a: { type: number }) => a.type === 16);
    if (txtRecord?.data) {
      const match = txtRecord.data.match(/did=([^\s"]+)/);
      if (match) return match[1];
    }
    return null;
  } catch {
    return null;
  }
};

const resolveHandleViaHTTPS = async (handle: string): Promise<string | null> => {
  try {
    const response = await fetch(`https://${handle}/.well-known/atproto-did`);
    if (!response.ok) return null;
    const text = await response.text();
    return text.trim();
  } catch {
    return null;
  }
};

const resolveHandleViaBsky = async (handle: string): Promise<string | null> => {
  try {
    const response = await fetch(
      `https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=${encodeURIComponent(handle)}`
    );
    if (!response.ok) return null;
    const data = await response.json();
    return data.did || null;
  } catch {
    return null;
  }
};

export const makeATProtoService = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  const getCachedDID = (
    handle: string
  ): DIDCacheRecord | null => {
    const cached = db
      .query<DIDCacheRecord, [string]>(
        "SELECT * FROM did_cache WHERE handle = ? AND cached_at > ?"
      )
      .get(handle, Date.now() - CACHE_TTL_MS);
    return cached || null;
  };

  const getCachedByDID = (
    did: string
  ): DIDCacheRecord | null => {
    const cached = db
      .query<DIDCacheRecord, [string]>(
        "SELECT * FROM did_cache WHERE did = ? AND cached_at > ?"
      )
      .get(did, Date.now() - CACHE_TTL_MS);
    return cached || null;
  };

  const cacheDID = (record: DIDCacheRecord): void => {
    db.run(
      `INSERT OR REPLACE INTO did_cache (did, handle, pds_url, public_key, cached_at)
       VALUES (?, ?, ?, ?, ?)`,
      [record.did, record.handle, record.pds_url, record.public_key, record.cached_at]
    );
  };

  const resolveHandle = (
    handle: string
  ): Effect.Effect<ResolvedDID, ATProtoError | HandleNotFoundError> =>
    Effect.gen(function* () {
      const normalized = normalizeHandle(handle);

      // Check cache first
      const cached = getCachedDID(normalized);
      if (cached) {
        return {
          did: cached.did,
          handle: cached.handle,
          pdsUrl: cached.pds_url,
          publicKey: cached.public_key,
        };
      }

      // Try DNS resolution first
      let did = yield* Effect.tryPromise({
        try: () => resolveHandleViaDNS(normalized),
        catch: (e) => new ATProtoError("DNS resolution failed", e),
      });

      // Try HTTPS resolution
      if (!did) {
        did = yield* Effect.tryPromise({
          try: () => resolveHandleViaHTTPS(normalized),
          catch: (e) => new ATProtoError("HTTPS resolution failed", e),
        });
      }

      // Try Bluesky API
      if (!did) {
        did = yield* Effect.tryPromise({
          try: () => resolveHandleViaBsky(normalized),
          catch: (e) => new ATProtoError("Bluesky resolution failed", e),
        });
      }

      if (!did) {
        return yield* Effect.fail(new HandleNotFoundError(handle));
      }

      // Fetch DID document for PDS URL
      const docInfo = yield* Effect.tryPromise({
        try: () => fetchDIDDocument(did!),
        catch: (e) => new ATProtoError("Failed to fetch DID document", e),
      });

      const record: DIDCacheRecord = {
        did,
        handle: normalized,
        pds_url: docInfo.pdsUrl,
        public_key: docInfo.publicKey,
        cached_at: Date.now(),
      };

      cacheDID(record);

      return {
        did: record.did,
        handle: record.handle,
        pdsUrl: record.pds_url,
        publicKey: record.public_key,
      };
    });

  const resolveDID = (
    did: string
  ): Effect.Effect<ResolvedDID, ATProtoError | HandleNotFoundError> =>
    Effect.gen(function* () {
      // Check cache first
      const cached = getCachedByDID(did);
      if (cached) {
        return {
          did: cached.did,
          handle: cached.handle,
          pdsUrl: cached.pds_url,
          publicKey: cached.public_key,
        };
      }

      // Fetch DID document
      const docInfo = yield* Effect.tryPromise({
        try: () => fetchDIDDocument(did),
        catch: (e) => new ATProtoError("Failed to fetch DID document", e),
      });

      if (!docInfo.handle) {
        return yield* Effect.fail(new HandleNotFoundError(did));
      }

      const record: DIDCacheRecord = {
        did,
        handle: docInfo.handle,
        pds_url: docInfo.pdsUrl,
        public_key: docInfo.publicKey,
        cached_at: Date.now(),
      };

      cacheDID(record);

      return {
        did: record.did,
        handle: record.handle,
        pdsUrl: record.pds_url,
        publicKey: record.public_key,
      };
    });

  return { resolveHandle, resolveDID };
});

export const ATProtoServiceLive = Layer.effect(ATProtoService, makeATProtoService);
