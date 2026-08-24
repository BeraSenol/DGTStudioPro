/// Every `UserDefaults` key the app writes.
///
/// **A constant's name is its stored string**, with five exceptions, each noted where it sits.
///
/// **Never rename a key** - the stored value is orphaned and the preference silently resets.
/// **Retired keys are left inert**: code that deletes keys it no longer understands will one day
/// delete one it does.
enum StorageKeys {
    static let boardStyle = "boardStyle"
    
    // Absent reads true. A **twin** - `SettingsView` and `BoardView` each state that default.
    static let showBoardCoordinates = "showBoardCoordinates"
    
    // Seconds; both read sites take the default from `BoardPieceLayer`.
    static let pieceAnimationDuration = "pieceAnimationDuration"
    
    // The flag, not a tag count, so deleting all the default tags sticks.
    static let didSeedDefaultSmartTags = "didSeedDefaultSmartTags"
    
    // View mode, icon size, spacing and sort are all per destination. `CollectionViewOptions` owns
    // them rather than `@AppStorage` reading them here, which is what makes the legacy fallback
    // below possible: an `@AppStorage` default must be a literal, so it can never read a retired key.
    static let libraryViewMode = "libraryViewMode"
    static let playersViewMode = "playersViewMode"
    
    // Library-only, deliberately not a pair: the Players card has no document sheet to inscribe.
    static let libraryCardInscription = "libraryCardInscription"
    
    // Read-only fallbacks for the pair that replaced them, so a tuned grid survives the split.
    // Deletable once no install predates it.
    static let legacyCollectionViewMode    = "collectionViewMode"
    static let legacyCollectionIconSize    = "collectionIconSize"
    static let legacyCollectionGridSpacing = "collectionGridSpacing"
    
    /// What rank 1 means; absent reads `.wins`. A new key rather than the retired
    /// `playersSortOrder`, whose stale values would decode as an unknown method.
    static let playersRanking = "playersRanking"
    
    // `Customization` because that is what `TableColumnCustomization` wrote, and the layouts
    // already shipped under these names.
    static let libraryColumns = "libraryColumnCustomization"
    static let playersColumns = "playersColumnCustomization"
    
    // Gates the two player backfills. Absent reads false; cleared only by Erase Library.
    static let playerBackfillsConverged = "playerBackfillsConverged"
    
    // New-game dialog: recurring tags only, pre-filled on open and written back on Start.
    // Fallbacks live at the one read site, `NewLiveGameSheet`.
    static let defaultEvent       = "defaultEvent"
    static let defaultSite        = "defaultSite"
    static let defaultWhitePlayer = "defaultWhitePlayer"
    
    // Absent reads true. A **twin** - `SettingsView` and `autoConnectAtLaunch()` each state it.
    static let autoConnectOnLaunch = "autoConnectOnLaunch"
    
    // The nine cue gates. Absent reads **true** for each, stated once in `BoardSounds.init`. One
    // key per cue: a stored set would make "which cue is off" a decoding question.
    static let illegalMoveSoundEnabled = "illegalMoveSoundEnabled"
    static let moveSoundEnabled        = "moveSoundEnabled"
    static let captureSoundEnabled     = "captureSoundEnabled"
    static let castleSoundEnabled      = "castleSoundEnabled"
    static let promoteSoundEnabled     = "promoteSoundEnabled"
    static let checkSoundEnabled       = "checkSoundEnabled"
    static let checkmateSoundEnabled   = "checkmateSoundEnabled"
    static let gameStartSoundEnabled   = "gameStartSoundEnabled"
    static let gameEndSoundEnabled     = "gameEndSoundEnabled"
    
    // Absent reads **true**; `SleepInhibitor` states both.
    static let preventSleepDuringPlay     = "preventSleepDuringPlay"
    static let preventSleepDuringAnalysis = "preventSleepDuringAnalysis"
    
    // The *collapsed* set is stored, so "default open" is a property of the representation.
    static let collapsedInspectorSections = "collapsedInspectorSections"
    
    // Absent reads `EngineConfiguration.default`, clamped on every read.
    static let analysisDepth = "analysisDepth"
    static let engineHashMB  = "engineHashMB"
    static let engineThreads = "engineThreads"
    
    static let libraryIconSize       = "libraryIconSize"
    static let playersIconSize       = "playersIconSize"
    static let libraryGridSpacing    = "libraryGridSpacing"
    static let playersGridSpacing    = "playersGridSpacing"
    static let librarySort           = "librarySort"
    static let playersSort           = "playersSort"
    /// One key, read by the inspector section and the columns detail, so the two lists agree on
    /// what "recent" means.
    static let playersRecentGames    = "playersRecentGames"
    /// The evaluation bar's spoiler switch. App-wide and persisted deliberately: a reader replaying
    /// an unseen game wants it off until they choose otherwise, and wants that to last.
    static let evaluationBarHidden   = "evaluationBarHidden"
    
    // One Syzygy location as **two** keys: the bookmark opens the folder, the path is a label
    // Settings renders without holding a scoped resource. `syzygy50MoveRule` mirrors Stockfish's
    // own option name - that spelling belongs to the engine, not to this file.
    static let syzygyBookmark    = "syzygyBookmark"
    static let syzygyDisplayPath = "syzygyDisplayPath"
    static let syzygyProbeDepth  = "syzygyProbeDepth"
    static let syzygy50MoveRule  = "syzygy50MoveRule"
    static let syzygyProbeLimit  = "syzygyProbeLimit"
}
