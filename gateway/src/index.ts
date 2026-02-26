/**
 * Lightweight reverse proxy that routes incoming HTTP traffic to the
 * feed or timers service based on the request path.
 *
 * On Fly.io the two backend services are reachable via internal DNS:
 *   feed.process.brew-haiku.internal:8080
 *   timers.process.brew-haiku.internal:8083
 *
 * Only the gateway process group is exposed to the internet (ports 80/443).
 */

const PORT = parseInt(process.env.GATEWAY_PORT || process.env.PORT || "8080", 10);
const HOST = process.env.HOST || "localhost";

const FEED_ORIGIN =
  process.env.FEED_INTERNAL_URL || "http://localhost:8080";
const TIMERS_ORIGIN =
  process.env.TIMERS_INTERNAL_URL || "http://localhost:8083";

/** Path prefixes that belong to the timers / appview service. */
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

const server = Bun.serve({
  port: PORT,
  hostname: HOST,

  async fetch(req) {
    const url = new URL(req.url);
    const origin = routeOrigin(url.pathname);
    const target = `${origin}${url.pathname}${url.search}`;

    try {
      const headers = new Headers(req.headers);
      // Pass original host for logging / debugging
      headers.set("X-Forwarded-Host", url.host);

      const proxyRes = await fetch(target, {
        method: req.method,
        headers,
        body: req.body,
        // @ts-expect-error — Bun supports duplex streaming
        duplex: "half",
      });

      // Forward the response back, preserving status + headers
      return new Response(proxyRes.body, {
        status: proxyRes.status,
        statusText: proxyRes.statusText,
        headers: proxyRes.headers,
      });
    } catch (err) {
      console.error(`Gateway proxy error → ${target}: ${err}`);
      return new Response(
        JSON.stringify({ error: "BadGateway", message: "Upstream unavailable" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }
  },
});

console.log(`Gateway listening on ${HOST}:${PORT}`);
console.log(`  Feed  → ${FEED_ORIGIN}`);
console.log(`  Timers → ${TIMERS_ORIGIN}`);
