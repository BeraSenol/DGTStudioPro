enum StorageKeys {
    static let boardStyle = "boardStyle"

    // Board coordinates (D21′). Absent reads true; the two read sites (SettingsView, BoardView)
    // must agree — documented twin.
    static let showBoardCoordinates = "showBoardCoordinates"

    // Glide duration, seconds. Absent reads `BoardPieceLayer.defaultDuration` at both read sites,
    // each spelled off the owning static so the number lives once.
    static let pieceAnimationDuration = "pieceAnimationDuration"

    // Seed guard for default smart tags: the flag, not tag count, so deleting all defaults sticks.
    static let didSeedDefaultSmartTags = "didSeedDefaultSmartTags"
    // One view mode for both collection destinations — browsing preference, not per-destination.
    // The two `.list` defaults are the documented twin.
    static let collectionViewMode = "collectionViewMode"

    /// D62′ — what rank 1 means. Absent reads `.wins` (D11′). A new key, not the retired
    /// `playersSortOrder`: its stale rank/name values would read as an unknown method — a migration
    /// disguised as a coincidence.
    static let playersRanking = "playersRanking"

    // The two tables' column layouts. Two keys, not one: a column set is per-table. One
    // `@AppStorage` site each — no twins. Absent reads the shipped layout.
    static let libraryColumns = "libraryColumnCustomization"
    static let playersColumns = "playersColumnCustomization"

    // The converged stamp gating the two player backfills (D75′). Absent reads false — scan until
    // one clean pass. Cleared only by Erase Library, which retires the store the stamp described.
    static let playerBackfillsConverged = "playerBackfillsConverged"

    // New-game dialog defaults: pre-filled on open, written back on Start. Recurring tags only.
    static let defaultEvent       = "defaultEvent"
    static let defaultSite        = "defaultSite"
    static let defaultWhitePlayer = "defaultWhitePlayer"

    // Launch auto-connect; absent reads true everywhere.
    static let autoConnectOnLaunch = "autoConnectOnLaunch"

    // Illegal-move sound (D13′). Absent reads true; SettingsView and the App's `onDesync` closure
    // are the documented twin.
    static let illegalMoveSoundEnabled = "illegalMoveSoundEnabled"

    // The four board cues (D81′). Absent reads **true** for each. Single read site apiece —
    // `BoardSounds` owns the values and Settings binds to the properties, so unlike the key above
    // these have no twin to document. Four keys rather than one because four toggles were asked
    // for, and a single stored set would make "which cue is off" a decoding question.
    /// Which sample set the cues come from (D82′). Absent reads `.wood` — the set that shipped
    /// first, so an existing install hears what it heard yesterday. An unknown stored value falls
    /// back to the same default rather than failing, which is what makes retiring a set safe.
    static let boardSoundSet = "boardSoundSet"

    static let moveSoundEnabled      = "moveSoundEnabled"
    static let captureSoundEnabled   = "captureSoundEnabled"
    static let checkSoundEnabled     = "checkSoundEnabled"
    static let checkmateSoundEnabled = "checkmateSoundEnabled"

    // Idle-sleep play gate (D25′). Absent reads **true**. Single read site — `SleepInhibitor` owns
    // the value; Settings binds to the property. The shape the twins above should eventually take.
    static let preventSleepDuringPlay = "preventSleepDuringPlay"

    // The analysis sleep gate (D66′): same semantics, same single-read-site shape. Two keys because
    // the causes share nothing; renaming would silently reset the stored choice (the D36′ trap).
    static let preventSleepDuringAnalysis = "preventSleepDuringAnalysis"

    // Collapsed inspector sections (D45′): the *collapsed* set is stored, so "default open" is a
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

    static let syzygyBookmark    = "syzygyBookmark"
    static let syzygyDisplayPath = "syzygyDisplayPath"
    static let syzygyProbeDepth  = "syzygyProbeDepth"
    static let syzygy50MoveRule  = "syzygy50MoveRule"
    static let syzygyProbeLimit  = "syzygyProbeLimit"
}
