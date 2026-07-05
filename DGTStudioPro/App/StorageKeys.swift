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
}
