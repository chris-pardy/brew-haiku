import { Effect, Layer } from "effect";
import { HttpRouter, HttpServer, HttpServerResponse, HttpMiddleware } from "@effect/platform";
import { BunHttpServer, BunRuntime } from "@effect/platform-bun";
import { healthRoutes } from "./routes/health.js";
import { didDocumentRoutes } from "./routes/did-document.js";
import { feedRoutes } from "./routes/feed.js";
import { DatabaseServiceLive } from "./services/database.js";
import { FirehoseService } from "./services/firehose.js";
import { FeedGeneratorServiceLive } from "./services/feed-generator.js";
import { FirehoseServiceWorker } from "./services/firehose-worker-layer.js";

const PORT = parseInt(process.env.PORT || "3000", 10);
const HOST = process.env.HOST || "localhost";

// Spawn firehose worker on a separate thread
const firehoseWorker = new Worker(
  new URL("./workers/firehose-worker.ts", import.meta.url).href
);

const AppRouter = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/",
    HttpServerResponse.json({
      name: "Brew Haiku Feed Generator",
      version: "1.0.0",
      status: "running",
    })
  ),
  HttpRouter.get(
    "/firehose/status",
    Effect.gen(function* () {
      const firehose = yield* FirehoseService;
      const status = yield* firehose.status();
      return yield* HttpServerResponse.json(status);
    })
  ),
  HttpRouter.concat(healthRoutes),
  HttpRouter.concat(didDocumentRoutes),
  HttpRouter.concat(feedRoutes)
);

const app = AppRouter.pipe(HttpServer.serve(HttpMiddleware.logger));

// Database layer (main thread — used for feed reads only)
const DbLayer = DatabaseServiceLive(process.env.DATABASE_PATH);

// Firehose layer backed by worker (no DB/Jetstream deps on main thread)
const FirehoseLayer = FirehoseServiceWorker(firehoseWorker);

// Feed generator depends on Database
const FeedGeneratorLayer = FeedGeneratorServiceLive().pipe(Layer.provide(DbLayer));

// Combined layers for the app
const AppLayers = Layer.mergeAll(DbLayer, FirehoseLayer, FeedGeneratorLayer);

const ServerLive = app.pipe(
  Layer.provide(BunHttpServer.layer({ port: PORT, hostname: HOST })),
  Layer.provide(AppLayers)
);

const program = Effect.gen(function* () {
  // Launch the server in background
  yield* Effect.fork(Layer.launch(ServerLive));
  yield* Effect.log(`Brew Haiku Feed Generator running on port ${PORT}`);

  // Start firehose via worker
  const firehose = yield* FirehoseService;
  yield* firehose.start();
  yield* Effect.log("Firehose worker started");

  // Keep running
  yield* Effect.never;
}).pipe(Effect.scoped, Effect.provide(AppLayers));

BunRuntime.runMain(program);
