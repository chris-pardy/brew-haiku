import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import {
  ATProtoService,
  ATProtoError,
  HandleNotFoundError,
} from "../services/atproto.js";

export const resolveRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/resolve/:handle",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");
      const pathParts = url.pathname.split("/");
      const handle = pathParts[pathParts.length - 1];

      if (!handle) {
        return yield* HttpServerResponse.json(
          { error: "Handle parameter is required" },
          { status: 400 }
        );
      }

      const atproto = yield* ATProtoService;
      const result = yield* atproto.resolveHandle(handle).pipe(
        Effect.catchTag("HandleNotFoundError", (e) =>
          Effect.succeed({
            error: "not_found",
            message: e.message,
            handle: e.handle,
          })
        ),
        Effect.catchTag("ATProtoError", (e) =>
          Effect.succeed({
            error: "resolution_failed",
            message: e.message,
          })
        )
      );

      if ("error" in result) {
        const status = result.error === "not_found" ? 404 : 500;
        return yield* HttpServerResponse.json(result, { status });
      }

      return yield* HttpServerResponse.json({
        did: result.did,
        handle: result.handle,
        pdsUrl: result.pdsUrl,
      });
    })
  )
);
