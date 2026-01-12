import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import {
  SavedTimersService,
  SavedTimersError,
} from "../services/saved-timers.js";
import { ATProtoError } from "../services/atproto.js";

const DEFAULT_ACCOUNT_DID = process.env.DEFAULT_ACCOUNT_DID;

export const savedTimersRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/saved-timers",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;

      // Check for authenticated user DID
      // Support both Authorization Bearer token (DID) and X-User-DID header
      let userDid: string | null = null;

      const authHeader = request.headers.authorization;
      if (authHeader?.startsWith("Bearer ")) {
        const token = authHeader.slice(7);
        // For now, treat the token as the DID directly
        // In production, this would validate a JWT and extract the DID
        if (token.startsWith("did:")) {
          userDid = token;
        }
      }

      // Fallback to X-User-DID header
      if (!userDid) {
        const didHeader = request.headers["x-user-did"];
        if (typeof didHeader === "string" && didHeader.startsWith("did:")) {
          userDid = didHeader;
        }
      }

      // If no authenticated user, use the default account
      const targetDid = userDid || DEFAULT_ACCOUNT_DID;

      if (!targetDid) {
        return yield* HttpServerResponse.json(
          {
            error: "ConfigurationError",
            message:
              "No user authenticated and DEFAULT_ACCOUNT_DID is not configured",
          },
          { status: 500 }
        );
      }

      const savedTimersService = yield* SavedTimersService;
      const result = yield* savedTimersService.getSavedTimers(targetDid).pipe(
        Effect.catchTag("SavedTimersError", (e: SavedTimersError) =>
          Effect.succeed({
            error: "InternalError" as const,
            message: e.message,
          })
        ),
        Effect.catchTag("ATProtoError", (e: ATProtoError) =>
          Effect.succeed({
            error: "InternalError" as const,
            message: e.message,
          })
        )
      );

      if ("error" in result) {
        return yield* HttpServerResponse.json(result, { status: 500 });
      }

      return yield* HttpServerResponse.json({
        savedTimers: result,
        source: userDid ? "user" : "default",
        did: targetDid,
      });
    })
  )
);
