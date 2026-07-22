//
//  StorageKeys.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/04/2026.
//

internal enum StorageKeys {
    internal static let boardStyle = "boardStyle"
    
    // First-run seed guard for the default smart tags (M-prs.5): the flag
    // — not tag count — decides, so deleting all defaults sticks.
    internal static let didSeedDefaultSmartTags = "didSeedDefaultSmartTags"
    internal static let libraryViewMode = "libraryViewMode"
    internal static let playersViewMode = "playersViewMode"
    internal static let rankingsViewMode = "rankingsViewMode"
    
    // New-game dialog persisted defaults (M3.4): pre-filled on open,
    // written back on Start. Deliberately just the recurring tags.
    internal static let defaultEvent       = "defaultEvent"
    internal static let defaultSite        = "defaultSite"
    internal static let defaultWhitePlayer = "defaultWhitePlayer"
    
    // DGT board connection (M7): the last successfully connected device —
    // path is the stable identity, the name rides along for logs/UI — plus
    // the launch auto-connect preference. Written by `DGTConnection` on the
    // `.connected` transition; read by `autoConnectAtLaunch()`. An absent
    // `autoConnectOnLaunch` reads as true everywhere (the roadmap default).
    internal static let rememberedDevicePath = "rememberedDevicePath"
    internal static let rememberedDeviceName = "rememberedDeviceName"
    internal static let autoConnectOnLaunch  = "autoConnectOnLaunch"
    
    // Live play (M-ux.1, D13′): the illegal-move alert sound. An absent key
    // reads as true everywhere — the `autoConnectOnLaunch` semantics; the
    // two read sites (SettingsView's `@AppStorage` initial and the App's
    // `onDesync` closure) must agree on that default.
    internal static let illegalMoveSoundEnabled = "illegalMoveSoundEnabled"
    
    // Engine configuration (M11 review): the three Stockfish options the
    // app controls. Absent keys read as `EngineConfiguration.default`
    // (18 / 128 MB / 1 thread), clamped on every read — see that type for
    // the why, including why `UserDefaults.register` was rejected.
    internal static let analysisDepth = "analysisDepth"
    internal static let engineHashMB  = "engineHashMB"
    internal static let engineThreads = "engineThreads"
}
