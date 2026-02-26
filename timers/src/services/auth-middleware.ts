import { Effect } from "effect";
import { HttpServerRequest } from "@effect/platform";
import { ATProtoService, ATProtoError } from "./atproto.js";

export class AuthError extends Error {
  readonly _tag = "AuthError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface AuthInfo {
  did: string;
  handle: string;
  pdsUrl: string;
  accessToken: string;
}

/**
 * Decode JWT payload without crypto validation.
 * We validate authenticity by successfully writing to the user's PDS.
 */
const decodeJwtPayload = (token: string): { sub?: string; iss?: string } => {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new AuthError("Invalid JWT format");
  }
  const payload = parts[1];
  const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
  return JSON.parse(decoded);
};

/**
 * Extract auth info from Bearer token.
 * Decodes DID from JWT sub claim, resolves PDS URL via ATProtoService.
 */
export const getAuth: Effect.Effect<
  AuthInfo,
  AuthError | ATProtoError,
  ATProtoService | HttpServerRequest.HttpServerRequest
> = Effect.gen(function* () {
  const request = yield* HttpServerRequest.HttpServerRequest;
  const authHeader = request.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    return yield* Effect.fail(new AuthError("Missing or invalid Authorization header"));
  }

  const accessToken = authHeader.slice(7);

  let did: string;
  try {
    const claims = decodeJwtPayload(accessToken);
    if (!claims.sub || !claims.sub.startsWith("did:")) {
      return yield* Effect.fail(new AuthError("JWT missing valid 'sub' claim"));
    }
    did = claims.sub;
  } catch (e) {
    if (e instanceof AuthError) {
      return yield* Effect.fail(e);
    }
    return yield* Effect.fail(new AuthError("Failed to decode JWT", e));
  }

  const atproto = yield* ATProtoService;
  const resolved = yield* atproto.resolveDID(did).pipe(
    Effect.catchTag("HandleNotFoundError", () =>
      Effect.fail(new AuthError(`Could not resolve DID: ${did}`))
    )
  );

  return {
    did,
    handle: resolved.handle,
    pdsUrl: resolved.pdsUrl,
    accessToken,
  };
});

/**
 * Optional auth — returns null when unauthenticated instead of failing.
 */
export const getOptionalAuth: Effect.Effect<
  AuthInfo | null,
  never,
  ATProtoService | HttpServerRequest.HttpServerRequest
> = getAuth.pipe(
  Effect.map((auth) => auth as AuthInfo | null),
  Effect.catchAll(() => Effect.succeed(null))
);
