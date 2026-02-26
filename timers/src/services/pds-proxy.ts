import { Effect, Context, Layer } from "effect";
import type { AuthInfo } from "./auth-middleware.js";

export class PDSProxyError extends Error {
  readonly _tag = "PDSProxyError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export class RecordAlreadyExistsError extends Error {
  readonly _tag = "RecordAlreadyExistsError";
  constructor(public readonly uri?: string) {
    super("Record already exists");
  }
}

export class RecordNotFoundError extends Error {
  readonly _tag = "RecordNotFoundError";
  constructor(public readonly uri?: string) {
    super("Record not found");
  }
}

export interface CreateRecordResult {
  uri: string;
  cid: string;
}

export class PDSProxyService extends Context.Tag("PDSProxyService")<
  PDSProxyService,
  {
    readonly createRecord: (
      auth: AuthInfo,
      collection: string,
      record: Record<string, unknown>,
      rkey?: string
    ) => Effect.Effect<CreateRecordResult, PDSProxyError | RecordAlreadyExistsError>;
    readonly deleteRecord: (
      auth: AuthInfo,
      collection: string,
      rkey: string
    ) => Effect.Effect<void, PDSProxyError | RecordNotFoundError>;
  }
>() {}

export const makePDSProxyService = Effect.succeed({
  createRecord: (
    auth: AuthInfo,
    collection: string,
    record: Record<string, unknown>,
    rkey?: string
  ): Effect.Effect<CreateRecordResult, PDSProxyError | RecordAlreadyExistsError> =>
    Effect.tryPromise({
      try: async () => {
        const body: Record<string, unknown> = {
          repo: auth.did,
          collection,
          record,
        };
        if (rkey) {
          body.rkey = rkey;
        }

        const response = await fetch(
          `${auth.pdsUrl}/xrpc/com.atproto.repo.createRecord`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${auth.accessToken}`,
            },
            body: JSON.stringify(body),
          }
        );

        if (!response.ok) {
          const errorBody = await response.text();
          // PDS returns "RecordAlreadyExists" or similar when duplicate
          if (
            response.status === 400 &&
            (errorBody.includes("already exists") ||
              errorBody.includes("RecordAlreadyExists") ||
              errorBody.includes("duplicate"))
          ) {
            throw new RecordAlreadyExistsError();
          }
          throw new PDSProxyError(
            `PDS createRecord failed (${response.status}): ${errorBody}`
          );
        }

        const data = await response.json();
        return { uri: data.uri as string, cid: data.cid as string };
      },
      catch: (error) => {
        if (error instanceof RecordAlreadyExistsError) return error;
        if (error instanceof PDSProxyError) return error;
        return new PDSProxyError("Failed to create record on PDS", error);
      },
    }),

  deleteRecord: (
    auth: AuthInfo,
    collection: string,
    rkey: string
  ): Effect.Effect<void, PDSProxyError | RecordNotFoundError> =>
    Effect.tryPromise({
      try: async () => {
        const response = await fetch(
          `${auth.pdsUrl}/xrpc/com.atproto.repo.deleteRecord`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${auth.accessToken}`,
            },
            body: JSON.stringify({
              repo: auth.did,
              collection,
              rkey,
            }),
          }
        );

        if (!response.ok) {
          const errorBody = await response.text();
          if (
            response.status === 400 &&
            (errorBody.includes("not found") ||
              errorBody.includes("RecordNotFound") ||
              errorBody.includes("Could not locate record"))
          ) {
            throw new RecordNotFoundError();
          }
          throw new PDSProxyError(
            `PDS deleteRecord failed (${response.status}): ${errorBody}`
          );
        }
      },
      catch: (error) => {
        if (error instanceof RecordNotFoundError) return error;
        if (error instanceof PDSProxyError) return error;
        return new PDSProxyError("Failed to delete record on PDS", error);
      },
    }),
});

export const PDSProxyServiceLive = Layer.effect(
  PDSProxyService,
  makePDSProxyService
);
