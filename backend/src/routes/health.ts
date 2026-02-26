import { Effect } from "effect";
import { HttpRouter, HttpServerResponse } from "@effect/platform";
import { FirehoseService } from "../services/firehose.js";

const startTime = Date.now();

export const healthRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/health",
    Effect.gen(function* () {
      const uptime = Math.floor((Date.now() - startTime) / 1000);
      const memoryUsage = process.memoryUsage();

      const firehose = yield* FirehoseService;
      const firehoseStatus = yield* firehose.status();

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
        firehose: {
          running: firehoseStatus.running,
          eventsProcessed: firehoseStatus.eventsProcessed,
          haikuDetected: firehoseStatus.haikuDetected,
          haikuIndexed: firehoseStatus.haikuIndexed,
          likesProcessed: firehoseStatus.likesProcessed,
        },
      });
    })
  )
);
