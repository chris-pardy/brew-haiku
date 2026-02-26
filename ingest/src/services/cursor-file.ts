import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname } from "path";

/** Load a microsecond cursor from a file. Returns null if missing or invalid. */
export function loadCursor(path: string): number | null {
  try {
    if (!existsSync(path)) return null;
    const content = readFileSync(path, "utf-8").trim();
    const cursor = parseInt(content, 10);
    return isNaN(cursor) ? null : cursor;
  } catch {
    return null;
  }
}

/** Persist a microsecond cursor to a file (creates parent dirs). */
export function saveCursor(path: string, cursorUs: number): void {
  try {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, String(cursorUs), "utf-8");
  } catch (e) {
    console.error(`Failed to save cursor: ${e}`);
  }
}
