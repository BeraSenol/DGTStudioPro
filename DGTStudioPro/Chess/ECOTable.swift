import Foundation
import os

/// The bundled ECO dataset, parsed once into an `ECOClassifier` (D34′).
///
/// **Deliberately outside the chess core's purity contract, and filed beside
/// it anyway.** The invariant names types — `Position`, `GameState`, `Move`,
/// `FEN`, `Square`, `CastlingRights` and friends stay logger-free and
/// I/O-free — not folders, and splitting the pure classifier from its loader
/// is exactly what keeps that contract honest: `ECOClassifier` never learns
/// what a `Bundle` is, and its suite runs on five-row fixtures. The
/// alternative filing, PGN/, would have grown the misfiled-neighbour list
/// that `StockfishEngine` already sits on.
///
/// **Source and provenance.** lichess-org/chess-openings, five TSVs by ECO
/// volume, released CC0 as a collection of facts. Bundled as fetched, never
/// transcribed — the reference-PGN near-loss is the standing lesson about
/// what a hand-copied asset is worth. The dataset carries duplicate rows for
/// common transpositions on purpose, which is what makes
/// `ECOClassifier`'s longest-prefix walk land on the right name.
internal enum ECOTable {

    private static let logger = AppLog.logger(.eco)

    /// Resource base names, one per ECO volume. Fetched as `a.tsv`…`e.tsv`
    /// and renamed on the way in: bundle resources land flat at the Resources
    /// root, where a bare `a.tsv` says nothing about what it is.
    private static let resourceNames = [
        "eco-a", "eco-b", "eco-c", "eco-d", "eco-e",
    ]

    /// The parsed table, built on first use and held for the process.
    ///
    /// `static let` rather than a stored property on a shared object: the
    /// parse is pure, idempotent and read-only afterwards, so Swift's
    /// lazy-once initialization is the whole concurrency story — no actor, no
    /// lock, no injection seam that would only ever be handed the one value.
    /// Callers that *want* a seam take an `ECOClassifier` parameter instead,
    /// which is why `GameClassification.classify` does.
    internal static let bundled: ECOClassifier = load()

    /// Forces the lazy parse onto a background thread and hands back the
    /// table — the door every *async* caller should use.
    ///
    /// The parse is ~3,800 rows of tab splitting and SAN tokenisation. That
    /// is nothing in a release build and emphatically not nothing in a debug
    /// one, where this shape of string work runs an order of magnitude
    /// slower; touching ``bundled`` first from `LibraryDestination`'s
    /// `onAppear` put the whole thing on the main actor inside a view update
    /// and hung the first Library appearance for seconds. XCUITest found it
    /// before Instruments did — two unrelated suites started failing to
    /// resolve elements, which is what a main-thread hang looks like from
    /// the outside.
    ///
    /// After one warm call every later `bundled` touch is a property read,
    /// which is what keeps the synchronous callers (`applyMovetextEdit`)
    /// honest without threading a parameter through a sheet.
    internal static func warmed() async -> ECOClassifier {
        await Task.detached(priority: .utility) { bundled }.value
    }

    // MARK: Loading

    private static func load() -> ECOClassifier {
        var entries: [(line: [String], opening: ECOOpening)] = []
        for name in resourceNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "tsv") else {
                logger?.error(
                    """
                    ECO volume '\(name, privacy: .public).tsv' missing from the app bundle — \
                    games will classify as unclassified until it is restored
                    """
                )
                continue
            }
            do {
                entries.append(contentsOf: try parse(contentsOf: url))
            } catch {
                logger?.error(
                    """
                    ECO volume '\(name, privacy: .public).tsv' unreadable: \
                    \(error.localizedDescription, privacy: .public)
                    """
                )
            }
        }
        logger?.info("ECO table loaded: \(entries.count) lines")
        return ECOClassifier(entries)
    }

    /// Parses one volume. Three tab-separated columns — `eco`, `name`,
    /// `pgn` — with a header row.
    ///
    /// A malformed row is skipped rather than fatal, for the same reason
    /// `ECOClassifier` resolves duplicate keys first-wins: one bad line in a
    /// bundled asset should cost that opening, not the feature. Each skip
    /// logs, so a systematically broken file is loud in Console instead of
    /// quietly classifying nothing.
    private static func parse(contentsOf url: URL) throws -> [(line: [String], opening: ECOOpening)] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var entries: [(line: [String], opening: ECOOpening)] = []
        for row in text.split(whereSeparator: \.isNewline) {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else {
                // `String(row)`, not `row`: os.Logger's interpolation has no
                // `Substring` overload, and the split hands back Substrings.
                logger?.error(
                    "ECO row has \(columns.count) columns, expected 3: \(String(row), privacy: .public)"
                )
                continue
            }
            let code = String(columns[0])
            // The header, and nothing else, has a non-code first column.
            guard code != "eco" else { continue }

            // `MovetextEdit.tokenize` rather than a second move-number
            // stripper: the job is identical (whitespace split, `12.` and
            // glued `1.e4` prefixes dropped), and the codebase's standing
            // rule is that a second implementation of a parsing convention
            // is one drift away from a silent mismatch. The typed throw
            // cannot fire on this data — table lines carry no result token —
            // so it degrades to a skipped row rather than a caught case.
            guard let line = try? MovetextEdit.tokenize(String(columns[2])), !line.isEmpty else {
                logger?.error("ECO row has unusable movetext: \(String(row), privacy: .public)")
                continue
            }
            entries.append((line, ECOOpening(code: code, name: String(columns[1]))))
        }
        return entries
    }
}
