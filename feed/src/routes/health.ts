import { Effect } from "effect";
import { HttpRouter, HttpServerResponse } from "@effect/platform";
import { getIngestionServer } from "../services/ingestion-state.js";

const startTime = Date.now();

export const healthRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/health",
    Effect.gen(function* () {
      const uptime = Math.floor((Date.now() - startTime) / 1000);
      const memoryUsage = process.memoryUsage();

      const workers = getIngestionServer()?.getWorkerStats() ?? [];
      const aggregated = workers.reduce(
        (acc, w) => ({
          eventsProcessed: acc.eventsProcessed + w.eventsProcessed,
          haikuDetected: acc.haikuDetected + w.haikuDetected,
          haikuIndexed: acc.haikuIndexed + w.haikuIndexed,
          likesProcessed: acc.likesProcessed + w.likesProcessed,
        }),
        { eventsProcessed: 0, haikuDetected: 0, haikuIndexed: 0, likesProcessed: 0 }
      );

      return yield* HttpServerResponse.json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        uptime,
        version: "1.0.0",
        runtime: "bun",
        memory: {
          heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
          heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
          rss: Math.round(memoryUsage.rss / 1024 / 1024),
        },
        workers: {
          connected: workers.length,
          shards: workers.map((w) => w.shardId),
          ...aggregated,
        },
      });
    })
  )
);
