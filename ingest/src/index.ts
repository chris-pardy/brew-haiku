/**
 * Ingest worker entry point — connects to BOTH the feed server's and timers
 * server's ingestion WebSockets, runs the firehose pipeline, and streams
 * classified events to the appropriate server.
 *
 * Each downstream connection uses a BufferedIngestClient: when a server is
 * unavailable events are held in an in-memory ring buffer (default 10 000
 * events) and flushed as soon as the connection is (re)established.
 *
 * Environment variables:
 *   FEED_INGEST_URL   — WebSocket URL of the feed ingestion server
 *   TIMER_INGEST_URL  — WebSocket URL of the timers ingestion server
 *   CURSOR_PATH       — path to cursor persistence file (default: /data/cursor)
 *   SHARD_ID          — identifier for this worker shard (default: "default")
 */

import { Effect, Layer } from "effect";
import { JetstreamServiceLive } from "@brew-haiku/shared";
import { runFirehosePipeline } from "./services/firehose.js";
import { ClassifierServiceLive } from "./services/classifier.js";
import {
  FeedIngestClient,
  TimerIngestClient,
  BufferedIngestClient,
} from "./services/ingestion-client.js";
import type { IngestEvent, ServerMessage } from "@brew-haiku/shared";

const FEED_INGEST_URL = process.env.FEED_INGEST_URL || "ws://localhost:8081";
const TIMER_INGEST_URL = process.env.TIMER_INGEST_URL || "ws://localhost:8082";
const CURSOR_PATH = process.env.CURSOR_PATH || "/data/cursor";
const SHARD_ID = process.env.SHARD_ID || "default";
const RECONNECT_DELAY_MS = 5_000;

// ---------------------------------------------------------------------------
// WebSocket connect + handshake
// ---------------------------------------------------------------------------

function tryConnect(url: string, label: string): Promise<WebSocket | null> {
  return new Promise((resolve) => {
    console.log(`[${label}] connecting to ${url}…`);
    try {
      const ws = new WebSocket(url);

      const timeout = setTimeout(() => {
        ws.close();
        console.warn(`[${label}] connection timeout`);
        resolve(null);
      }, 10_000);

      ws.onopen = () => {
        const hello: IngestEvent = { type: "hello", shardId: SHARD_ID };
        ws.send(JSON.stringify(hello));
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(String(event.data)) as ServerMessage;
          if (msg.type === "welcome") {
            clearTimeout(timeout);
            console.log(`[${label}] connected (shard "${msg.shardId}")`);
            resolve(ws);
          } else if (msg.type === "error") {
            clearTimeout(timeout);
            console.warn(`[${label}] server error: ${msg.message}`);
            ws.close();
            resolve(null);
          }
        } catch {
          // ignore parse errors during handshake
        }
      };

      ws.onerror = () => {
        clearTimeout(timeout);
        console.warn(`[${label}] connection failed`);
        resolve(null);
      };
    } catch {
      console.warn(`[${label}] connection failed`);
      resolve(null);
    }
  });
}

// ---------------------------------------------------------------------------
// Wire a BufferedIngestClient to a WebSocket with auto-reconnect
// ---------------------------------------------------------------------------

function wireClient(
  client: BufferedIngestClient,
  url: string,
  label: string,
): void {
  // Kick off initial connect, then schedule reconnects on close.
  const connect = async () => {
    const ws = await tryConnect(url, label);
    if (ws) {
      client.attach(ws);
      if (client.buffered > 0) {
        console.log(`[${label}] flushed ${client.buffered} buffered events`);
      }
      ws.onclose = () => {
        console.warn(`[${label}] disconnected — buffering events`);
        client.detach();
        setTimeout(connect, RECONNECT_DELAY_MS);
      };
      ws.onerror = () => ws.close();
    } else {
      console.warn(`[${label}] unavailable — buffering events (retry in ${RECONNECT_DELAY_MS / 1000}s)`);
      setTimeout(connect, RECONNECT_DELAY_MS);
    }
  };
  connect();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function run(): Promise<void> {
  // Create buffered clients (start disconnected — wiring happens below)
  const feedClient = new BufferedIngestClient(null);
  const timerClient = new BufferedIngestClient(null);

  // Try initial connections (in parallel), then wire reconnect loops
  const [feedWs, timerWs] = await Promise.all([
    tryConnect(FEED_INGEST_URL, "feed"),
    tryConnect(TIMER_INGEST_URL, "timers"),
  ]);

  // Attach initial sockets (if connected) and wire auto-reconnect
  if (feedWs) {
    feedClient.attach(feedWs);
    feedWs.onclose = () => {
      console.warn("[feed] disconnected — buffering events");
      feedClient.detach();
      setTimeout(() => wireClient(feedClient, FEED_INGEST_URL, "feed"), RECONNECT_DELAY_MS);
    };
    feedWs.onerror = () => feedWs.close();
  } else {
    wireClient(feedClient, FEED_INGEST_URL, "feed");
  }

  if (timerWs) {
    timerClient.attach(timerWs);
    timerWs.onclose = () => {
      console.warn("[timers] disconnected — buffering events");
      timerClient.detach();
      setTimeout(() => wireClient(timerClient, TIMER_INGEST_URL, "timers"), RECONNECT_DELAY_MS);
    };
    timerWs.onerror = () => timerWs.close();
  } else {
    wireClient(timerClient, TIMER_INGEST_URL, "timers");
  }

  // Build Effect layers
  const FeedClientLayer = Layer.succeed(FeedIngestClient, feedClient.toShape());
  const TimerClientLayer = Layer.succeed(TimerIngestClient, timerClient.toShape());
  const JetstreamLayer = JetstreamServiceLive();
  const ClassifierLayer = ClassifierServiceLive;
  const AppLayers = Layer.mergeAll(FeedClientLayer, TimerClientLayer, JetstreamLayer, ClassifierLayer);

  const program = Effect.gen(function* () {
    yield* runFirehosePipeline(CURSOR_PATH).pipe(Effect.forkDaemon);
    yield* Effect.log("Firehose pipeline started");
    yield* Effect.never;
  }).pipe(Effect.scoped, Effect.provide(AppLayers));

  try {
    await Effect.runPromise(program);
  } catch (e) {
    console.error(`Pipeline error: ${e}`);
    await Bun.sleep(RECONNECT_DELAY_MS);
    return run();
  }
}

console.log(`Brew Haiku Ingest Worker (shard: ${SHARD_ID})`);
run();
