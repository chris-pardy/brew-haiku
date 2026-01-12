import { describe, test, expect } from "bun:test";
import { Effect, Layer } from "effect";
import { HttpRouter, HttpServer, HttpServerResponse } from "@effect/platform";
import { BunHttpServer } from "@effect/platform-bun";

describe("Backend Setup", () => {
  test("effect library is importable", () => {
    expect(Effect).toBeDefined();
    expect(Layer).toBeDefined();
  });

  test("http server components are importable", () => {
    expect(HttpServer).toBeDefined();
    expect(HttpRouter).toBeDefined();
    expect(HttpServerResponse).toBeDefined();
  });

  test("bun platform adapter is importable", () => {
    expect(BunHttpServer).toBeDefined();
  });

  test("can create a simple router", () => {
    const router = HttpRouter.empty.pipe(
      HttpRouter.get(
        "/test",
        Effect.succeed(HttpServerResponse.json({ test: true }))
      )
    );
    expect(router).toBeDefined();
  });

  test("can compose Effect pipelines", async () => {
    const result = await Effect.succeed(42).pipe(
      Effect.map((n) => n * 2),
      Effect.runPromise
    );
    expect(result).toBe(84);
  });

  test("environment variable parsing works", () => {
    const port = parseInt(process.env.PORT || "3000", 10);
    expect(typeof port).toBe("number");
    expect(port).toBeGreaterThan(0);
  });
});
