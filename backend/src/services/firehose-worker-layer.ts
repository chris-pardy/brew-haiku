import { Effect, Layer } from "effect";
import { FirehoseService, type FirehoseStatus, type FirehoseError } from "./firehose.js";
import type { JetstreamOptions } from "./jetstream.js";
import { detectHaiku } from "./haiku-detector.js";
import {
  HAIKU_SIGNATURE,
  SAVED_TIMER_COLLECTION,
} from "./firehose-indexers.js";

// Message types matching the worker protocol
type WorkerCommand =
  | { type: "start"; options?: JetstreamOptions }
  | { type: "stop" }
  | { type: "status" };

type WorkerMessage =
  | { type: "status"; data: FirehoseStatus }
  | { type: "started" }
  | { type: "stopped" }
  | { type: "error"; message: string };

/**
 * Creates a FirehoseService layer backed by a Bun Worker.
 * The worker runs the actual firehose pipeline on a separate thread.
 */
export const FirehoseServiceWorker = (worker: Worker) => {
  // Pending status request resolvers
  let statusResolve: ((status: FirehoseStatus) => void) | null = null;
  let startResolve: (() => void) | null = null;
  let stopResolve: (() => void) | null = null;

  worker.onmessage = (event: MessageEvent<WorkerMessage>) => {
    const msg = event.data;
    switch (msg.type) {
      case "status":
        statusResolve?.(msg.data);
        statusResolve = null;
        break;
      case "started":
        startResolve?.();
        startResolve = null;
        break;
      case "stopped":
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

    status: () =>
      Effect.tryPromise({
        try: () =>
          new Promise<FirehoseStatus>((resolve) => {
            const timeout = setTimeout(() => {
              statusResolve = null;
              resolve({
                running: true,
                lastCursor: null,
                eventsProcessed: -1,
                haikuDetected: -1,
                haikuIndexed: -1,
                likesProcessed: -1,
              });
            }, 3000);
            statusResolve = (status) => {
              clearTimeout(timeout);
              resolve(status);
            };
            sendCommand({ type: "status" });
          }),
        catch: () =>
          new Error("Failed to get firehose status") as unknown as FirehoseError,
      }),

    getLastCursor: () =>
      Effect.tryPromise({
        try: async () => {
          const status = await new Promise<FirehoseStatus>((resolve) => {
            const timeout = setTimeout(() => {
              statusResolve = null;
              resolve({
                running: true,
                lastCursor: null,
                eventsProcessed: -1,
                haikuDetected: -1,
                haikuIndexed: -1,
                likesProcessed: -1,
              });
            }, 3000);
            statusResolve = (status) => {
              clearTimeout(timeout);
              resolve(status);
            };
            sendCommand({ type: "status" });
          });
          return status.lastCursor;
        },
        catch: () =>
          new Error("Failed to get cursor from worker") as unknown as FirehoseError,
      }),
  });
};
