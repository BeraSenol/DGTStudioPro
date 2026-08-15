import AppKit
import Testing
@testable import DGTStudioPro

/// Renders a `Position` to PNG for attachments: a failing board assertion hands you two
/// rendered boards, not 64 sorted squares.
@MainActor
enum BoardAttachmentSupport {

    /// White on the bottom, a1 lower-left — the mirror's orientation.
    static func pngData(for position: Position) -> Data? {
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
    static func attach(_ position: Position, named name: String) {
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
