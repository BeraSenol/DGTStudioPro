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

    // New-game dialog defaults (M3.4): the recurring tags — event, site, and
    // the owner's own name on White — pre-fill the next dialog. Black is
    // deliberately *not* persisted: the opponent changes every game.
    internal static let defaultEvent = "defaultEvent"
    internal static let defaultSite = "defaultSite"
    internal static let defaultWhitePlayer = "defaultWhitePlayer"
}
