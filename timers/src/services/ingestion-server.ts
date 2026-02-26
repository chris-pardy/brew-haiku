import type { Database } from "bun:sqlite";
import type { Server, ServerWebSocket } from "bun";
import type { IngestEvent, ServerMessage } from "@brew-haiku/shared";

export interface IngestionServer {
  readonly server: Server;
  readonly stop: () => void;
}

export function createTimerIngestionServer(
  db: Database,
  port: number
): IngestionServer {
  function applyEvent(event: IngestEvent): void {
    switch (event.type) {
      case "timer:save": {
        const existing = db
          .query<{ uri: string }, [string]>(
            "SELECT uri FROM timer_index WHERE uri = ?"
          )
          .get(event.uri);

        if (existing) {
          db.run(
            `UPDATE timer_index SET save_count = save_count + 1 WHERE uri = ?`,
            [event.uri]
          );
        } else {
          db.run(
            `INSERT INTO timer_index
             (uri, did, cid, handle, name, vessel, brew_type, ratio, steps, save_count, created_at, indexed_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`,
            [
              event.uri,
              event.did,
              event.cid,
              event.handle,
              event.name,
              event.vessel,
              event.brewType,
              event.ratio,
              event.steps,
              event.createdAt,
              Date.now(),
            ]
          );
        }
        break;
      }

      case "timer:unsave": {
        // Find timer matching the rkey from the savedTimer record
        const result = db
          .query<{ uri: string }, [string]>(
            "SELECT uri FROM timer_index WHERE uri LIKE ?"
          )
          .get(`%/${event.rkey}`);

        if (result) {
          db.run(
            `UPDATE timer_index SET save_count = MAX(0, save_count - 1) WHERE uri = ?`,
            [result.uri]
          );
          db.run(
            "DELETE FROM timer_index WHERE uri = ? AND save_count <= 0",
            [result.uri]
          );
        }
        break;
      }

      default:
        // Timers service ignores non-timer events
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
            const reply: ServerMessage = {
              type: "welcome",
              shardId: event.shardId,
            };
            ws.send(JSON.stringify(reply));
            console.log(`Ingest worker shard "${event.shardId}" connected`);
            return;
          }

          applyEvent(event);
        } catch (e) {
          console.error(`Failed to process timer ingest event: ${e}`);
        }
      },
      open(ws) {
        console.log("Ingest worker WebSocket connected, awaiting hello");
      },
      close(ws) {
        console.log("Ingest worker disconnected");
      },
    },
  });

  console.log(`Timer ingestion WebSocket server listening on port ${port}`);

  return {
    server,
    stop: () => server.stop(),
  };
}
