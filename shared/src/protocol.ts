/**
 * WebSocket protocol between ingestion workers and service backends.
 *
 * Sharding strategy (design — not yet implemented):
 *   - Each worker identifies with a `shardId` on connect.
 *   - Shards can partition work by collection, DID-prefix range, or both.
 *   - Jetstream's `wantedCollections` supports collection-based sharding natively.
 *   - DID-range sharding requires client-side filtering (Jetstream doesn't support ranges).
 *   - Each shard maintains its own cursor file: `/data/cursor-{shardId}`.
 *   - The server accepts N worker connections and aggregates stats across shards.
 */

// ---------------------------------------------------------------------------
// Worker → Server
// ---------------------------------------------------------------------------

export type IngestEvent =
  | { type: "hello"; shardId: string }
  | {
      type: "haiku:create";
      uri: string;
      did: string;
      cid: string;
      text: string;
      hasSignature: boolean;
      scores: {
        coffee: number;
        tea: number;
        nature: number;
        relaxation: number;
        morning: number;
        evening: number;
      };
      createdAt: number;
    }
  | { type: "haiku:delete"; uri: string }
  | {
      type: "like:create";
      likeUri: string;
      postUri: string;
      likerDid: string;
      createdAt: number;
    }
  | { type: "like:delete"; likeUri: string }
  | {
      type: "timer:save";
      uri: string;
      did: string;
      cid: string;
      handle: string | null;
      name: string;
      vessel: string;
      brewType: string;
      ratio: number | null;
      steps: string;
      createdAt: number;
    }
  | { type: "timer:unsave"; rkey: string; did: string }
  | {
      type: "stats";
      shardId: string;
      eventsProcessed: number;
      haikuDetected: number;
      haikuIndexed: number;
      likesProcessed: number;
    };

// ---------------------------------------------------------------------------
// Server → Worker
// ---------------------------------------------------------------------------

export type ServerMessage =
  | { type: "welcome"; shardId: string }
  | { type: "error"; message: string };
