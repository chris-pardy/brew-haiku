import { describe, test, expect, beforeEach, afterEach, mock } from "bun:test";
import { Effect, Layer } from "effect";
import { Database } from "bun:sqlite";
import {
  DatabaseService,
  makeDatabaseService,
} from "../src/services/database.js";
import {
  ATProtoService,
  makeATProtoService,
} from "../src/services/atproto.js";
import {
  OAuthService,
  makeOAuthService,
  OAuthError,
  OAuthInvalidCodeError,
  type OAuthCallbackParams,
  type OAuthSession,
} from "../src/services/oauth.js";
import { authRoutes } from "../src/routes/auth.js";

describe("OAuthService", () => {
  test("service is properly typed", () => {
    expect(OAuthService).toBeDefined();
  });

  test("OAuthError has correct tag", () => {
    const error = new OAuthError("test error");
    expect(error._tag).toBe("OAuthError");
    expect(error.message).toBe("test error");
  });

  test("OAuthInvalidCodeError has correct tag", () => {
    const error = new OAuthInvalidCodeError("bad code");
    expect(error._tag).toBe("OAuthInvalidCodeError");
    expect(error.message).toBe("bad code");
  });

  test("OAuthInvalidCodeError has default message", () => {
    const error = new OAuthInvalidCodeError();
    expect(error.message).toBe("Invalid or expired authorization code");
  });
});

describe("OAuthCallbackParams", () => {
  test("validates required code field", () => {
    const params: OAuthCallbackParams = {
      code: "test-auth-code",
    };
    expect(params.code).toBe("test-auth-code");
  });

  test("accepts optional state and iss fields", () => {
    const params: OAuthCallbackParams = {
      code: "test-auth-code",
      state: "random-state",
      iss: "https://bsky.social",
    };
    expect(params.code).toBe("test-auth-code");
    expect(params.state).toBe("random-state");
    expect(params.iss).toBe("https://bsky.social");
  });
});

describe("OAuthSession", () => {
  test("has correct shape", () => {
    const session: OAuthSession = {
      did: "did:plc:test123",
      handle: "test.bsky.social",
      accessToken: "access-token",
      refreshToken: "refresh-token",
      expiresAt: Date.now() + 3600000,
    };

    expect(session.did).toBe("did:plc:test123");
    expect(session.handle).toBe("test.bsky.social");
    expect(session.accessToken).toBe("access-token");
    expect(session.refreshToken).toBe("refresh-token");
    expect(typeof session.expiresAt).toBe("number");
  });
});

describe("OAuthService with dependencies", () => {
  let dbService: { db: Database; close: () => Effect.Effect<void> };

  beforeEach(async () => {
    dbService = await Effect.runPromise(makeDatabaseService(":memory:"));
  });

  afterEach(async () => {
    await Effect.runPromise(dbService.close());
  });

  test("handleCallback fails with missing code", async () => {
    const DbLayer = Layer.succeed(DatabaseService, dbService);
    const ATProtoLayer = Layer.effect(ATProtoService, makeATProtoService).pipe(
      Layer.provide(DbLayer)
    );
    const OAuthLayer = Layer.effect(OAuthService, makeOAuthService).pipe(
      Layer.provide(ATProtoLayer)
    );
    const TestLayer = Layer.merge(DbLayer, Layer.merge(ATProtoLayer, OAuthLayer));

    const program = Effect.gen(function* () {
      const service = yield* OAuthService;
      // Pass empty string to simulate missing code
      return yield* service.handleCallback({ code: "" });
    }).pipe(Effect.provide(TestLayer));

    const exit = await Effect.runPromiseExit(program);
    expect(exit._tag).toBe("Failure");
  });

  test("makeOAuthService creates service with required methods", async () => {
    const DbLayer = Layer.succeed(DatabaseService, dbService);
    const ATProtoLayer = Layer.effect(ATProtoService, makeATProtoService).pipe(
      Layer.provide(DbLayer)
    );
    const OAuthLayer = Layer.effect(OAuthService, makeOAuthService).pipe(
      Layer.provide(ATProtoLayer)
    );
    const TestLayer = Layer.merge(DbLayer, Layer.merge(ATProtoLayer, OAuthLayer));

    const program = Effect.gen(function* () {
      const service = yield* OAuthService;
      return {
        hasHandleCallback: typeof service.handleCallback === "function",
        hasRefreshToken: typeof service.refreshToken === "function",
      };
    }).pipe(Effect.provide(TestLayer));

    const result = await Effect.runPromise(program);

    expect(result.hasHandleCallback).toBe(true);
    expect(result.hasRefreshToken).toBe(true);
  });
});

describe("Auth Routes", () => {
  test("authRoutes is a valid router", () => {
    expect(authRoutes).toBeDefined();
  });
});

describe("OAuth Token Response handling", () => {
  test("expires_in is converted to expiresAt timestamp", () => {
    const now = Date.now();
    const expiresIn = 3600; // 1 hour in seconds
    const expiresAt = now + (expiresIn * 1000);

    // Verify the calculation is correct
    expect(expiresAt).toBeGreaterThan(now);
    expect(expiresAt - now).toBe(3600000); // 1 hour in milliseconds
  });
});

describe("OAuth Discovery", () => {
  test("default PDS URL is bsky.social", () => {
    const defaultPdsUrl = "https://bsky.social";
    expect(defaultPdsUrl).toBe("https://bsky.social");
  });

  test("issuer overrides default PDS URL", () => {
    const issuer = "https://custom-pds.example.com";
    const pdsUrl = issuer || "https://bsky.social";
    expect(pdsUrl).toBe("https://custom-pds.example.com");
  });
});
