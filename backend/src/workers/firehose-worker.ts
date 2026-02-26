/// <reference lib="webworker" />
import { Effect, Layer } from "effect";
import { makeDatabaseService, DatabaseService } from "../services/database.js";
import { makeFirehoseService, FirehoseService, type FirehoseStatus } from "../services/firehose.js";
import { JetstreamServiceLive, JetstreamService } from "../services/jetstream.js";
import { ClassifierServiceLive } from "../services/classifier.js";
import type { JetstreamOptions } from "../services/jetstream.js";

// Message protocol
type WorkerCommand =
  | { type: "start"; options?: JetstreamOptions }
  | { type: "stop" };

type WorkerMessage =
  | { type: "stats"; data: FirehoseStatus }
  | { type: "started" }
  | { type: "stopped" }
  | { type: "error"; message: string };

function post(msg: WorkerMessage) {
  self.postMessage(msg);
}

// Build layers with worker's own DB connection
const DbLayer = Layer.effect(
  DatabaseService,
  makeDatabaseService(process.env.DATABASE_PATH)
);

const JetstreamLayer = JetstreamServiceLive();

const ClassifierLayer = ClassifierServiceLive;

const FirehoseLayer = Layer.effect(
  FirehoseService,
  makeFirehoseService
).pipe(
  Layer.provide(Layer.mergeAll(DbLayer, JetstreamLayer, ClassifierLayer))
);

const AppLayers = Layer.mergeAll(DbLayer, JetstreamLayer, ClassifierLayer, FirehoseLayer);

// Resolve the firehose service once, reuse for all commands
const servicePromise = Effect.gen(function* () {
  return yield* FirehoseService;
}).pipe(
  Effect.provide(AppLayers),
  Effect.runPromise
);

// Push stats to main thread every 10 seconds
let statsInterval: ReturnType<typeof setInterval> | null = null;

function startStatsPush(service: Awaited<typeof servicePromise>) {
  if (statsInterval) return;
  statsInterval = setInterval(async () => {
    try {
      const data = await Effect.runPromise(service.status());
      post({ type: "stats", data });
    } catch {
      // Ignore stats push errors
    }
  }, 10_000);
}

function stopStatsPush() {
  if (statsInterval) {
    clearInterval(statsInterval);
    statsInterval = null;
  }
}

self.onmessage = async (event: MessageEvent<WorkerCommand>) => {
  const cmd = event.data;

  try {
    const service = await servicePromise;

    switch (cmd.type) {
      case "start": {
        await Effect.runPromise(service.start(cmd.options));
        // Push initial stats immediately, then periodically
        const data = await Effect.runPromise(service.status());
        post({ type: "stats", data });
        startStatsPush(service);
        post({ type: "started" });
        break;
      }
      case "stop": {
        stopStatsPush();
        await Effect.runPromise(service.stop());
        post({ type: "stopped" });
        break;
      }
    }
  } catch (err) {
    post({ type: "error", message: err instanceof Error ? err.message : String(err) });
  }
};
