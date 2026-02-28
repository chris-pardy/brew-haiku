/**
 * Lightweight reverse proxy that routes incoming HTTP traffic to the
 * feed or timers service based on the request path.
 *
 * Also handles OAuth login flow for ATProto (PAR + PKCE).
 *
 * On Fly.io the two backend services are reachable via internal DNS:
 *   feed.process.brew-haiku.internal:8080
 *   timers.process.brew-haiku.internal:8083
 *
 * Only the gateway process group is exposed to the internet (ports 80/443).
 */

import { Effect, Layer } from "effect";
import { HttpRouter, HttpServer, HttpServerResponse, HttpMiddleware } from "@effect/platform";
import { BunHttpServer, BunRuntime } from "@effect/platform-bun";
import { oauthRoutes } from "./routes/oauth.js";
import { proxyHandler } from "./routes/proxy.js";
import { OAuthGatewayServiceLive } from "./services/oauth.js";

const PORT = parseInt(process.env.GATEWAY_PORT || process.env.PORT || "8080", 10);
const HOST = process.env.HOST || "localhost";

const AppRouter = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/",
    HttpServerResponse.json({
      name: "Brew Haiku Gateway",
      version: "1.0.0",
      status: "running",
    })
  ),
  HttpRouter.concat(oauthRoutes),
  // Catch-all: proxy unmatched routes to upstream services
  HttpRouter.all("*", proxyHandler)
);

const app = AppRouter.pipe(HttpServer.serve(HttpMiddleware.logger));

const ServerLive = app.pipe(
  Layer.provide(BunHttpServer.layer({ port: PORT, hostname: HOST })),
  Layer.provide(OAuthGatewayServiceLive)
);

const program = Layer.launch(ServerLive).pipe(
  Effect.tap(() =>
    Effect.log(`Gateway listening on ${HOST}:${PORT}`)
  ),
  Effect.tap(() =>
    Effect.log(`  Feed  → ${process.env.FEED_INTERNAL_URL || "http://localhost:8080"}`)
  ),
  Effect.tap(() =>
    Effect.log(`  Timers → ${process.env.TIMERS_INTERNAL_URL || "http://localhost:8083"}`)
  )
);

BunRuntime.runMain(program);
