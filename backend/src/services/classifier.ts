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

/** Strip non-ASCII, collapse whitespace, lowercase, truncate. */
export function cleanTextForClassifier(text: string): string | null {
  // Strip non-roman characters (keep basic latin + common punctuation)
  const cleaned = text
    .replace(/[^\x20-\x7E]/g, " ")  // replace non-printable-ASCII with space
    .replace(/\s+/g, " ")            // collapse whitespace
    .trim()
    .toLowerCase();

  // Skip if too short after cleaning or doesn't look like English
  if (cleaned.length < 10) return null;

  // Simple English heuristic: mostly ASCII letters
  const letterCount = (cleaned.match(/[a-z]/g) || []).length;
  if (letterCount / cleaned.length < 0.5) return null;

  // Truncate (haikus are short, but be safe)
  return cleaned.slice(0, 200);
}

export function applyKeywordBoosts(text: string, scores: CategoryScores): CategoryScores {
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

const ZERO_SCORES: CategoryScores = {
  coffee: 0, tea: 0, nature: 0, relaxation: 0, morning: 0, evening: 0,
};

// Load model eagerly at layer construction time
const makeClassifier = Effect.tryPromise({
  try: async () => {
    console.log("Loading zero-shot classification model...");
    const classifier = await pipeline(
      "zero-shot-classification",
      "Xenova/mobilebert-uncased-mnli",
      { dtype: "fp32" }
    );
    console.log("Classification model loaded.");

    return {
      classify: (text: string): Effect.Effect<CategoryScores, ClassifierError> => {
        const cleaned = cleanTextForClassifier(text);

        // If text doesn't pass cleaning, return keyword-only scores
        if (!cleaned) {
          return Effect.succeed(applyKeywordBoosts(text, { ...ZERO_SCORES }));
        }

        return Effect.tryPromise({
          try: async () => {
            const result = await classifier(cleaned, [...CATEGORY_LABELS], {
              multi_label: true,
              hypothesis_template: "This poem is related to {}.",
            });

            const output = result as {
              labels: string[];
              scores: number[];
            };
            const scores: CategoryScores = { ...ZERO_SCORES };
            for (let i = 0; i < output.labels.length; i++) {
              const label = output.labels[i] as CategoryLabel;
              if (label in scores) {
                scores[label] = output.scores[i];
              }
            }
            return applyKeywordBoosts(text, scores);
          },
          catch: (error) => new ClassifierError("Classification failed", error),
        });
      },
    };
  },
  catch: (error) => new ClassifierError("Failed to load classification model", error),
});

export const ClassifierServiceLive = Layer.effect(
  ClassifierService,
  makeClassifier
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
