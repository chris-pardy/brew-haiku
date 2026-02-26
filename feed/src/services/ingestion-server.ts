import type { Database } from "bun:sqlite";
import type { Server, ServerWebSocket } from "bun";
import type { IngestEvent, ServerMessage } from "@brew-haiku/shared";

export interface WorkerStats {
  shardId: string;
  eventsProcessed: number;
  haikuDetected: number;
  haikuIndexed: number;
  likesProcessed: number;
  connectedAt: number;
  lastStatsAt: number;
}

export interface IngestionServer {
  readonly server: Server;
  readonly getWorkerStats: () => WorkerStats[];
  readonly stop: () => void;
}

export function createIngestionServer(
  db: Database,
  port: number
): IngestionServer {
  const workers = new Map<ServerWebSocket<unknown>, WorkerStats>();

  function applyEvent(event: IngestEvent): void {
    switch (event.type) {
      case "hello":
      case "stats":
        // Handled separately in message handler
        break;

      case "haiku:create": {
        const existing = db
          .query<{ like_count: number }, [string]>(
            "SELECT like_count FROM haiku_posts WHERE uri = ?"
          )
          .get(event.uri);
        const likeCount = existing?.like_count ?? 0;

        db.run(
          `INSERT OR REPLACE INTO haiku_posts
           (uri, did, cid, text, has_signature, like_count, created_at, indexed_at,
            score_coffee, score_tea, score_morning, score_afternoon, score_evening,
            score_nature, score_relaxation)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            event.uri,
            event.did,
            event.cid,
            event.text,
            event.hasSignature ? 1 : 0,
            likeCount,
            event.createdAt,
            Date.now(),
            event.scores.coffee,
            event.scores.tea,
            event.scores.morning,
            0, // afternoon — not yet classified
            event.scores.evening,
            event.scores.nature,
            event.scores.relaxation,
          ]
        );
        break;
      }

      case "haiku:delete": {
        db.run("DELETE FROM haiku_likes WHERE post_uri = ?", [event.uri]);
        db.run("DELETE FROM haiku_posts WHERE uri = ?", [event.uri]);
        break;
      }

      case "like:create": {
        // Only process likes for posts we're tracking
        const post = db
          .query<{ uri: string }, [string]>(
            "SELECT uri FROM haiku_posts WHERE uri = ?"
          )
          .get(event.postUri);
        if (!post) break;

        db.run(
          `INSERT OR IGNORE INTO haiku_likes (like_uri, post_uri, liker_did, created_at)
           VALUES (?, ?, ?, ?)`,
          [event.likeUri, event.postUri, event.likerDid, event.createdAt]
        );
        db.run(
          `UPDATE haiku_posts SET like_count = like_count + 1 WHERE uri = ?`,
          [event.postUri]
        );
        break;
      }

      case "like:delete": {
        const like = db
          .query<{ post_uri: string }, [string]>(
            "SELECT post_uri FROM haiku_likes WHERE like_uri = ?"
          )
          .get(event.likeUri);
        if (!like) break;

        db.run("DELETE FROM haiku_likes WHERE like_uri = ?", [event.likeUri]);
        db.run(
          `UPDATE haiku_posts SET like_count = MAX(0, like_count - 1) WHERE uri = ?`,
          [like.post_uri]
        );
        break;
      }

      case "timer:save":
      case "timer:unsave":
        // Feed service does not handle timer events
        break;
    }
  }

  const server = Bun.serve({
    port,
    fetch(req, server) {
      if (server.upgrade(req)) return;
      return new Response("Upgrade Required", { status: 426 });
    },
    websocket: {
      message(ws, message) {
        try {
          const event = JSON.parse(String(message)) as IngestEvent;

          if (event.type === "hello") {
            const stats: WorkerStats = {
              shardId: event.shardId,
              eventsProcessed: 0,
              haikuDetected: 0,
              haikuIndexed: 0,
              likesProcessed: 0,
              connectedAt: Date.now(),
              lastStatsAt: Date.now(),
            };
            workers.set(ws, stats);
            const reply: ServerMessage = {
              type: "welcome",
              shardId: event.shardId,
            };
            ws.send(JSON.stringify(reply));
            console.log(`Worker shard "${event.shardId}" connected`);
            return;
          }

          if (event.type === "stats") {
            const existing = workers.get(ws);
            if (existing) {
              existing.eventsProcessed = event.eventsProcessed;
              existing.haikuDetected = event.haikuDetected;
              existing.haikuIndexed = event.haikuIndexed;
              existing.likesProcessed = event.likesProcessed;
              existing.lastStatsAt = Date.now();
            }
            return;
          }

          applyEvent(event);
        } catch (e) {
          console.error(`Failed to process ingest event: ${e}`);
        }
      },
      open(ws) {
        console.log("Worker WebSocket connected, awaiting hello");
      },
      close(ws) {
        const stats = workers.get(ws);
        if (stats) {
          console.log(`Worker shard "${stats.shardId}" disconnected`);
          workers.delete(ws);
        }
      },
    },
  });

  console.log(`Ingestion WebSocket server listening on port ${port}`);

  return {
    server,
    getWorkerStats: () => Array.from(workers.values()),
    stop: () => server.stop(),
  };
}
