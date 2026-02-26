import { pipeline } from "@huggingface/transformers";

// Download the q8 model (used on Linux in production)
console.log("Downloading zero-shot classification model (q8)...");
await pipeline("zero-shot-classification", "Xenova/mobilebert-uncased-mnli", {
  dtype: "q8",
});
console.log("Model downloaded successfully.");
