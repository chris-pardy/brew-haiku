import { pipeline } from "@huggingface/transformers";

console.log("Downloading zero-shot classification model...");
await pipeline("zero-shot-classification", "Xenova/mobilebert-uncased-mnli", {
  dtype: "q8",
});
console.log("Model downloaded successfully.");
