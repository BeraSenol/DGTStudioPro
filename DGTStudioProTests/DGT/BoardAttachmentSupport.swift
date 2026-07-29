//
//  BoardAttachmentSupport.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/07/2026.
//

import AppKit
import Testing
@testable import DGTStudioPro

/// Renders a `Position` to PNG data for Swift Testing attachments — the
/// M1 item-19 tooling: a failing board assertion should hand you two
/// rendered boards, not 64 sorted squares to diff by eye. PNG `Data` is
/// attached rather than an image type deliberately: byte-buffer
/// attachables are the attachments feature's floor (shipping 6.3), so
/// this takes no dependency on the AppKit attachable overlay, and Xcode
/// previews a `.png`-named attachment either way.
///
/// `@MainActor`: `NSImage.lockFocus` drawing belongs on the main thread.
/// Consuming tests annotate themselves `@MainActor` individually —
/// isolation is per function, so their suites stay nonisolated for
/// everything else.
@MainActor
internal enum BoardAttachmentSupport {

    /// White on the bottom, a1 lower-left — the mirror's orientation.
    internal static func pngData(for position: Position) -> Data? {
        let side: CGFloat = 44
        let image = NSImage(size: NSSize(width: side * 8, height: side * 8))
        image.lockFocus()

        for square in 0..<64 {
            let file = square % 8
            let rank = square / 8
            let rect = NSRect(
                x: CGFloat(file) * side,
                y: CGFloat(rank) * side,
                width: side, height: side
            )
            let isLight = (file + rank) % 2 == 1
            (isLight
             ? NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.79, alpha: 1)
             : NSColor(calibratedRed: 0.72, green: 0.58, blue: 0.44, alpha: 1)).setFill()
            rect.fill()

            guard let glyph = Self.glyph(for: position[square]) else { continue }
            let text = NSAttributedString(
                string: glyph,
                attributes: [
                    .font: NSFont.systemFont(ofSize: side * 0.72),
                    .foregroundColor: NSColor.black,
                ]
            )
            let textSize = text.size()
            text.draw(at: NSPoint(
                x: rect.midX - textSize.width / 2,
                y: rect.midY - textSize.height / 2
            ))
        }

        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Records a rendered board as a PNG attachment. Call on the failure
    /// path only — a green run should attach nothing.
    internal static func attach(_ position: Position, named name: String) {
        guard let png = pngData(for: position) else { return }
        Attachment.record(png, named: name)
    }

    private static func glyph(for piece: Piece) -> String? {
        guard let color = piece.color, let type = piece.type else { return nil }
        switch (color, type) {
        case (.white, .king):   return "♔"
        case (.white, .queen):  return "♕"
        case (.white, .rook):   return "♖"
        case (.white, .bishop): return "♗"
        case (.white, .knight): return "♘"
        case (.white, .pawn):   return "♙"
        case (.black, .king):   return "♚"
        case (.black, .queen):  return "♛"
        case (.black, .rook):   return "♜"
        case (.black, .bishop): return "♝"
        case (.black, .knight): return "♞"
        case (.black, .pawn):   return "♟"
        }
    }
}
