//
//  EvaluationBarView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/07/2026.
//

import SwiftUI

/// The vertical evaluation bar beside the review board (M3, D33′). Dumb by
/// design: all semantics live in `EvaluationBarReading` (suited); this view
/// owns only geometry — which end is "near" — and the board-material
/// palette, `style.light` for white's share against `style.dark`, the same
/// pairing the inspector graph fills with.
///
/// D33′'s orientation rule: **the bottom tracks the near player.** White's
/// share grows from the bottom under the default perspective and from the
/// top when the board is flipped, so the bar always reads physically —
/// toward whoever is winning on your side of the board. The reading itself
/// stays white-relative (the label's sign never flips; `+1.5` means white
/// is better from either seat).
///
/// The always-visible tip label (D33′, over hover-only and none) sits in a
/// fixed slot *below* the bar rather than floating inside it: inside, a
/// thin losing share swallows the text or forces a contrast dance; a fixed
/// slot never moves, never overlaps, and reads in both orientations.
///
/// Rendered only beside an analysed archived game — presence is
/// `BoardDestination`'s guard, absence-not-a-50/50-lie — and never on the
/// live surface (no live engine eval, assumed-never).
internal struct EvaluationBarView: View {

    // MARK: Static Constants

    /// The bar's fixed width, and the **one** place it is stated.
    ///
    /// It lived here as a bare `.frame(width: 20)` while `BoardDestination`
    /// carried its own `evaluationBarWidth = 16` for the surrounding
    /// geometry — two numbers for one measurement, disagreeing. The inner
    /// fixed frame won on intrinsic size, so the bar drew 20 pt centred in a
    /// 16 pt slot: 2 pt of bleed on each side and a gap that was really 8.
    /// The caller's own doc claimed the constants existed "so the geometry
    /// and any future reader agree", which is exactly the twin-read-site
    /// symptom D25′ names — and its cure, applied here: where a value has an
    /// owning type, that type holds it. The view that draws the bar owns how
    /// wide the bar is; the caller owns only the *gap*, which is a
    /// relationship between two views and belongs to neither alone.
    internal static let width: CGFloat = 20

    // MARK: Stored Properties

    internal let reading: EvaluationBarReading
    internal let perspective: PieceColor
    internal let style: BoardStyle

    // MARK: Derived

    /// The share drawn from the bar's *bottom* — white's under the white
    /// perspective, black's under the black (D33′'s one flip, applied to
    /// geometry only).
    private var bottomFraction: Double {
        perspective == .white ? reading.whiteFraction : 1 - reading.whiteFraction
    }

    /// The color of the bottom share; the remainder wears the other.
    private var bottomColor: Color {
        perspective == .white ? style.light : style.dark
    }

    private var topColor: Color {
        perspective == .white ? style.dark : style.light
    }

    // MARK: Body

    internal var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(topColor)
                    Rectangle()
                        .fill(bottomColor)
                        .frame(height: geometry.size.height * bottomFraction)
                }
                .animation(.snappy(duration: 0.2), value: reading.whiteFraction)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.gridBorder, lineWidth: 1)
            }

            Text(reading.label)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Evaluation")
        .accessibilityValue(reading.label)
        .accessibilityIdentifier(AccessibilityID.boardEvaluationBar)
    }
}

// MARK: Previews

#Preview("Drawn (nil folds here)") {
    EvaluationBarView(
        reading: EvaluationBarReading(nil),
        perspective: .white,
        style: .walnut
    )
    .frame(width: 50, height: 400)
    .padding()
}

#Preview("Winning (+1.5)") {
    EvaluationBarView(
        reading: EvaluationBarReading(.centipawns(150)),
        perspective: .white,
        style: .walnut
    )
    .frame(width: 50, height: 400)
    .padding()
}

#Preview("Losing (−2.3)") {
    EvaluationBarView(
        reading: EvaluationBarReading(.centipawns(-230)),
        perspective: .white,
        style: .rosewood
    )
    .frame(width: 50, height: 400)
    .padding()
}

#Preview("Mate (#3, clamped full)") {
    EvaluationBarView(
        reading: EvaluationBarReading(.mate(3)),
        perspective: .white,
        style: .wenge
    )
    .frame(width: 50, height: 400)
    .padding()
}

#Preview("Flipped (+1.5 from Black's seat)") {
    EvaluationBarView(
        reading: EvaluationBarReading(.centipawns(150)),
        perspective: .black,
        style: .walnut
    )
    .frame(width: 50, height: 400)
    .padding()
}
