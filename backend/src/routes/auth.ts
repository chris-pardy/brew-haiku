import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import {
  OAuthService,
  OAuthError,
  OAuthInvalidCodeError,
} from "../services/oauth.js";

export const authRoutes = HttpRouter.empty.pipe(
  HttpRouter.post(
    "/auth/callback",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;

      // Parse the request body
      let body: Record<string, string>;
      try {
        const bodyText = yield* Effect.tryPromise({
          try: () => request.text,
          catch: () => new Error("Failed to read request body"),
        });
        body = JSON.parse(bodyText);
      } catch {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Invalid JSON body" },
          { status: 400 }
        );
      }

      const { code, state, iss } = body;

      if (!code) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Authorization code is required" },
          { status: 400 }
        );
      }

      const oauthService = yield* OAuthService;
      const result = yield* oauthService
        .handleCallback({ code, state, iss })
        .pipe(
          Effect.catchTag("OAuthInvalidCodeError", (e) =>
            Effect.succeed({
              error: "InvalidCode",
              message: e.message,
            })
          ),
          Effect.catchTag("OAuthError", (e) =>
            Effect.succeed({
              error: "OAuthError",
              message: e.message,
            })
          )
        );

      if ("error" in result) {
        const status = result.error === "InvalidCode" ? 401 : 500;
        return yield* HttpServerResponse.json(result, { status });
      }

      return yield* HttpServerResponse.json({
        did: result.did,
        handle: result.handle,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresAt: result.expiresAt,
      });
    })
  ),

  HttpRouter.post(
    "/auth/refresh",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;

      // Parse the request body
      let body: Record<string, string>;
      try {
        const bodyText = yield* Effect.tryPromise({
          try: () => request.text,
          catch: () => new Error("Failed to read request body"),
        });
        body = JSON.parse(bodyText);
      } catch {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Invalid JSON body" },
          { status: 400 }
        );
      }

      const { refreshToken, did } = body;

      if (!refreshToken) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Refresh token is required" },
          { status: 400 }
        );
      }

      if (!did) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "DID is required" },
          { status: 400 }
        );
      }

      const oauthService = yield* OAuthService;
      const result = yield* oauthService
        .refreshToken(refreshToken, did)
        .pipe(
          Effect.catchTag("OAuthInvalidCodeError", (e) =>
            Effect.succeed({
              error: "InvalidToken",
              message: e.message,
            })
          ),
          Effect.catchTag("OAuthError", (e) =>
            Effect.succeed({
              error: "OAuthError",
              message: e.message,
            })
          )
        );

      if ("error" in result) {
        const status = result.error === "InvalidToken" ? 401 : 500;
        return yield* HttpServerResponse.json(result, { status });
      }

      return yield* HttpServerResponse.json({
        did: result.did,
        handle: result.handle,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresAt: result.expiresAt,
      });
    })
  )
);
