import SwiftUI

/// The vertical evaluation bar. Dumb by design: semantics live in
/// `EvaluationBarReading`; this view owns only geometry - which end is "near". The reading
/// stays white-relative; the flip is one boolean of geometry. Label: always visible, never
/// inside the bar - a thin losing share would swallow it.
struct EvaluationBarView: View {
    
    // MARK: Static Constants
    
    /// The bar's fixed width, the **one** place it is stated - it was 20 here and 16 in the caller
    /// for a month (the twin-read-site pattern); the caller owns only the *gap*.
    static let width: CGFloat = 22
    
    // MARK: Stored Properties
    
    let reading: EvaluationBarReading
    let perspective: PieceColor
    let style: BoardStyle
    
    // MARK: Derived
    
    /// The share drawn from the *bottom* - white's under white perspective (the one flip, geometry only).
    private var bottomFraction: Double {
        perspective == .white ? reading.whiteFraction : 1 - reading.whiteFraction
    }
    
    /// The bottom share's colour; the remainder wears the other.
    private var bottomColor: Color {
        perspective == .white ? style.light : style.dark
    }
    
    private var topColor: Color {
        perspective == .white ? style.dark : style.light
    }
    
    // MARK: Body
    
    var body: some View {
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
        .frame(width: Self.width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Evaluation")
        .accessibilityValue(reading.label)
        .accessibilityIdentifier(AccessibilityID.boardEvaluationBar)
    }
}

// MARK: Previews

/// Previews the bar and nothing else - the score label moved to `BoardDestination`, which is
/// waived from previews; the arrangement is manual-check territory.
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
