//
//  ECOClassifier.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/07/2026.
//

/// One named opening from the bundled ECO table (D19′, D34′).
///
/// The name arrives from the source as a single string in lichess's
/// documented `Family: Variation, Subvariation` shape; ``init(code:name:)``
/// is the one place that convention is read, so the split happens once per
/// table row at load rather than once per surface at render (D35′).
internal struct ECOOpening: Sendable, Hashable {

    /// The ECO volume code — `"C18"`. Deliberately **not** unique: a code
    /// names a *region* of opening theory and dozens of named lines share
    /// one, so it identifies the neighbourhood and `family` identifies the
    /// opening. Anything keying on code alone is reading it wrong.
    internal let code: String

    /// Everything left of the first colon — `"French Defense"`. The short
    /// form the Library column shows.
    internal let family: String

    /// Everything right of the first colon — `"Winawer Variation, Poisoned
    /// Pawn Variation"` — or `nil` for a bare family line (`"Vienna Game"`).
    /// Nil and `""` must not both be reachable, or two surfaces will
    /// disagree about which means "no variation": the initializer folds an
    /// empty remainder to nil, so nil is the only spelling.
    internal let variation: String?

    /// Splits a source name at its **first** colon. First, not last: lichess
    /// nests subvariations after commas, never after a second colon, so a
    /// later colon would be inside the variation text and splitting there
    /// would move part of the variation into the family.
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

    /// Rebuilds an opening from already-split parts — the door
    /// `PGN.opening` uses to rehydrate its three stored columns.
    ///
    /// Two initializers, two jobs, and the distinction is worth keeping
    /// straight: ``init(code:name:)`` *parses* a source name and is the only
    /// place the colon convention lives; this one trusts a split that already
    /// happened. Handing a full `"Family: Variation"` string to `family:`
    /// here would store a name that never splits again — which is why the
    /// parsing door is the one with the shorter, more inviting label.
    internal init(code: String, family: String, variation: String?) {
        self.code = code
        self.family = family
        self.variation = variation
    }

    /// The name as the source carries it — family, then the variation after
    /// a colon. The inverse of the initializer's split, so a stored pair
    /// round-trips to the string it came from; the inspector shows this and
    /// the Library column shows ``family`` alone.
    internal var fullName: String {
        guard let variation else { return family }
        return "\(family): \(variation)"
    }
}

// MARK: - Classification

/// Longest-prefix ECO classification over a game's SAN moves (D19′).
///
/// Pure and table-injected: the bundled table's I/O lives in `ECOTable`,
/// outside the chess core, so this type stays inside the core's
/// no-I/O-no-Foundation contract and its suite runs on five-row fixtures
/// with no bundle at all.
///
/// **Longest prefix, not first match.** The source README prescribes
/// "play moves backwards until a named position is found", and the table
/// deliberately carries duplicate rows for common transpositions to make
/// that work — so the walk starts deep and shortens, and the first hit
/// wins. Walking forwards instead would stop at `1. e4 e5` and call every
/// Ruy Lopez a King's Pawn Game.
internal struct ECOClassifier: Sendable {

    /// Keyed by the folded SAN line, plies joined by one space.
    private let table: [String: ECOOpening]

    /// The deepest line in the table, in plies — where the walk starts.
    /// Starting at the *game's* length instead would spend one fruitless
    /// lookup per ply beyond the table's reach, which on a 60-move game is
    /// most of them.
    private let deepestLine: Int

    /// Duplicate lines resolve first-wins rather than trapping: a repeated
    /// line in the table is a data defect in a bundled asset, and a personal
    /// tool should classify the other 3,500 openings rather than refuse to
    /// launch. First-wins also matches the app's standing identity rule
    /// (`Player`'s first-seen casing, D29′'s first-seen tag form).
    internal init(_ entries: [(line: [String], opening: ECOOpening)]) {
        table = Dictionary(
            entries.map { (Self.key(for: $0.line), $0.opening) },
            uniquingKeysWith: { first, _ in first }
        )
        // A closure, not `map(\.line.count)`: key paths don't reach tuple
        // elements.
        deepestLine = entries.map { $0.line.count }.max() ?? 0
    }

    /// The named opening this game reaches, or `nil` when no prefix of it is
    /// in the table (an unplayed game, or a line the source doesn't name).
    ///
    /// Cost, recorded rather than optimised: the fold runs once, but each
    /// step re-joins its prefix, so this is quadratic in the table's depth —
    /// bounded at 36 plies by the shipped dataset's deepest line, and run
    /// once per game during a backfill or an analysis pass. It buys a flat
    /// dictionary over a trie; revisit only if M7's Instruments pass says so.
    internal func opening(for moves: [String]) -> ECOOpening? {
        let folded = moves.prefix(deepestLine).map(Self.foldedSAN)
        var depth = folded.count
        while depth > 0 {
            if let hit = table[folded.prefix(depth).joined(separator: " ")] {
                return hit
            }
            depth -= 1
        }
        return nil
    }

    // MARK: Folding

    private static func key(for line: [String]) -> String {
        line.map(foldedSAN).joined(separator: " ")
    }

    /// The **matching fold** for a single SAN ply — the SAN sibling of
    /// `TagRule`'s D30′ string fold, not a third content stripper.
    ///
    /// The distinction is load-bearing, because the codebase already carries
    /// two deliberately-different SAN strippers and a doc warning not to grow
    /// a third: `PGNParser.stripAnnotations` preserves `+`/`#` because export
    /// round-trips them byte for byte (D24′), and `GameState.parseSAN`'s
    /// cleaning step drops all four because the move generator recomputes
    /// them. Neither is what a *comparison* wants. This one never touches
    /// stored text — it exists only to build and probe dictionary keys, so
    /// both sides fold identically and nothing round-trips through it.
    ///
    /// Two things fold:
    /// - **Trailing `+ # ! ?`** — the table writes `Bxc3+`, and a foreign PGN
    ///   may or may not.
    /// - **Zero-form castling** — `GameState.parseSAN` accepts `0-0` as well
    ///   as `O-O` and stores imported SAN verbatim, so a game imported from a
    ///   producer that writes zeros holds `0-0` while every table row holds
    ///   `O-O`. Without this the entire Ruy Lopez main line silently fails to
    ///   classify for exactly those games — invisible, because "no opening
    ///   found" is a legitimate answer.
    ///
    /// Case is deliberately **not** folded: SAN is case-significant (`b4` is
    /// a pawn move, `B4` is nothing), so lowercasing here would collide
    /// bishop and b-pawn moves onto one key.
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

/// Space-only trims for the name split. Deliberately not
/// `trimmingCharacters(in: .whitespaces)`: that lives in Foundation, and the
/// chess core's one Foundation import is the SAN layer's `CharacterSet` —
/// growing a second for two trims would cost the core's stated purity for
/// nothing.
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
