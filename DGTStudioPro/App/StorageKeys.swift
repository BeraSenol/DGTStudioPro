//
//  StorageKeys.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/04/2026.
//

internal enum StorageKeys {
    internal static let boardStyle = "boardStyle"
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

    // Engine configuration (M11 review): the three Stockfish options the
    // app controls. Absent keys read as `EngineConfiguration.default`
    // (18 / 128 MB / 1 thread), clamped on every read — see that type for
    // the why, including why `UserDefaults.register` was rejected.
    internal static let analysisDepth = "analysisDepth"
    internal static let engineHashMB  = "engineHashMB"
    internal static let engineThreads = "engineThreads"
}
