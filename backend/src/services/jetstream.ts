import { Effect, Context, Layer, Stream, Queue, Ref, Schedule, Duration, Scope, Chunk, pipe } from "effect";

export class JetstreamError extends Error {
  readonly _tag = "JetstreamError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

// Jetstream event types based on https://github.com/bluesky-social/jetstream
export interface JetstreamCommitEvent {
  did: string;
  time_us: number;
  kind: "commit";
  commit: {
    rev: string;
    operation: "create" | "update" | "delete";
    collection: string;
    rkey: string;
    record?: Record<string, unknown>;
    cid?: string;
  };
}

export interface JetstreamIdentityEvent {
  did: string;
  time_us: number;
  kind: "identity";
  identity: {
    did: string;
    handle: string;
    seq: number;
    time: string;
  };
}

export interface JetstreamAccountEvent {
  did: string;
  time_us: number;
  kind: "account";
  account: {
    active: boolean;
    did: string;
    seq: number;
    time: string;
  };
}

export type JetstreamEvent =
  | JetstreamCommitEvent
  | JetstreamIdentityEvent
  | JetstreamAccountEvent;

export interface JetstreamOptions {
  wantedCollections?: string[];
  wantedDids?: string[];
  cursor?: number;
  compress?: boolean;
}

export interface ConnectionStatus {
  connected: boolean;
  lastEventTime?: number;
  reconnectCount: number;
}

export interface JetstreamConfig {
  url: string;
  queueBufferSize: number;
  reconnectMaxDelay: Duration.Duration;
}

export const defaultJetstreamConfig: JetstreamConfig = {
  url: "wss://jetstream2.us-east.bsky.network/subscribe",
  queueBufferSize: 1000,
  reconnectMaxDelay: Duration.minutes(5),
};

// Helper to build Jetstream URL with query parameters
const buildJetstreamUrl = (
  baseUrl: string,
  options: JetstreamOptions
): string => {
  const url = new URL(baseUrl);

  if (options.wantedCollections?.length) {
    for (const collection of options.wantedCollections) {
      url.searchParams.append("wantedCollections", collection);
    }
  }

  if (options.wantedDids?.length) {
    for (const did of options.wantedDids) {
      url.searchParams.append("wantedDids", did);
    }
  }

  if (options.cursor !== undefined) {
    url.searchParams.set("cursor", String(options.cursor));
  }

  if (options.compress !== undefined) {
    url.searchParams.set("compress", String(options.compress));
  }

  return url.toString();
};

// Parse raw WebSocket message into typed event
const parseJetstreamMessage = (data: string): JetstreamEvent | null => {
  try {
    const event = JSON.parse(data) as JetstreamEvent;
    if (!event.did || !event.time_us || !event.kind) {
      return null;
    }
    return event;
  } catch {
    return null;
  }
};

export class JetstreamService extends Context.Tag("JetstreamService")<
  JetstreamService,
  {
    readonly createEventStream: (
      options: JetstreamOptions
    ) => Stream.Stream<JetstreamEvent, JetstreamError>;
    readonly config: JetstreamConfig;
  }
>() {}

export const makeJetstreamService = (
  config: JetstreamConfig = defaultJetstreamConfig
): Effect.Effect<{
  createEventStream: (options: JetstreamOptions) => Stream.Stream<JetstreamEvent, JetstreamError>;
  config: JetstreamConfig;
}> =>
  Effect.succeed({
    config,

    createEventStream: (options: JetstreamOptions): Stream.Stream<JetstreamEvent, JetstreamError> => {
      // Create a stream that connects to Jetstream and emits events
      return Stream.unwrapScoped(
        Effect.gen(function* () {
          const queue = yield* Queue.bounded<JetstreamEvent>(config.queueBufferSize);
          const cursorRef = yield* Ref.make<number | null>(options.cursor ?? null);
          const statusRef = yield* Ref.make<ConnectionStatus>({
            connected: false,
            reconnectCount: 0,
          });

          // Function to connect and process messages
          const connect = Effect.gen(function* () {
            const currentCursor = yield* Ref.get(cursorRef);
            const wsUrl = buildJetstreamUrl(config.url, {
              ...options,
              cursor: currentCursor ?? options.cursor,
            });

            yield* Effect.log(`Connecting to Jetstream: ${wsUrl}`);

            const ws = new WebSocket(wsUrl);

            // Set up message handler
            const messageHandler = (event: MessageEvent) => {
              try {
                const data = typeof event.data === "string" ? event.data : "";
                const parsed = parseJetstreamMessage(data);

                if (parsed) {
                  // Update cursor
                  Ref.set(cursorRef, parsed.time_us).pipe(Effect.runSync);

                  // Offer to queue (non-blocking, will drop if full or shut down)
                  Queue.offer(queue, parsed).pipe(
                    Effect.catchAll(() => Effect.void),
                    Effect.runSync
                  );
                }
              } catch {
                // Queue was shut down — ignore remaining messages
              }
            };

            // Set up connection handlers
            const openPromise = new Promise<void>((resolve, reject) => {
              ws.onopen = () => {
                Ref.update(statusRef, (s) => ({
                  ...s,
                  connected: true,
                })).pipe(Effect.runSync);
                resolve();
              };
              ws.onerror = (err) => reject(new JetstreamError("WebSocket error", err));
            });

            ws.onmessage = messageHandler;

            // Wait for connection
            yield* Effect.tryPromise({
              try: () => openPromise,
              catch: (e) => new JetstreamError("Failed to connect to Jetstream", e),
            });

            yield* Effect.log("Connected to Jetstream");

            // Create close promise to wait for disconnect
            const closePromise = new Promise<void>((resolve) => {
              ws.onclose = () => {
                Ref.update(statusRef, (s) => ({
                  ...s,
                  connected: false,
                })).pipe(Effect.runSync);
                resolve();
              };
            });

            // Return cleanup function and close promise
            return {
              close: () => ws.close(),
              waitForClose: closePromise,
            };
          });

          // Reconnection schedule with exponential backoff
          const reconnectSchedule = pipe(
            Schedule.exponential(Duration.seconds(1)),
            Schedule.jittered,
            Schedule.whileOutput((delay) => Duration.lessThanOrEqualTo(delay, config.reconnectMaxDelay))
          );

          // Run connection loop in background with reconnection
          const connectionFiber = yield* Effect.gen(function* () {
            while (true) {
              const result = yield* connect.pipe(
                Effect.catchAll((error) =>
                  Effect.gen(function* () {
                    yield* Effect.logError(`Jetstream connection error: ${error.message}`);
                    yield* Ref.update(statusRef, (s) => ({
                      ...s,
                      connected: false,
                      reconnectCount: s.reconnectCount + 1,
                    }));
                    return null;
                  })
                )
              );

              if (result) {
                // Wait for close
                yield* Effect.tryPromise({
                  try: () => result.waitForClose,
                  catch: () => new JetstreamError("Connection closed unexpectedly"),
                });
              }

              // Wait before reconnecting
              yield* Effect.sleep(Duration.seconds(1));
              yield* Effect.log("Attempting to reconnect to Jetstream...");
            }
          }).pipe(Effect.forkScoped);

          // Add finalizer to close connection
          yield* Effect.addFinalizer(() =>
            Effect.gen(function* () {
              yield* Effect.log("Shutting down Jetstream connection");
              yield* Queue.shutdown(queue);
            })
          );

          // Return stream from queue
          return Stream.fromQueue(queue);
        })
      );
    },
  });

export const JetstreamServiceLive = (config?: JetstreamConfig) =>
  Layer.effect(JetstreamService, makeJetstreamService(config));

// Type guard helpers
export const isCommitEvent = (event: JetstreamEvent): event is JetstreamCommitEvent =>
  event.kind === "commit";

export const isIdentityEvent = (event: JetstreamEvent): event is JetstreamIdentityEvent =>
  event.kind === "identity";

export const isAccountEvent = (event: JetstreamEvent): event is JetstreamAccountEvent =>
  event.kind === "account";

// Helper to filter stream for specific collection
export const filterByCollection = (
  collection: string
) => <E, R>(
  stream: Stream.Stream<JetstreamEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(
    Stream.filter(isCommitEvent),
    Stream.filter((e) => e.commit.collection === collection)
  );

// Helper to filter stream for specific operation
export const filterByOperation = (
  operation: "create" | "update" | "delete"
) => <E, R>(
  stream: Stream.Stream<JetstreamCommitEvent, E, R>
): Stream.Stream<JetstreamCommitEvent, E, R> =>
  stream.pipe(Stream.filter((e) => e.commit.operation === operation));
