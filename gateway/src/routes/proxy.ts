import { Effect } from "effect";
import { HttpServerRequest, HttpServerResponse } from "@effect/platform";
import { getAuth } from "../services/auth-guard.js";

const FEED_ORIGIN =
  process.env.FEED_INTERNAL_URL || "http://localhost:8080";
const TIMERS_ORIGIN =
  process.env.TIMERS_INTERNAL_URL || "http://localhost:8083";

const TIMERS_PREFIXES = [
  "/xrpc/app.brew-haiku.",
  "/timers",
  "/saved-timers",
  "/auth",
  "/resolve",
];

function routeOrigin(pathname: string): string {
  for (const prefix of TIMERS_PREFIXES) {
    if (pathname.startsWith(prefix)) return TIMERS_ORIGIN;
  }
  return FEED_ORIGIN;
}

/** Endpoints that require a valid Bearer token before proxying. */
const AUTH_REQUIRED: ReadonlySet<string> = new Set([
  "/xrpc/app.brew-haiku.createTimer",
  "/xrpc/app.brew-haiku.saveTimer",
  "/xrpc/app.brew-haiku.forgetTimer",
  "/xrpc/app.brew-haiku.createBrew",
  "/xrpc/app.brew-haiku.getActivity",
]);

/**
 * Proxy handler used as the catch-all for unmatched routes.
 * Enforces auth on write endpoints, then forwards the request upstream.
 */
export const proxyHandler = Effect.gen(function* () {
  const request = yield* HttpServerRequest.HttpServerRequest;
  const url = new URL(request.url, "http://localhost");

  // Enforce auth on protected endpoints
  if (AUTH_REQUIRED.has(url.pathname)) {
    const authResult = yield* getAuth.pipe(
      Effect.map((did) => ({ ok: true as const, did })),
      Effect.catchTag("AuthError", (e) =>
        Effect.succeed({ ok: false as const, message: e.message })
      )
    );

    if (!authResult.ok) {
      return yield* HttpServerResponse.json(
        { error: "AuthRequired", message: authResult.message },
        { status: 401 }
      );
    }
  }

  // Proxy to upstream
  const origin = routeOrigin(url.pathname);
  const target = `${origin}${url.pathname}${url.search}`;

  const proxyRes = yield* Effect.tryPromise({
    try: async () => {
      // Access the underlying Bun Request for body streaming
      const source = request.source as Request;
      const headers = new Headers(request.headers as Record<string, string>);
      headers.set("X-Forwarded-Host", url.host);

      return fetch(target, {
        method: request.method,
        headers,
        body: source.body,
        // @ts-expect-error — Bun supports duplex streaming
        duplex: "half",
      });
    },
    catch: () => "proxy-error" as const,
  });

  return HttpServerResponse.fromWeb(proxyRes);
}).pipe(
  Effect.catchAll(() =>
    HttpServerResponse.json(
      { error: "BadGateway", message: "Upstream unavailable" },
      { status: 502 }
    )
  )
);
