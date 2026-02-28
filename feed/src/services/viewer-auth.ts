import { Effect } from "effect";
import { HttpServerRequest } from "@effect/platform";

/**
 * Extract viewer DID from Authorization: Bearer <jwt> header.
 * Decodes JWT sub claim without crypto verification — auth is optional
 * per the ATProto feed generator spec.
 * Returns null when no valid auth header is present.
 */
export const getViewerDid: Effect.Effect<
  string | null,
  never,
  HttpServerRequest.HttpServerRequest
> = Effect.gen(function* () {
  const request = yield* HttpServerRequest.HttpServerRequest;
  const authHeader = request.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }

  const token = authHeader.slice(7);

  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const payload = parts[1];
    const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    const claims: { sub?: string } = JSON.parse(decoded);

    if (!claims.sub || !claims.sub.startsWith("did:")) return null;
    return claims.sub;
  } catch {
    return null;
  }
});
