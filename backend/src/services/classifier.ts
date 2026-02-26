import { Effect, Context, Layer } from "effect";
import { pipeline, type ZeroShotClassificationPipeline } from "@huggingface/transformers";

export class ClassifierError extends Error {
  readonly _tag = "ClassifierError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export const CATEGORY_LABELS = ["coffee", "tea", "nature", "relaxation", "morning", "evening"] as const;
export type CategoryLabel = (typeof CATEGORY_LABELS)[number];
export type CategoryScores = Record<CategoryLabel, number>;

export class ClassifierService extends Context.Tag("ClassifierService")<
  ClassifierService,
  {
    readonly classify: (text: string) => Effect.Effect<CategoryScores, ClassifierError>;
  }
>() {}

// Keyword patterns that boost coffee/tea scores
const COFFEE_KEYWORDS = /\b(coffee|espresso|latte|cappuccino|mocha|americano|macchiato|cortado|pour.?over|french.?press|aeropress|chemex|v60|moka|drip|roast|crema|grounds|barista|cafe|café)\b/i;
const TEA_KEYWORDS = /\b(tea|matcha|oolong|chamomile|earl.?grey|green.?tea|black.?tea|herbal|steep|steeping|teapot|teacup|chai|sencha|gongfu|infuse|infusion|kettle|leaves)\b/i;
const BREW_KEYWORDS = /\b(brew|brewing|brewed|steep|steeping|steeped|pour|sip|sipping|cup)\b/i;

const KEYWORD_BOOST = 0.3;

function applyKeywordBoosts(text: string, scores: CategoryScores): CategoryScores {
  const lower = text.toLowerCase();
  const boosted = { ...scores };

  if (COFFEE_KEYWORDS.test(lower)) {
    boosted.coffee = Math.min(1, boosted.coffee + KEYWORD_BOOST);
  }
  if (TEA_KEYWORDS.test(lower)) {
    boosted.tea = Math.min(1, boosted.tea + KEYWORD_BOOST);
  }
  if (BREW_KEYWORDS.test(lower)) {
    boosted.coffee = Math.min(1, boosted.coffee + KEYWORD_BOOST * 0.5);
    boosted.tea = Math.min(1, boosted.tea + KEYWORD_BOOST * 0.5);
  }

  return boosted;
}

// Lazy singleton — model loads on first classify() call
const makeClassifier = (): Effect.Effect<{
  classify: (text: string) => Effect.Effect<CategoryScores, ClassifierError>;
}> =>
  Effect.succeed({
    classify: (text: string) =>
      Effect.tryPromise({
        try: async () => {
          const classifier = await getOrLoadPipeline();
          const result = await classifier(text, [...CATEGORY_LABELS], {
            multi_label: true,
            hypothesis_template: "This poem is related to {}.",
          });

          // Build scores map from labels + scores arrays
          const output = result as {
            labels: string[];
            scores: number[];
          };
          const scores: CategoryScores = {
            coffee: 0,
            tea: 0,
            nature: 0,
            relaxation: 0,
            morning: 0,
            evening: 0,
          };
          for (let i = 0; i < output.labels.length; i++) {
            const label = output.labels[i] as CategoryLabel;
            if (label in scores) {
              scores[label] = output.scores[i];
            }
          }
          return applyKeywordBoosts(text, scores);
        },
        catch: (error) => new ClassifierError("Classification failed", error),
      }),
  });

// Pipeline singleton
let pipelineInstance: ZeroShotClassificationPipeline | null = null;
let pipelinePromise: Promise<ZeroShotClassificationPipeline> | null = null;

async function getOrLoadPipeline(): Promise<ZeroShotClassificationPipeline> {
  if (pipelineInstance) return pipelineInstance;
  if (pipelinePromise) return pipelinePromise;

  pipelinePromise = (async () => {
    console.log("Loading zero-shot classification model...");
    const instance = await pipeline(
      "zero-shot-classification",
      "Xenova/mobilebert-uncased-mnli",
      { dtype: "q8" }
    );
    console.log("Classification model loaded.");
    pipelineInstance = instance;
    return instance;
  })();

  return pipelinePromise;
}

export const ClassifierServiceLive = Layer.effect(
  ClassifierService,
  makeClassifier()
);

/** Test layer that returns zero scores without loading any model. */
export const ClassifierServiceTest = Layer.succeed(
  ClassifierService,
  {
    classify: () =>
      Effect.succeed({
        coffee: 0,
        tea: 0,
        nature: 0,
        relaxation: 0,
        morning: 0,
        evening: 0,
      } as CategoryScores),
  }
);
