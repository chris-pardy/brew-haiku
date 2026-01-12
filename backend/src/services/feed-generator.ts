import { Effect, Context, Layer } from "effect";
import { DatabaseService } from "./database.js";

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
}

export interface FeedPost {
  post: string;
}

export interface FeedSkeleton {
  feed: FeedPost[];
  cursor?: string;
}

const DEFAULT_CONFIG: FeedConfig = {
  likeWeight: parseFloat(process.env.LIKE_WEIGHT || "1.0"),
  recencyWeight: parseFloat(process.env.RECENCY_WEIGHT || "2.0"),
  recencyHalfLifeHours: parseFloat(process.env.RECENCY_HALF_LIFE_HOURS || "24"),
  signatureBonus: parseFloat(process.env.SIGNATURE_BONUS || "50.0"),
};

/** SQL scoring expression using config values. Expects `like_count`, `created_at`, `has_signature` columns. */
export const scoreSql = (config: FeedConfig, nowParam: string = "?") =>
  `(${config.likeWeight} * like_count + ${config.recencyWeight} * exp(-0.693147 * ((${nowParam} - created_at) / (3600000.0 * ${config.recencyHalfLifeHours}))) + ${config.signatureBonus} * has_signature)`;

export class FeedGeneratorService extends Context.Tag("FeedGeneratorService")<
  FeedGeneratorService,
  {
    readonly getFeedSkeleton: (
      limit: number,
      cursor?: string
    ) => Effect.Effect<FeedSkeleton, FeedGeneratorError>;
    readonly config: FeedConfig;
  }
>() {}

export const makeFeedGeneratorService = (
  configOverrides?: Partial<FeedConfig>
) =>
  Effect.gen(function* () {
    const dbService = yield* DatabaseService;
    const { db } = dbService;

    const config: FeedConfig = {
      ...DEFAULT_CONFIG,
      ...configOverrides,
    };

    const getFeedSkeleton = (
      limit: number,
      cursor?: string
    ): Effect.Effect<FeedSkeleton, FeedGeneratorError> =>
      Effect.try({
        try: () => {
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

    return { getFeedSkeleton, config };
  });

export const FeedGeneratorServiceLive = (configOverrides?: Partial<FeedConfig>) =>
  Layer.effect(FeedGeneratorService, makeFeedGeneratorService(configOverrides));
