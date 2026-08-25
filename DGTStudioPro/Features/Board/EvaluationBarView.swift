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
    
    // MARK: Spoiler Switch
    
    /// Hidden draws a flat grey bar and no score (17 Aug 2026, by request) - the spoiler
    /// guard for replaying a game you haven't seen. App-wide and persisted: the state is
    /// about the reader, not about one game or one window. The hosts read the same key for
    /// their score labels, so bar and label can never disagree about being hidden.
    @AppStorage(StorageKeys.evaluationBarHidden) private var isHidden = false
    
    /// Pointer-only affordance: canvases have no pointer, and a hover state with no witness is how
    /// it silently stops working.
    ///
    /// **The manual check this sentence promised does not exist.** No document mentions the spoiler
    /// switch - the evaluation-bar checklist predates it (17 Aug 2026) and was never extended, and
    /// no preview covers `isHidden`. Three witnesses short: no test, no canvas, no written check.
    @State private var isHovering = false
    
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
                if isHidden {
                    // One flat fill, no split: a hidden bar must not leak the share it would
                    // have drawn - a two-tone "hidden" bar is the spoiler with extra steps.
                    Rectangle()
                        .fill(.gray.opacity(0.35))
                } else {
                    Rectangle()
                        .fill(topColor)
                    Rectangle()
                        .fill(bottomColor)
                        .frame(height: geometry.size.height * bottomFraction)
                }
            }
            .animation(.snappy(duration: 0.2), value: reading.whiteFraction)
            .animation(.snappy(duration: 0.2), value: isHidden)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.gridBorder, lineWidth: 1)
        }
        // The hover affordance: an eye-with-slash while pointing at the bar, click to flip.
        // Drawn as an overlay on the bar rather than a control beside it - the bar is 22 pt
        // wide and a neighbour would move the board.
        .overlay {
            if isHovering {
                Button {
                    isHidden.toggle()
                } label: {
                    Image(systemName: isHidden ? "eye" : "eye.slash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
                .help(isHidden ? "Show the evaluation" : "Hide the evaluation")
                .accessibilityIdentifier(AccessibilityID.boardEvaluationBarHideToggle)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Evaluation")
        .accessibilityValue(isHidden ? "Hidden" : reading.label)
        .accessibilityIdentifier(AccessibilityID.boardEvaluationBar)
    }
}

// MARK: Previews

/// Previews the bar and nothing else - the score label moved to `BoardDestination`, which is
/// waived from previews; the arrangement is manual-check territory.
///
/// **All five read the real `evaluationBarHidden`.** None passes `.defaultAppStorage`, so if the
/// spoiler switch has ever been turned on in the app, every one of these renders a flat grey bar
/// and not one shows the state it is named for. Nothing on canvas would say why.
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
