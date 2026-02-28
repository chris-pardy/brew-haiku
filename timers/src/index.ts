import { Effect, Layer } from "effect";
import { HttpRouter, HttpServer, HttpServerResponse, HttpMiddleware } from "@effect/platform";
import { BunHttpServer, BunRuntime } from "@effect/platform-bun";
import { DatabaseServiceLive, DatabaseService, FollowsResolverServiceLive } from "@brew-haiku/shared";
import { healthRoutes } from "./routes/health.js";
import { timerRoutes } from "./routes/timers.js";
import { savedTimersRoutes } from "./routes/saved-timers.js";
import { authRoutes } from "./routes/auth.js";
import { resolveRoutes } from "./routes/resolve.js";
import { xrpcRoutes } from "./routes/xrpc.js";
import { TimerServiceLive } from "./services/timer.js";
import { ATProtoServiceLive } from "./services/atproto.js";
import { OAuthServiceLive } from "./services/oauth.js";
import { SavedTimersServiceLive } from "./services/saved-timers.js";
import { PDSProxyServiceLive } from "./services/pds-proxy.js";
import { BrewServiceLive } from "./services/brew.js";
import { ActivityServiceLive } from "./services/activity.js";
import { createTimerIngestionServer } from "./services/ingestion-server.js";
import { timersMigrations } from "./db/migrations.js";

const PORT = parseInt(process.env.TIMERS_PORT || process.env.PORT || "8083", 10);
const HOST = process.env.HOST || "localhost";
const INGEST_PORT = parseInt(process.env.TIMERS_INGEST_PORT || process.env.INGEST_PORT || "8082", 10);

const AppRouter = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/",
    HttpServerResponse.json({
      name: "Brew Haiku Timers",
      version: "1.0.0",
      status: "running",
    })
  ),
  HttpRouter.concat(healthRoutes),
  HttpRouter.concat(timerRoutes),
  HttpRouter.concat(savedTimersRoutes),
  HttpRouter.concat(authRoutes),
  HttpRouter.concat(resolveRoutes),
  HttpRouter.concat(xrpcRoutes)
);

const app = AppRouter.pipe(HttpServer.serve(HttpMiddleware.logger));

// Database layer
const DbLayer = DatabaseServiceLive(process.env.TIMERS_DATABASE_PATH || process.env.DATABASE_PATH, timersMigrations);

// Timer service depends on Database
const TimerLayer = TimerServiceLive.pipe(Layer.provide(DbLayer));

// ATProto service depends on Database
const ATProtoLayer = ATProtoServiceLive.pipe(Layer.provide(DbLayer));

// OAuth service depends on ATProto
const OAuthLayer = OAuthServiceLive.pipe(Layer.provide(ATProtoLayer));

// Brew service depends on Database
const BrewLayer = BrewServiceLive.pipe(Layer.provide(DbLayer));

// Activity service depends on Database
const ActivityLayer = ActivityServiceLive.pipe(Layer.provide(DbLayer));

// Combined layers
const AppLayers = Layer.mergeAll(
  DbLayer,
  TimerLayer,
  ATProtoLayer,
  OAuthLayer,
  SavedTimersServiceLive,
  PDSProxyServiceLive,
  BrewLayer,
  ActivityLayer,
  FollowsResolverServiceLive
);

const ServerLive = app.pipe(
  Layer.provide(BunHttpServer.layer({ port: PORT, hostname: HOST })),
  Layer.provide(AppLayers)
);

const program = Effect.gen(function* () {
  // Get DB handle for ingestion WebSocket server
  const dbService = yield* DatabaseService;
  createTimerIngestionServer(dbService.db, INGEST_PORT);

  // Launch HTTP server
  yield* Effect.fork(Layer.launch(ServerLive));
  yield* Effect.log(`Brew Haiku Timers running on port ${PORT}`);
  yield* Effect.log(`Timer ingestion WebSocket on port ${INGEST_PORT}`);

  // Keep running
  yield* Effect.never;
}).pipe(Effect.scoped, Effect.provide(AppLayers));

BunRuntime.runMain(program);
