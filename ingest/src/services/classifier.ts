import { Effect, Context, Layer } from "effect";

export class ClassifierError extends Error {
  readonly _tag = "ClassifierError";
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
  }
}

export const CATEGORY_LABELS = [
  "coffee", "tea", "nature", "relaxation", "morning", "afternoon", "evening",
] as const;
export type CategoryLabel = (typeof CATEGORY_LABELS)[number];
export type CategoryScores = Record<CategoryLabel, number>;

export class ClassifierService extends Context.Tag("ClassifierService")<
  ClassifierService,
  {
    readonly classify: (text: string) => Effect.Effect<CategoryScores, ClassifierError>;
  }
>() {}

// ---------------------------------------------------------------------------
// Word lists (150-200 words each)
// ---------------------------------------------------------------------------

const COFFEE_WORDS = new Set([
  // Drinks
  "coffee", "espresso", "latte", "cappuccino", "mocha", "americano", "macchiato",
  "cortado", "ristretto", "affogato", "doppio", "lungo", "frappe", "frappuccino",
  "decaf", "decaffeinated", "drip", "cold", "iced", "nitro", "irish",
  // Equipment & methods
  "pourover", "pour", "french", "press", "aeropress", "chemex", "v60", "hario",
  "moka", "siphon", "percolator", "keurig", "nespresso", "grinder", "burr",
  "filter", "carafe", "portafilter", "tamper", "dripper", "brewer",
  // Processes
  "brew", "brewing", "brewed", "roast", "roasted", "roasting", "grind",
  "grinding", "ground", "grounds", "extract", "extraction", "bloom", "blooming",
  "tamp", "tamping", "pull", "pulling", "dose", "dosing",
  // Beans & origin
  "bean", "beans", "arabica", "robusta", "single", "origin", "blend",
  "ethiopian", "colombian", "brazilian", "kenyan", "sumatran", "guatemalan",
  "java", "sumatra", "yemen", "kona", "geisha", "bourbon", "typica",
  // Roast levels
  "light", "medium", "dark", "french", "italian", "city", "full",
  // Flavor & texture
  "crema", "foam", "froth", "frothed", "steamed", "milk", "cream",
  "sugar", "bitter", "bold", "rich", "smooth", "nutty", "chocolatey",
  "fruity", "acidic", "bright", "earthy", "smoky", "caramel", "vanilla",
  // Culture
  "barista", "cafe", "café", "coffeehouse", "coffeeshop", "counter",
  "mug", "cup", "demitasse", "shot", "sip", "sipping", "aroma",
  "caffeine", "caffeinated", "morning", "ritual", "daily",
  // Misspellings
  "coffe", "coffie", "expresso", "capuccino", "cappucino", "macchiatto",
  "labled", "americanno", "barrista", "esspresso",
  // Related
  "drinkware", "thermos", "tumbler", "pour", "steep",
]);

const TEA_WORDS = new Set([
  // Varieties
  "tea", "matcha", "oolong", "chamomile", "earl", "grey", "gray",
  "green", "black", "white", "herbal", "rooibos", "pu", "erh", "puer",
  "sencha", "gyokuro", "genmaicha", "hojicha", "bancha", "kukicha",
  "darjeeling", "assam", "ceylon", "lapsang", "souchong", "keemun",
  "jasmine", "chrysanthemum", "hibiscus", "peppermint", "spearmint",
  "mint", "bergamot", "chai", "masala", "yerba", "mate", "tisane",
  "gunpowder", "dragon", "well", "longjing", "tieguanyin", "baozhong",
  // Equipment
  "teapot", "teacup", "kettle", "infuser", "strainer", "gaiwan",
  "yixing", "kyusu", "tetsubin", "samovar", "cozy", "cosy", "caddy",
  "pot", "lid", "spout", "handle", "saucer",
  // Processes
  "steep", "steeping", "steeped", "infuse", "infusing", "infusion",
  "brew", "brewing", "brewed", "pour", "pouring", "poured",
  "strain", "straining", "strained", "boil", "boiling", "boiled",
  "simmer", "simmering", "simmered", "whisking", "whisk", "whisked",
  // Gongfu
  "gongfu", "kungfu", "ceremony", "ceremonial", "ritual",
  // Flavor
  "floral", "grassy", "vegetal", "umami", "astringent", "malty",
  "sweet", "delicate", "smooth", "aromatic", "fragrant", "subtle",
  // Culture
  "leaf", "leaves", "bud", "buds", "flush", "harvest", "garden",
  "estate", "plantation", "oxidation", "oxidized", "fermented",
  "aged", "loose", "bagged", "sachet", "teaware",
  // Misspellings
  "tae", "chai", "chammomile", "camomile", "oolung", "matchta",
  "greentea", "blacktea", "herble", "chamomille", "roobios",
  // Related
  "sip", "sipping", "cup", "steam", "warm", "hot",
]);

const MORNING_WORDS = new Set([
  // Time
  "morning", "dawn", "daybreak", "sunrise", "sunup", "daylight",
  "early", "first", "waking", "wake", "woke", "awake", "awaken",
  "alarm", "clock", "rooster", "crow",
  // Activities
  "breakfast", "cereal", "toast", "eggs", "pancake", "pancakes",
  "oatmeal", "porridge", "bagel", "muffin", "croissant", "yogurt",
  "juice", "orange", "smoothie", "commute", "commuting",
  // Qualities
  "fresh", "new", "begin", "beginning", "start", "starting",
  "rise", "rising", "risen", "open", "opening", "stretch",
  // Nature morning
  "dew", "dewdrop", "dewdrops", "mist", "misty", "fog", "foggy",
  "haze", "hazy", "frost", "frosty", "crisp", "cool", "chill",
  "birdsong", "birds", "robin", "sparrow", "chirp", "chirping",
  "rooster", "cockadoodle", "songbird",
  // Light
  "ray", "rays", "beam", "beams", "glow", "glowing", "golden",
  "amber", "pink", "peach", "orange", "horizon", "east", "eastern",
  "bright", "brightening", "lighten", "lightening",
  // Routine
  "routine", "ritual", "habit", "shower", "dress", "prepare",
  "ready", "meditation", "yoga", "jog", "jogging", "run", "running",
  "walk", "walking", "exercise", "newspaper", "news",
  // Misspellings
  "mornin", "mourning", "brekfast", "breakfest", "surise",
  "dawm", "dwan", "wakeing", "sunris",
  // Related
  "am", "ante", "dayspring",
]);

const AFTERNOON_WORDS = new Set([
  // Time
  "afternoon", "midday", "noon", "noonday", "noontide", "noontime",
  "twelve", "lunch", "lunchtime", "luncheon", "midafternoon",
  "postmeridian", "meridian",
  // Activities
  "siesta", "nap", "napping", "doze", "dozing", "drowsy", "drowsing",
  "snack", "snacking", "picnic", "stroll", "strolling", "meander",
  "leisure", "leisurely", "idle", "idling", "lounge", "lounging",
  "read", "reading", "browse", "browsing", "chat", "chatting",
  // Qualities
  "warm", "warmth", "lazy", "languid", "unhurried", "slow",
  "sleepy", "drowsy", "heavy", "hazy", "muggy", "humid",
  "balmy", "pleasant", "mild", "temperate",
  // Nature afternoon
  "shade", "shadow", "shadows", "shaded", "shady", "tree", "trees",
  "bench", "park", "garden", "patio", "porch", "veranda", "terrace",
  "gazebo", "hammock", "deck", "yard", "lawn", "courtyard",
  // Light
  "sun", "sunny", "sunlight", "sunbeam", "sunlit", "sundrenched",
  "bright", "blazing", "radiant", "glare", "glaring", "shimmer",
  "shimmering", "dappled", "filtered", "streaming",
  // Food & drink
  "teatime", "tea", "lemonade", "iced", "cool", "refreshing",
  "sandwich", "salad", "fruit", "pastry", "cake", "scone",
  // Misspellings
  "afternon", "afernoon", "afternoom", "noone", "middday",
  "sieta", "lesiure", "liesure",
  // Related
  "pm", "post", "break", "recess", "pause", "interlude",
]);

const EVENING_WORDS = new Set([
  // Time
  "evening", "dusk", "twilight", "sunset", "sundown", "nightfall",
  "gloaming", "eventide", "vesper", "vespers", "late", "night",
  "nighttime", "midnight", "bedtime",
  // Sky
  "moon", "moonlight", "moonlit", "moonrise", "moonbeam", "lunar",
  "crescent", "full", "waning", "waxing", "star", "stars", "starry",
  "starlight", "starlit", "constellation", "galaxy", "cosmos",
  "milky", "way", "venus", "mars", "jupiter", "orion", "pleiades",
  // Qualities
  "dark", "darkness", "dim", "dimming", "fading", "fade", "faded",
  "dusky", "shadowy", "somber", "quiet", "quieting", "hushed",
  "silent", "silence", "still", "stillness", "calm", "calming",
  // Nature evening
  "firefly", "fireflies", "cricket", "crickets", "owl", "owls",
  "bat", "bats", "moth", "moths", "whippoorwill", "nightingale",
  "frog", "frogs", "cicada", "cicadas", "nocturnal",
  // Activities
  "dinner", "supper", "feast", "dine", "dining", "wine", "candle",
  "candles", "candlelight", "candlelit", "fire", "fireplace",
  "fireside", "hearth", "lamp", "lantern", "porch", "veranda",
  "sleep", "sleeping", "slumber", "dream", "dreaming", "dreams",
  "rest", "resting", "retire", "retiring", "repose",
  // Light
  "glow", "glowing", "ember", "embers", "flicker", "flickering",
  "shimmer", "twinkle", "twinkling", "sparkle", "sparkling",
  "luminous", "luminescence", "phosphorescent",
  // Misspellings
  "evning", "evenning", "twighlight", "twilite", "dusck",
  "moonlite", "stary", "nightime", "midnite",
  // Related
  "pm", "nocturne", "serenade", "lullaby",
]);

const NATURE_WORDS = new Set([
  // Plants
  "flower", "flowers", "petal", "petals", "bloom", "blooming",
  "blossom", "blossoms", "bud", "buds", "seed", "seeds", "sprout",
  "leaf", "leaves", "branch", "branches", "tree", "trees", "trunk",
  "root", "roots", "bark", "canopy", "forest", "woods", "grove",
  "meadow", "field", "prairie", "grass", "grasses", "fern", "ferns",
  "moss", "lichen", "vine", "vines", "ivy", "reed", "reeds",
  "bamboo", "willow", "oak", "maple", "pine", "cedar", "birch",
  "cherry", "plum", "lotus", "lily", "rose", "daisy", "orchid",
  "tulip", "iris", "sunflower", "wildflower", "wildflowers",
  // Animals
  "bird", "birds", "sparrow", "robin", "hawk", "eagle", "crane",
  "heron", "swan", "duck", "goose", "owl", "crow", "raven",
  "hummingbird", "jay", "wren", "finch", "dove", "pigeon",
  "butterfly", "butterflies", "dragonfly", "bee", "bees", "ant",
  "ants", "spider", "snail", "worm", "caterpillar", "ladybug",
  "deer", "fox", "rabbit", "hare", "squirrel", "bear", "wolf",
  "frog", "toad", "turtle", "fish", "salmon", "trout", "koi",
  // Water
  "river", "stream", "creek", "brook", "pond", "lake", "ocean",
  "sea", "wave", "waves", "tide", "tidal", "shore", "beach",
  "waterfall", "cascade", "rapids", "current", "ripple", "ripples",
  // Weather
  "rain", "raining", "raindrop", "raindrops", "drizzle", "shower",
  "storm", "thunder", "lightning", "cloud", "clouds", "cloudy",
  "wind", "windy", "breeze", "breezy", "gust", "gale",
  "snow", "snowy", "snowflake", "snowfall", "blizzard", "frost",
  "ice", "icy", "hail", "fog", "mist", "dew",
  // Landscape
  "mountain", "mountains", "hill", "hills", "valley", "canyon",
  "cliff", "ridge", "peak", "summit", "plateau", "mesa",
  "island", "peninsula", "cape", "cove", "bay", "harbor",
  "desert", "dune", "dunes", "oasis", "tundra", "glacier",
  "volcano", "crater", "cavern", "cave", "gorge", "ravine",
  // Sky
  "sky", "horizon", "rainbow", "aurora",
  "sunrise", "sunset", "dawn", "dusk",
  // Seasons
  "spring", "summer", "autumn", "fall", "winter",
  // Misspellings
  "mountian", "mountians", "forrest", "butterly", "butterflys",
  "flowrs", "leafe", "brid", "brids", "raindop", "snowfake",
]);

const RELAXATION_WORDS = new Set([
  // Calm states
  "calm", "calming", "calmness", "peace", "peaceful", "peacefully",
  "serene", "serenity", "tranquil", "tranquility", "placid",
  "gentle", "gently", "soft", "softly", "softness", "tender",
  "tenderly", "tender", "mild", "mildly", "soothe", "soothing",
  "soothed", "comfort", "comfortable", "comforting", "cozy", "cosy",
  // Stillness
  "still", "stillness", "quiet", "quietly", "quietude", "silent",
  "silence", "silently", "hush", "hushed", "mute", "muted",
  "pause", "pausing", "rest", "resting", "restful", "repose",
  "ease", "easing", "easy", "leisurely", "leisure", "unhurried",
  // Slow movement
  "slow", "slowly", "drift", "drifting", "drifted", "float",
  "floating", "floated", "glide", "gliding", "sway", "swaying",
  "linger", "lingering", "lingered", "meander", "meandering",
  "wander", "wandering", "stroll", "strolling",
  // Breathing
  "breath", "breathe", "breathing", "inhale", "exhale", "sigh",
  "sighing", "sighed",
  // Warmth & comfort
  "warm", "warmth", "cozy", "blanket", "wrap", "wrapped",
  "embrace", "cradle", "cradled", "nestle", "nestled", "snug",
  "pillow", "cushion", "hammock", "fireside",
  // Meditation
  "meditate", "meditation", "mindful", "mindfulness", "zen",
  "contemplate", "contemplation", "contemplative", "reflect",
  "reflection", "introspect", "introspection",
  // Water calm
  "ripple", "ripples", "pool", "puddle", "pond", "stream",
  "trickle", "trickling", "murmur", "murmuring", "babble",
  "babbling", "lap", "lapping",
  // Sounds
  "whisper", "whispering", "whispered", "hum", "humming",
  "chime", "chiming", "rustle", "rustling",
  // Emotional state
  "content", "contentment", "bliss", "blissful", "harmony",
  "harmonious", "balanced", "centered", "grounded", "present",
  "grateful", "gratitude", "thankful", "blessed", "grace",
  "graceful", "gracefully",
  // Nature calm
  "garden", "sanctuary", "retreat", "haven", "refuge", "oasis",
  // Misspellings
  "peacful", "peacfull", "relaxtion", "relaxaton", "tranquill",
  "serean", "sereen", "tranquillity", "calmnes", "peacefull",
  "confortable", "comfertable",
  // Related
  "unwind", "unwinding", "decompress", "detox", "rejuvenate",
  "restore", "renew", "refresh", "refreshing", "refreshed",
]);

const WORD_LISTS: Record<CategoryLabel, Set<string>> = {
  coffee: COFFEE_WORDS,
  tea: TEA_WORDS,
  morning: MORNING_WORDS,
  afternoon: AFTERNOON_WORDS,
  evening: EVENING_WORDS,
  nature: NATURE_WORDS,
  relaxation: RELAXATION_WORDS,
};

// ---------------------------------------------------------------------------
// Tokenizer
// ---------------------------------------------------------------------------

export function tokenize(text: string): string[] {
  const words = text.toLowerCase().split(/[^a-z]+/).filter(Boolean);
  return [...new Set(words)];
}

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

function score(tokens: string[], wordList: Set<string>): number {
  if (tokens.length === 0) return 0;
  let matches = 0;
  for (const token of tokens) {
    if (wordList.has(token)) matches++;
  }
  return matches / tokens.length;
}

const ZERO_SCORES: CategoryScores = {
  coffee: 0, tea: 0, nature: 0, relaxation: 0, morning: 0, afternoon: 0, evening: 0,
};

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

export const ClassifierServiceLive = Layer.succeed(
  ClassifierService,
  {
    classify: (text: string): Effect.Effect<CategoryScores, ClassifierError> => {
      const tokens = tokenize(text);
      if (tokens.length === 0) return Effect.succeed({ ...ZERO_SCORES });

      const scores: CategoryScores = { ...ZERO_SCORES };
      for (const label of CATEGORY_LABELS) {
        scores[label] = score(tokens, WORD_LISTS[label]);
      }
      return Effect.succeed(scores);
    },
  }
);

/** Test layer that returns zero scores. */
export const ClassifierServiceTest = Layer.succeed(
  ClassifierService,
  {
    classify: () => Effect.succeed({ ...ZERO_SCORES }),
  }
);
