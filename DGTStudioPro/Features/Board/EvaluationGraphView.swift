import SwiftUI

struct EvaluationGraphView: View {
    
    // MARK: Stored Properties

    /// `[Double]`, already flattened: `PGN.winProbabilityCurve` folds an unscored ply to 0.5
    /// before it arrives, so this view cannot tell the unsearched opening book from a genuinely
    /// level game. Drawing that gap would need the optionality kept across the boundary, not a
    /// change in here.
    let evaluations: [Double]
    let currentMoveIndex: Int?
    let style: BoardStyle
    
    // MARK: Body
    var body: some View {
        Canvas { context, size in
            let drawArea = CGRect(
                x: 0,
                y: 0,
                width: size.width,
                height: size.height
            )
            
            let midY = drawArea.midY
            
            var midline = Path()
            
            midline.move(to: CGPoint(x: drawArea.minX, y: midY))
            midline.addLine(to: CGPoint(x: drawArea.maxX, y: midY))
            
            context.stroke(
                midline,
                // Neutral, not `style.light`: the 50/50 line is structure, and it has to carry
                // itself - the wash below is at its faintest exactly here.
                with: .color(.black.opacity(0.15)),
                lineWidth: 0.5
            )
            
            guard evaluations.count >= 2 else { return }
            
            let points = evaluationPoints(in: drawArea)
            let curve = curvePath(through: points)
            let area = closedAreaPath(
                curve: curve,
                start: points[0],
                end: points[points.count - 1],
                baseY: midY
            )
            
            context.drawLayer { ctx in
                let clip = CGRect(x: 0, y: 0, width: size.width, height: midY)
                ctx.clip(to: Path(clip))
                ctx.fill(area, with: .color(style.light.opacity(0.50)))
            }
            
            context.drawLayer { ctx in
                let clip = CGRect(x: 0, y: midY, width: size.width, height: size.height - midY)
                ctx.clip(to: Path(clip))
                ctx.fill(area, with: .color(style.dark.opacity(0.65)))
            }
            
            
            let curveStroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            
            context.drawLayer { ctx in
                let clip = CGRect(x: 0, y: 0, width: size.width, height: midY)
                ctx.clip(to: Path(clip))
                ctx.stroke(curve, with: .color(style.light.opacity(0.75)), style: curveStroke)
            }
            context.drawLayer { ctx in
                let clip = CGRect(x: 0, y: midY, width: size.width, height: size.height - midY)
                ctx.clip(to: Path(clip))
                ctx.stroke(curve, with: .color(style.dark.opacity(0.90)), style: curveStroke)
            }
            
            if let index = currentMoveIndex,
               index >= 0, index < points.count {
                let p = points[index]
                let dotColor = p.y <= midY ? style.light : style.dark
                
                let dot = Path(ellipseIn: CGRect(
                    x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7
                ))
                context.fill(dot, with: .color(dotColor.opacity(0.95)))
            }
        }
        .background {
            // The triple wash (Bera's design, four iterations): a symmetric neutral gradient,
            // heaviest at the poles and near-clear at the seam. **It has never contained
            // `.gridBorder`** - three grays in every commit that ever touched this file, while
            // successive comments claimed the seam carried the app's structural-line colour.
            // Those comments also described the inverse shape - seam tinted to back the thin
            // near-equality sliver, poles left to the fill's own mass - which is what these stops
            // would do reversed.
            LinearGradient(
                colors: [
                    .gray.opacity(0.1),
                    .gray.opacity(0.01),
                    .gray.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        // Cancels the hosts' 8 pt `listRowInsets`, as `MoveHistoryView` does for the same reason.
        .padding(.horizontal, -8)
    }
    
    // MARK: Instance Methods
    /// Horizontal placement comes from `EvaluationGraphGeometry` - the same arithmetic
    /// gained a second consumer pointing the other way.
    private func evaluationPoints(in rect: CGRect) -> [CGPoint] {
        let geometry = EvaluationGraphGeometry(
            width: rect.width,
            plyCount: evaluations.count
        )
        
        return evaluations.enumerated().map { index, probability in
            let x = rect.minX + (geometry.x(forPly: index) ?? 0)
            let y = rect.maxY - CGFloat(probability) * rect.height
            return CGPoint(x: x, y: y)
        }
    }
    
    /// Monotone cubic (Fritsch-Carlson) since 17 Aug 2026, replacing Catmull-Rom - the graph
    /// read as violently spiky and **part of that was drawn, not played**: Catmull-Rom
    /// overshoots at a direction reversal, sailing past the data point and inventing a peak
    /// higher than any evaluation in the game. A monotone fit cannot leave the interval
    /// between two plies, so every visible extreme is a real one, and the curve is smoother
    /// besides - the two goals turned out to be the same goal.
    ///
    /// A blunder still shows as a cliff. Damping *that* would need a moving average over the
    /// evaluations, which is a lie a study tool must not tell: the sharp drop is the thing the
    /// reader opened the graph to find.
    private func curvePath(through points: [CGPoint]) -> Path {
        guard points.count >= 2 else { return Path() }

        let slopes = monotoneSlopes(through: points)

        return Path { path in
            path.move(to: points[0])

            // Hermite → Bézier: the control points sit a third of the span along each
            // endpoint's tangent. Two points degenerate to a straight line on their own, so
            // the old `count == 2` special case retired with the old interpolation.
            for i in 0 ..< (points.count - 1) {
                let p1 = points[i]
                let p2 = points[i + 1]
                let third = (p2.x - p1.x) / 3

                path.addCurve(
                    to: p2,
                    control1: CGPoint(x: p1.x + third, y: p1.y + third * slopes[i]),
                    control2: CGPoint(x: p2.x - third, y: p2.y - third * slopes[i + 1])
                )
            }
        }
    }
    
    /// `curve` already opens with `move(to:)`, so it *is* the leading edge - an explicit move+line
    /// opened a second degenerate subpath and the fill leaked.
    private func closedAreaPath(curve: Path, start: CGPoint, end: CGPoint, baseY: CGFloat) -> Path {
        var area = curve
        area.addLine(to: CGPoint(x: end.x, y: baseY))
        area.addLine(to: CGPoint(x: start.x, y: baseY))
        area.closeSubpath()
        return area
    }
    
    /// Fritsch-Carlson tangents: the whole anti-overshoot rule, in two clauses. **A ply that
    /// reverses direction gets a flat tangent** (the neighbouring slopes disagree in sign), so
    /// the curve arrives level at the turn instead of sailing through it - that clause alone
    /// removes the invented peaks. Otherwise the average slope is clamped to three times the
    /// gentler neighbour, which keeps a steep segment from bending its calm neighbour out of
    /// range. Plies are evenly spaced so `dx` is never zero in practice; guarded anyway,
    /// because a zero here would be a NaN in a `Path`.
    private func monotoneSlopes(through points: [CGPoint]) -> [CGFloat] {
        let count = points.count
        guard count >= 2 else { return Array(repeating: 0, count: count) }

        let secants: [CGFloat] = (0 ..< count - 1).map { i in
            let dx = points[i + 1].x - points[i].x
            return dx == 0 ? 0 : (points[i + 1].y - points[i].y) / dx
        }

        var slopes = [CGFloat](repeating: 0, count: count)
        slopes[0] = secants[0]
        slopes[count - 1] = secants[count - 2]

        for i in 1 ..< count - 1 {
            let before = secants[i - 1]
            let after = secants[i]

            if before * after <= 0 {
                slopes[i] = 0
            } else {
                let average = (before + after) / 2
                let limit = 3 * min(abs(before), abs(after))
                slopes[i] = min(abs(average), limit) * (average < 0 ? -1 : 1)
            }
        }

        return slopes
    }
}

// MARK: Previews
#Preview("Walnut, Dramatic Endgame") {
    EvaluationGraphView(
        evaluations: [
            0.50, 0.52, 0.51, 0.49, 0.50, 0.52, 0.50, 0.48,
            0.46, 0.44, 0.46, 0.44, 0.42, 0.44, 0.43, 0.45,
            0.42, 0.40, 0.42, 0.44, 0.41, 0.38, 0.40, 0.42,
            0.38, 0.35, 0.37, 0.40, 0.36, 0.32, 0.35, 0.30,
            0.34, 0.42, 0.50, 0.58, 0.72, 0.88, 0.96
        ],
        currentMoveIndex: 2,
        style: .walnut
    )
    .frame(width: 580, height: 350)
    .padding()
    .background(.black)
}

#Preview("Rosewood, Back-and-Forth") {
    EvaluationGraphView(
        evaluations: [
            0.50, 0.55, 0.48, 0.58, 0.45, 0.52, 0.40, 0.55,
            0.42, 0.60, 0.38, 0.52, 0.45, 0.50, 0.55, 0.48,
            0.58, 0.42, 0.55, 0.50, 0.45, 0.52, 0.48, 0.50
        ],
        currentMoveIndex: 18,
        style: .rosewood
    )
    .frame(width: 580, height: 350)
    .padding()
    .background(.black)
}

#Preview("Wenge, Black Dominates") {
    EvaluationGraphView(
        evaluations: [
            0.50, 0.48, 0.42, 0.38, 0.35, 0.30, 0.25, 0.22,
            0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.06, 0.05,
            0.04, 0.03, 0.02, 0.02
        ],
        currentMoveIndex: 14,
        style: .wenge
    )
    .frame(width: 580, height: 350)
    .padding()
    .background(.black)
}

#Preview("Inspector Integration") {
    List {
        CollapsibleSection(.roster, title: "Magnus Carlsen vs Ian Nepomniachtchi") {
            LabeledContent("White", value: "Carlsen")
            LabeledContent("Black", value: "Nepomniachtchi")
            LabeledContent("Round", value: "7")
            LabeledContent("Result", value: "*")
        }
        
        CollapsibleSection(.evaluation, title: "Evaluation") {
            EvaluationGraphView(
                evaluations: [
                    0.50, 0.52, 0.51, 0.49, 0.50, 0.52, 0.50, 0.48,
                    0.46, 0.44, 0.46, 0.44, 0.42, 0.44, 0.43, 0.45,
                    0.42, 0.40, 0.42, 0.44, 0.41, 0.38, 0.40, 0.42,
                    0.38, 0.35, 0.37, 0.40, 0.36, 0.32, 0.35, 0.30,
                    0.34, 0.42, 0.50, 0.58, 0.72, 0.88, 0.96
                ],
                currentMoveIndex: 1,
                style: .walnut
            )
            .frame(height: 110)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        }
    }
    .listStyle(.sidebar)
    .frame(width: 580, height: 400)
    .environment(InspectorSectionCollapse.preview)
}
