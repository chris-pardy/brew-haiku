import { Effect, Layer } from "effect";
import { FirehoseService, type FirehoseStatus, type FirehoseError } from "./firehose.js";
import type { JetstreamOptions } from "./jetstream.js";
import { detectHaiku } from "./haiku-detector.js";
import {
  SAVED_TIMER_COLLECTION,
} from "./firehose-indexers.js";

// Message types matching the worker protocol
type WorkerCommand =
  | { type: "start"; options?: JetstreamOptions }
  | { type: "stop" };

type WorkerMessage =
  | { type: "stats"; data: FirehoseStatus }
  | { type: "started" }
  | { type: "stopped" }
  | { type: "error"; message: string };

/**
 * Creates a FirehoseService layer backed by a Bun Worker.
 * The worker pushes stats to the main thread periodically;
 * the main thread caches the latest stats and returns them immediately.
 */
export const FirehoseServiceWorker = (worker: Worker) => {
  // Cached stats from worker — updated via push
  let latestStats: FirehoseStatus = {
    running: false,
    lastCursor: null,
    eventsProcessed: 0,
    haikuDetected: 0,
    haikuIndexed: 0,
    likesProcessed: 0,
  };

  let startResolve: (() => void) | null = null;
  let stopResolve: (() => void) | null = null;

  worker.onmessage = (event: MessageEvent<WorkerMessage>) => {
    const msg = event.data;
    switch (msg.type) {
      case "stats":
        latestStats = msg.data;
        break;
      case "started":
        latestStats = { ...latestStats, running: true };
        startResolve?.();
        startResolve = null;
        break;
      case "stopped":
        latestStats = { ...latestStats, running: false };
        stopResolve?.();
        stopResolve = null;
        break;
      case "error":
        console.error(`[firehose-worker] ${msg.message}`);
        break;
    }
  };

  const sendCommand = (cmd: WorkerCommand) => {
    worker.postMessage(cmd);
  };

  return Layer.succeed(FirehoseService, {
    isHaikuPost: (text: string) => detectHaiku(text).isHaiku,

    isSavedTimerEvent: (collection: string) =>
      collection === SAVED_TIMER_COLLECTION,

    start: (options: JetstreamOptions = {}) =>
      Effect.tryPromise({
        try: () =>
          new Promise<void>((resolve) => {
            startResolve = resolve;
            sendCommand({ type: "start", options });
          }),
        catch: () =>
          new Error("Failed to start firehose worker") as unknown as FirehoseError,
      }).pipe(Effect.asVoid),

    stop: () =>
      Effect.tryPromise({
        try: () =>
          new Promise<void>((resolve) => {
            stopResolve = resolve;
            sendCommand({ type: "stop" });
          }),
        catch: () =>
          new Error("Failed to stop firehose worker") as unknown as FirehoseError,
      }).pipe(Effect.asVoid),

    // Return cached stats immediately — no round-trip to worker
    status: () => Effect.succeed(latestStats),

    getLastCursor: () => Effect.succeed(latestStats.lastCursor),
  });
};
