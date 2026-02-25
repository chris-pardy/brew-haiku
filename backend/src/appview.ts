import { Effect, Layer } from "effect";
import { HttpRouter, HttpServer, HttpServerResponse, HttpMiddleware } from "@effect/platform";
import { BunHttpServer, BunRuntime } from "@effect/platform-bun";
import { healthRoutes } from "./routes/health.js";
import { timerRoutes } from "./routes/timers.js";
import { savedTimersRoutes } from "./routes/saved-timers.js";
import { authRoutes } from "./routes/auth.js";
import { resolveRoutes } from "./routes/resolve.js";
import { DatabaseServiceLive } from "./services/database.js";
import { TimerServiceLive } from "./services/timer.js";
import { ATProtoServiceLive } from "./services/atproto.js";
import { OAuthServiceLive } from "./services/oauth.js";
import { SavedTimersServiceLive } from "./services/saved-timers.js";
import { AppViewFirehoseService, AppViewFirehoseServiceLive } from "./services/appview-firehose.js";

const PORT = parseInt(process.env.PORT || "3000", 10);

const AppRouter = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/",
    HttpServerResponse.json({
      name: "Brew Haiku App View",
      version: "1.0.0",
      status: "running",
    })
  ),
  HttpRouter.get(
    "/firehose/status",
    Effect.gen(function* () {
      const firehose = yield* AppViewFirehoseService;
      const status = yield* firehose.status();
      return yield* HttpServerResponse.json(status);
    })
  ),
  HttpRouter.concat(healthRoutes),
  HttpRouter.concat(timerRoutes),
  HttpRouter.concat(savedTimersRoutes),
  HttpRouter.concat(authRoutes),
  HttpRouter.concat(resolveRoutes)
);

const app = AppRouter.pipe(HttpServer.serve(HttpMiddleware.logger));

// Database layer
const DbLayer = DatabaseServiceLive(process.env.DATABASE_PATH);

// Timer service depends on Database
const TimerLayer = TimerServiceLive.pipe(Layer.provide(DbLayer));

// ATProto service depends on Database
const ATProtoLayer = ATProtoServiceLive.pipe(Layer.provide(DbLayer));

// OAuth service depends on ATProto
const OAuthLayer = OAuthServiceLive.pipe(Layer.provide(ATProtoLayer));

// Appview firehose depends on Database
const FirehoseLayer = AppViewFirehoseServiceLive.pipe(Layer.provide(DbLayer));

// Combined layers
const AppLayers = Layer.mergeAll(
  DbLayer,
  TimerLayer,
  ATProtoLayer,
  OAuthLayer,
  SavedTimersServiceLive,
  FirehoseLayer
);

const ServerLive = app.pipe(
  Layer.provide(BunHttpServer.layer({ port: PORT })),
  Layer.provide(AppLayers)
);

const program = Effect.gen(function* () {
  // Launch the server in background
  yield* Effect.fork(Layer.launch(ServerLive));
  yield* Effect.log(`Brew Haiku App View running on port ${PORT}`);

  // Start firehose
  const firehose = yield* AppViewFirehoseService;
  yield* firehose.start();
  yield* Effect.log("Appview firehose indexer started");

  // Keep running
  yield* Effect.never;
}).pipe(Effect.scoped, Effect.provide(AppLayers));

BunRuntime.runMain(program);
