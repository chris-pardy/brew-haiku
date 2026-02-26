import { Effect, Context, Layer } from "effect";
import { resolve } from "path";
import { DatabaseService, type TimerRecord } from "@brew-haiku/shared";

export class TimerError extends Error {
  readonly _tag = "TimerError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export class TimerNotFoundError extends Error {
  readonly _tag = "TimerNotFoundError";
  constructor(public readonly uri: string) {
    super(`Timer not found: ${uri}`);
  }
}

export interface TimerStep {
  action: string;
  stepType: "timed" | "indeterminate";
  durationSeconds?: number;
}

export interface Timer {
  uri: string;
  did: string;
  handle: string | null;
  name: string;
  vessel: string;
  brewType: string;
  ratio: number | null;
  steps: TimerStep[];
  notes: string | null;
  saveCount: number;
  createdAt: Date;
}

export interface TimerListOptions {
  limit?: number;
  offset?: number;
  brewType?: string;
  vessel?: string;
}

export interface TimerSearchOptions {
  query: string;
  limit?: number;
  offset?: number;
  brewType?: string;
  vessel?: string;
  saveWeight?: number;
  textWeight?: number;
}

export interface TimerSearchResult {
  timers: Timer[];
  total: number;
}

export interface SearchColumnWeights {
  uri: number;
  name: number;
  vessel: number;
  brewType: number;
  steps: number;
  notes: number;
}

export interface SearchConfig {
  columnWeights: SearchColumnWeights;
  saveWeight: number;
  textWeight: number;
}

const FALLBACK_SEARCH_CONFIG: SearchConfig = {
  columnWeights: {
    uri: 0.0,
    name: 2.0,
    vessel: 1.5,
    brewType: 1.0,
    steps: 1.0,
    notes: 0.5,
  },
  saveWeight: 1.0,
  textWeight: 1.0,
};

/** Load search config from JSON file. Falls back to hardcoded defaults if file is missing. */
export function loadSearchConfig(): SearchConfig {
  try {
    const configPath = resolve(import.meta.dir, "../../search-config.json");
    const fs = require("fs");
    const json = JSON.parse(fs.readFileSync(configPath, "utf-8"));
    return {
      columnWeights: { ...FALLBACK_SEARCH_CONFIG.columnWeights, ...json.columnWeights },
      saveWeight: json.saveWeight ?? FALLBACK_SEARCH_CONFIG.saveWeight,
      textWeight: json.textWeight ?? FALLBACK_SEARCH_CONFIG.textWeight,
    };
  } catch {
    console.warn("Could not load search-config.json, using defaults");
    return FALLBACK_SEARCH_CONFIG;
  }
}

export class TimerService extends Context.Tag("TimerService")<
  TimerService,
  {
    readonly getTimer: (
      uri: string
    ) => Effect.Effect<Timer, TimerError | TimerNotFoundError>;
    readonly listTimers: (
      options?: TimerListOptions
    ) => Effect.Effect<{ timers: Timer[]; total: number }, TimerError>;
    readonly searchTimers: (
      options: TimerSearchOptions
    ) => Effect.Effect<TimerSearchResult, TimerError>;
    readonly getTimersByUris: (
      uris: string[]
    ) => Effect.Effect<Timer[], TimerError>;
    readonly indexTimer: (timer: TimerRecord) => Effect.Effect<void, TimerError>;
    readonly ensureTimer: (timer: TimerRecord) => Effect.Effect<void, TimerError>;
    readonly deleteTimer: (uri: string) => Effect.Effect<void, TimerError>;
    readonly updateSaveCount: (
      uri: string,
      delta: number
    ) => Effect.Effect<void, TimerError>;
  }
>() {}

const recordToTimer = (record: TimerRecord): Timer => {
  let steps: TimerStep[] = [];
  try {
    steps = JSON.parse(record.steps);
  } catch {
    steps = [];
  }

  return {
    uri: record.uri,
    did: record.did,
    handle: record.handle,
    name: record.name,
    vessel: record.vessel,
    brewType: record.brew_type,
    ratio: record.ratio,
    steps,
    notes: record.notes,
    saveCount: record.save_count,
    createdAt: new Date(record.created_at),
  };
};

export const makeTimerService = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;
  const searchConfig = loadSearchConfig();
  const { columnWeights: cw } = searchConfig;
  const bm25Args = `${cw.uri}, ${cw.name}, ${cw.vessel}, ${cw.brewType}, ${cw.steps}, ${cw.notes}`;

  const getTimer = (
    uri: string
  ): Effect.Effect<Timer, TimerError | TimerNotFoundError> =>
    Effect.try({
      try: () => {
        const record = db
          .query<TimerRecord, [string]>(
            "SELECT * FROM timer_index WHERE uri = ?"
          )
          .get(uri);

        if (!record) {
          throw new TimerNotFoundError(uri);
        }

        return recordToTimer(record);
      },
      catch: (error) => {
        if (error instanceof TimerNotFoundError) {
          return error;
        }
        return new TimerError("Failed to get timer", error);
      },
    });

  const listTimers = (
    options?: TimerListOptions
  ): Effect.Effect<{ timers: Timer[]; total: number }, TimerError> =>
    Effect.try({
      try: () => {
        const limit = Math.min(Math.max(1, options?.limit ?? 20), 100);
        const offset = Math.max(0, options?.offset ?? 0);

        let whereClause = "WHERE save_count > 0";
        const params: (string | number)[] = [];

        if (options?.brewType) {
          whereClause += " AND brew_type = ?";
          params.push(options.brewType);
        }

        if (options?.vessel) {
          whereClause += " AND vessel = ?";
          params.push(options.vessel);
        }

        // Get total count
        const countResult = db
          .query<{ count: number }, (string | number)[]>(
            `SELECT COUNT(*) as count FROM timer_index ${whereClause}`
          )
          .get(...params);
        const total = countResult?.count ?? 0;

        // Get paginated results
        const records = db
          .query<TimerRecord, (string | number)[]>(
            `SELECT * FROM timer_index ${whereClause}
             ORDER BY save_count DESC, created_at DESC
             LIMIT ? OFFSET ?`
          )
          .all(...params, limit, offset);

        return {
          timers: records.map(recordToTimer),
          total,
        };
      },
      catch: (error) => new TimerError("Failed to list timers", error),
    });

  const getTimersByUris = (
    uris: string[]
  ): Effect.Effect<Timer[], TimerError> =>
    Effect.try({
      try: () => {
        if (uris.length === 0) return [];
        const placeholders = uris.map(() => "?").join(", ");
        const records = db
          .query<TimerRecord, string[]>(
            `SELECT * FROM timer_index WHERE uri IN (${placeholders})`
          )
          .all(...uris);
        return records.map(recordToTimer);
      },
      catch: (error) => new TimerError("Failed to get timers by URIs", error),
    });

  const indexTimer = (timer: TimerRecord): Effect.Effect<void, TimerError> =>
    Effect.try({
      try: () => {
        db.run(
          `INSERT OR REPLACE INTO timer_index
           (uri, did, cid, handle, name, vessel, brew_type, ratio, steps, save_count, created_at, indexed_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            timer.uri,
            timer.did,
            timer.cid,
            timer.handle,
            timer.name,
            timer.vessel,
            timer.brew_type,
            timer.ratio,
            timer.steps,
            timer.save_count,
            timer.created_at,
            timer.indexed_at,
          ]
        );
      },
      catch: (error) => new TimerError("Failed to index timer", error),
    });

  const ensureTimer = (timer: TimerRecord): Effect.Effect<void, TimerError> =>
    Effect.try({
      try: () => {
        db.run(
          `INSERT OR IGNORE INTO timer_index
           (uri, did, cid, handle, name, vessel, brew_type, ratio, steps, notes, save_count, created_at, indexed_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            timer.uri,
            timer.did,
            timer.cid,
            timer.handle,
            timer.name,
            timer.vessel,
            timer.brew_type,
            timer.ratio,
            timer.steps,
            timer.notes,
            timer.save_count,
            timer.created_at,
            timer.indexed_at,
          ]
        );
      },
      catch: (error) => new TimerError("Failed to ensure timer", error),
    });

  const deleteTimer = (uri: string): Effect.Effect<void, TimerError> =>
    Effect.try({
      try: () => {
        db.run("DELETE FROM timer_index WHERE uri = ?", [uri]);
      },
      catch: (error) => new TimerError("Failed to delete timer", error),
    });

  const updateSaveCount = (
    uri: string,
    delta: number
  ): Effect.Effect<void, TimerError> =>
    Effect.try({
      try: () => {
        db.run(
          `UPDATE timer_index
           SET save_count = MAX(0, save_count + ?)
           WHERE uri = ?`,
          [delta, uri]
        );
      },
      catch: (error) => new TimerError("Failed to update save count", error),
    });

  const searchTimers = (
    options: TimerSearchOptions
  ): Effect.Effect<TimerSearchResult, TimerError> =>
    Effect.try({
      try: () => {
        const limit = Math.min(Math.max(1, options.limit ?? 20), 100);
        const offset = Math.max(0, options.offset ?? 0);
        const saveWeight = options.saveWeight ?? searchConfig.saveWeight;
        const textWeight = options.textWeight ?? searchConfig.textWeight;

        // Build WHERE clause for filters
        let filterClause = "WHERE t.save_count > 0";
        const filterParams: (string | number)[] = [];

        if (options.brewType) {
          filterClause += " AND t.brew_type = ?";
          filterParams.push(options.brewType);
        }

        if (options.vessel) {
          filterClause += " AND t.vessel = ?";
          filterParams.push(options.vessel);
        }

        // Quote the search query for FTS5 to handle special characters
        const quotedQuery = `"${options.query.replace(/"/g, '""')}"`;

        // Get total count for pagination
        const countResult = db
          .query<{ count: number }, (string | number)[]>(
            `SELECT COUNT(*) as count
             FROM timer_search ts
             JOIN timer_index t ON ts.uri = t.uri
             ${filterClause}
             AND timer_search MATCH ?`
          )
          .get(...filterParams, quotedQuery);
        const total = countResult?.count ?? 0;

        // bm25() returns negative values (more negative = better match), so we negate it
        // Column weights loaded from search-config.json
        const records = db
          .query<TimerRecord & { rank: number }, (string | number)[]>(
            `SELECT t.*, -bm25(timer_search, ${bm25Args}) as rank
             FROM timer_search ts
             JOIN timer_index t ON ts.uri = t.uri
             ${filterClause}
             AND timer_search MATCH ?
             ORDER BY (t.save_count * ?) + (-bm25(timer_search, ${bm25Args}) * ?) DESC
             LIMIT ? OFFSET ?`
          )
          .all(...filterParams, quotedQuery, saveWeight, textWeight, limit, offset);

        return {
          timers: records.map(recordToTimer),
          total,
        };
      },
      catch: (error) => new TimerError("Failed to search timers", error),
    });

  return {
    getTimer,
    getTimersByUris,
    listTimers,
    searchTimers,
    indexTimer,
    ensureTimer,
    deleteTimer,
    updateSaveCount,
  };
});

export const TimerServiceLive = Layer.effect(TimerService, makeTimerService);
