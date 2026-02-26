import { Effect } from "effect";
import { HttpRouter, HttpServerResponse } from "@effect/platform";

const DOMAIN = process.env.DOMAIN || "feed.brew-haiku.app";
const SERVICE_DID = `did:web:${DOMAIN}`;

export const didDocumentRoutes = HttpRouter.empty.pipe(
  HttpRouter.get(
    "/.well-known/did.json",
    Effect.gen(function* () {
      const didDocument = {
        "@context": ["https://www.w3.org/ns/did/v1"],
        id: SERVICE_DID,
        alsoKnownAs: [],
        verificationMethod: [
          {
            id: `${SERVICE_DID}#atproto`,
            type: "Multikey",
            controller: SERVICE_DID,
          },
        ],
        service: [
          {
            id: "#bsky_fg",
            type: "BskyFeedGenerator",
            serviceEndpoint: `https://${DOMAIN}`,
          },
        ],
      };

      return yield* HttpServerResponse.json(didDocument, {
        headers: {
          "Content-Type": "application/did+json",
          "Cache-Control": "max-age=3600",
        },
      });
    })
  )
);

export { SERVICE_DID, DOMAIN };
