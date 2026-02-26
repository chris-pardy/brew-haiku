import { Effect, Context, Layer } from "effect";
import type { IngestEvent } from "@brew-haiku/shared";

export interface IngestClientShape {
  readonly send: (event: IngestEvent) => Effect.Effect<void>;
}

/** Create an IngestClient backed by a connected WebSocket. */
export function makeIngestClient(ws: WebSocket): IngestClientShape {
  return {
    send: (event) =>
      Effect.try({
        try: () => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(event));
          }
        },
        catch: () => new Error("Failed to send ingest event"),
      }).pipe(Effect.ignore),
  };
}

// ---------------------------------------------------------------------------
// Buffered client — queues events when WS is unavailable, flushes when it's
// connected.  The buffer has a fixed max size; oldest events are dropped when
// full (the cursor will replay them on a future restart if needed).
// ---------------------------------------------------------------------------

const DEFAULT_MAX_BUFFER = 10_000;

export class BufferedIngestClient {
  private buffer: IngestEvent[] = [];
  private ws: WebSocket | null = null;
  readonly maxBuffer: number;

  constructor(ws: WebSocket | null, maxBuffer = DEFAULT_MAX_BUFFER) {
    this.maxBuffer = maxBuffer;
    if (ws) this.attach(ws);
  }

  /** Attach (or replace) the underlying WebSocket and flush the buffer. */
  attach(ws: WebSocket): void {
    this.ws = ws;
    this.flush();
  }

  /** Detach the current WebSocket (called on close). */
  detach(): void {
    this.ws = null;
  }

  get connected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  get buffered(): number {
    return this.buffer.length;
  }

  /** Enqueue an event — sends immediately if connected, otherwise buffers. */
  send(event: IngestEvent): void {
    if (this.connected) {
      this.ws!.send(JSON.stringify(event));
    } else {
      if (this.buffer.length >= this.maxBuffer) {
        this.buffer.shift(); // drop oldest
      }
      this.buffer.push(event);
    }
  }

  /** Drain the buffer over the current WebSocket. */
  private flush(): void {
    while (this.buffer.length > 0 && this.connected) {
      const event = this.buffer.shift()!;
      this.ws!.send(JSON.stringify(event));
    }
  }

  /** Produce an IngestClientShape backed by this buffer. */
  toShape(): IngestClientShape {
    return {
      send: (event) =>
        Effect.sync(() => this.send(event)),
    };
  }
}

/** IngestClient tag for feed-bound events (haiku, like). */
export class FeedIngestClient extends Context.Tag("FeedIngestClient")<
  FeedIngestClient,
  IngestClientShape
>() {}

/** IngestClient tag for timer-bound events (timer:save, timer:unsave). */
export class TimerIngestClient extends Context.Tag("TimerIngestClient")<
  TimerIngestClient,
  IngestClientShape
>() {}

export const FeedIngestClientLive = (ws: WebSocket) =>
  Layer.succeed(FeedIngestClient, makeIngestClient(ws));

export const TimerIngestClientLive = (ws: WebSocket) =>
  Layer.succeed(TimerIngestClient, makeIngestClient(ws));
