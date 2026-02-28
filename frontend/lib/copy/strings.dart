class S {
  S._();

  // Loading
  static const loading = 'Steeping...';
  static const gathering = 'Gathering...';

  // Network / Offline
  static const networkLost =
      'The connection drifted away. Your brew continues.';
  static const offlineMode =
      'Brewing without the cloud. Everything you need is here.';
  static const offlineSearch = 'Search needs a connection. Browse what\u2019s here.';
  static const offlineComposer =
      'Your haiku will find its way when you\u2019re back online.';

  // Errors
  static const saveFailed = 'That one slipped through. We\u2019ll try again shortly.';
  static const loadFailed = 'The tea house is quiet right now. Try again in a moment.';
  static const postFailed =
      'Your haiku is resting. We\u2019ll send it along shortly.';
  static const genericError = 'Something shifted. Give it another moment.';

  // Auth
  static const sessionExpired =
      'Your session has settled. Sign in again when you\u2019re ready.';
  static const signInToPost = 'Sign in to share your words.';
  static const signInToSave = 'Sign in to keep this one close.';
  static const signInToCreate = 'Sign in to share your recipe.';
  static const signInTitle = 'Sign in';
  static const signInButton = 'Continue with Bluesky';
  static const signOut = 'Sign out';
  static const handleHint = 'your.handle.bsky.social';

  // Empty states
  static const searchEmpty = 'Nothing here yet. Try different words.';
  static const savedEmpty = 'Your saved recipes will gather here.';
  static const activityEmpty = 'A quiet moment. Your friends\u2019 brews will appear here.';
  static const feedEmpty = 'No haiku just yet. They\u2019ll arrive as you wait.';

  // Brew
  static const brewComplete = 'Your brew is ready.';
  static const brewAgain = 'Brew again';
  static const backToTimers = 'Back to recipes';
  static const startBrew = 'Begin';
  static const tapWhenDone = 'Done';

  // Haiku composer
  static const composeHaiku = 'A moment for words';
  static const composerHint = 'Write your haiku...';
  static const postHaiku = 'Share';
  static const notNow = 'Another time';
  static const syllablesRemaining = 'syllables to go';

  // Activity
  static const activityLocked =
      'Brew and share a haiku to see what others are making.';
  static const activityTitle = 'Activity';

  // Timer selection
  static const browse = 'Browse';
  static const search = 'Search';
  static const saved = 'Saved';
  static const searchHint = 'Search recipes...';

  // Focus guard
  static const returnToRitual = 'Welcome back';
  static const longPressToReturn = 'Hold to continue';

  // Brew config
  static const configTitle = 'Your Brew';

  // Settings
  static const settings = 'Settings';
}
