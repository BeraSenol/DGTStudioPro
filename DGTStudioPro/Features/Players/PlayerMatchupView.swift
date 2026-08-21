import SwiftUI

// MARK: Matchup View

/// The head-to-head core (17 Aug 2026, by request): the fixed player against a re-selectable
/// opponent, seeded with the MOST RECENT one - "the last match up". The W-D-L reads from the
/// fixed player's side via `PlayerStats.opponents`, the same fold the gallery's old opponents
/// panel used, so these numbers cannot disagree with any other surface that folds it.
///
/// **A green/grey/red donut since 18 Aug 2026** (Bera's redesign), where three big numbers in a
/// row stood before. The fold beneath is untouched - this is the same record drawn as a shape, and
/// the shape is what the row could not show: a 12-3-8 and a 3-1-2 printed the same way at different
/// magnitudes, where two donuts differ at a glance. The numbers did not leave; they moved into the
/// legend and the hole. The drawing itself is `RecordChart`, which left this file the same day the
/// Profile tab asked for the same picture - what is left here is the head-to-head fold and the
/// opponent the reader points it at.
///
/// Two hosts: the Players gallery's preview band, and the Matchup tab of a player's Get Info
/// window. **This type is all that survives `PlayerMatchupWindow.swift`** - the window, its
/// `PlayerMatchupRequest` and its `PlayerInfoTabs` merged into `GetInfoWindow` on 18 Aug 2026,
/// and the file was renamed for what is left in it. Hosts apply `.id(playerKey)` so the opponent
/// selection resets when the subject changes.
struct PlayerMatchupView: View {

    let playerKey: String
    let playerName: String
    let records: [GameRecord]

    /// The re-selectable half. Seeded once in `onAppear` rather than derived per render -
    /// the whole point is that the reader can point it somewhere else.
    @State private var opponentKey: String?

    /// The head-to-head fold, memoized (21 Aug 2026). `PlayerStats.opponents` opens by sorting the
    /// **entire** game history, and `body` reads `opponents` twice - once for the picker's
    /// `ForEach`, once through `opponent` - so the plain computed property sorted the whole history
    /// twice on every render of this view, with a third sort in `seedOpponent`.
    ///
    /// The destinations' own `CollectionFoldCache` box at one-view scale, rather than the simpler
    /// `@State` + `onAppear` seed: the hosts do apply `.id(playerKey)`, so a subject change would
    /// re-seed, but `records` can also move underneath a window that stays open (an import, an
    /// edit), and a seeded array would go quietly stale. Keying on the records costs one array
    /// compare of `Hashable` values against an `O(n log n)` sort - the same trade the Library's
    /// fold key already makes.
    @State private var opponentsCache =
        CollectionFoldCache<OpponentsKey, [PlayerStats.Opponent]>()

    /// The fold's inputs as one value. `records` is `[GameRecord]` and `GameRecord` is `Hashable`,
    /// so the whole array participates - a missed input here is a stale opponent list, which is
    /// the only failure mode a memo key has.
    private struct OpponentsKey: Equatable {
        let playerKey: String
        let records: [GameRecord]
    }

    private var opponents: [PlayerStats.Opponent] {
        opponentsCache.value(for: OpponentsKey(playerKey: playerKey, records: records)) {
            PlayerStats.opponents(of: playerKey, in: records)
        }
    }

    /// The other side of the player's chronologically last game - "the last match up".
    /// Decided-or-not deliberately: the most recent opponent is who you *played*, even if
    /// that game is still ongoing; the score below only ever counts decided games.
    ///
    /// **A function, not a property** (21 Aug 2026): it sorts the whole history and its one caller
    /// is `seedOpponent`, which runs on appearance. As a computed property it read like something
    /// `body` could reach for; the call parentheses are the cheapest way to say it is not.
    private func mostRecentOpponentKey() -> String? {
        records
            .filter { $0.white?.key == playerKey || $0.black?.key == playerKey }
            .sorted(by: GameRecord.chronologicalOrder)
            .last
            .flatMap { $0.white?.key == playerKey ? $0.black?.key : $0.white?.key }
    }

    private var opponent: PlayerStats.Opponent? {
        opponents.first { $0.key == opponentKey }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            if let opponent {
                Text("\(playerName) vs \(opponent.name)")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                // `opponent.decided` cannot be zero here - `PlayerStats.opponents` only mints a row
                // when it tallies a decided game - so the chart's empty arm belongs to the Profile
                // tab alone and this host never reaches it.
                RecordChart(
                    wins: opponent.wins,
                    draws: opponent.draws,
                    losses: opponent.losses,
                    accessibilityContext: "against \(opponent.name)"
                )

                Picker("Opponent", selection: $opponentKey) {
                    ForEach(opponents) { entry in
                        Text(entry.name).tag(Optional(entry.key))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 260)
            } else {
                ContentUnavailableView(
                    "No Opponents",
                    systemImage: "person.line.dotted.person",
                    description: Text(
                        "\(playerName) has no decided games against another named player."
                    )
                )
            }
        }
        .onAppear(perform: seedOpponent)
    }

    /// Seeds the opponent once. **The most recent opponent only if they are one of `opponents`**:
    /// that key is deliberately taken from the last game decided or not, and a player whose latest
    /// game is their first against someone - still in progress - has no tally row yet. Seeding to
    /// them left `opponent` nil and the whole view fell to "No Opponents" while real opponents sat
    /// in the picker. (Found 18 Aug 2026 while rebuilding this view; the fallback is the fix.)
    private func seedOpponent() {
        guard opponentKey == nil else { return }
        let recent = mostRecentOpponentKey()
        opponentKey = opponents.contains { $0.key == recent } ? recent : opponents.first?.key
    }

}

// MARK: Previews

#Preview("Matchup") {
    PlayerMatchupView(
        playerKey: PreviewFixtures.topStats().key,
        playerName: PreviewFixtures.topStats().name,
        records: PreviewFixtures.records()
    )
    .padding(28)
    .frame(width: 460, height: 400)
}

/// 7-0-2 through the whole path: hand-written records in, `PlayerStats.opponents` folding them, the
/// shared chart drawing them. `RecordChart`'s own previews check the zero-slice filter directly;
/// this one checks that the fold in front of it produces the record the chart then draws.
#Preview("No Draws") {
    let subject = GameRecord.Side(key: "senol, bera", name: "Bera Senol")
    let rival = GameRecord.Side(key: "heylen, christophe", name: "Christophe Heylen")
    // Subject is always White here, so `.whiteWins` is a win and `.blackWins` a loss.
    let results: [GameResult] = [.whiteWins, .whiteWins, .whiteWins, .whiteWins,
                                 .whiteWins, .whiteWins, .whiteWins, .blackWins, .blackWins]
    let records = results.enumerated().map { index, result in
        GameRecord(
            white: subject,
            black: rival,
            result: result,
            endedInMate: false,
            date: Date(timeIntervalSinceReferenceDate: Double(index) * 86_400),
            importedAt: .now,
            contentHash: "preview-no-draws-\(index)"
        )
    }
    return PlayerMatchupView(
        playerKey: subject.key,
        playerName: subject.name,
        records: records
    )
    .padding(28)
    .frame(width: 460, height: 400)
}

/// The no-opponents arm - a player whose only games are ongoing or against nobody named.
#Preview("No Opponents") {
    PlayerMatchupView(
        playerKey: "nobody",
        playerName: "Nobody Yet",
        records: []
    )
    .padding(28)
    .frame(width: 460, height: 400)
}
