//
//  EvaluationGraphView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import SwiftUI

// MARK: Evaluation Graph View
/// Renders a smooth area chart of engine evaluations in the board inspector.
/// Each evaluation is a win probability from white's perspective (0.0–1.0),
/// where 0.5 is equal, 1.0 is decisive white advantage, 0.0 is decisive
/// black advantage. The midline separates two color regions: white's advantage
/// above uses the board style's light color, while black's advantage below
/// uses the dark color — area fills, curve stroke, and dot markers all
/// respect this split.
internal struct EvaluationGraphView: View {

    // MARK: Stored Properties
    internal let evaluations: [Double]
    internal let currentMoveIndex: Int?
    internal let style: BoardStyle

    // MARK: Body
    internal var body: some View {
        Canvas { context, size in
            guard evaluations.count >= 2 else { return }

            let inset: CGFloat = 10
            let drawArea = CGRect(
                x: inset,
                y: inset,
                width: size.width - 2 * inset,
                height: size.height - 2 * inset
            )
            let midY = drawArea.midY
            let points = evaluationPoints(in: drawArea)
            let area = closedAreaPath(through: points, baseY: midY)
            let curve = smoothPath(through: points)

            // White advantage — upper half, board's light color.
            context.drawLayer { ctx in
                let clip = CGRect(x: 0, y: 0, width: size.width, height: midY)
                ctx.clip(to: Path(clip))
                ctx.fill(area, with: .color(style.light.opacity(0.50)))
            }

            // Black advantage — lower half, board's dark color.
            context.drawLayer { ctx in
                let clip = CGRect(x: 0, y: midY, width: size.width, height: size.height - midY)
                ctx.clip(to: Path(clip))
                ctx.fill(area, with: .color(style.dark.opacity(0.65)))
            }

            // Midline — barely-there reference line.
            var midline = Path()
            midline.move(to: CGPoint(x: drawArea.minX, y: midY))
            midline.addLine(to: CGPoint(x: drawArea.maxX, y: midY))
            context.stroke(
                midline,
                with: .color(style.light.opacity(0.10)),
                lineWidth: 0.5
            )

            let curveStroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

            // Evaluation curve — light above midline, dark below.
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

            // Dot markers at significant turning points.
            drawSignificantDots(
                in: &context,
                points: points,
                midY: midY,
                threshold: drawArea.height * 0.06
            )

            // Current move indicator — larger dot with soft glow.
            // Color matches whichever side of the midline the point falls on.
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
        .background(graphBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Instance Methods

    /// Neutral dark background — no board-style tint, so both the light
    /// and dark fill regions have clear contrast against the base.
    private var graphBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(white: 0.11))
    }

    /// Maps win-probability evaluations to drawable CGPoints.
    /// y = 1.0 sits at the top of the draw area; y = 0.0 at the bottom.
    private func evaluationPoints(in rect: CGRect) -> [CGPoint] {
        let count = evaluations.count
        let step = rect.width / CGFloat(count - 1)

        return evaluations.enumerated().map { index, probability in
            let x = rect.minX + CGFloat(index) * step
            // Invert: high probability → low y (top of screen).
            let y = rect.maxY - CGFloat(probability) * rect.height
            return CGPoint(x: x, y: y)
        }
    }

    /// Builds a smooth Catmull-Rom cubic Bezier path through the evaluation points.
    private func smoothPath(through points: [CGPoint]) -> Path {
        guard points.count >= 2 else { return Path() }

        return Path { path in
            path.move(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
                return
            }

            for i in 0 ..< (points.count - 1) {
                let (cp1, cp2) = catmullRomControlPoints(at: i, in: points)
                path.addCurve(to: points[i + 1], control1: cp1, control2: cp2)
            }
        }
    }

    /// Builds a closed area path: smooth curve → vertical drop to baseY → close.
    /// Used for the filled regions above and below the midline.
    private func closedAreaPath(through points: [CGPoint], baseY: CGFloat) -> Path {
        guard points.count >= 2 else { return Path() }

        return Path { path in
            // Start on the baseline directly below (or above) the first point.
            path.move(to: CGPoint(x: points[0].x, y: baseY))
            path.addLine(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
            } else {
                for i in 0 ..< (points.count - 1) {
                    let (cp1, cp2) = catmullRomControlPoints(at: i, in: points)
                    path.addCurve(to: points[i + 1], control1: cp1, control2: cp2)
                }
            }

            // Close back to the baseline.
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: baseY))
            path.closeSubpath()
        }
    }

    /// Converts a Catmull-Rom segment into cubic Bezier control points.
    ///
    /// Given four sequential Catmull-Rom knots P0–P3, the Bezier that
    /// interpolates P1→P2 uses:
    ///   CP1 = P1 + (P2 − P0) / 6τ
    ///   CP2 = P2 − (P3 − P1) / 6τ
    /// where τ (tension) controls curvature. Lower τ = tighter curves.
    private func catmullRomControlPoints(
        at index: Int,
        in points: [CGPoint]
    ) -> (CGPoint, CGPoint) {
        let p0 = index > 0 ? points[index - 1] : points[index]
        let p1 = points[index]
        let p2 = points[index + 1]
        let p3 = index + 2 < points.count ? points[index + 2] : points[index + 1]

        // Tension of 6.0 yields a classic Catmull-Rom spline.
        // Raise for gentler curves, lower for tighter ones.
        let tension: CGFloat = 6.0

        let cp1 = CGPoint(
            x: p1.x + (p2.x - p0.x) / tension,
            y: p1.y + (p2.y - p0.y) / tension
        )
        let cp2 = CGPoint(
            x: p2.x - (p3.x - p1.x) / tension,
            y: p2.y - (p3.y - p1.y) / tension
        )

        return (cp1, cp2)
    }

    /// Draws small dot markers at positions where the evaluation shifts
    /// significantly — crossovers through the midline, local extrema,
    /// or moves with large centipawn swings. Dots above the midline use
    /// the board style's light color; dots below use the dark color.
    private func drawSignificantDots(
        in context: inout GraphicsContext,
        points: [CGPoint],
        midY: CGFloat,
        threshold: CGFloat
    ) {
        guard points.count >= 3 else { return }

        let radius: CGFloat = 2.5

        for i in 1 ..< (points.count - 1) {
            let prev = points[i - 1]
            let curr = points[i]
            let next = points[i + 1]

            // Midline crossover: the curve passes through equal evaluation.
            let crossesMidline = (curr.y - midY) * (prev.y - midY) < 0

            // Local vertical extremum (peak or valley in the curve).
            let isExtremum = (curr.y - prev.y) * (next.y - curr.y) < 0

            // Large single-move swing.
            let bigSwing = abs(curr.y - prev.y) > threshold

            guard crossesMidline || isExtremum || bigSwing else { continue }

            // Pick color based on which side of the midline this point sits on.
            let dotColor = curr.y <= midY ? style.light : style.dark

            let dot = Path(ellipseIn: CGRect(
                x: curr.x - radius, y: curr.y - radius,
                width: radius * 2, height: radius * 2
            ))
            context.fill(dot, with: .color(dotColor.opacity(0.85)))
        }
    }
}

// MARK: Previews

#Preview("Walnut — Dramatic Endgame") {
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
    .frame(width: 280, height: 110)
    .padding()
    .background(.black)
}

#Preview("Rosewood — Back-and-Forth") {
    EvaluationGraphView(
        evaluations: [
            0.50, 0.55, 0.48, 0.58, 0.45, 0.52, 0.40, 0.55,
            0.42, 0.60, 0.38, 0.52, 0.45, 0.50, 0.55, 0.48,
            0.58, 0.42, 0.55, 0.50, 0.45, 0.52, 0.48, 0.50
        ],
        currentMoveIndex: 18,
        style: .rosewood
    )
    .frame(width: 280, height: 110)
    .padding()
    .background(.black)
}

#Preview("Leather — Drawn Game") {
    EvaluationGraphView(
        evaluations: [
            0.50, 0.51, 0.49, 0.50, 0.51, 0.50, 0.49, 0.50,
            0.51, 0.50, 0.49, 0.50, 0.50, 0.51, 0.49, 0.50,
            0.50, 0.49, 0.50, 0.51, 0.50, 0.50, 0.49, 0.50
        ],
        currentMoveIndex: nil,
        style: .leather
    )
    .frame(width: 280, height: 110)
    .padding()
    .background(.black)
}

#Preview("Wenge — Black Dominates") {
    EvaluationGraphView(
        evaluations: [
            0.50, 0.48, 0.42, 0.38, 0.35, 0.30, 0.25, 0.22,
            0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 0.06, 0.05,
            0.04, 0.03, 0.02, 0.02
        ],
        currentMoveIndex: 14,
        style: .wenge
    )
    .frame(width: 280, height: 110)
    .padding()
    .background(.black)
}

#Preview("Inspector Integration") {
    List {
        Section {
            LabeledContent("White", value: "Carlsen")
            LabeledContent("Black", value: "Nepomniachtchi")
            LabeledContent("Round", value: "7")
            LabeledContent("Result", value: "*")
        } header: {
            Text("Game")
        }

        Section {
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
        } header: {
            Text("Evaluation")
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 400)
}
