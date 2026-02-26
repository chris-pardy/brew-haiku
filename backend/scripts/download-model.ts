import { pipeline } from "@huggingface/transformers";

console.log("Downloading zero-shot classification model...");
await pipeline("zero-shot-classification", "Xenova/mobilebert-uncased-mnli", {
  dtype: "fp32",
});
console.log("Model downloaded successfully.");
