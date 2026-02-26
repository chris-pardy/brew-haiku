import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import {
  TimerService,
  TimerError,
  TimerNotFoundError,
} from "../services/timer.js";

export const timerRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/timers/search",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");

      const query = url.searchParams.get("q");
      if (!query || query.trim().length === 0) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Search query 'q' is required" },
          { status: 400 }
        );
      }

      const limitParam = url.searchParams.get("limit");
      const offsetParam = url.searchParams.get("offset");
      const brewType = url.searchParams.get("brew_type") || undefined;
      const vessel = url.searchParams.get("vessel") || undefined;
      const saveWeightParam = url.searchParams.get("save_weight");
      const textWeightParam = url.searchParams.get("text_weight");

      const limit = limitParam ? parseInt(limitParam, 10) : 20;
      const offset = offsetParam ? parseInt(offsetParam, 10) : 0;
      const saveWeight = saveWeightParam ? parseFloat(saveWeightParam) : undefined;
      const textWeight = textWeightParam ? parseFloat(textWeightParam) : undefined;

      if (isNaN(limit) || limit < 1 || limit > 100) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "limit must be between 1 and 100" },
          { status: 400 }
        );
      }

      if (isNaN(offset) || offset < 0) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "offset must be non-negative" },
          { status: 400 }
        );
      }

      const timerService = yield* TimerService;
      const result = yield* timerService
        .searchTimers({
          query: query.trim(),
          limit,
          offset,
          brewType,
          vessel,
          saveWeight,
          textWeight,
        })
        .pipe(
          Effect.catchTag("TimerError", (e) =>
            Effect.succeed({
              error: "InternalError",
              message: e.message,
            })
          )
        );

      if ("error" in result) {
        return yield* HttpServerResponse.json(result, { status: 500 });
      }

      return yield* HttpServerResponse.json({
        timers: result.timers,
        total: result.total,
        query: query.trim(),
        limit,
        offset,
      });
    })
  ),

  HttpRouter.get(
    "/timers",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");

      const limitParam = url.searchParams.get("limit");
      const offsetParam = url.searchParams.get("offset");
      const brewType = url.searchParams.get("brew_type") || undefined;
      const vessel = url.searchParams.get("vessel") || undefined;

      const limit = limitParam ? parseInt(limitParam, 10) : 20;
      const offset = offsetParam ? parseInt(offsetParam, 10) : 0;

      if (isNaN(limit) || limit < 1 || limit > 100) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "limit must be between 1 and 100" },
          { status: 400 }
        );
      }

      if (isNaN(offset) || offset < 0) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "offset must be non-negative" },
          { status: 400 }
        );
      }

      const timerService = yield* TimerService;
      const result = yield* timerService
        .listTimers({ limit, offset, brewType, vessel })
        .pipe(
          Effect.catchTag("TimerError", (e) =>
            Effect.succeed({
              error: "InternalError",
              message: e.message,
            })
          )
        );

      if ("error" in result) {
        return yield* HttpServerResponse.json(result, { status: 500 });
      }

      return yield* HttpServerResponse.json({
        timers: result.timers,
        total: result.total,
        limit,
        offset,
      });
    })
  ),

  HttpRouter.get(
    "/timers/:uri",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");

      // Extract URI from path - it's URL encoded
      const pathParts = url.pathname.split("/timers/");
      const encodedUri = pathParts[1];

      if (!encodedUri) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "Timer URI is required" },
          { status: 400 }
        );
      }

      const uri = decodeURIComponent(encodedUri);

      const timerService = yield* TimerService;
      const result = yield* timerService.getTimer(uri).pipe(
        Effect.catchTag("TimerNotFoundError", (e) =>
          Effect.succeed({
            error: "NotFound",
            message: e.message,
            uri: e.uri,
          })
        ),
        Effect.catchTag("TimerError", (e) =>
          Effect.succeed({
            error: "InternalError",
            message: e.message,
          })
        )
      );

      if ("error" in result) {
        const status = result.error === "NotFound" ? 404 : 500;
        return yield* HttpServerResponse.json(result, { status });
      }

      return yield* HttpServerResponse.json(result);
    })
  )
);
