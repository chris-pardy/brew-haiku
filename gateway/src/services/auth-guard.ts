import { Effect } from "effect";
import { HttpServerRequest } from "@effect/platform";

export class AuthError extends Error {
  readonly _tag = "AuthError";
  constructor(message: string = "Authentication required") {
    super(message);
  }
}

/**
 * Extracts the DID from a Bearer JWT token.
 * Decodes the JWT payload without crypto verification
 * (same pattern as feed/src/services/viewer-auth.ts).
 */
export const getAuth: Effect.Effect<
  string,
  AuthError,
  HttpServerRequest.HttpServerRequest
> = Effect.gen(function* () {
  const request = yield* HttpServerRequest.HttpServerRequest;
  const authHeader = request.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    return yield* Effect.fail(new AuthError("Missing Bearer token"));
  }

  try {
    const token = authHeader.slice(7);
    const parts = token.split(".");
    if (parts.length !== 3) {
      return yield* Effect.fail(new AuthError("Invalid token format"));
    }

    const payload = parts[1];
    const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    const claims: { sub?: string } = JSON.parse(decoded);

    if (!claims.sub || !claims.sub.startsWith("did:")) {
      return yield* Effect.fail(new AuthError("Invalid token: missing DID"));
    }

    return claims.sub;
  } catch {
    return yield* Effect.fail(new AuthError("Failed to decode token"));
  }
});
