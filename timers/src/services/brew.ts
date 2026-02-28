import { Effect, Context, Layer } from "effect";
import { DatabaseService } from "@brew-haiku/shared";

export class BrewError extends Error {
  readonly _tag = "BrewError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface BrewRecord {
  uri: string;
  did: string;
  timer_uri: string;
  post_uri: string | null;
  step_values: string | null;
  created_at: number;
  indexed_at: number;
}

export interface Brew {
  uri: string;
  did: string;
  timerUri: string;
  postUri: string | null;
  stepValues: Array<{ stepIndex: number; value: number }> | null;
  createdAt: Date;
}

const recordToBrew = (record: BrewRecord): Brew => {
  let stepValues: Array<{ stepIndex: number; value: number }> | null = null;
  if (record.step_values) {
    try {
      stepValues = JSON.parse(record.step_values);
    } catch {
      stepValues = null;
    }
  }
  return {
    uri: record.uri,
    did: record.did,
    timerUri: record.timer_uri,
    postUri: record.post_uri,
    stepValues,
    createdAt: new Date(record.created_at),
  };
};

export class BrewService extends Context.Tag("BrewService")<
  BrewService,
  {
    readonly listBrews: (
      did: string,
      limit: number,
      offset: number
    ) => Effect.Effect<{ brews: Brew[]; total: number }, BrewError>;
    readonly indexBrew: (record: BrewRecord) => Effect.Effect<void, BrewError>;
    readonly deleteBrew: (uri: string) => Effect.Effect<void, BrewError>;
  }
>() {}

export const makeBrewService = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  const listBrews = (
    did: string,
    limit: number,
    offset: number
  ): Effect.Effect<{ brews: Brew[]; total: number }, BrewError> =>
    Effect.try({
      try: () => {
        const safeLimit = Math.min(Math.max(1, limit), 100);
        const safeOffset = Math.max(0, offset);

        const countResult = db
          .query<{ count: number }, [string]>(
            "SELECT COUNT(*) as count FROM brew_index WHERE did = ?"
          )
          .get(did);
        const total = countResult?.count ?? 0;

        const records = db
          .query<BrewRecord, [string, number, number]>(
            `SELECT * FROM brew_index WHERE did = ?
             ORDER BY created_at DESC
             LIMIT ? OFFSET ?`
          )
          .all(did, safeLimit, safeOffset);

        return { brews: records.map(recordToBrew), total };
      },
      catch: (error) => new BrewError("Failed to list brews", error),
    });

  const indexBrew = (record: BrewRecord): Effect.Effect<void, BrewError> =>
    Effect.try({
      try: () => {
        db.run(
          `INSERT OR IGNORE INTO brew_index
           (uri, did, timer_uri, post_uri, step_values, created_at, indexed_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            record.uri,
            record.did,
            record.timer_uri,
            record.post_uri,
            record.step_values,
            record.created_at,
            record.indexed_at,
          ]
        );
      },
      catch: (error) => new BrewError("Failed to index brew", error),
    });

  const deleteBrew = (uri: string): Effect.Effect<void, BrewError> =>
    Effect.try({
      try: () => {
        db.run("DELETE FROM brew_index WHERE uri = ?", [uri]);
      },
      catch: (error) => new BrewError("Failed to delete brew", error),
    });

  return { listBrews, indexBrew, deleteBrew };
});

export const BrewServiceLive = Layer.effect(BrewService, makeBrewService);
