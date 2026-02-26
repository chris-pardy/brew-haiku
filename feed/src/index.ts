import { Effect, Layer, Duration } from "effect";
import { HttpRouter, HttpServer, HttpServerResponse, HttpMiddleware } from "@effect/platform";
import { BunHttpServer, BunRuntime } from "@effect/platform-bun";
import { DatabaseServiceLive, DatabaseService } from "@brew-haiku/shared";
import { healthRoutes } from "./routes/health.js";
import { didDocumentRoutes } from "./routes/did-document.js";
import { feedRoutes } from "./routes/feed.js";
import { FeedGeneratorServiceLive, loadFeedConfigFile, scoreSql } from "./services/feed-generator.js";
import { createIngestionServer } from "./services/ingestion-server.js";
import { setIngestionServer, getIngestionServer } from "./services/ingestion-state.js";
import { feedMigrations } from "./db/migrations.js";

const PORT = parseInt(process.env.FEED_PORT || process.env.PORT || "8080", 10);
const HOST = process.env.HOST || "localhost";
const INGEST_PORT = parseInt(process.env.FEED_INGEST_PORT || process.env.INGEST_PORT || "8081", 10);

const RETENTION_HOURS = parseInt(process.env.RETENTION_HOURS || "6", 10);
const TOP_N = parseInt(process.env.RETENTION_TOP_N || "40", 10);
const CLEANUP_INTERVAL_MS = 10 * 60 * 1000; // every 10 minutes


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
      const stats = getIngestionServer()?.getWorkerStats() ?? [];
      return yield* HttpServerResponse.json({
        workers: stats,
        totalWorkers: stats.length,
      });
    })
  ),
  HttpRouter.concat(healthRoutes),
  HttpRouter.concat(didDocumentRoutes),
  HttpRouter.concat(feedRoutes)
);

const app = AppRouter.pipe(HttpServer.serve(HttpMiddleware.logger));

// Database layer (feed owns its database)
const DbLayer = DatabaseServiceLive(process.env.FEED_DATABASE_PATH || process.env.DATABASE_PATH, feedMigrations);

// Feed generator depends on Database
const FeedGeneratorLayer = FeedGeneratorServiceLive().pipe(Layer.provide(DbLayer));

const AppLayers = Layer.mergeAll(DbLayer, FeedGeneratorLayer);

const ServerLive = app.pipe(
  Layer.provide(BunHttpServer.layer({ port: PORT, hostname: HOST })),
  Layer.provide(AppLayers)
);

// Cleanup loop — runs on the server since it owns the DB
const runCleanupLoop = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;
  const cleanupConfig = loadFeedConfigFile().base;

  yield* Effect.log("Cleanup loop started");

  while (true) {
    yield* Effect.sleep(Duration.millis(CLEANUP_INTERVAL_MS));

    yield* Effect.try({
      try: () => {
        const now = Date.now();
        const cutoff = now - RETENTION_HOURS * 60 * 60 * 1000;
        const score = scoreSql(cleanupConfig, String(now));

        db.run(
          `DELETE FROM haiku_likes WHERE post_uri IN (
            SELECT uri FROM haiku_posts
            WHERE created_at < ?
              AND uri NOT IN (
                SELECT uri FROM haiku_posts
                ORDER BY ${score} DESC
                LIMIT ?
              )
          )`,
          [cutoff, TOP_N]
        );

        const result = db.run(
          `DELETE FROM haiku_posts
           WHERE created_at < ?
             AND uri NOT IN (
               SELECT uri FROM haiku_posts
               ORDER BY ${score} DESC
               LIMIT ?
             )`,
          [cutoff, TOP_N]
        );

        if (result.changes > 0) {
          console.log(
            `Cleanup: pruned ${result.changes} posts (keeping top ${TOP_N} + <${RETENTION_HOURS}h)`
          );
        }
      },
      catch: (error) => {
        console.error(`Cleanup error: ${error}`);
        return error;
      },
    }).pipe(Effect.ignore);
  }
}).pipe(Effect.provide(DbLayer));

const program = Effect.gen(function* () {
  // Start ingestion WebSocket server (needs raw DB handle)
  const dbService = yield* DatabaseService;
  setIngestionServer(createIngestionServer(dbService.db, INGEST_PORT));

  // Launch HTTP server
  yield* Effect.fork(Layer.launch(ServerLive));
  yield* Effect.log(`Brew Haiku Feed Server running on port ${PORT}`);
  yield* Effect.log(`Ingestion WebSocket on port ${INGEST_PORT}`);

  // Launch cleanup loop
  yield* Effect.fork(runCleanupLoop);

  // Keep running
  yield* Effect.never;
}).pipe(Effect.scoped, Effect.provide(AppLayers));

BunRuntime.runMain(program);
