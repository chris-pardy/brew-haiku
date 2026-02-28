# Product Requirements Document: Brew Haiku

**Version:** 2.0
**Domain:** brew-haiku.app
**Status:** Draft

---

## 1. Executive Summary

Brew Haiku is a mobile application that transforms the functional waiting period of brewing tea or coffee into a mindful ritual. The app enforces presence through focus-guarding mechanics and rewards patience with poetry, creating a "quiet corner" of the internet where users can share their brewing rituals and haikus through decentralized social integration via the AT Protocol (Bluesky).

### 1.1 Core Philosophy

- **Presence over productivity**: The app actively discourages multitasking during brew time
- **Ritual over routine**: Elevate daily beverage preparation into a contemplative practice
- **Poetry as reward**: Completing a focused brewing session unlocks the ability to compose and share haiku

### 1.2 Target Audience

- Tea and coffee enthusiasts seeking mindful brewing experiences
- Users interested in digital wellness and focus-oriented applications
- Bluesky/AT Protocol community members
- Hobbyist poets and creative writers

---

## 2. Technical Architecture

### 2.1 Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Frontend | Flutter | Cross-platform iOS/Android with high-fidelity custom rendering |
| Backend Runtime | Bun | Fast JavaScript runtime with native SQLite support |
| Backend Framework | Effect | Type-safe, composable effects for robust error handling and dependency injection |
| Database | SQLite | Lightweight, fast, single-file database suitable for Fly.io deployment |
| Hosting | Fly.io | Edge deployment with persistent storage for SQLite |
| Authentication | Bluesky (AT Protocol) | Decentralized identity, no password management required |
| Social Layer | AT Protocol | Decentralized posting and discovery |

### 2.2 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Mobile App                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Timer &   │  │   Haiku     │  │   ATProto Client        │  │
│  │   Brew UI   │  │   Composer  │  │   (Auth + Post to PDS)  │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │                                       │
          │ Timer recipes                         │ Haiku feed (via AppView)
          ▼                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    api.brew-haiku.app (Bun + Effect)            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Timer     │  │    Feed     │  │   Firehose              │  │
│  │   Recipes   │  │  Generator  │  │   Subscriber            │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│         │                │                      ▲               │
│         ▼                ▼                      │               │
│        ┌──────────────────┐                     │               │
│        │      SQLite      │                     │               │
│        └──────────────────┘                     │               │
└─────────────────────────────────────────────────│───────────────┘
                                                  │
                              ┌────────────────────┘
                              │ Firehose (WebSocket)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AT Protocol Network                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  User PDS    │  │   Bluesky    │  │   Relay/Firehose     │   │
│  │  instances   │  │   AppView    │  │   (bsky.network)     │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Authentication System

### 3.1 Bluesky OAuth Flow

Authentication is handled entirely through Bluesky's AT Protocol OAuth implementation. Users sign in with their existing Bluesky identity.

#### 3.1.1 Authentication Flow

1. User taps "Sign in with Bluesky"
2. App initiates OAuth flow with user's PDS (Personal Data Server)
3. User authorizes Brew Haiku in their Bluesky client/browser
4. App receives OAuth tokens and stores securely
5. App resolves user's DID and fetches profile information

#### 3.1.2 Required Scopes

- `atproto` - Basic AT Protocol access
- `transition:generic` - Ability to create records in custom lexicons

#### 3.1.3 Session Management

- Access tokens stored in secure device storage (Flutter Secure Storage)
- Automatic token refresh handling
- Graceful degradation to read-only mode if auth expires

### 3.2 Anonymous Usage

Users may use the app without authentication for:
- Running brew timers (default timers provided for common brewing methods)
- Searching and browsing public timer recipes
- Starting any timer found via search (but not saving it)
- Reading the haiku discovery feed

Authentication required for:
- Saving timer recipes to their account
- Creating and publishing new timer recipes
- Composing and posting haikus
- Liking/interacting with community content

#### 3.2.1 Default Timers

Anonymous users are provided with a curated set of built-in timers:

| Timer | Vessel | Type | Default Ratio |
|-------|--------|------|---------------|
| Simple Pour Over | Generic | Coffee | 16:1 |
| French Press | French Press | Coffee | 15:1 |
| Green Tea | Teapot | Tea | 50:1 |
| Black Tea | Teapot | Tea | 50:1 |
| Gongfu Intro | Gaiwan | Tea | 5:1 |

These timers are hardcoded in the app and don't require network access.

---

## 4. Frontend Specifications (Flutter)

### 4.1 UI/UX Design System

#### 4.1.1 Typography

| Usage | Font Family | Weight | Notes |
|-------|-------------|--------|-------|
| Haiku Display | Playfair Display | Regular/Italic | Serif for poetry, elegance |
| Body Text | Inter | Regular (400) | High readability |
| Labels/Captions | Inter | Medium (500) | Functional UI elements |
| Timer Display | Custom/Mono | Light | Large, zen-like numerals |

#### 4.1.2 Adaptive Theming: "Morning Fog"

The app uses a soft, low-contrast palette that subtly shifts based on brew type:

| Brew Category | Primary Hue | Accent | Example Beverages |
|---------------|-------------|--------|-------------------|
| Light Tea | Cool Blue-Green | Sage | White tea, Green tea |
| Dark Tea | Warm Amber | Rust | Black tea, Pu-erh |
| Light Coffee | Warm Cream | Honey | Pour-over, Light roast |
| Dark Coffee | Deep Brown | Copper | Espresso, Dark roast |

#### 4.1.3 Custom Visual Elements

- **Timer Visualization**: CustomPainter implementation depicting rising steam or filling vessel
- **Haiku Cards**: Elegant bordered containers with subtle paper texture
- **Transitions**: Slow, intentional page transitions (300-500ms curves)

### 4.2 Focus Guard System

The Focus Guard is a core differentiating feature that enforces presence during brewing.

#### 4.2.1 Lifecycle Detection

```dart
// Conceptual implementation
class FocusGuard with AppLifecycleListener {
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // Timer continues running - the brew doesn't pause in real life
      recordInterruption(timestamp: DateTime.now());
      enterInterruptedState();
    }
  }
}
```

**Important**: The timer never pauses. The physical brewing process continues regardless of whether the user is looking at their phone. The Focus Guard's purpose is to encourage presence and awareness, not to sync with actual brew time.

#### 4.2.2 "Ritual Interrupted" Recovery

When the user returns after backgrounding:

1. UI blurs via `BackdropFilter` (sigma: 10-15)
2. "Return to Ritual" overlay appears, showing time spent away
3. User must long-press (2 seconds) to acknowledge and return to the timer
4. Gentle haptic feedback confirms return
5. Timer display updates to show current progress (timer was never paused)

#### 4.2.3 Interruption Tracking

- Track number of interruptions per session
- Track total time spent away from the app during the ritual
- Optional: Display interruption stats on completion screen (count + total away time)
- No punishment, only gentle awareness - the goal is mindfulness, not guilt

### 4.3 State Management

Using Riverpod for reactive state management:

#### 4.3.1 Core Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `authStateProvider` | StateNotifier | Manages Bluesky auth session |
| `timerStateProvider` | StateNotifier | Active timer state (elapsed time, running, etc.) |
| `currentBrewProvider` | StateNotifier | Current brew configuration |
| `haikuCacheProvider` | FutureProvider | Cached haikus from discovery feed |
| `focusGuardProvider` | StateNotifier | Tracks app lifecycle and interruptions |

### 4.4 ATProto Client Integration

The Flutter app communicates directly with the AT Protocol for write operations:

- **Authentication**: OAuth flow with user's PDS
- **Posting Haikus**: Creates `app.bsky.feed.post` record on user's PDS with "via @brew-haiku.app" signature
- **Reading Haiku Feed**: Via Bluesky AppView using the custom feed generator (standard `app.bsky.feed.getFeed` call)

---

## 5. Backend Specifications (Bun + Effect)

### 5.1 API Design

**Base URL:** `https://api.brew-haiku.app`

#### 5.1.1 Endpoints

| Method | Path | Description | Auth Required |
|--------|------|-------------|---------------|
| GET | `/health` | Health check | No |
| GET | `/timers` | List public timer recipes | No |
| GET | `/timers/:id` | Get specific timer recipe | No |
| GET | `/timers/search` | Search timers by vessel, brew type | No |
| POST | `/timers` | Create/publish timer recipe | Yes |
| GET | `/resolve/:handle` | Resolve handle to DID | No |
| POST | `/auth/callback` | OAuth callback handler | No |

#### 5.1.2 Feed Generator Endpoints (Bluesky Custom Feed)

The haiku discovery feed is implemented as a standard Bluesky custom feed generator.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/xrpc/app.bsky.feed.getFeedSkeleton` | Returns feed skeleton for Bluesky AppView |
| GET | `/xrpc/app.bsky.feed.describeFeedGenerator` | Feed generator metadata |
| GET | `/.well-known/did.json` | DID document for feed generator identity |

#### 5.1.3 Effect Service Architecture

```typescript
// Conceptual service layers
- TimerService          // Timer recipe CRUD operations, search
- FeedGeneratorService  // Implements getFeedSkeleton, haiku ranking algorithm
- FirehoseService       // Subscribes to Bluesky firehose, indexes haiku posts and timer saves
- ATProtoService        // DID resolution, PDS communication
- CacheService          // SQLite caching layer
```

### 5.2 Database Schema

#### 5.2.1 Tables

**timer_index**
| Column | Type | Description |
|--------|------|-------------|
| uri | TEXT PRIMARY KEY | AT URI of the app.brew-haiku.timer record |
| did | TEXT | Creator's DID |
| cid | TEXT | Content identifier |
| handle | TEXT | Creator's handle (cached) |
| name | TEXT | Recipe name |
| vessel | TEXT | Brewing vessel name |
| brew_type | TEXT | tea/coffee category |
| ratio | REAL | Water to dry ratio (nullable) |
| steps | TEXT (JSON) | Array of steps |
| save_count | INTEGER | Number of saves (must be >= 1 to be indexed) |
| created_at | INTEGER | Timer creation timestamp |
| indexed_at | INTEGER | When we indexed this timer |

**Note**: Timers are only indexed when `save_count >= 1`. When a timer's save count drops to 0, it is removed from the index.

**timer_search** (FTS5 Virtual Table)

SQLite FTS5 is used for full-text search on timer recipes.

```sql
CREATE VIRTUAL TABLE timer_search USING fts5(
  uri,           -- for joining back to timer_index
  name,          -- recipe name (searchable)
  vessel,        -- vessel type (searchable)
  handle,        -- creator handle (searchable)
  content=timer_index,
  content_rowid=rowid
);
```

**Search Query Example:**
```sql
SELECT t.*, ts.rank
FROM timer_search ts
JOIN timer_index t ON ts.uri = t.uri
WHERE timer_search MATCH 'v60 OR pour over'
ORDER BY (t.save_count * :save_weight) + (ts.rank * :text_weight) DESC
LIMIT 20;
```

The final ranking combines FTS5 text relevance with save count popularity.

**did_cache**
| Column | Type | Description |
|--------|------|-------------|
| did | TEXT PRIMARY KEY | Decentralized identifier |
| handle | TEXT | Current handle |
| pds_url | TEXT | PDS endpoint |
| public_key | TEXT | Signing key |
| cached_at | INTEGER | Unix timestamp |

**haiku_posts**
| Column | Type | Description |
|--------|------|-------------|
| uri | TEXT PRIMARY KEY | AT URI (e.g., at://did:plc:xxx/app.bsky.feed.post/yyy) |
| did | TEXT | Author's DID |
| cid | TEXT | Content identifier for the post |
| text | TEXT | Haiku content |
| like_count | INTEGER | Cached like count for ranking |
| created_at | INTEGER | Post creation timestamp (for newness ranking) |
| indexed_at | INTEGER | When we indexed this post |

**Note**: Posts are identified by the suffix "via @brew-haiku.app" in the post text.

### 5.3 ATProto Lexicon

#### 5.3.1 app.brew-haiku.timer

The timer record stores a brewing recipe. Steps can be either **timed** (with a duration) or **indeterminate** (user marks complete manually).

```json
{
  "lexicon": 1,
  "id": "app.brew-haiku.timer",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["name", "vessel", "steps", "brewType", "createdAt"],
        "properties": {
          "name": {
            "type": "string",
            "maxLength": 100,
            "description": "Recipe name (e.g., 'My V60 Recipe')"
          },
          "vessel": {
            "type": "string",
            "maxLength": 100,
            "description": "Brewing vessel (e.g., Hario V60, Gaiwan)"
          },
          "brewType": {
            "type": "string",
            "enum": ["coffee", "tea"],
            "description": "Primary beverage category"
          },
          "ratio": {
            "type": "number",
            "minimum": 1,
            "maximum": 100,
            "description": "Water to dry ingredient ratio (optional for non-ratio brews)"
          },
          "steps": {
            "type": "array",
            "items": { "type": "ref", "ref": "#step" },
            "maxLength": 20,
            "description": "Ordered brewing steps"
          },
          "notes": {
            "type": "string",
            "maxLength": 500,
            "description": "Optional brewing notes"
          },
          "createdAt": {
            "type": "string",
            "format": "datetime"
          }
        }
      }
    },
    "step": {
      "type": "object",
      "required": ["action", "stepType"],
      "properties": {
        "action": {
          "type": "string",
          "maxLength": 200,
          "description": "Step instruction (e.g., 'Steep tea' or 'Heat water to 165°C')"
        },
        "stepType": {
          "type": "string",
          "enum": ["timed", "indeterminate"],
          "description": "Whether step has a fixed duration or user-controlled completion"
        },
        "durationSeconds": {
          "type": "integer",
          "minimum": 1,
          "maximum": 3600,
          "description": "Step duration in seconds (required if stepType is 'timed')"
        }
      }
    }
  }
}
```

**Step Types:**
- **timed**: Step has a countdown timer (e.g., "Steep for 3 minutes" → 180 seconds)
- **indeterminate**: Step waits for user confirmation (e.g., "Heat water to 165°C" → user taps "Done" when ready)

#### 5.3.2 app.brew-haiku.savedTimer

A lightweight record that references a timer the user has saved to their collection. Separating saved timers from created timers allows users to remove a timer from their visible collection while keeping the original record on their PDS (which may be referenced by other users).

The record key is derived from the timer URI to ensure each timer can only be saved once per user.

```json
{
  "lexicon": 1,
  "id": "app.brew-haiku.savedTimer",
  "defs": {
    "main": {
      "type": "record",
      "key": "any",
      "record": {
        "type": "object",
        "required": ["timerUri", "savedAt"],
        "properties": {
          "timerUri": {
            "type": "string",
            "format": "at-uri",
            "description": "Reference to the app.brew-haiku.timer record"
          },
          "savedAt": {
            "type": "string",
            "format": "datetime"
          }
        }
      }
    }
  }
}
```

**Record Key Generation:**

The rkey is derived from the timer's AT URI to enforce one save per timer per user:

```typescript
// Example: at://did:plc:abc123/app.brew-haiku.timer/3jk5xyz
// → rkey: "3jk5xyz" (use the timer's rkey directly)

function getSavedTimerRkey(timerUri: string): string {
  // Extract the rkey from the timer URI
  const parts = timerUri.split('/');
  return parts[parts.length - 1];
}
```

Attempting to save the same timer twice will overwrite the existing record (effectively a no-op since the data is identical).

**Record Lifecycle:**
1. User creates a timer → `app.brew-haiku.timer` record created on their PDS
2. User saves the timer to their collection → `app.brew-haiku.savedTimer` record created with rkey matching the timer's rkey
3. User "removes" timer from their collection → `app.brew-haiku.savedTimer` record deleted, but `app.brew-haiku.timer` remains
4. Other users can still reference the original timer via its AT URI

---

## 6. Core User Flows

### 6.1 First-Time User Experience

1. **Splash Screen**: Minimalist logo with "Brew Haiku" text
2. **Onboarding Carousel** (3 screens):
   - "Transform your brew into a ritual"
   - "Stay present. No distractions."
   - "Complete your ritual. Write a haiku."
3. **Optional Sign In**: "Sign in with Bluesky" or "Continue without account"
4. **First Brew Setup**: Guided timer configuration

### 6.2 Daily Brewing Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Select    │────▶│   Input     │────▶│   Review    │
│   Vessel    │     │   Amounts   │     │   Recipe    │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Compose   │◀────│   Timer     │◀────│   Start     │
│   Haiku     │     │   Running   │     │   Ritual    │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│   Share     │────▶│   Complete  │
│   (optional)│     │             │
└─────────────┘     └─────────────┘
```

### 6.3 Brew Configuration

#### 6.3.1 Vessel Selection

Pre-configured vessels with sensible defaults:

| Vessel | Default Ratio | Default Time | Category |
|--------|---------------|--------------|----------|
| Hario V60 | 16:1 | 3:00 | Coffee |
| Chemex | 15:1 | 4:00 | Coffee |
| AeroPress | 12:1 | 2:00 | Coffee |
| French Press | 15:1 | 4:00 | Coffee |
| Gaiwan | 5:1 | 0:30 | Tea |
| Kyusu | 10:1 | 1:00 | Tea |
| Western Teapot | 50:1 | 3:00 | Tea |
| Grandpa Style | 20:1 | Variable | Tea |

#### 6.3.2 Ratio Calculator

User inputs dry weight (grams), app calculates water volume:

```
Water (ml) = Dry Weight (g) × Ratio
```

Real-time display updates as user adjusts values.

### 6.4 Timer Experience

#### 6.4.1 During Timer

- **Visual**: Custom-painted timer animation (steam rising / vessel filling)
- **Haiku Display**: PageView carousel with slow fade transitions
- **Interaction**: Heart button to "like" displayed haiku (haptic feedback)
- **Audio**: Optional gentle chime at step transitions

#### 6.4.2 Step Progression

For multi-step brews (e.g., pour-over):

1. Step name displayed prominently
2. Countdown for current step
3. Total time remaining shown smaller
4. Automatic progression with optional audio cue

### 6.5 Haiku Composition

#### 6.5.1 Soft Format (5/7/5)

The haiku composer uses a "soft format" approach that guides users toward 5/7/5 syllable structure without strict enforcement.

**Auto-Line Breaking Behavior:**
- As the user types, syllables are counted in real-time
- When a word is completed (space or punctuation) and the current line reaches or exceeds its target syllable count, the cursor automatically moves to the next line
- Line 1: Auto-breaks after reaching/exceeding 5 syllables
- Line 2: Auto-breaks after reaching/exceeding 7 syllables
- Line 3: No auto-break (final line)

**Manual Control:**
- Users can press Enter at any point to force a line break before the syllable target
- This allows for intentional short lines or artistic choices
- Backspace at the start of a line returns to the previous line

**Visual Feedback:**
```
Line 1: ████████░░░░░░░ 5/5 ✓
Line 2: ██████████░░░░░ 7/7 ✓
Line 3: ████████░░░░░░░ 5/5 ✓
```

Lines display current/target syllables with a progress indicator. Exceeding the target shows in a subtle warning color but doesn't prevent submission.

#### 6.5.2 Syllable Counting Algorithm

- Use CMU Pronouncing Dictionary for English
- Fallback: Vowel counting heuristic for unknown words
- Handle common contractions and edge cases
- Count is updated on each keystroke for responsive feedback

#### 6.5.3 Share Card Generation

Using Flutter's RepaintBoundary:

1. Render haiku with brew context in styled container
2. Export as PNG
3. Options: Share to Bluesky, Save to device, Copy text

---

## 7. Discovery & Social Features

### 7.1 Haiku Feed (Bluesky Custom Feed)

The haiku discovery feed is implemented as a standard Bluesky custom feed generator, allowing users to subscribe to it directly in their Bluesky client or view it in the Brew Haiku app.

#### 7.1.1 Feed Generator Implementation

**Feed URI**: `at://did:web:brew-haiku.app/app.bsky.feed.generator/haikus`

The backend implements the `app.bsky.feed.getFeedSkeleton` endpoint:

```typescript
// GET /xrpc/app.bsky.feed.getFeedSkeleton?feed=<uri>&limit=<n>&cursor=<cursor>
// Returns: { feed: [{ post: "at://..." }, ...], cursor?: string }
```

#### 7.1.2 Post Identification

Haiku posts are identified by the signature text appended when sharing from Brew Haiku:

```
[haiku text]

via @brew-haiku.app
```

The FirehoseService subscribes to the Bluesky firehose and indexes any `app.bsky.feed.post` records containing this signature.

#### 7.1.3 Ranking Algorithm

Posts are ranked using a weighted score combining popularity (likes) and recency:

```typescript
// Ranking formula
score = (LIKE_WEIGHT * likeCount) + (RECENCY_WEIGHT * recencyScore)

// Configurable constants
const LIKE_WEIGHT = 1.0;      // Importance of likes
const RECENCY_WEIGHT = 2.0;   // Importance of newness
const RECENCY_HALF_LIFE = 24; // Hours until recency score halves

// Recency calculation (exponential decay)
recencyScore = Math.pow(0.5, hoursAge / RECENCY_HALF_LIFE)
```

These constants are stored in configuration and can be tuned without code changes.

#### 7.1.4 Firehose Indexing

- FirehoseService maintains a persistent WebSocket connection to `bsky.network`
- Filters for `app.bsky.feed.post` create events
- Checks post text for "via @brew-haiku.app" suffix
- Indexes matching posts to SQLite with initial like_count of 0
- Periodically refreshes like counts for recent posts via AppView API

### 7.2 Timer Recipe Sharing

#### 7.2.1 Creating and Publishing

Authenticated users can create and publish timer recipes:

1. Configure a new timer (vessel, steps, ratio, etc.)
2. Save the timer → creates both `app.brew-haiku.timer` and `app.brew-haiku.savedTimer` records
3. Timer is now on the user's PDS and in their saved collection
4. Timer becomes eligible for indexing (has at least 1 save)

#### 7.2.2 Saving Other Users' Timers

Users can save timers created by others:

1. Find a timer via search or browsing
2. Tap "Save" → creates `app.brew-haiku.savedTimer` record referencing the original timer's AT URI
3. Timer appears in the user's collection
4. Save count is incremented for the original timer (affects search ranking)

#### 7.2.3 Removing Timers

When a user removes a timer from their collection:

- The `app.brew-haiku.savedTimer` record is deleted
- If the user created the timer, the original `app.brew-haiku.timer` record **remains** on their PDS
- Other users who saved the timer can still access it via the AT URI
- Save count is decremented; if it reaches 0, the timer is de-indexed from search

#### 7.2.4 Timer Search and Indexing

**Indexing Requirements:**
- Timers must have at least 1 save to be indexed in search
- When a user creates a timer, the auto-save counts as the first save
- Timers with 0 saves (creator removed it, no one else saved) are not searchable

**Firehose Indexing:**
- FirehoseService monitors for `app.brew-haiku.savedTimer` create/delete events
- On create: increment save count for referenced timer, add to index if first save
- On delete: decrement save count, remove from index if count reaches 0

**Search Ranking:**

```typescript
// Timer search ranking formula
score = (SAVE_WEIGHT * saveCount) + (RECENCY_WEIGHT * recencyScore)

// Configurable constants
const SAVE_WEIGHT = 1.0;       // Importance of saves
const RECENCY_WEIGHT = 0.5;    // Importance of newness (lower than haiku feed)
const RECENCY_HALF_LIFE = 168; // Hours (1 week) until recency score halves
```

#### 7.2.5 Discovering Recipes

- Full-text search powered by SQLite FTS5 (name, vessel, creator handle)
- Filter by brew type (tea/coffee) and step types (timed-only, includes indeterminate)
- Browse popular recipes (sorted by save count)
- Search ranking combines text relevance with save count popularity
- Results exclude timers with 0 saves

### 7.3 Interactions

| Action | Implementation | Storage |
|--------|----------------|---------|
| Like Haiku | app.bsky.feed.like record | User's PDS |
| Save Timer | app.brew-haiku.savedTimer record | User's PDS |
| Follow User | app.bsky.graph.follow | User's PDS |

---

## 8. Non-Functional Requirements

### 8.1 Performance

| Metric | Target |
|--------|--------|
| App cold start | < 2 seconds |
| Timer start latency | < 100ms |
| API response time | < 200ms (p95) |
| SQLite query time | < 10ms |
| Haiku feed load | < 1 second |

### 8.2 Reliability

- Backend uptime target: 99.5%
- Graceful degradation when offline (timer works without network)
- Local caching of essential data

### 8.3 Security

- OAuth tokens stored in platform secure storage
- No plaintext credential storage
- API rate limiting (100 req/min per IP)
- Input sanitization on all endpoints

### 8.4 Privacy

- Minimal data collection
- No analytics tracking beyond basic crash reporting
- Users control what gets posted to AT Protocol
- No data sold to third parties

### 8.5 Accessibility

- VoiceOver/TalkBack support
- Minimum touch target size: 44x44pt
- Color contrast ratios meet WCAG AA
- Timer audio cues for visually impaired users

### 8.6 Testing

#### 8.6.1 Frontend Testing (Flutter)

Uses the built-in `flutter_test` package.

| Test Type | Tool | Coverage Target |
|-----------|------|-----------------|
| Unit Tests | `flutter_test` | Core logic (syllable counting, timer state, ratio calculations) |
| Widget Tests | `flutter_test` | UI components in isolation |
| Integration Tests | `integration_test` | Full user flows (brew → haiku → share) |

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

**Key Test Areas:**
- Syllable counting algorithm accuracy
- Timer state transitions (running, interrupted, completed)
- Focus Guard lifecycle detection
- Ratio calculator correctness
- Haiku soft-format auto-line breaking logic

#### 8.6.2 Backend Testing (Bun)

Uses Bun's built-in test runner (`bun:test`).

| Test Type | Scope | Coverage Target |
|-----------|-------|-----------------|
| Unit Tests | Services, utilities | Effect services, ranking algorithms |
| Integration Tests | API endpoints | Full request/response cycles |
| Database Tests | SQLite operations | Indexing, queries, migrations |

```bash
# Run all tests
bun test

# Run with watch mode
bun test --watch

# Run specific test file
bun test src/services/feed.test.ts
```

**Key Test Areas:**
- Feed generator skeleton responses
- Timer search ranking algorithm
- Firehose event processing (savedTimer create/delete)
- Save count increment/decrement logic
- ATProto lexicon validation

#### 8.6.3 Test Data

- Use deterministic test fixtures for haikus and timers
- Mock ATProto/PDS interactions in unit tests
- Use in-memory SQLite for database tests

---

## 9. Future Considerations

The following features are explicitly out of scope for v1 but may be considered for future versions:

### 9.1 Potential v2 Features

- **Brew Journal**: Local history of all brews with notes
- **Community Challenges**: Weekly haiku themes
- **Widget Support**: iOS/Android home screen timer widget
- **Apple Watch / WearOS**: Companion app for wrist notifications
- **Advanced Analytics**: Personal brewing statistics

### 9.2 Potential Integrations

- Coffee/tea vendor partnerships for recipe presets
- Smart kettle integration (Fellow Stagg, Brewista)

---

## 10. Success Metrics

### 10.1 Key Performance Indicators

| Metric | Target (3 months) |
|--------|-------------------|
| Monthly Active Users | 1,000 |
| Avg. session duration | > 3 minutes |
| Brew completion rate | > 80% |
| Haiku composition rate | > 30% of completed brews |
| Bluesky auth adoption | > 50% of users |

### 10.2 Qualitative Goals

- Positive sentiment in AT Protocol community
- Featured in mindfulness/wellness app roundups
- User testimonials about improved brewing ritual

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| AT Protocol | Decentralized social networking protocol (Bluesky) |
| DID | Decentralized Identifier - unique user identity |
| PDS | Personal Data Server - user's AT Protocol data host |
| Lexicon | AT Protocol schema definition |
| Focus Guard | App feature preventing backgrounding during brew |
| Ritual | The complete brew + haiku experience |

---

## Appendix B: References

- [AT Protocol Documentation](https://atproto.com/docs)
- [Bluesky OAuth Specification](https://docs.bsky.app/docs/advanced-guides/oauth-client)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Effect Documentation](https://effect.website/docs)
- [Bun Documentation](https://bun.sh/docs)
- [Fly.io Documentation](https://fly.io/docs/)
