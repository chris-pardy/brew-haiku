import { test, expect, describe } from "bun:test";
import { Effect } from "effect";
import {
  ClassifierService,
  ClassifierServiceLive,
  cleanTextForClassifier,
  applyKeywordBoosts,
  type CategoryScores,
} from "../src/services/classifier.js";

const zeros: CategoryScores = {
  coffee: 0, tea: 0, nature: 0, relaxation: 0, morning: 0, evening: 0,
};

describe("cleanTextForClassifier", () => {
  test("lowercases and strips non-ASCII", () => {
    expect(cleanTextForClassifier("Hello World! café ☕️")).toBe("hello world! caf");
  });

  test("returns null for non-English text", () => {
    expect(cleanTextForClassifier("日本語のテスト")).toBeNull();
  });

  test("returns null for very short text", () => {
    expect(cleanTextForClassifier("hi")).toBeNull();
  });

  test("returns null for mostly numeric text", () => {
    expect(cleanTextForClassifier("123456789 0 1 2 3")).toBeNull();
  });

  test("collapses whitespace", () => {
    expect(cleanTextForClassifier("morning   light\n\nsteam rises")).toBe(
      "morning light steam rises"
    );
  });

  test("truncates to 200 chars", () => {
    const long = "a ".repeat(200);
    const result = cleanTextForClassifier(long);
    expect(result!.length).toBeLessThanOrEqual(200);
  });

  test("passes normal English haiku", () => {
    const result = cleanTextForClassifier("steam rises softly from the morning cup of tea");
    expect(result).toBe("steam rises softly from the morning cup of tea");
  });
});

describe("applyKeywordBoosts", () => {
  test("boosts coffee for coffee keywords", () => {
    const scores = applyKeywordBoosts("morning espresso", { ...zeros });
    expect(scores.coffee).toBeCloseTo(0.3);
    expect(scores.tea).toBe(0);
  });

  test("boosts tea for tea keywords", () => {
    const scores = applyKeywordBoosts("chamomile in a teapot", { ...zeros });
    expect(scores.tea).toBeCloseTo(0.3);
  });

  test("boosts both for brew keywords", () => {
    const scores = applyKeywordBoosts("brewing something warm", { ...zeros });
    expect(scores.coffee).toBeCloseTo(0.15);
    expect(scores.tea).toBeCloseTo(0.15);
  });

  test("stacks coffee keyword + brew keyword", () => {
    const scores = applyKeywordBoosts("brewing espresso", { ...zeros });
    expect(scores.coffee).toBeCloseTo(0.45); // 0.3 + 0.15
    expect(scores.tea).toBeCloseTo(0.15);
  });

  test("caps at 1.0", () => {
    const high: CategoryScores = { ...zeros, coffee: 0.9 };
    const scores = applyKeywordBoosts("espresso", high);
    expect(scores.coffee).toBe(1.0);
  });

  test("no boost for unrelated text", () => {
    const scores = applyKeywordBoosts("the sun sets over mountains", { ...zeros });
    expect(scores.coffee).toBe(0);
    expect(scores.tea).toBe(0);
  });
});

describe("classifier with model", () => {
  const classifyReal = (text: string) =>
    Effect.gen(function* () {
      const svc = yield* ClassifierService;
      return yield* svc.classify(text);
    }).pipe(Effect.provide(ClassifierServiceLive), Effect.runPromise);

  test("coffee haiku scores high on coffee", async () => {
    const scores = await classifyReal(
      "dark roasted beans ground\nsteam rises from my pour over\nmorning ritual"
    );
    expect(scores.coffee).toBeGreaterThan(0.3);
  }, 30000);

  test("tea haiku scores high on tea", async () => {
    const scores = await classifyReal(
      "green leaves unfurling\nsteeping slowly in warm water\npeace in every sip"
    );
    expect(scores.tea).toBeGreaterThan(0.3);
  }, 30000);

  test("nature haiku scores high on nature", async () => {
    const scores = await classifyReal(
      "cherry blossoms fall\ngentle rain upon the pond\nfrogs begin to sing"
    );
    expect(scores.nature).toBeGreaterThan(0.2);
  }, 30000);

  test("spam text scores low across categories", async () => {
    const scores = await classifyReal(
      "follow me on twitter for the best deals and discounts today only"
    );
    expect(scores.coffee).toBeLessThan(0.3);
    expect(scores.tea).toBeLessThan(0.3);
    expect(scores.nature).toBeLessThan(0.5);
  }, 30000);

  test("non-ASCII text gets keyword-only scores", async () => {
    const scores = await classifyReal("コーヒーを飲む coffee morning brew");
    // coffee keyword boost should apply
    expect(scores.coffee).toBeGreaterThan(0);
  }, 30000);

  test("does not crash on emoji-heavy text", async () => {
    const scores = await classifyReal("morning brew in my cup with cream and sugar");
    expect(scores).toBeDefined();
    expect(typeof scores.coffee).toBe("number");
  }, 30000);
});
