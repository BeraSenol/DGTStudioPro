import Testing
import Foundation
@testable import DGTStudioPro

/// D78′'s only defence: a memo key is correct iff it covers every input, and a missed input is
/// stale rows on screen with a green build. Each assertion moves ONE field and expects
/// inequality — a field the key stops covering goes red here before it goes stale there.
@MainActor
@Suite("Display memo keys")
struct DestinationDisplayKeyTests {

    // MARK: Library

    private static func foldKey(hash: String = "h1") -> LibraryDestination.FoldKey {
        .init(
            content: CollectionFoldKey(rows: [.init(contentHash: hash, checkmate: nil)]),
            running: nil,
            completed: 0,
            hasFailures: false
        )
    }

    private static func narrowKey(
        fold: LibraryDestination.FoldKey = foldKey(),
        filter: LibraryFilter.Signature? = nil,
        query: String = "",
        tokens: [LibrarySearchToken] = [],
        sort: [KeyPathComparator<PGN>] = LibraryDestination.defaultSortOrder
    ) -> LibraryDestination.NarrowKey {
        .init(fold: fold, filter: filter, query: query, tokens: tokens, sort: sort)
    }

    @Test("Every Library narrowing input moves the key")
    func libraryKeyCoversEveryInput() {
        let base = Self.narrowKey()
        #expect(base == Self.narrowKey())
        #expect(base != Self.narrowKey(fold: Self.foldKey(hash: "h2")))
        #expect(base != Self.narrowKey(
            filter: .init(tagID: nil, matchAll: true, rules: [], playerID: nil)
        ))
        #expect(base != Self.narrowKey(query: "carlsen"))
        #expect(base != Self.narrowKey(tokens: [.analyzed]))
        #expect(base != Self.narrowKey(sort: [KeyPathComparator(\PGN.effectiveDate)]))
    }

    /// The live-model input: a tag's rules are editable without any game's content moving, and a
    /// rule edit must invalidate the memo — the one input `CollectionFoldKey` cannot see.
    @Test("A tag rule edit moves the filter signature")
    func ruleEditsMoveTheSignature() {
        let quiet = LibraryFilter.Signature(
            tagID: nil, matchAll: true, rules: [], playerID: nil
        )
        let edited = LibraryFilter.Signature(
            tagID: nil, matchAll: true,
            rules: [TagRule(field: .event, comparison: .contains, text: "Wijk")],
            playerID: nil
        )
        #expect(quiet != edited)
    }

    // MARK: Players

    @Test("Every Players display input moves the key")
    func playersKeyCoversEveryInput() {
        func key(
            content: CollectionFoldKey = CollectionFoldKey(rows: []),
            method: PlayerRanking = .wins,
            sort: [KeyPathComparator<RankedPlayer>] = PlayersDestination.defaultSortOrder,
            query: String = "",
            tokens: [PlayersSearchToken] = []
        ) -> PlayersDestination.DisplayKey {
            .init(content: content, method: method, sort: sort, query: query, tokens: tokens)
        }

        let base = key()
        #expect(base == key())
        #expect(base != key(
            content: CollectionFoldKey(rows: [.init(contentHash: "x", checkmate: nil)])
        ))
        #expect(base != key(method: .rating))
        #expect(base != key(sort: [KeyPathComparator(\RankedPlayer.stats.name)]))
        #expect(base != key(query: "giri"))
        #expect(base != key(tokens: [.rated]))
    }
}
