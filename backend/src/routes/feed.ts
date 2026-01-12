import { Effect } from "effect";
import { HttpRouter, HttpServerResponse, HttpServerRequest } from "@effect/platform";
import { FeedGeneratorService, FeedGeneratorError } from "../services/feed-generator.js";
import { SERVICE_DID, DOMAIN } from "./did-document.js";

const PUBLISHER_DID = process.env.PUBLISHER_DID || "";
const FEED_URI = `at://${SERVICE_DID}/app.bsky.feed.generator/haikus`;
const PUBLISHER_FEED_URI = PUBLISHER_DID
  ? `at://${PUBLISHER_DID}/app.bsky.feed.generator/haikus`
  : "";

const isValidFeedUri = (uri: string) =>
  uri === FEED_URI || (PUBLISHER_FEED_URI && uri === PUBLISHER_FEED_URI);

export const feedRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/xrpc/app.bsky.feed.getFeedSkeleton",
    Effect.gen(function* () {
      const request = yield* HttpServerRequest.HttpServerRequest;
      const url = new URL(request.url, "http://localhost");

      const feed = url.searchParams.get("feed");
      const limitParam = url.searchParams.get("limit");
      const cursor = url.searchParams.get("cursor") || undefined;

      // Validate feed parameter
      if (!feed) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "feed parameter is required" },
          { status: 400 }
        );
      }

      if (!isValidFeedUri(feed)) {
        return yield* HttpServerResponse.json(
          { error: "UnknownFeed", message: `Unknown feed: ${feed}` },
          { status: 400 }
        );
      }

      const limit = limitParam ? parseInt(limitParam, 10) : 50;
      if (isNaN(limit) || limit < 1 || limit > 100) {
        return yield* HttpServerResponse.json(
          { error: "InvalidRequest", message: "limit must be between 1 and 100" },
          { status: 400 }
        );
      }

      const feedGenerator = yield* FeedGeneratorService;
      const result = yield* feedGenerator.getFeedSkeleton(limit, cursor).pipe(
        Effect.catchTag("FeedGeneratorError", (e) =>
          Effect.succeed({
            error: "InternalError",
            message: e.message,
          })
        )
      );

      if ("error" in result) {
        return yield* HttpServerResponse.json(result, { status: 500 });
      }

      return yield* HttpServerResponse.json(result);
    })
  ),

  HttpRouter.get(
    "/xrpc/app.bsky.feed.describeFeedGenerator",
    Effect.gen(function* () {
      return yield* HttpServerResponse.json({
        did: SERVICE_DID,
        feeds: [
          {
            uri: FEED_URI,
          },
        ],
      });
    })
  )
);

export { FEED_URI };
