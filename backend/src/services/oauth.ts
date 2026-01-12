import { Effect, Context, Layer } from "effect";
import { ATProtoService, ATProtoError } from "./atproto.js";

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

// DPoP (Demonstrating Proof of Possession) is required for ATProto OAuth
// For now, we implement a simplified flow that works with the Bluesky PDS
// Full DPoP implementation would require crypto key generation and JWT signing

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

  // Add client_secret if configured (some PDS implementations require it)
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

// Discover the authorization server metadata to find the token endpoint
const discoverTokenEndpoint = async (pdsUrl: string): Promise<string> => {
  // Try OAuth Authorization Server Metadata discovery
  try {
    const metadataUrl = `${pdsUrl}/.well-known/oauth-authorization-server`;
    const response = await fetch(metadataUrl);
    if (response.ok) {
      const metadata = await response.json();
      if (metadata.token_endpoint) {
        return metadata.token_endpoint;
      }
    }
  } catch {
    // Fall through to default
  }

  // Default to standard ATProto token endpoint
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

      // Determine the PDS URL from the issuer or use default
      let pdsUrl = "https://bsky.social";

      if (iss) {
        // The issuer should be the PDS URL
        pdsUrl = iss;
      }

      // Discover the token endpoint
      const tokenEndpoint = yield* Effect.tryPromise({
        try: () => discoverTokenEndpoint(pdsUrl),
        catch: (e) => new OAuthError("Failed to discover token endpoint", e),
      });

      // Exchange authorization code for tokens
      const tokenResponse = yield* Effect.tryPromise({
        try: () => exchangeCodeForTokens(code, tokenEndpoint),
        catch: (e) => {
          if (e instanceof OAuthError) return e;
          return new OAuthInvalidCodeError("Failed to exchange authorization code");
        },
      });

      // Get the user's DID from the token response
      const did = tokenResponse.sub;

      // Resolve the handle from the DID
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
      // Resolve the DID to get the PDS URL
      const resolvedDID = yield* atprotoService.resolveDID(did).pipe(
        Effect.catchTag("HandleNotFoundError", () =>
          Effect.fail(new OAuthError("Could not resolve DID to find PDS"))
        ),
        Effect.catchTag("ATProtoError", (e) =>
          Effect.fail(new OAuthError("Failed to resolve DID", e))
        )
      );

      const pdsUrl = resolvedDID.pdsUrl;

      // Discover the token endpoint
      const tokenEndpoint = yield* Effect.tryPromise({
        try: () => discoverTokenEndpoint(pdsUrl),
        catch: (e) => new OAuthError("Failed to discover token endpoint", e),
      });

      // Refresh the token
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

  return { handleCallback, refreshToken };
});

export const OAuthServiceLive = Layer.effect(OAuthService, makeOAuthService);
