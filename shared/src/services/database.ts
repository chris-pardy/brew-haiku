import { Effect, Context, Layer } from "effect";
import { Database } from "bun:sqlite";
import { runMigrations, type Migration } from "../db/migrations.js";

export class DatabaseError extends Error {
  readonly _tag = "DatabaseError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface TimerRecord {
  uri: string;
  did: string;
  cid: string;
  handle: string | null;
  name: string;
  vessel: string;
  brew_type: string;
  ratio: number | null;
  steps: string;
  notes: string | null;
  save_count: number;
  created_at: number;
  indexed_at: number;
}

export interface DIDCacheRecord {
  did: string;
  handle: string;
  pds_url: string;
  public_key: string | null;
  cached_at: number;
}

export interface HaikuPostRecord {
  uri: string;
  did: string;
  cid: string;
  text: string;
  has_signature: number;
  like_count: number;
  created_at: number;
  indexed_at: number;
}

export class DatabaseService extends Context.Tag("DatabaseService")<
  DatabaseService,
  {
    readonly db: Database;
    readonly close: () => Effect.Effect<void, DatabaseError>;
  }
>() {}

export const makeDatabaseService = (
  dbPath: string = "brew-haiku.db",
  migrations: Migration[] = []
): Effect.Effect<{ db: Database; close: () => Effect.Effect<void, DatabaseError> }, DatabaseError> =>
  Effect.try({
    try: () => {
      const db = new Database(dbPath);
      db.run("PRAGMA journal_mode = WAL");
      db.run("PRAGMA foreign_keys = ON");
      runMigrations(db, migrations);
      return {
        db,
        close: () =>
          Effect.try({
            try: () => {
              db.close();
            },
            catch: (error) => new DatabaseError("Failed to close database", error),
          }),
      };
    },
    catch: (error) => new DatabaseError("Failed to initialize database", error),
  });

export const DatabaseServiceLive = (dbPath?: string, migrations: Migration[] = []) =>
  Layer.effect(
    DatabaseService,
    makeDatabaseService(dbPath, migrations)
  );

export const DatabaseServiceTest = (migrations: Migration[] = []) =>
  Layer.effect(
    DatabaseService,
    makeDatabaseService(":memory:", migrations)
  );
