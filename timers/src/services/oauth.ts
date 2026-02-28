import { Effect, Context, Layer } from "effect";
import { ATProtoService, ATProtoError } from "./atproto.js";
import crypto from "node:crypto";

export class OAuthError extends Error {
  readonly _tag = "OAuthError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export class OAuthInvalidCodeError extends Error {
  readonly _tag = "OAuthInvalidCodeError";
  constructor(message: string = "Invalid or expired authorization code") {
    super(message);
  }
}

export interface OAuthCallbackParams {
  code: string;
  state?: string;
  iss?: string;
}

export interface OAuthTokenResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  scope: string;
  sub: string;
}

export interface OAuthSession {
  did: string;
  handle: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

export interface LoginInitResult {
  authorizationUrl: string;
  state: string;
}

export class OAuthService extends Context.Tag("OAuthService")<
  OAuthService,
  {
    readonly handleCallback: (
      params: OAuthCallbackParams
    ) => Effect.Effect<OAuthSession, OAuthError | OAuthInvalidCodeError>;
    readonly refreshToken: (
      refreshToken: string,
      did: string
    ) => Effect.Effect<OAuthSession, OAuthError | OAuthInvalidCodeError>;
    readonly initiateLogin: (
      handle: string
    ) => Effect.Effect<LoginInitResult, OAuthError>;
    readonly handleWebCallback: (
      code: string,
      state: string,
      iss?: string
    ) => Effect.Effect<OAuthSession, OAuthError | OAuthInvalidCodeError>;
  }
>() {}

// Client configuration (should be from environment in production)
const CLIENT_ID = process.env.OAUTH_CLIENT_ID || "https://brew-haiku.app/oauth/client-metadata.json";
const CLIENT_SECRET = process.env.OAUTH_CLIENT_SECRET || "";
const REDIRECT_URI = process.env.OAUTH_REDIRECT_URI || "https://brew-haiku.app/oauth/callback";

interface TokenEndpointResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  scope: string;
  sub: string;
}

const exchangeCodeForTokens = async (
  code: string,
  tokenEndpoint: string
): Promise<TokenEndpointResponse> => {
  const params = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
  });

  if (CLIENT_SECRET) {
    params.append("client_secret", CLIENT_SECRET);
  }

  const response = await fetch(tokenEndpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new OAuthError(`Token exchange failed: ${response.status} - ${error}`);
  }

  return response.json();
};

const refreshAccessToken = async (
  refreshToken: string,
  tokenEndpoint: string
): Promise<TokenEndpointResponse> => {
  const params = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: CLIENT_ID,
  });

  if (CLIENT_SECRET) {
    params.append("client_secret", CLIENT_SECRET);
  }

  const response = await fetch(tokenEndpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new OAuthError(`Token refresh failed: ${response.status} - ${error}`);
  }

  return response.json();
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

// --- In-memory state for PKCE (short-lived, login flow only) ---
interface PendingAuth {
  handle: string;
  codeVerifier: string;
  pdsUrl: string;
  authServer: string;
  createdAt: number;
}

const pendingAuths = new Map<string, PendingAuth>();

// Clean up stale entries (older than 10 minutes)
setInterval(() => {
  const cutoff = Date.now() - 10 * 60 * 1000;
  for (const [key, val] of pendingAuths) {
    if (val.createdAt < cutoff) pendingAuths.delete(key);
  }
}, 60_000);

// --- Auth server discovery (PDS → protected resource → auth server) ---
interface AuthServerMetadata {
  authorization_endpoint: string;
  token_endpoint: string;
  pushed_authorization_request_endpoint?: string;
}

const discoverAuthServer = async (
  pdsUrl: string
): Promise<{ authServerUrl: string; metadata: AuthServerMetadata }> => {
  // Step 1: Get the authorization server URL from the PDS
  const prResponse = await fetch(
    `${pdsUrl}/.well-known/oauth-protected-resource`
  );
  if (!prResponse.ok) {
    throw new OAuthError("Could not discover authorization server from PDS");
  }
  const prData = await prResponse.json();
  const servers = prData.authorization_servers as string[] | undefined;
  if (!servers || servers.length === 0) {
    throw new OAuthError("No authorization server found for PDS");
  }
  const authServerUrl = servers[0];

  // Step 2: Get the auth server's OAuth metadata
  const asResponse = await fetch(
    `${authServerUrl}/.well-known/oauth-authorization-server`
  );
  if (!asResponse.ok) {
    throw new OAuthError("Could not fetch authorization server metadata");
  }
  const metadata = (await asResponse.json()) as AuthServerMetadata;

  return { authServerUrl, metadata };
};

const discoverTokenEndpoint = async (pdsUrl: string): Promise<string> => {
  try {
    const { metadata } = await discoverAuthServer(pdsUrl);
    if (metadata.token_endpoint) {
      return metadata.token_endpoint;
    }
  } catch {
    // Fall through to default
  }

  return `${pdsUrl}/xrpc/com.atproto.server.createSession`;
};

export const makeOAuthService = Effect.gen(function* () {
  const atprotoService = yield* ATProtoService;

  const handleCallback = (
    params: OAuthCallbackParams
  ): Effect.Effect<OAuthSession, OAuthError | OAuthInvalidCodeError> =>
    Effect.gen(function* () {
      const { code, iss } = params;

      if (!code) {
        return yield* Effect.fail(new OAuthInvalidCodeError("Missing authorization code"));
      }

      let pdsUrl = "https://bsky.social";
      if (iss) {
        pdsUrl = iss;
      }

      const tokenEndpoint = yield* Effect.tryPromise({
        try: () => discoverTokenEndpoint(pdsUrl),
        catch: (e) => new OAuthError("Failed to discover token endpoint", e),
      });

      const tokenResponse = yield* Effect.tryPromise({
        try: () => exchangeCodeForTokens(code, tokenEndpoint),
        catch: (e) => {
          if (e instanceof OAuthError) return e;
          return new OAuthInvalidCodeError("Failed to exchange authorization code");
        },
      });

      const did = tokenResponse.sub;

      const resolvedDID = yield* atprotoService.resolveDID(did).pipe(
        Effect.catchAll((e) =>
          Effect.succeed({ did, handle: did, pdsUrl, publicKey: null })
        )
      );

      const expiresAt = Date.now() + (tokenResponse.expires_in * 1000);

      return {
        did,
        handle: resolvedDID.handle,
        accessToken: tokenResponse.access_token,
        refreshToken: tokenResponse.refresh_token,
        expiresAt,
      };
    });

  const refreshToken = (
    token: string,
    did: string
  ): Effect.Effect<OAuthSession, OAuthError | OAuthInvalidCodeError> =>
    Effect.gen(function* () {
      const resolvedDID = yield* atprotoService.resolveDID(did).pipe(
        Effect.catchTag("HandleNotFoundError", () =>
          Effect.fail(new OAuthError("Could not resolve DID to find PDS"))
        ),
        Effect.catchTag("ATProtoError", (e) =>
          Effect.fail(new OAuthError("Failed to resolve DID", e))
        )
      );

      const pdsUrl = resolvedDID.pdsUrl;

      const tokenEndpoint = yield* Effect.tryPromise({
        try: () => discoverTokenEndpoint(pdsUrl),
        catch: (e) => new OAuthError("Failed to discover token endpoint", e),
      });

      const tokenResponse = yield* Effect.tryPromise({
        try: () => refreshAccessToken(token, tokenEndpoint),
        catch: (e) => {
          if (e instanceof OAuthError) return e;
          return new OAuthInvalidCodeError("Failed to refresh token");
        },
      });

      const expiresAt = Date.now() + (tokenResponse.expires_in * 1000);

      return {
        did,
        handle: resolvedDID.handle,
        accessToken: tokenResponse.access_token,
        refreshToken: tokenResponse.refresh_token,
        expiresAt,
      };
    });

  const initiateLogin = (
    handle: string
  ): Effect.Effect<LoginInitResult, OAuthError> =>
    Effect.gen(function* () {
      // Resolve handle to get PDS URL
      const resolved = yield* atprotoService.resolveHandle(handle).pipe(
        Effect.catchAll((e) =>
          Effect.fail(new OAuthError(`Could not resolve handle: ${e.message}`))
        )
      );

      // Discover auth server and its metadata
      const { metadata } = yield* Effect.tryPromise({
        try: () => discoverAuthServer(resolved.pdsUrl),
        catch: (e) =>
          new OAuthError("Failed to discover auth server", e),
      });

      const parEndpoint = metadata.pushed_authorization_request_endpoint;
      if (!parEndpoint) {
        return yield* Effect.fail(
          new OAuthError("Authorization server does not support PAR")
        );
      }

      // Generate PKCE
      const codeVerifier = generateCodeVerifier();
      const codeChallenge = generateCodeChallenge(codeVerifier);
      const state = generateState();

      // Push Authorization Request
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

      const parResponse = yield* Effect.tryPromise({
        try: async () => {
          const res = await fetch(parEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: parParams.toString(),
          });
          if (!res.ok) {
            const errBody = await res.text();
            throw new Error(
              `PAR failed (${res.status}): ${errBody}`
            );
          }
          return res.json() as Promise<{ request_uri: string; expires_in: number }>;
        },
        catch: (e) => new OAuthError(`PAR request failed: ${e}`),
      });

      // Store state for callback
      pendingAuths.set(state, {
        handle,
        codeVerifier,
        pdsUrl: resolved.pdsUrl,
        authServer: metadata.token_endpoint,
        createdAt: Date.now(),
      });

      // Build authorization URL
      const authUrl = new URL(metadata.authorization_endpoint);
      authUrl.searchParams.set("client_id", CLIENT_ID);
      authUrl.searchParams.set("request_uri", parResponse.request_uri);

      return { authorizationUrl: authUrl.toString(), state };
    });

  const handleWebCallback = (
    code: string,
    state: string,
    iss?: string
  ): Effect.Effect<OAuthSession, OAuthError | OAuthInvalidCodeError> =>
    Effect.gen(function* () {
      const pending = pendingAuths.get(state);
      if (!pending) {
        return yield* Effect.fail(
          new OAuthInvalidCodeError("Invalid or expired login state")
        );
      }
      pendingAuths.delete(state);

      // Exchange code with PKCE verifier
      const params = new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: REDIRECT_URI,
        client_id: CLIENT_ID,
        code_verifier: pending.codeVerifier,
      });

      if (CLIENT_SECRET) {
        params.append("client_secret", CLIENT_SECRET);
      }

      const tokenResponse = yield* Effect.tryPromise({
        try: async () => {
          const res = await fetch(pending.authServer, {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: params.toString(),
          });
          if (!res.ok) {
            const errBody = await res.text();
            throw new OAuthError(
              `Token exchange failed (${res.status}): ${errBody}`
            );
          }
          return res.json() as Promise<TokenEndpointResponse>;
        },
        catch: (e) => {
          if (e instanceof OAuthError) return e;
          return new OAuthInvalidCodeError(
            "Failed to exchange authorization code"
          );
        },
      });

      const did = tokenResponse.sub;

      const resolvedDID = yield* atprotoService.resolveDID(did).pipe(
        Effect.catchAll(() =>
          Effect.succeed({
            did,
            handle: pending.handle,
            pdsUrl: pending.pdsUrl,
            publicKey: null,
          })
        )
      );

      const expiresAt = Date.now() + tokenResponse.expires_in * 1000;

      return {
        did,
        handle: resolvedDID.handle,
        accessToken: tokenResponse.access_token,
        refreshToken: tokenResponse.refresh_token,
        expiresAt,
      };
    });

  return { handleCallback, refreshToken, initiateLogin, handleWebCallback };
});

export const OAuthServiceLive = Layer.effect(OAuthService, makeOAuthService);
