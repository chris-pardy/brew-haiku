/**
 * Publishes the feed generator record to the publisher's Bluesky repo.
 *
 * Usage:
 *   BLUESKY_HANDLE=you.bsky.social BLUESKY_PASSWORD=app-password bun run feed/scripts/publish-feed.ts
 */

const DOMAIN = process.env.DOMAIN || "feed.brew-haiku.app";
const SERVICE_DID = `did:web:${DOMAIN}`;
const FEED_RKEY = "haikus";

const BLUESKY_SERVICE = process.env.BLUESKY_SERVICE || "https://bsky.social";
const HANDLE = process.env.BLUESKY_HANDLE;
const PASSWORD = process.env.BLUESKY_PASSWORD;

if (!HANDLE || !PASSWORD) {
  console.error(
    "Usage: BLUESKY_HANDLE=you.bsky.social BLUESKY_PASSWORD=app-password bun run feed/scripts/publish-feed.ts"
  );
  process.exit(1);
}

async function main() {
  console.log(`Logging in as ${HANDLE}...`);
  const sessionRes = await fetch(
    `${BLUESKY_SERVICE}/xrpc/com.atproto.server.createSession`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identifier: HANDLE, password: PASSWORD }),
    }
  );

  if (!sessionRes.ok) {
    const err = await sessionRes.text();
    console.error(`Login failed: ${err}`);
    process.exit(1);
  }

  const session = (await sessionRes.json()) as {
    did: string;
    accessJwt: string;
  };
  console.log(`Logged in as ${session.did}`);

  const record = {
    $type: "app.bsky.feed.generator",
    did: SERVICE_DID,
    displayName: "Haikus",
    description:
      "Haiku poetry from across the Bluesky network. Posts with the brew-haiku signature are boosted.",
    createdAt: new Date().toISOString(),
  };

  console.log(`Publishing feed generator record...`);
  console.log(`  DID: ${SERVICE_DID}`);
  console.log(`  Record key: ${FEED_RKEY}`);
  console.log(`  Feed URI: at://${session.did}/app.bsky.feed.generator/${FEED_RKEY}`);

  const putRes = await fetch(
    `${BLUESKY_SERVICE}/xrpc/com.atproto.repo.putRecord`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${session.accessJwt}`,
      },
      body: JSON.stringify({
        repo: session.did,
        collection: "app.bsky.feed.generator",
        rkey: FEED_RKEY,
        record,
      }),
    }
  );

  if (!putRes.ok) {
    const err = await putRes.text();
    console.error(`Failed to publish: ${err}`);
    process.exit(1);
  }

  const result = await putRes.json();
  console.log(`Feed published successfully!`);
  console.log(`  URI: ${(result as any).uri}`);
  console.log(
    `\nUsers can now find this feed at: https://bsky.app/profile/${HANDLE}/feed/${FEED_RKEY}`
  );
}

main();
