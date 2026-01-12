# Brew Haiku

A mindful tea and coffee brewing timer app with haiku poetry, powered by Bluesky's AT Protocol.

## Overview

Brew Haiku transforms your daily brewing ritual into a moment of mindfulness. The app guides you through timed brew steps while encouraging presence and focus. After completing your brew, compose a haiku to capture the moment and share it with the Brew Haiku community on Bluesky.

### Features

- **Guided Brewing Timers**: Pre-configured recipes for coffee (V60, Chemex, AeroPress, French Press) and tea (Gaiwan, Kyusu, Western Teapot)
- **Ratio Calculator**: Real-time water calculation based on coffee/tea weight and ratio
- **Focus Guard**: Tracks interruptions to encourage mindful presence during brewing
- **Haiku Composer**: Write and share haikus with syllable counting assistance
- **Bluesky Integration**: OAuth authentication, post haikus, and browse the community feed

## Project Structure

```
brew-haiku/
├── backend/           # Bun + Effect backend
│   ├── src/
│   │   ├── services/  # Effect service layers
│   │   ├── routes/    # HTTP route handlers
│   │   └── db/        # SQLite migrations
│   └── test/          # Bun tests
├── frontend/          # Flutter mobile app
│   ├── lib/
│   │   ├── providers/ # Riverpod state management
│   │   ├── screens/   # Screen widgets
│   │   ├── services/  # API and auth services
│   │   └── theme/     # Design system
│   └── test/          # Flutter tests
└── lexicons/          # ATProto lexicon definitions
```

## Prerequisites

### Backend
- [Bun](https://bun.sh/) v1.0 or later

### Frontend
- [Flutter](https://flutter.dev/) 3.2.0 or later
- iOS: Xcode 14+ (for iOS development)
- Android: Android Studio with Android SDK (for Android development)

## Running Locally

### Backend

```bash
cd backend

# Install dependencies
bun install

# Run in development mode (with hot reload)
bun run dev

# Or run in production mode
bun run start
```

The backend server runs on `http://localhost:3000` by default.

#### Backend Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /.well-known/did.json` | DID document for feed generator |
| `GET /resolve/:handle` | Resolve Bluesky handle to DID |
| `GET /timers` | List indexed timers |
| `GET /timers/:id` | Get timer by ID |
| `GET /timers/search` | Search timers with FTS5 |
| `POST /auth/callback` | OAuth callback handler |
| `GET /xrpc/app.bsky.feed.getFeedSkeleton` | Feed generator |
| `GET /xrpc/app.bsky.feed.describeFeedGenerator` | Feed description |

### Frontend

```bash
cd frontend

# Install dependencies
flutter pub get

# Run on iOS Simulator
flutter run -d ios

# Run on Android Emulator
flutter run -d android

# Run on connected device
flutter run
```

#### Environment Setup

For Bluesky OAuth to work, you'll need to configure the OAuth client. The app uses `flutter_secure_storage` for token persistence.

## Testing

### Backend Tests

```bash
cd backend

# Run all tests
bun test

# Run tests in watch mode
bun test --watch

# Run a specific test file
bun test test/database.test.ts
```

### Frontend Tests

```bash
cd frontend

# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run a specific test file
flutter test test/screens/brew_config_screen_test.dart

# Run tests matching a pattern
flutter test --name "displays ratio calculator"
```

## Development

### Code Style

- **Backend**: TypeScript with Effect for functional effects
- **Frontend**: Dart with Riverpod for state management

### Key Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| Backend Runtime | Bun | Fast JavaScript runtime with native SQLite |
| Backend Framework | Effect | Type-safe functional effects |
| Backend Database | SQLite + FTS5 | Full-text search for timers |
| Frontend Framework | Flutter | Cross-platform mobile |
| State Management | Riverpod | Reactive state with providers |
| Authentication | Bluesky OAuth | AT Protocol integration |

### ATProto Lexicons

Custom lexicons are defined in `lexicons/`:

- `app.brew-haiku.timer` - Timer/recipe records
- `app.brew-haiku.savedTimer` - Saved timer references

## Architecture

### Timer State Machine

```
notStarted → running → stepComplete → running → ... → completed
                ↓                        ↓
          waitingForUser           waitingForUser
          (indeterminate)          (indeterminate)
```

### Focus Guard

The Focus Guard tracks app backgrounding during active brews:
- Timer continues running when app is backgrounded
- Interruptions are counted
- "Ritual Interrupted" overlay requires intentional return

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## Links

- [Bluesky](https://bsky.app)
- [AT Protocol](https://atproto.com)
- [Flutter](https://flutter.dev)
- [Effect](https://effect.website)
