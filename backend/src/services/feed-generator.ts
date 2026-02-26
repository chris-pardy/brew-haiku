import { Effect, Context, Layer } from "effect";
import { DatabaseService } from "./database.js";
import { resolve } from "path";

export class FeedGeneratorError extends Error {
  readonly _tag = "FeedGeneratorError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface FeedConfig {
  likeWeight: number;
  recencyWeight: number;
  recencyHalfLifeHours: number;
  signatureBonus: number;
  coffeeWeight: number;
  teaWeight: number;
  natureWeight: number;
  relaxationWeight: number;
  morningWeight: number;
  afternoonWeight: number;
  eveningWeight: number;
}

export type FeedType = "coffee" | "tea";
export type FeedTime = "morning" | "afternoon" | "evening";

export interface FeedConfigFile {
  base: FeedConfig;
  type: Record<string, Partial<FeedConfig>>;
  time: Record<string, Partial<FeedConfig>>;
}

export interface FeedPost {
  post: string;
}

export interface FeedSkeleton {
  feed: FeedPost[];
  cursor?: string;
}

/** Load feed config from JSON file. Falls back to hardcoded defaults if file is missing. */
export function loadFeedConfigFile(): FeedConfigFile {
  const FALLBACK: FeedConfigFile = {
    base: {
      likeWeight: 1.0,
      recencyWeight: 100.0,
      recencyHalfLifeHours: 6,
      signatureBonus: 50.0,
      natureWeight: 10.0,
      relaxationWeight: 5.0,
      coffeeWeight: 15.0,
      teaWeight: 15.0,
      morningWeight: 0,
      afternoonWeight: 0,
      eveningWeight: 0,
    },
    type: {
      coffee: { coffeeWeight: 30.0, teaWeight: 5.0 },
      tea: { teaWeight: 30.0, coffeeWeight: 5.0 },
    },
    time: {
      morning: { morningWeight: 20.0 },
      afternoon: { afternoonWeight: 20.0 },
      evening: { eveningWeight: 20.0 },
    },
  };

  try {
    const configPath = resolve(import.meta.dir, "../../feed-config.json");
    const fs = require("fs");
    const json = JSON.parse(fs.readFileSync(configPath, "utf-8"));
    return {
      base: { ...FALLBACK.base, ...json.base },
      type: { ...FALLBACK.type, ...json.type },
      time: { ...FALLBACK.time, ...json.time },
    };
  } catch {
    console.warn("Could not load feed-config.json, using defaults");
    return FALLBACK;
  }
}

/** Resolve a full FeedConfig from the config file given optional type/time selectors. */
export function resolveFeedConfig(
  configFile: FeedConfigFile,
  type?: FeedType,
  time?: FeedTime
): FeedConfig {
  let config = { ...configFile.base };

  if (type && configFile.type[type]) {
    config = { ...config, ...configFile.type[type] };
  }

  if (time && configFile.time[time]) {
    config = { ...config, ...configFile.time[time] };
  }

  return config;
}

/** SQL scoring expression using config values. Expects `like_count`, `created_at`, `has_signature`, and `score_*` columns. */
export const scoreSql = (config: FeedConfig, nowParam: string = "?") => {
  const base = `${config.likeWeight} * like_count + ${config.recencyWeight} * exp(-0.693147 * ((${nowParam} - created_at) / (3600000.0 * ${config.recencyHalfLifeHours}))) + ${config.signatureBonus} * has_signature`;

  // Only include category terms when their weight is non-zero
  const categoryTerms: string[] = [];
  if (config.coffeeWeight) categoryTerms.push(`${config.coffeeWeight} * score_coffee`);
  if (config.teaWeight) categoryTerms.push(`${config.teaWeight} * score_tea`);
  if (config.natureWeight) categoryTerms.push(`${config.natureWeight} * score_nature`);
  if (config.relaxationWeight) categoryTerms.push(`${config.relaxationWeight} * score_relaxation`);
  if (config.morningWeight) categoryTerms.push(`${config.morningWeight} * score_morning`);
  if (config.afternoonWeight) categoryTerms.push(`${config.afternoonWeight} * score_afternoon`);
  if (config.eveningWeight) categoryTerms.push(`${config.eveningWeight} * score_evening`);

  if (categoryTerms.length > 0) {
    return `(${base} + ${categoryTerms.join(" + ")})`;
  }
  return `(${base})`;
};

export class FeedGeneratorService extends Context.Tag("FeedGeneratorService")<
  FeedGeneratorService,
  {
    readonly getFeedSkeleton: (
      limit: number,
      cursor?: string,
      type?: FeedType,
      time?: FeedTime
    ) => Effect.Effect<FeedSkeleton, FeedGeneratorError>;
    readonly configFile: FeedConfigFile;
  }
>() {}

export const makeFeedGeneratorService = (
  configFileOverride?: FeedConfigFile
) =>
  Effect.gen(function* () {
    const dbService = yield* DatabaseService;
    const { db } = dbService;

    const configFile = configFileOverride ?? loadFeedConfigFile();

    const getFeedSkeleton = (
      limit: number,
      cursor?: string,
      type?: FeedType,
      time?: FeedTime
    ): Effect.Effect<FeedSkeleton, FeedGeneratorError> =>
      Effect.try({
        try: () => {
          const config = resolveFeedConfig(configFile, type, time);
          const effectiveLimit = Math.min(Math.max(1, limit), 100);

          let offset = 0;
          if (cursor) {
            const parsed = parseInt(cursor, 10);
            if (!isNaN(parsed)) {
              offset = parsed;
            }
          }

          const now = Date.now();
          const rows = db
            .query<{ uri: string }, [number, number]>(
              `SELECT uri, ${scoreSql(config, String(now))} AS score
               FROM haiku_posts
               ORDER BY score DESC
               LIMIT ? OFFSET ?`
            )
            .all(effectiveLimit + 1, offset);

          const hasMore = rows.length > effectiveLimit;
          const feed: FeedPost[] = rows.slice(0, effectiveLimit).map((row) => ({
            post: row.uri,
          }));

          const nextCursor = hasMore
            ? String(offset + effectiveLimit)
            : undefined;

          return {
            feed,
            cursor: nextCursor,
          };
        },
        catch: (error) =>
          new FeedGeneratorError("Failed to generate feed skeleton", error),
      });

    return { getFeedSkeleton, configFile };
  });

export const FeedGeneratorServiceLive = (configFileOverride?: FeedConfigFile) =>
  Layer.effect(FeedGeneratorService, makeFeedGeneratorService(configFileOverride));
