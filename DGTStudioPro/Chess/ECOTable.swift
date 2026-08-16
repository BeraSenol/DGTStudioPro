import Foundation
import os

/// The bundled ECO dataset, parsed once. Deliberately outside the chess core's purity
/// contract and filed beside the classifier - the invariant names types, not folders. lichess
/// data, CC0, bundled as fetched, never transcribed.
enum ECOTable {

    private static let logger = AppLog.logger(.eco)

    /// One resource per volume, renamed from `a.tsv` - bundle resources land flat, where a bare
    /// `a.tsv` says nothing.
    private static let resourceNames = [
        "eco-a", "eco-b", "eco-c", "eco-d", "eco-e",
    ]

    /// Built on first use, held for the process - `static let` gives once-only init for free; the
    /// parse is pure and read-only afterwards.
    static let bundled: ECOClassifier = load()

    /// Forces the lazy parse onto a background thread - the door every async caller should use
    /// (the parse is an order of magnitude slower in debug builds).
    static func warmed() async -> ECOClassifier {
        await Task.detached(priority: .utility) { bundled }.value
    }

    // MARK: Loading

    private static func load() -> ECOClassifier {
        var entries: [(line: [String], opening: ECOOpening)] = []
        for name in resourceNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "tsv") else {
                logger?.error(
                    """
                    ECO volume '\(name, privacy: .public).tsv' missing from the app bundle - \
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

    /// One volume: three tab-separated columns with a header row. Malformed rows skip and log -
    /// trusted content; a defect should cost that opening, not the feature.
    private static func parse(contentsOf url: URL) throws -> [(line: [String], opening: ECOOpening)] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var entries: [(line: [String], opening: ECOOpening)] = []
        for row in text.split(whereSeparator: \.isNewline) {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else {
                // `String(row)`: os.Logger interpolation has no `Substring` overload.
                logger?.error(
                    "ECO row has \(columns.count) columns, expected 3: \(String(row), privacy: .public)"
                )
                continue
            }
            let code = String(columns[0])
            // The header, and nothing else, has a non-code first column.
            guard code != "eco" else { continue }

            // `MovetextEdit.tokenize`, not a second move-number stripper - the splice throw cannot fire on
            // this data (table lines carry no result token).
            guard let line = try? MovetextEdit.tokenize(String(columns[2])), !line.isEmpty else {
                logger?.error("ECO row has unusable movetext: \(String(row), privacy: .public)")
                continue
            }
            entries.append((line, ECOOpening(code: code, name: String(columns[1]))))
        }
        return entries
    }
}
