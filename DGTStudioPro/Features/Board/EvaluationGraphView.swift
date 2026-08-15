import SwiftUI

struct EvaluationGraphView: View {
    
    // MARK: Stored Properties
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
                // Neutral, not `style.light`: the 50/50 line is structure, and the wash already places the
                // grid-border colour at this height.
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
            // The triple wash, final form (Bera's design after four iterations): native window ground at
            // both poles — melts into whatever the window is — and the board's grid-border colour at the
            // seam, backing the near-equality slivers; extreme advantages carry themselves on fill mass.
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
        .padding(.horizontal, -8)
    }
    
    // MARK: Instance Methods
    /// Horizontal placement comes from `EvaluationGraphGeometry` (D46′) — the same arithmetic
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
    
    private func curvePath(through points: [CGPoint]) -> Path {
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
    
    /// `curve` already opens with `move(to:)`, so it *is* the leading edge — an explicit move+line
    /// opened a second degenerate subpath and the fill leaked.
    private func closedAreaPath(curve: Path, start: CGPoint, end: CGPoint, baseY: CGFloat) -> Path {
        var area = curve
        area.addLine(to: CGPoint(x: end.x, y: baseY))
        area.addLine(to: CGPoint(x: start.x, y: baseY))
        area.closeSubpath()
        return area
    }
    
    private func catmullRomControlPoints(
        at index: Int,
        in points: [CGPoint]
    ) -> (CGPoint, CGPoint) {
        let p0 = index > 0 ? points[index - 1] : points[index]
        let p1 = points[index]
        let p2 = points[index + 1]
        let p3 = index + 2 < points.count ? points[index + 2] : points[index + 1]
        let tension: CGFloat = 5.0
        
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
