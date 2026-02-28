import { Effect, Context, Layer } from "effect";
import { DatabaseService } from "@brew-haiku/shared";

export class ActivityError extends Error {
  readonly _tag = "ActivityError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export interface ActivityEvent {
  eventType: "brew" | "save" | "create";
  did: string;
  uri: string;
  timerUri: string;
  postUri: string | null;
  createdAt: Date;
}

interface RawActivityRow {
  event_type: string;
  did: string;
  uri: string;
  timer_uri: string;
  post_uri: string | null;
  created_at: number;
}

export class ActivityService extends Context.Tag("ActivityService")<
  ActivityService,
  {
    readonly getActivity: (
      dids: Set<string>,
      limit: number,
      offset: number
    ) => Effect.Effect<{ events: ActivityEvent[]; total: number }, ActivityError>;
  }
>() {}

export const makeActivityService = Effect.gen(function* () {
  const dbService = yield* DatabaseService;
  const { db } = dbService;

  const getActivity = (
    dids: Set<string>,
    limit: number,
    offset: number
  ): Effect.Effect<{ events: ActivityEvent[]; total: number }, ActivityError> =>
    Effect.try({
      try: () => {
        if (dids.size === 0) return { events: [], total: 0 };

        const safeLimit = Math.min(Math.max(1, limit), 100);
        const safeOffset = Math.max(0, offset);

        const didArray = Array.from(dids);
        const placeholders = didArray.map(() => "?").join(", ");

        // UNION ALL across brew_index, timer_saves, and timer_index
        const unionQuery = `
          SELECT 'brew' as event_type, did, uri, timer_uri, post_uri, created_at
          FROM brew_index WHERE did IN (${placeholders})
          UNION ALL
          SELECT 'save' as event_type, saver_did as did,
            saver_did || '/' || timer_uri as uri, timer_uri, NULL as post_uri, created_at
          FROM timer_saves WHERE saver_did IN (${placeholders})
          UNION ALL
          SELECT 'create' as event_type, did, uri, uri as timer_uri, NULL as post_uri, created_at
          FROM timer_index WHERE did IN (${placeholders})
        `;

        // Get total count
        const countResult = db
          .query<{ count: number }, string[]>(
            `SELECT COUNT(*) as count FROM (${unionQuery})`
          )
          .get(...didArray, ...didArray, ...didArray);
        const total = countResult?.count ?? 0;

        // Get paginated results
        const rows = db
          .query<RawActivityRow, (string | number)[]>(
            `${unionQuery}
             ORDER BY created_at DESC
             LIMIT ? OFFSET ?`
          )
          .all(...didArray, ...didArray, ...didArray, safeLimit, safeOffset);

        const events: ActivityEvent[] = rows.map((row) => ({
          eventType: row.event_type as "brew" | "save" | "create",
          did: row.did,
          uri: row.uri,
          timerUri: row.timer_uri,
          postUri: row.post_uri,
          createdAt: new Date(row.created_at),
        }));

        return { events, total };
      },
      catch: (error) => new ActivityError("Failed to get activity", error),
    });

  return { getActivity };
});

export const ActivityServiceLive = Layer.effect(ActivityService, makeActivityService);
