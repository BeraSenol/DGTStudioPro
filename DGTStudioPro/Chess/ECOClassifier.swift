/// One named opening from the bundled table. `init(code:name:)` is the one place lichess's
/// `Family: Variation` convention is read — split once per row at load, not per surface (D35′).
internal struct ECOOpening: Sendable, Hashable {

    /// The ECO volume code — deliberately not unique: it names a region; `family` identifies the
    /// opening. Keying on code alone is reading it wrong.
    internal let code: String

    /// Left of the first colon — the short form the Library column shows.
    internal let family: String

    /// Right of the first colon, or nil for a bare family line. The initializer folds an empty
    /// remainder to nil, so nil is the only spelling of "no variation".
    internal let variation: String?

    /// Splits at the **first** colon — lichess nests subvariations after commas, never a second
    /// colon, so a later colon is inside the variation text.
    internal init(code: String, name: String) {
        self.code = code
        guard let colon = name.firstIndex(of: ":") else {
            self.family = name
            self.variation = nil
            return
        }
        self.family = String(name[name.startIndex..<colon])
            .trimmingTrailingSpaces()
        let rest = String(name[name.index(after: colon)...])
            .trimmingLeadingSpaces()
        self.variation = rest.isEmpty ? nil : rest
    }

    /// Rehydrates already-split parts (`PGN.opening`'s door). Two initializers, two jobs: this one
    /// must not parse — re-splitting a stored family would corrupt names containing colons.
    internal init(code: String, family: String, variation: String?) {
        self.code = code
        self.family = family
        self.variation = variation
    }

    /// The source's own form — the inverse of the split, so a stored pair round-trips.
    internal var fullName: String {
        guard let variation else { return family }
        return "\(family): \(variation)"
    }
}

// MARK: - Classification

/// Longest-prefix ECO classification (D19′). Pure and table-injected — I/O lives in `ECOTable`.
/// Longest prefix, not first match: the table deliberately carries duplicate transposition rows.
internal struct ECOClassifier: Sendable {

    /// Keyed by the folded SAN line, plies joined by one space.
    private let table: [String: ECOOpening]

    /// The deepest table line, where the walk starts — starting at the game's length would waste a
    /// lookup per ply beyond the table's reach.
    private let deepestLine: Int

    /// Duplicate lines resolve first-wins rather than trapping: a bundled-asset defect should not
    /// stop the other 3,500 openings classifying. First-wins matches the app's identity rule.
    internal init(_ entries: [(line: [String], opening: ECOOpening)]) {
        table = Dictionary(
            entries.map { (Self.key(for: $0.line), $0.opening) },
            uniquingKeysWith: { first, _ in first }
        )
        // A closure, not `map(\.line.count)`: key paths don't reach tuple elements.
        deepestLine = entries.map { $0.line.count }.max() ?? 0
    }

    /// The named opening and the matched prefix length in plies, or nil (D74′ — the length is what
    /// the analysis book-skip reads). Cost, recorded: quadratic prefix re-join, bounded at 36
    /// plies — revisit only if Instruments says so.
    internal func match(for moves: [String]) -> (opening: ECOOpening, plies: Int)? {
        let folded = moves.prefix(deepestLine).map(Self.foldedSAN)
        var depth = folded.count
        while depth > 0 {
            if let hit = table[folded.prefix(depth).joined(separator: " ")] {
                return (hit, depth)
            }
            depth -= 1
        }
        return nil
    }

    /// `match(for:)` without the length, for the callers that never need the book depth.
    internal func opening(for moves: [String]) -> ECOOpening? {
        match(for: moves)?.opening
    }

    // MARK: Folding

    private static func key(for line: [String]) -> String {
        line.map(foldedSAN).joined(separator: " ")
    }

    /// The **matching fold** for one SAN ply — a comparison fold, NOT a third content stripper
    /// (the app's two strippers differ on purpose and stored text is never touched here). Exists
    /// only to build and probe dictionary keys.
    private static func foldedSAN(_ san: String) -> String {
        var result = san
        while let last = result.last,
              last == "+" || last == "#" || last == "!" || last == "?" {
            result.removeLast()
        }
        switch result {
        case "0-0":   return "O-O"
        case "0-0-0": return "O-O-O"
        default:      return result
        }
    }
}

// MARK: - String Trimming

/// Space-only trims. Deliberately not Foundation's `trimmingCharacters` — the chess core's one
/// Foundation import is the SAN layer's `CharacterSet`.
extension String {
    fileprivate func trimmingTrailingSpaces() -> String {
        var result = self
        while result.last == " " { result.removeLast() }
        return result
    }

    fileprivate func trimmingLeadingSpaces() -> String {
        var result = self
        while result.first == " " { result.removeFirst() }
        return result
    }
}
