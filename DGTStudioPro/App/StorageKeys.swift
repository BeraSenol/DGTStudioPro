enum StorageKeys {
    static let boardStyle = "boardStyle"

    // Board coordinates. Absent reads true; the two read sites (SettingsView, BoardView)
    // must agree - documented twin.
    static let showBoardCoordinates = "showBoardCoordinates"

    // Glide duration, seconds. Absent reads `BoardPieceLayer.defaultDuration` at both read sites,
    // each spelled off the owning static so the number lives once.
    static let pieceAnimationDuration = "pieceAnimationDuration"

    // Seed guard for default smart tags: the flag, not tag count, so deleting all defaults sticks.
    static let didSeedDefaultSmartTags = "didSeedDefaultSmartTags"
    // One view mode for both collection destinations - browsing preference, not per-destination.
    // The two `.list` defaults are the documented twin.
    static let collectionViewMode = "collectionViewMode"

    /// What rank 1 means. Absent reads `.wins`. A new key, not the retired
    /// `playersSortOrder`: its stale rank/name values would read as an unknown method - a migration
    /// disguised as a coincidence.
    static let playersRanking = "playersRanking"

    // The two tables' column layouts. Two keys, not one: a column set is per-table. One
    // `@AppStorage` site each - no twins. Absent reads the shipped layout.
    static let libraryColumns = "libraryColumnCustomization"
    static let playersColumns = "playersColumnCustomization"

    // The converged stamp gating the two player backfills. Absent reads false - scan until
    // one clean pass. Cleared only by Erase Library, which retires the store the stamp described.
    static let playerBackfillsConverged = "playerBackfillsConverged"

    // New-game dialog defaults: pre-filled on open, written back on Start. Recurring tags only.
    // Built-in fallbacks for absent keys live at the one read site (`NewLiveGameSheet`).
    static let defaultEvent       = "defaultEvent"
    static let defaultSite        = "defaultSite"
    static let defaultWhitePlayer = "defaultWhitePlayer"

    // Launch auto-connect; absent reads true everywhere.
    static let autoConnectOnLaunch = "autoConnectOnLaunch"

    // Illegal-move sound. Absent reads true. **The twin is gone**: this used to be read in two
    // places - `SettingsView` via `@AppStorage` and the App's `onDesync` closure via a bare
    // `UserDefaults` lookup - each spelling its own `?? true`. It is now owned by `BoardSounds`
    // like every other cue, so the default is stated once, in that type's `init`. The key name is
    // kept as-is on purpose: renaming it would silently reset the preference of every existing
    // install to the default, which for an opt-out toggle means switching a sound back *on* for
    // anyone who had turned it off.
    static let illegalMoveSoundEnabled = "illegalMoveSoundEnabled"

    // The four board cues. Absent reads **true** for each. Single read site apiece -
    // `BoardSounds` owns the values and Settings binds to the properties, so unlike the key above
    // these have no twin to document. Four keys rather than one because four toggles were asked
    // for, and a single stored set would make "which cue is off" a decoding question.
    // `boardSoundSet` lived here and is gone with `BoardSoundSet`: the app ships one set of
    // sounds, so there is nothing to store. The key is deliberately **not** cleaned up on launch -
    // a stale string in an existing install's defaults is inert, and code that deletes keys it no
    // longer understands is code that will one day delete a key it does.
    static let moveSoundEnabled      = "moveSoundEnabled"
    static let captureSoundEnabled   = "captureSoundEnabled"
    static let castleSoundEnabled    = "castleSoundEnabled"
    static let promoteSoundEnabled   = "promoteSoundEnabled"
    static let checkSoundEnabled     = "checkSoundEnabled"
    static let checkmateSoundEnabled = "checkmateSoundEnabled"

    // The two lifecycle cues. Separate keys rather than one shared "game sounds" flag, for the
    // same reason the six above are separate: one flag per cue is what makes the gate a lookup
    // instead of a rule, and a shared flag would make "start is on, end is off" unrepresentable
    // for no saving. Absent reads **true**, like every cue.
    static let gameStartSoundEnabled = "gameStartSoundEnabled"
    static let gameEndSoundEnabled   = "gameEndSoundEnabled"

    // Idle-sleep play gate. Absent reads **true**. Single read site - `SleepInhibitor` owns
    // the value; Settings binds to the property. The shape the twins above should eventually take.
    static let preventSleepDuringPlay = "preventSleepDuringPlay"

    // The analysis sleep gate: same semantics, same single-read-site shape. Two keys because
    // the causes share nothing; renaming would silently reset the stored choice.
    static let preventSleepDuringAnalysis = "preventSleepDuringAnalysis"

    // Collapsed inspector sections: the *collapsed* set is stored, so "default open" is a
    // property of the representation, not a fourth `?? true`.
    static let collapsedInspectorSections = "collapsedInspectorSections"

    // Engine options. Absent reads `EngineConfiguration.default`, clamped on every read.
    static let analysisDepth = "analysisDepth"
    static let engineHashMB  = "engineHashMB"
    static let engineThreads = "engineThreads"

    // Syzygy tablebases: four options plus a location as two keys (bookmark opens the folder; path
    // is a label Settings renders without holding a scoped resource). Defaults stated once, in the
    // owning type's `init`. Icon size / grid spacing follow the same owned-value shape.
    static let collectionIconSize    = "collectionIconSize"
    static let collectionGridSpacing = "collectionGridSpacing"
    static let librarySort           = "librarySort"
    static let playersSort           = "playersSort"
    /// Recent-games caps in the Players surfaces: 3 by default (17 Aug 2026, by request),
    /// 5 and 10 a menu away. One key, read by the inspector section and the columns detail,
    /// so the two lists always agree on "recent".
    static let playersRecentGames    = "playersRecentGames"
    /// The evaluation bar's spoiler switch (17 Aug 2026): hidden draws a flat grey bar with no
    /// score. App-wide and persisted deliberately - a reader replaying a game they haven't seen
    /// wants it off until they choose otherwise, and wants that to survive the next launch.
    static let evaluationBarHidden   = "evaluationBarHidden"

    static let syzygyBookmark    = "syzygyBookmark"
    static let syzygyDisplayPath = "syzygyDisplayPath"
    static let syzygyProbeDepth  = "syzygyProbeDepth"
    static let syzygy50MoveRule  = "syzygy50MoveRule"
    static let syzygyProbeLimit  = "syzygyProbeLimit"
}
