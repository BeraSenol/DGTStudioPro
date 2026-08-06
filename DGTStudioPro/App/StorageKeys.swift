internal enum StorageKeys {
    internal static let boardStyle = "boardStyle"

    // Board coordinates (M-ux.3, D21′): the file letters and rank numbers
    // printed on the board frame. Absent reads as true — the
    // `autoConnectOnLaunch` semantics; the two read sites (SettingsView's
    // `@AppStorage` initial and `BoardView`'s own) must agree on that default.
    internal static let showBoardCoordinates = "showBoardCoordinates"

    // Board presentation (2 Aug 2026): the piece glide duration, in
    // seconds. Absent reads as `BoardPieceLayer.defaultDuration` at both
    // read sites (the layer's own and SettingsView's slider), each spelled
    // off the owning static so the number lives exactly once — the
    // `EngineConfiguration` arrangement. The layer clamps every read to
    // `BoardPieceLayer.durationRange` (0.1…1 s), so a hand-edited default
    // can't push the board into absurd motion.
    //
    // Was three sites for one day: `GameNavigationCommands` read it to pace
    // ←/→ stepping to the glide, and that throttle was removed 3 Aug 2026.
    // Corrected here rather than left to decay, because a count of read
    // sites is exactly the kind of claim that stays plausible long after it
    // stops being true.
    internal static let pieceAnimationDuration = "pieceAnimationDuration"

    // First-run seed guard for the default smart tags (M-prs.5): the flag
    // — not tag count — decides, so deleting all defaults sticks.
    internal static let didSeedDefaultSmartTags = "didSeedDefaultSmartTags"
    // One view mode for both collection destinations: the last mode used
    // anywhere is the mode everywhere — switch the Library to icons and
    // Players opens in icons. A view mode is a preference about *browsing*,
    // not about a destination, which is the same argument that kept D45′'s
    // collapse state out of `TabState`. Replaces the per-destination
    // `libraryViewMode` / `playersViewMode` pair; both stored values join
    // `rankingsViewMode` (retired with its destination, D48′) in existing
    // defaults, unread — accepted rather than migrated: a leftover key
    // costs nothing, a cleanup pass is machinery the leftover doesn't earn.
    // Absent reads as `.list`; the two `@AppStorage` read sites (Library's
    // and Players') must agree on that default — the documented twin.
    internal static let collectionViewMode = "collectionViewMode"
    // `playersSortOrder` was here until 5 Aug 2026 — D48′'s rank/name toggle,
    // stored as a `PlayersSortOrder` raw value. Removed with the picker it
    // backed: the Players list sorts by column header now, and that sort is
    // deliberately session-only, so there is nothing left to persist.
    //
    // The stored value lingers in `UserDefaults` unread, on `collectionViewMode`'s
    // precedent four lines up: a leftover key costs nothing and a migration is
    // machinery the leftover does not earn. Worth one line rather than none,
    // because this namespace now carries **two** dead keys and a third would be
    // the point at which "unread leftover" stops being a footnote and starts
    // being a pattern that needs a sweep.

    /// D62′ — how the ladder is ordered, which is to say what rank 1 means.
    /// Stored as `PlayerRanking.rawValue`; absent reads as `.wins`, which is
    /// D11′'s order and the one the app shipped with for months.
    ///
    /// **A new key rather than the retired `playersSortOrder`**, deliberately:
    /// that one held a *sort* (`rank` / `name`) and its stored values are still
    /// sitting in defaults unread. Reusing the name would read a stale `"name"`
    /// as an unknown ranking method on the first launch after this ships, and
    /// silently fall back — a migration disguised as a coincidence.
    ///
    /// Persisted where the column sort deliberately is not, and the difference
    /// is the point: a sort is the question being asked right now, while a
    /// ranking method is a standing statement about what the ladder measures.
    internal static let playersRanking = "playersRanking"

    // The two list-mode tables' column layouts — which columns are shown,
    // in what order, at what width. **Two keys, not one**, deliberately and
    // for the opposite reason `collectionViewMode` is one: a view mode is a
    // preference about browsing and travels between destinations, while a
    // column layout is a statement about *these columns*, and the two tables
    // share none. `TableColumnCustomization` is generic over its row type, so
    // one key could not have typed both anyway — but the reason is the
    // product one, not the compiler's.
    //
    // Each has exactly one `@AppStorage` site (the table that owns it), so
    // neither is a documented twin. Absent reads as the shipped layout, which
    // is a property of the representation rather than a default anyone has to
    // restate: an empty customization means "nothing customized", the same
    // trick D45′ uses by storing the *collapsed* set.
    internal static let libraryColumns = "libraryColumnCustomization"
    internal static let playersColumns = "playersColumnCustomization"

    // New-game dialog persisted defaults (M3.4): pre-filled on open,
    // written back on Start. Deliberately just the recurring tags.
    internal static let defaultEvent       = "defaultEvent"
    internal static let defaultSite        = "defaultSite"
    internal static let defaultWhitePlayer = "defaultWhitePlayer"

    // DGT board connection (M7): the launch auto-connect preference. An
    // absent `autoConnectOnLaunch` reads as true everywhere (the roadmap
    // default). `rememberedDevicePath` / `rememberedDeviceName` retired
    // 2 Aug 2026 with the device picker — the board is
    // `DGTConnection.onlyBoardPath`, a constant, and a constant needs no
    // memory; the stored values linger in existing defaults, unread (the
    // `rankingsViewMode` stance).
    internal static let autoConnectOnLaunch = "autoConnectOnLaunch"

    // Live play (M-ux.1, D13′): the illegal-move alert sound. An absent key
    // reads as true everywhere — the `autoConnectOnLaunch` semantics; the
    // two read sites (SettingsView's `@AppStorage` initial and the App's
    // `onDesync` closure) must agree on that default.
    internal static let illegalMoveSoundEnabled = "illegalMoveSoundEnabled"

    // Live play (D25′): the idle-sleep gate. Absent reads as **true** — the
    // `autoConnectOnLaunch` semantics, preserving D14′'s pre-toggle
    // behaviour. Unlike every other default above, this one has a *single*
    // read site: `SleepInhibitor` owns the value as an observable property
    // and Settings binds to that property, so there is no twin to keep in
    // step. That's the shape the other three should eventually take.
    internal static let preventSleepDuringPlay = "preventSleepDuringPlay"

    // Inspector chrome (M8, D45′): the sections the user has folded shut,
    // as an array of `InspectorSection` raw values. The *collapsed* ones are
    // stored, not the expanded ones, which is what makes "sections default
    // open" a property of the representation rather than a fourth `?? true`
    // on this page — an absent key and an empty set are the same state. The
    // value has an owning type (`InspectorSectionCollapse`), so like
    // `preventSleepDuringPlay` above it has no twin read site.
    internal static let collapsedInspectorSections = "collapsedInspectorSections"

    // Engine configuration (M11 review): the three Stockfish options the
    // app controls. Absent keys read as `EngineConfiguration.default`
    // (18 / 128 MB / 1 thread), clamped on every read — see that type for
    // the why, including why `UserDefaults.register` was rejected.
    internal static let analysisDepth = "analysisDepth"
    internal static let engineHashMB  = "engineHashMB"
    internal static let engineThreads = "engineThreads"

    // Syzygy endgame tablebases (7 Aug 2026). Four options plus a location,
    // and the location is two keys rather than one for a reason argued at
    // `SyzygyLocation`: the bookmark is the thing that opens the folder, the
    // path is a label Settings can render without holding a scoped resource
    // open on every body pass.
    //
    // Absent keys read as Stockfish's own defaults — probe depth 1, 50-move
    // rule on, probe limit 7 — which is the same "absent means the documented
    // default" contract the three engine keys above have, and here it also
    // means an app that has never been told about tablebases sends nothing
    // about them.
    internal static let syzygyBookmark    = "syzygyBookmark"
    internal static let syzygyDisplayPath = "syzygyDisplayPath"
    internal static let syzygyProbeDepth  = "syzygyProbeDepth"
    internal static let syzygy50MoveRule  = "syzygy50MoveRule"
    internal static let syzygyProbeLimit  = "syzygyProbeLimit"
}
