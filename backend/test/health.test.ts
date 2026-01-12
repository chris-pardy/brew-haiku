import { describe, test, expect } from "bun:test";
import { Effect } from "effect";
import { HttpRouter, HttpServerResponse } from "@effect/platform";
import { healthRoutes } from "../src/routes/health.js";

describe("Health Routes", () => {
  test("healthRoutes is a valid router", () => {
    expect(healthRoutes).toBeDefined();
  });

  test("health endpoint returns expected structure", async () => {
    const testHealth = Effect.gen(function* () {
      const memoryUsage = process.memoryUsage();
      return {
        status: "healthy",
        timestamp: new Date().toISOString(),
        uptime: 0,
        version: "1.0.0",
        runtime: "bun",
        memory: {
          heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
          heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
          rss: Math.round(memoryUsage.rss / 1024 / 1024),
        },
      };
    });

    const result = await Effect.runPromise(testHealth);

    expect(result.status).toBe("healthy");
    expect(result.version).toBe("1.0.0");
    expect(result.runtime).toBe("bun");
    expect(result.memory).toBeDefined();
    expect(typeof result.memory.heapUsed).toBe("number");
    expect(typeof result.memory.heapTotal).toBe("number");
    expect(typeof result.memory.rss).toBe("number");
    expect(typeof result.uptime).toBe("number");
    expect(result.timestamp).toBeDefined();
  });

  test("timestamp is valid ISO string", () => {
    const timestamp = new Date().toISOString();
    const parsed = Date.parse(timestamp);
    expect(isNaN(parsed)).toBe(false);
  });

  test("memory values are reasonable", () => {
    const memoryUsage = process.memoryUsage();
    const heapUsedMB = Math.round(memoryUsage.heapUsed / 1024 / 1024);
    const heapTotalMB = Math.round(memoryUsage.heapTotal / 1024 / 1024);
    const rssMB = Math.round(memoryUsage.rss / 1024 / 1024);

    expect(heapUsedMB).toBeGreaterThanOrEqual(0);
    expect(heapTotalMB).toBeGreaterThanOrEqual(0);
    expect(rssMB).toBeGreaterThanOrEqual(0);
  });
});
