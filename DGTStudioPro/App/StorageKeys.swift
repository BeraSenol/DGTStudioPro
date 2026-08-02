//
//  StorageKeys.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/04/2026.
//

internal enum StorageKeys {
    internal static let boardStyle = "boardStyle"

    // Board coordinates (M-ux.3, D21′): the file letters and rank numbers
    // printed on the board frame. Absent reads as true — the
    // `autoConnectOnLaunch` semantics; the two read sites (SettingsView's
    // `@AppStorage` initial and `BoardView`'s own) must agree on that default.
    internal static let showBoardCoordinates = "showBoardCoordinates"

    // Board presentation (2 Aug 2026): the piece glide duration, in
    // seconds. Absent reads as `BoardPieceLayer.defaultDuration` at all
    // three read sites (the layer's own, SettingsView's slider, and
    // `GameNavigationCommands`' step throttle — review stepping is paced
    // to the glide), each spelled off the owning static so the number
    // lives exactly once — the `EngineConfiguration` arrangement. The
    // layer and the throttle clamp every read to
    // `BoardPieceLayer.durationRange` (0.1…1 s), so a hand-edited default
    // can't push the board into absurd motion.
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
    /// D48′ — the merged Players destination's ordering. Stored as
    /// `PlayersSortOrder.rawValue`; absent reads as `.rank` at the one
    /// `@AppStorage` site, which is the destination's default read.
    internal static let playersSortOrder = "playersSortOrder"

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
}
