import { test, expect, describe } from "bun:test";
import {
  cleanText,
  isLatinScript,
  looksEnglish,
  numberToWords,
  countWordSyllables,
  findHaikuSplit,
  detectHaiku,
} from "../src/services/haiku-detector.js";
import testCases from "../src/data/haiku-test-cases.json";

describe("cleanText", () => {
  test("removes haiku signature", () => {
    expect(cleanText("Hello world\n\nvia @brew-haiku.app")).toBe("Hello world");
  });

  test("removes hashtags", () => {
    expect(cleanText("Hello #world #haiku")).toBe("Hello");
  });

  test("collapses whitespace", () => {
    expect(cleanText("Hello   world\n\nfoo")).toBe("Hello world foo");
  });

  test("handles text without signature", () => {
    expect(cleanText("Just a normal text")).toBe("Just a normal text");
  });

  test("handles signature in middle (only removes last occurrence)", () => {
    expect(cleanText("via @brew-haiku.app is cool\n\nvia @brew-haiku.app")).toBe(
      "via @brew-haiku.app is cool"
    );
  });
});

describe("isLatinScript", () => {
  test("accepts ASCII text", () => {
    expect(isLatinScript("Hello world")).toBe(true);
  });

  test("accepts accented Latin characters", () => {
    expect(isLatinScript("café résumé naïve")).toBe(true);
  });

  test("rejects CJK characters", () => {
    expect(isLatinScript("古池や蛙飛び込む水の音")).toBe(false);
  });

  test("rejects Cyrillic characters", () => {
    expect(isLatinScript("Привет мир")).toBe(false);
  });

  test("rejects Arabic characters", () => {
    expect(isLatinScript("مرحبا بالعالم")).toBe(false);
  });

  test("accepts numbers and punctuation", () => {
    expect(isLatinScript("Hello, world! 123")).toBe(true);
  });
});

describe("looksEnglish", () => {
  test("accepts English text", () => {
    expect(looksEnglish(["the", "cat", "sat", "on", "a", "mat"])).toBe(true);
  });

  test("accepts short English text with one stop word", () => {
    expect(looksEnglish(["steam", "rises", "from", "cup"])).toBe(true);
  });

  test("rejects text with no stop words", () => {
    expect(looksEnglish(["sol", "brilla", "sobre", "mar", "tranquilo", "azul", "profundo"])).toBe(false);
  });

  test("rejects empty array", () => {
    expect(looksEnglish([])).toBe(false);
  });
});

describe("numberToWords", () => {
  test("converts 0", () => {
    expect(numberToWords(0)).toBe("zero");
  });

  test("converts single digits", () => {
    expect(numberToWords(5)).toBe("five");
  });

  test("converts teens", () => {
    expect(numberToWords(13)).toBe("thirteen");
  });

  test("converts tens", () => {
    expect(numberToWords(42)).toBe("forty two");
  });

  test("converts hundreds", () => {
    expect(numberToWords(100)).toBe("one hundred");
    expect(numberToWords(305)).toBe("three hundred five");
  });

  test("converts thousands", () => {
    expect(numberToWords(1000)).toBe("one thousand");
    expect(numberToWords(9999)).toBe("nine thousand nine hundred ninety nine");
  });

  test("returns string for out-of-range", () => {
    expect(numberToWords(10000)).toBe("10000");
    expect(numberToWords(-1)).toBe("-1");
  });
});

describe("countWordSyllables", () => {
  test("dictionary words", () => {
    expect(countWordSyllables("coffee")).toBe(2);
    expect(countWordSyllables("espresso")).toBe(3);
    expect(countWordSyllables("ceremony")).toBe(4);
    expect(countWordSyllables("the")).toBe(1);
  });

  test("contractions", () => {
    expect(countWordSyllables("don't")).toBe(1);
    expect(countWordSyllables("isn't")).toBe(2);
    expect(countWordSyllables("wouldn't")).toBe(2);
    expect(countWordSyllables("gonna")).toBe(2);
  });

  test("heuristic fallback", () => {
    const count = countWordSyllables("unfamiliar");
    expect(count).toBeGreaterThanOrEqual(3);
    expect(count).toBeLessThanOrEqual(5);
  });

  test("empty/invalid input", () => {
    expect(countWordSyllables("")).toBe(0);
    expect(countWordSyllables("!!!")).toBe(0);
  });
});

describe("findHaikuSplit", () => {
  test("finds exact 5-7-5 split", () => {
    const counts = [3, 2, 3, 2, 2, 3, 2];
    const result = findHaikuSplit(counts);
    expect(result).not.toBeNull();
    expect(result!.lineSyllables).toEqual([5, 7, 5]);
  });

  test("finds split with grace (4-6-5)", () => {
    const counts = [2, 2, 3, 3, 5];
    const result = findHaikuSplit(counts);
    expect(result).not.toBeNull();
    expect(result!.lineSyllables[0]).toBeGreaterThanOrEqual(4);
    expect(result!.lineSyllables[0]).toBeLessThanOrEqual(6);
  });

  test("rejects too few words", () => {
    expect(findHaikuSplit([5, 7])).toBeNull();
  });

  test("rejects wrong total", () => {
    expect(findHaikuSplit([3, 4, 3])).toBeNull();
  });

  test("rejects when no valid partition exists", () => {
    expect(findHaikuSplit([1, 1, 1, 1, 1])).toBeNull();
  });
});

describe("detectHaiku", () => {
  test("detects hasSignature", () => {
    const withSig = detectHaiku("Steam rises slowly\nPatience rewards the waiting\nFirst sip of pure bliss\n\nvia @brew-haiku.app");
    expect(withSig.hasSignature).toBe(true);

    const withoutSig = detectHaiku("Steam rises slowly\nPatience rewards the waiting\nFirst sip of pure bliss");
    expect(withoutSig.hasSignature).toBe(false);
  });

  test("valid haiku from test cases", () => {
    for (const tc of testCases.valid) {
      const result = detectHaiku(tc.text);
      expect(result.isHaiku).toBe(true);
    }
  });

  test("invalid haiku from test cases", () => {
    for (const tc of testCases.invalid) {
      const result = detectHaiku(tc.text);
      expect(result.isHaiku).toBe(false);
    }
  });

  test("rejects empty text", () => {
    const result = detectHaiku("");
    expect(result.isHaiku).toBe(false);
    expect(result.rejectionReason).toBe("empty text");
  });

  test("rejects non-latin script", () => {
    const result = detectHaiku("古池や蛙飛び込む水の音");
    expect(result.isHaiku).toBe(false);
    expect(result.rejectionReason).toBe("non-latin script");
  });

  test("rejects non-english text", () => {
    const result = detectHaiku("El sol brilla sobre el mar tranquilo y azul profundo y sereno hoy");
    expect(result.isHaiku).toBe(false);
    expect(result.rejectionReason).toBe("not english");
  });

  test("returns line words and syllables for valid haiku", () => {
    const result = detectHaiku("An old silent pond\nA frog jumps into the pond\nSplash silence again");
    expect(result.isHaiku).toBe(true);
    expect(result.lineSyllables).toBeDefined();
    expect(result.lineWords).toBeDefined();
    expect(result.lineWords!.length).toBe(3);
  });
});
