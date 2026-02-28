import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import { OAuthGatewayService, OAuthLoginError, OAuthCallbackError } from "../services/oauth.js";

const MOBILE_REDIRECT = "brew-haiku://oauth/callback";

export const oauthRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/oauth/client-metadata.json",
    Effect.gen(function* () {
      const oauth = yield* OAuthGatewayService;
      const metadata = yield* oauth.clientMetadata();
      return yield* HttpServerResponse.json(metadata, {
        headers: {
          "Access-Control-Allow-Origin": "*",
        },
      });
    })
  ),

  HttpRouter.get(
    "/oauth/login",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");
      const handle = url.searchParams.get("handle");

      if (!handle) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Missing handle parameter" },
          { status: 400 }
        );
      }

      const oauth = yield* OAuthGatewayService;
      const authorizationUrl = yield* oauth.initiateLogin(handle).pipe(
        Effect.catchTag("OAuthLoginError", (e) =>
          Effect.succeed(
            `${MOBILE_REDIRECT}?error=${encodeURIComponent(e.message)}`
          )
        )
      );

      return HttpServerResponse.empty({
        status: 302,
        headers: { Location: authorizationUrl },
      });
    })
  ),

  HttpRouter.get(
    "/oauth/callback",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");
      const code = url.searchParams.get("code");
      const state = url.searchParams.get("state");
      const error = url.searchParams.get("error");

      if (error) {
        const desc = url.searchParams.get("error_description") || error;
        return HttpServerResponse.empty({
          status: 302,
          headers: {
            Location: `${MOBILE_REDIRECT}?error=${encodeURIComponent(desc)}`,
          },
        });
      }

      if (!code || !state) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Missing code or state" },
          { status: 400 }
        );
      }

      const oauth = yield* OAuthGatewayService;
      const redirectUrl = yield* oauth.handleCallback(code, state).pipe(
        Effect.catchTag("OAuthCallbackError", (e) =>
          Effect.succeed(
            `${MOBILE_REDIRECT}?error=${encodeURIComponent(e.message)}`
          )
        )
      );

      return HttpServerResponse.empty({
        status: 302,
        headers: { Location: redirectUrl },
      });
    })
  )
);
