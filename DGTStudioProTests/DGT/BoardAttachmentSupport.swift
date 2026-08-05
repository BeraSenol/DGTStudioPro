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
/// `@MainActor`: the PNG conversion below renders synchronously on the
/// calling thread, and AppKit drawing prefers main. Consuming tests
/// annotate themselves `@MainActor` individually — isolation is per
/// function, so their suites stay nonisolated for everything else.
/// (`glyph(for:)` is `nonisolated`: the drawing handler runs as a plain
/// nonisolated closure, and a pure switch has no business being
/// actor-bound anyway.)
@MainActor
internal enum BoardAttachmentSupport {

    /// White on the bottom, a1 lower-left — the mirror's orientation.
    ///
    /// Drawn through `NSImage(size:flipped:drawingHandler:)`, the modern
    /// replacement for the `lockFocus()`/`unlockFocus()` pair this used at
    /// first (deprecated since macOS 14; the 30 July audit's one warning
    /// burn). `flipped: false` keeps the y-up geometry the rank arithmetic
    /// below assumes; the handler runs when `tiffRepresentation` renders
    /// the image — synchronously, right here.
    internal static func pngData(for position: Position) -> Data? {
        let side: CGFloat = 44
        let size = NSSize(width: side * 8, height: side * 8)
        let image = NSImage(size: size, flipped: false) { _ in
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
            return true
        }

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

    private nonisolated static func glyph(for piece: Piece) -> String? {
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
