import { Effect, Context, Layer } from "effect";
import crypto from "node:crypto";

// --- Error types ---

export class OAuthLoginError extends Error {
  readonly _tag = "OAuthLoginError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export class OAuthCallbackError extends Error {
  readonly _tag = "OAuthCallbackError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

// --- OAuth configuration ---

const CLIENT_ID =
  process.env.OAUTH_CLIENT_ID || "https://brew-haiku.app/oauth/client-metadata.json";
const REDIRECT_URI =
  process.env.OAUTH_REDIRECT_URI || "https://brew-haiku.app/oauth/callback";
const MOBILE_REDIRECT = "brew-haiku://oauth/callback";

const CLIENT_METADATA = {
  client_id: CLIENT_ID,
  client_name: "Brew Haiku",
  client_uri: "https://brew-haiku.app",
  logo_uri: "https://brew-haiku.app/icon.png",
  redirect_uris: [MOBILE_REDIRECT, REDIRECT_URI],
  grant_types: ["authorization_code", "refresh_token"],
  response_types: ["code"],
  scope: "atproto transition:generic",
  token_endpoint_auth_method: "none",
  application_type: "native",
  dpop_bound_access_tokens: false,
};

// --- PKCE helpers ---

function generateCodeVerifier(): string {
  return crypto.randomBytes(32).toString("base64url");
}

function generateCodeChallenge(verifier: string): string {
  return crypto.createHash("sha256").update(verifier).digest("base64url");
}

function generateState(): string {
  return crypto.randomBytes(16).toString("base64url");
}

// --- In-memory PKCE state ---

interface PendingAuth {
  handle: string;
  codeVerifier: string;
  tokenEndpoint: string;
  createdAt: number;
}

// --- ATProto discovery ---

interface AuthServerMetadata {
  authorization_endpoint: string;
  token_endpoint: string;
  pushed_authorization_request_endpoint?: string;
}

const resolveHandleToPds = async (handle: string): Promise<string> => {
  const resolveRes = await fetch(
    `https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=${encodeURIComponent(handle)}`
  );
  if (!resolveRes.ok) throw new Error(`Handle not found: ${handle}`);
  const { did } = (await resolveRes.json()) as { did: string };

  const plcRes = await fetch(`https://plc.directory/${did}`);
  if (!plcRes.ok) throw new Error(`Could not resolve DID: ${did}`);
  const doc = (await plcRes.json()) as {
    service?: Array<{ id: string; serviceEndpoint: string }>;
  };
  const pds = doc.service?.find((s) => s.id === "#atproto_pds");
  if (!pds) throw new Error(`No PDS found for DID: ${did}`);
  return pds.serviceEndpoint;
};

const discoverAuthServer = async (pdsUrl: string): Promise<AuthServerMetadata> => {
  const prRes = await fetch(`${pdsUrl}/.well-known/oauth-protected-resource`);
  if (!prRes.ok) throw new Error("Could not discover auth server from PDS");
  const pr = (await prRes.json()) as { authorization_servers?: string[] };
  const authServerUrl = pr.authorization_servers?.[0];
  if (!authServerUrl) throw new Error("No authorization server found");

  const asRes = await fetch(
    `${authServerUrl}/.well-known/oauth-authorization-server`
  );
  if (!asRes.ok) throw new Error("Could not fetch auth server metadata");
  return asRes.json() as Promise<AuthServerMetadata>;
};

// --- Service definition ---

export class OAuthGatewayService extends Context.Tag("OAuthGatewayService")<
  OAuthGatewayService,
  {
    readonly clientMetadata: () => Effect.Effect<typeof CLIENT_METADATA>;
    readonly initiateLogin: (
      handle: string
    ) => Effect.Effect<string, OAuthLoginError>;
    readonly handleCallback: (
      code: string,
      state: string
    ) => Effect.Effect<string, OAuthCallbackError>;
  }
>() {}

// --- Service implementation ---

export const makeOAuthGatewayService = Effect.sync(() => {
  const pendingAuths = new Map<string, PendingAuth>();

  // Clean stale entries every 60s
  setInterval(() => {
    const cutoff = Date.now() - 10 * 60 * 1000;
    for (const [key, val] of pendingAuths) {
      if (val.createdAt < cutoff) pendingAuths.delete(key);
    }
  }, 60_000);

  const clientMetadata = () => Effect.succeed(CLIENT_METADATA);

  const initiateLogin = (
    handle: string
  ): Effect.Effect<string, OAuthLoginError> =>
    Effect.tryPromise({
      try: async () => {
        const pdsUrl = await resolveHandleToPds(handle);
        const metadata = await discoverAuthServer(pdsUrl);

        if (!metadata.pushed_authorization_request_endpoint) {
          throw new Error("Auth server does not support PAR");
        }

        const codeVerifier = generateCodeVerifier();
        const codeChallenge = generateCodeChallenge(codeVerifier);
        const state = generateState();

        // Pushed Authorization Request
        const parParams = new URLSearchParams({
          response_type: "code",
          client_id: CLIENT_ID,
          redirect_uri: REDIRECT_URI,
          scope: "atproto transition:generic",
          state,
          code_challenge: codeChallenge,
          code_challenge_method: "S256",
          login_hint: handle,
        });

        const parRes = await fetch(
          metadata.pushed_authorization_request_endpoint,
          {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: parParams.toString(),
          }
        );

        if (!parRes.ok) {
          const errBody = await parRes.text();
          throw new Error(`PAR failed (${parRes.status}): ${errBody}`);
        }

        const { request_uri } = (await parRes.json()) as { request_uri: string };

        // Store PKCE state
        pendingAuths.set(state, {
          handle,
          codeVerifier,
          tokenEndpoint: metadata.token_endpoint,
          createdAt: Date.now(),
        });

        // Build authorization URL
        const authUrl = new URL(metadata.authorization_endpoint);
        authUrl.searchParams.set("client_id", CLIENT_ID);
        authUrl.searchParams.set("request_uri", request_uri);

        return authUrl.toString();
      },
      catch: (e) =>
        new OAuthLoginError(
          e instanceof Error ? e.message : "Login failed",
          e
        ),
    });

  const handleCallback = (
    code: string,
    state: string
  ): Effect.Effect<string, OAuthCallbackError> =>
    Effect.tryPromise({
      try: async () => {
        const pending = pendingAuths.get(state);
        if (!pending) {
          throw new Error("Login session expired. Please try again.");
        }
        pendingAuths.delete(state);

        // Exchange code for tokens with PKCE verifier
        const tokenParams = new URLSearchParams({
          grant_type: "authorization_code",
          code,
          redirect_uri: REDIRECT_URI,
          client_id: CLIENT_ID,
          code_verifier: pending.codeVerifier,
        });

        const tokenRes = await fetch(pending.tokenEndpoint, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: tokenParams.toString(),
        });

        if (!tokenRes.ok) {
          const errBody = await tokenRes.text();
          throw new Error(
            `Token exchange failed (${tokenRes.status}): ${errBody}`
          );
        }

        const tokens = (await tokenRes.json()) as {
          access_token: string;
          refresh_token: string;
          expires_in: number;
          sub: string;
        };

        // Resolve DID to get handle
        let handle = pending.handle;
        try {
          const plcRes = await fetch(`https://plc.directory/${tokens.sub}`);
          if (plcRes.ok) {
            const doc = (await plcRes.json()) as {
              alsoKnownAs?: string[];
            };
            const aka = doc.alsoKnownAs?.[0];
            if (aka) handle = aka.replace("at://", "");
          }
        } catch {
          // Keep the input handle
        }

        const expiresAt = Date.now() + tokens.expires_in * 1000;

        // Build redirect URL with session data
        const params = new URLSearchParams({
          did: tokens.sub,
          handle,
          accessToken: tokens.access_token,
          refreshToken: tokens.refresh_token,
          expiresAt: String(expiresAt),
        });

        return `${MOBILE_REDIRECT}?${params.toString()}`;
      },
      catch: (e) =>
        new OAuthCallbackError(
          e instanceof Error ? e.message : "Callback failed",
          e
        ),
    });

  return { clientMetadata, initiateLogin, handleCallback };
});

export const OAuthGatewayServiceLive = Layer.effect(
  OAuthGatewayService,
  makeOAuthGatewayService
);
