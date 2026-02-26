import type { IngestionServer } from "./ingestion-server.js";

let ingestionServer: IngestionServer | null = null;

export function setIngestionServer(server: IngestionServer): void {
  ingestionServer = server;
}

export function getIngestionServer(): IngestionServer | null {
  return ingestionServer;
}
