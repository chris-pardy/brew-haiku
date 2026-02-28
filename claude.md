# Claude Code Notes - Brew Haiku

## Project Structure

Bun workspace monorepo with 4 services + shared code.

```
brew-haiku/
├── package.json         # Bun workspace root
├── Dockerfile           # Single image, CMD overridden by fly.toml
├── fly.toml             # 4 process groups: gateway, feed, ingest, timers
├── shared/              # @brew-haiku/shared — common code
│   ├── src/
│   │   ├── index.ts     # Barrel re-exports
│   │   ├── protocol.ts  # IngestEvent, ServerMessage types
│   │   ├── db/migrations.ts  # Migration runner
│   │   └── services/
│   │       ├── database.ts   # DatabaseService, record types
│   │       └── jetstream.ts  # JetstreamService, event types
│   └── test/
├── ingest/              # @brew-haiku/ingest — firehose worker
│   ├── src/
│   │   ├── index.ts     # Connects to feed + timers WebSockets
│   │   ├── services/
│   │   │   ├── firehose.ts          # Pipeline orchestration
│   │   │   ├── firehose-indexers.ts  # Haiku, like, timer indexers
│   │   │   ├── classifier.ts        # ML zero-shot classification
│   │   │   ├── haiku-detector.ts    # Syllable counting
│   │   │   ├── ingestion-client.ts  # FeedIngestClient + TimerIngestClient
│   │   │   └── cursor-file.ts       # Cursor persistence
│   │   ├── data/        # Syllable dictionary, test cases
│   │   └── scripts/     # download-model.ts
│   └── test/
├── feed/                # @brew-haiku/feed — feed generator HTTP + ingestion
│   ├── src/
│   │   ├── index.ts     # HTTP server + haiku ingestion WebSocket
│   │   ├── db/migrations.ts  # Feed-specific migrations
│   │   ├── services/
│   │   │   ├── feed-generator.ts    # Feed ranking/scoring
│   │   │   ├── ingestion-server.ts  # WebSocket server (haiku/like only)
│   │   │   └── ingestion-state.ts   # Global singleton
│   │   ├── routes/      # health, feed, did-document
│   │   └── scripts/     # publish-feed.ts
│   ├── feed-config.json
│   └── test/
├── timers/              # @brew-haiku/timers — timer CRUD HTTP + ingestion
│   ├── src/
│   │   ├── index.ts     # HTTP server + timer ingestion WebSocket
│   │   ├── db/migrations.ts  # Timer-specific migrations
│   │   ├── services/
│   │   │   ├── timer.ts             # Timer CRUD, search, FTS5
│   │   │   ├── saved-timers.ts      # Fetch saved timers from PDS
│   │   │   ├── atproto.ts           # Handle/DID resolution
│   │   │   ├── oauth.ts             # OAuth token exchange/refresh
│   │   │   └── ingestion-server.ts  # WebSocket server (timer only)
│   │   └── routes/      # health, timers, saved-timers, auth, resolve
│   └── test/
├── gateway/             # @brew-haiku/gateway — HTTP reverse proxy
│   └── src/
│       └── index.ts     # Routes to feed or timers via Fly internal DNS
├── frontend/            # Flutter mobile app
│   ├── lib/
│   │   ├── providers/   # Riverpod providers
│   │   ├── screens/     # Screen widgets
│   │   ├── widgets/     # Reusable components
│   │   ├── services/    # ATProto client, API calls
│   │   └── main.dart
│   ├── test/
│   └── pubspec.yaml
├── lexicons/            # ATProto lexicon definitions
├── prd.md               # Product requirements
└── prd.json             # Feature tracking
```

## Backend (Bun + Effect)

### Architecture
- **3 services**: `feed` (HTTP + haiku ingestion), `ingest` (firehose worker), `timers` (HTTP + timer ingestion)
- **Shared code**: `@brew-haiku/shared` provides DatabaseService, JetstreamService, protocol types, migration runner
- **Ingest worker** connects to both feed and timers via separate WebSockets
- **Dual IngestClient tags**: `FeedIngestClient` (haiku/like events) and `TimerIngestClient` (timer events)

### Tech Stack
- **Runtime**: Bun (fast JavaScript runtime with native SQLite)
- **Framework**: Effect (type-safe functional effects)
- **Database**: SQLite with FTS5 for full-text search (separate DBs per service)
- **Deployment**: Fly.io (3 process groups, 3 volumes)

### Key Packages
```json
{
  "dependencies": {
    "effect": "^3.0.0",
    "@effect/platform": "^0.48.0",
    "@effect/platform-bun": "^0.31.0"
  }
}
```

### Effect Patterns

Use Effect's service pattern for dependency injection:

```typescript
import { Effect, Context, Layer } from "effect";

// Define service interface
class TimerService extends Context.Tag("TimerService")<
  TimerService,
  {
    readonly getTimer: (id: string) => Effect.Effect<Timer, NotFoundError>;
    readonly searchTimers: (query: string) => Effect.Effect<Timer[]>;
  }
>() {}

// Implement service
const TimerServiceLive = Layer.succeed(
  TimerService,
  {
    getTimer: (id) => Effect.tryPromise(() => db.query(...)),
    searchTimers: (query) => Effect.tryPromise(() => db.search(...)),
  }
);
```

### HTTP Server with Effect

```typescript
import { HttpServer, HttpServerRequest } from "@effect/platform";

const routes = HttpServer.router.empty.pipe(
  HttpServer.router.get("/health", Effect.succeed({ status: "ok" })),
  HttpServer.router.get("/timers/:id", (req) =>
    Effect.gen(function* () {
      const timerService = yield* TimerService;
      const id = HttpServerRequest.param(req, "id");
      return yield* timerService.getTimer(id);
    })
  )
);
```

### SQLite with Bun

```typescript
import { Database } from "bun:sqlite";

const db = new Database("brew-haiku.db");

// FTS5 search
db.query(`
  SELECT t.*, ts.rank
  FROM timer_search ts
  JOIN timer_index t ON ts.uri = t.uri
  WHERE timer_search MATCH ?
  ORDER BY (t.save_count * ?) + (ts.rank * ?) DESC
  LIMIT 20
`).all(query, saveWeight, textWeight);
```

### Testing with Bun

```typescript
import { test, expect, describe } from "bun:test";

describe("TimerService", () => {
  test("searchTimers returns ranked results", async () => {
    const result = await Effect.runPromise(
      timerService.searchTimers("v60").pipe(
        Effect.provide(TestLayer)
      )
    );
    expect(result.length).toBeGreaterThan(0);
  });
});
```

Run tests: `bun test shared/test/ feed/test/ ingest/test/ timers/test/`

## Frontend (Flutter)

### Tech Stack
- **Framework**: Flutter (cross-platform mobile)
- **State Management**: Riverpod
- **Auth**: Bluesky OAuth via atproto/bluesky packages
- **Storage**: flutter_secure_storage for tokens

### Key Packages
```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  flutter_secure_storage: ^9.0.0
  bluesky: ^0.8.0
  atproto: ^0.8.0
  google_fonts: ^6.1.0  # For Playfair Display, Inter
```

### Riverpod Providers

```dart
// Auth state
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// Timer state
final timerStateProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier();
});

// Focus guard
final focusGuardProvider = StateNotifierProvider<FocusGuardNotifier, FocusGuardState>((ref) {
  return FocusGuardNotifier();
});
```

### ATProto Client Usage

```dart
import 'package:bluesky/bluesky.dart';

// Create session
final session = await createSession(
  identifier: handle,
  password: appPassword,
);

// Post haiku
await session.feed.post(
  text: '$haikuText\n\nvia @brew-haiku.app',
);

// Create timer record
await session.atproto.repo.createRecord(
  collection: 'app.brew-haiku.timer',
  record: {
    'name': timerName,
    'vessel': vessel,
    'brewType': brewType,
    'steps': steps,
    'createdAt': DateTime.now().toIso8601String(),
  },
);
```

### Focus Guard Implementation

```dart
class FocusGuardNotifier extends StateNotifier<FocusGuardState>
    with WidgetsBindingObserver {

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Record interruption, timer keeps running
      state = state.copyWith(
        interruptions: state.interruptions + 1,
        lastInterruptedAt: DateTime.now(),
      );
    }
  }
}
```

### Custom Painter for Timer

```dart
class TimerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw steam rising or vessel filling based on progress
  }
}
```

### Testing with Flutter

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyllableCounter', () {
    test('counts syllables correctly', () {
      expect(countSyllables('haiku'), 2);
      expect(countSyllables('beautiful'), 3);
    });
  });

  testWidgets('Timer displays correctly', (tester) async {
    await tester.pumpWidget(TimerWidget(duration: Duration(minutes: 3)));
    expect(find.text('3:00'), findsOneWidget);
  });
}
```

Run tests: `flutter test`

## ATProto Lexicons

Lexicon files go in `lexicons/` directory:

- `app.brew-haiku.timer.json` - Timer/recipe record
- `app.brew-haiku.savedTimer.json` - Saved timer reference

### Timer Lexicon Key Points

- Steps have `stepType`: `"timed"` or `"indeterminate"`
- `ratio` is optional (for non-ratio brews)
- `key: "tid"` uses timestamp-based IDs

### SavedTimer Lexicon Key Points

- `key: "any"` allows custom rkeys
- Use timer's rkey as the savedTimer rkey (enforces one save per timer per user)
- Deleting savedTimer doesn't delete the original timer

## Git Commit Convention

Use conventional commits:

```
feat(timers): add timer search with FTS5
fix(ingest): correct syllable count for contractions
test(feed): add feed generator tests
feat(shared): add migration runner
docs: update PRD with new feature
```

Scopes: `shared`, `ingest`, `feed`, `timers`, `frontend`

Co-author line:
```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Important Notes

1. **Timer never pauses** - Focus Guard tracks interruptions but doesn't stop the timer
2. **Save count drives indexing** - Timers need >= 1 save to appear in search
3. **Haiku signature** - Posts must end with "via @brew-haiku.app" to be indexed
4. **Ranking is configurable** - LIKE_WEIGHT, RECENCY_WEIGHT, etc. should be in config
5. **Domain is `brew-haiku.app`** - Use hyphenated version consistently
