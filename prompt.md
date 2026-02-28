# Feature Implementation Prompt

You are implementing features for **Brew Haiku**, a mobile app for mindful tea/coffee brewing with haiku poetry.

## Your Task

1. **Read the feature list** from `prd.json`
2. **Select the best feature to implement next** based on:
   - Feature is not marked as `done: true`
   - All dependencies are marked as `done: true`
   - Prioritize foundational/setup features before dependent features
   - Prefer backend features before frontend features that depend on them
3. **Implement the feature** following the specifications in `prd.md` and patterns in `claude.md`
4. **Write tests** using `flutter test` (frontend) or `bun test` (backend)
5. **Run tests** to verify the implementation works
6. **Commit the changes** with a conventional commit message
7. **Update `prd.json`** to mark the feature as `done: true`
8. **Exit** after completing one feature

## Detailed Steps

### Step 1: Select Feature

Read `prd.json` and find the best candidate feature:

```
For each feature where done === false:
  Check if all dependencies have done === true
  If yes, this feature is a candidate

From candidates, prefer:
  1. Features with fewer/no dependencies (foundational)
  2. Backend features (frontend often depends on backend)
  3. Earlier features in the list (generally ordered by priority)
```

### Step 2: Implement Feature

- Read the relevant sections of `prd.md` for detailed requirements
- Follow the code patterns and conventions in `claude.md`
- Create necessary directories if they don't exist
- Write clean, well-structured code

For **backend** features:
- Place code in `backend/src/`
- Use Effect patterns for services
- Use Bun's native SQLite

For **frontend** features:
- Place code in `frontend/lib/`
- Use Riverpod for state management
- Follow the "Morning Fog" theme system

### Step 3: Write Tests

For **backend** (`bun test`):
```typescript
// backend/test/feature-name.test.ts
import { test, expect, describe } from "bun:test";

describe("FeatureName", () => {
  test("does the expected thing", () => {
    // Test implementation
  });
});
```

For **frontend** (`flutter test`):
```dart
// frontend/test/feature_name_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureName', () {
    test('does the expected thing', () {
      // Test implementation
    });
  });
}
```

### Step 4: Run Tests

Backend:
```bash
cd backend && bun test
```

Frontend:
```bash
cd frontend && flutter test
```

Ensure all tests pass before committing.

### Step 5: Commit Changes

Use conventional commit format:

```bash
git add .
git commit -m "feat(layer): short description of feature

Longer description if needed.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

Where `layer` is `backend`, `frontend`, or `shared`.

### Step 6: Update prd.json

Edit `prd.json` to set `done: true` for the completed feature:

```json
{
  "id": "feature-id",
  "name": "Feature Name",
  "done": true  // Changed from false
}
```

### Step 7: Exit

After successfully completing one feature:
1. Confirm tests pass
2. Confirm commit was created
3. Confirm prd.json was updated
4. Report what was completed
5. Exit

## Example Workflow

```
1. Read prd.json
   → Found "backend-setup" has no dependencies and done: false
   → Selected "backend-setup" as next feature

2. Implement backend-setup
   → Created backend/package.json
   → Created backend/tsconfig.json
   → Created backend/src/index.ts
   → Set up Effect and Bun configuration

3. Write tests
   → Created backend/test/setup.test.ts
   → Basic test that server can start

4. Run tests
   → bun test
   → All tests pass

5. Commit
   → git add .
   → git commit -m "feat(backend): initialize Bun project with Effect framework..."

6. Update prd.json
   → Set backend-setup.done = true

7. Exit
   → Completed: backend-setup
   → Next available: backend-database, backend-health, frontend-setup
```

## Important Rules

- **Only implement ONE feature per run**
- **All tests must pass before committing**
- **Follow existing code patterns** from `claude.md`
- **Use the exact dependency names** from `prd.json`
- **Do not skip features** - respect the dependency graph
- **Do not modify features marked as done**

## Files Reference

- `prd.md` - Full product requirements and specifications
- `prd.json` - Feature list with dependencies and completion status
- `claude.md` - Tech stack notes and code patterns

Begin by reading `prd.json` to select your feature.

If there are really no features left to build exit saying <promise>All Set</promise> do not say this if there are any features left to build