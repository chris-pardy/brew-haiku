import { test, expect, describe } from "bun:test";
import { Effect } from "effect";
import {
  ClassifierService,
  ClassifierServiceLive,
  tokenize,
  type CategoryScores,
} from "../src/services/classifier.js";

const classify = (text: string) =>
  Effect.gen(function* () {
    const svc = yield* ClassifierService;
    return yield* svc.classify(text);
  }).pipe(Effect.provide(ClassifierServiceLive), Effect.runPromise);

describe("tokenize", () => {
  test("lowercases and splits on non-alpha", () => {
    expect(tokenize("Hello World!")).toEqual(["hello", "world"]);
  });

  test("deduplicates tokens", () => {
    expect(tokenize("tea tea tea")).toEqual(["tea"]);
  });

  test("filters empty strings", () => {
    expect(tokenize("  ")).toEqual([]);
  });

  test("splits on punctuation and numbers", () => {
    expect(tokenize("cup-of-coffee 3pm")).toEqual(["cup", "of", "coffee", "pm"]);
  });
});

describe("word-list classifier", () => {
  test("coffee haiku scores highest on coffee", async () => {
    const scores = await classify(
      "dark roasted beans ground\nsteam rises from my pour over\nmorning ritual"
    );
    expect(scores.coffee).toBeGreaterThan(0);
    expect(scores.coffee).toBeGreaterThan(scores.nature);
    expect(scores.coffee).toBeGreaterThan(scores.evening);
  });

  test("tea haiku scores highest on tea", async () => {
    const scores = await classify(
      "green leaves unfurling\nsteeping slowly in warm water\npeace in every sip"
    );
    expect(scores.tea).toBeGreaterThan(0);
    expect(scores.tea).toBeGreaterThan(scores.coffee);
  });

  test("nature haiku scores on nature", async () => {
    const scores = await classify(
      "cherry blossoms fall\ngentle rain upon the pond\nfrogs begin to sing"
    );
    expect(scores.nature).toBeGreaterThan(0);
    expect(scores.nature).toBeGreaterThan(scores.coffee);
    expect(scores.nature).toBeGreaterThan(scores.tea);
  });

  test("morning haiku scores on morning", async () => {
    const scores = await classify(
      "dawn breaks the silence\nfirst light on dewy meadow\nbirds begin to sing"
    );
    expect(scores.morning).toBeGreaterThan(0);
    expect(scores.morning).toBeGreaterThan(scores.afternoon);
    expect(scores.morning).toBeGreaterThan(scores.evening);
  });

  test("evening haiku scores on evening", async () => {
    const scores = await classify(
      "moonlight on the lake\ncrickets sing their evening song\nstars fill the dark sky"
    );
    expect(scores.evening).toBeGreaterThan(0);
    expect(scores.evening).toBeGreaterThan(scores.morning);
    expect(scores.evening).toBeGreaterThan(scores.afternoon);
  });

  test("afternoon haiku scores on afternoon", async () => {
    const scores = await classify(
      "lazy afternoon\nsunlight streams through shaded porch\nsiesta beckons"
    );
    expect(scores.afternoon).toBeGreaterThan(0);
    expect(scores.afternoon).toBeGreaterThan(scores.morning);
  });

  test("relaxation haiku scores on relaxation", async () => {
    const scores = await classify(
      "gentle breeze whispers\npeaceful silence fills the room\nbreathing slow and calm"
    );
    expect(scores.relaxation).toBeGreaterThan(0);
    expect(scores.relaxation).toBeGreaterThan(scores.coffee);
  });

  test("unrelated text scores near zero", async () => {
    const scores = await classify(
      "follow me on twitter for the best deals and discounts today only"
    );
    for (const label of Object.keys(scores) as (keyof CategoryScores)[]) {
      expect(scores[label]).toBeLessThan(0.15);
    }
  });

  test("empty text returns all zeros", async () => {
    const scores = await classify("");
    for (const label of Object.keys(scores) as (keyof CategoryScores)[]) {
      expect(scores[label]).toBe(0);
    }
  });

  test("scores are between 0 and 1", async () => {
    const scores = await classify(
      "coffee espresso latte brew roast grind bean dark rich smooth cream"
    );
    for (const label of Object.keys(scores) as (keyof CategoryScores)[]) {
      expect(scores[label]).toBeGreaterThanOrEqual(0);
      expect(scores[label]).toBeLessThanOrEqual(1);
    }
  });
});
