import { Effect } from "effect";
import { HttpRouter, HttpServerResponse } from "@effect/platform";

const startTime = Date.now();

export const healthRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/health",
    Effect.gen(function* () {
      const uptime = Math.floor((Date.now() - startTime) / 1000);
      const memoryUsage = process.memoryUsage();

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
      });
    })
  )
);
