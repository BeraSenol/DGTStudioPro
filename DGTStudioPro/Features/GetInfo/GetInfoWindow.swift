import os
import SwiftData
import SwiftUI

// MARK: Window

/// M10 - Get Info over three subjects, and the app's one rename door.
/// A window, not a popover or sheet by design: it must survive a click elsewhere.
/// It edits exactly one thing across the player form - the tag; the game form edits per field;
/// the live form is read-only. Body re-runs on request/subject change, not on text-field churn.
struct GetInfoWindow: View {

    // MARK: Static Constants

    /// Borrowed from `DGTConnectionView.Metrics` by name and reason, not imported - two dialogs' two
    /// decisions that agree today.
    private static let contentPadding: CGFloat = 20

    /// `players`, not its own category: the manual checks name `category == "players"` for rename lines.
    private static let logger = AppLog.logger(.players)

    // MARK: Stored Properties

    /// Optional because `WindowGroup(for:)` binds an optional - a restored window with a gone subject
    /// arrives nil, and the unavailable state is the honest answer.
    let request: GetInfoRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(DGTLiveSession.self) private var session

    /// Registry for the seat menus. A `@Query` here where `EditGameInfoSheet` takes strings:
    /// the sheet is container-free for its previews; this window already carries a container.
    @Query(sort: \Player.name) private var knownPlayers: [Player]

    @State private var subject: Subject?

    /// The tag being edited; committed on Return. A draft, not a binding onto `Player.tagName` -
    /// a rename rewrites every linked game with an MD5 each, and a binding would run that per keystroke.
    @State private var draftTag = ""

    /// The refusal, held for the alert; a value means the retag was refused whole, nothing written.
    @State private var refusal: Refusal?

    // MARK: Game Details Drafts

    /// The six text-shaped roster tags as drafts, committed one at a time - `commitField(_:on:)` writes
    /// exactly the property its case names, so a stray edit cannot ride another row's Return.
    @State private var draftEvent = ""
    @State private var draftSite = ""
    @State private var draftRound = ""
    @State private var draftWhite = ""
    @State private var draftBlack = ""
    @State private var draftDate: Date?

    /// `Board` and `TimeControl`. Optional-backed in the model, so an emptied field
    /// is a legitimate nil here in a way it is not for Event or Site.
    @State private var draftBoard = ""
    @State private var draftTimeControl = ""

    /// Which row holds the keyboard, so a commit fires on focus loss as well as Return.
    /// **Focus loss commits here and deliberately not on the player tab** - blast radius: one row vs. every linked game.
    @FocusState private var focusedField: GameField?

    /// A refused field edit, held for its alert: a result the final position disproves, or a
    /// seat that would put one player on both sides.
    @State private var fieldRefusal: FieldRefusal?

    // MARK: Body
    var body: some View {
        Group {
            if let subject {
                content(for: subject)
            } else {
                unavailable
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .navigationTitle(title)
        .task(id: request) { resolve() }
        // Re-resolves when the live game ends - `.task(id: request)` cannot: a `.live` request never
        // changes, and without this the window renders a retained `LiveGame` as "Recording" forever.
        .onChange(of: session.liveGame == nil) { _, _ in
            if case .live = request { resolve() }
        }
        .alert(
            "Can’t Rename",
            isPresented: Binding(present: $refusal),
            presenting: refusal,
            actions: { _ in Button("OK", role: .cancel) {} },
            message: { refusal in Text(Self.refusalMessage(refusal.collisions)) }
        )
        // Separate from the rename refusal: two doors refusing different things must each name theirs.
        .alert(
            fieldRefusal?.title ?? "",
            isPresented: Binding(present: $fieldRefusal),
            presenting: fieldRefusal,
            actions: { _ in Button("OK", role: .cancel) {} },
            message: { refusal in Text(refusal.message) }
        )
    }
}

// MARK: Game Fields

extension GetInfoWindow {

    /// Focus identities and commit targets. Deliberately **not** `SevenTagRoster`: Result is a `Picker`
    /// with no focus state, and reusing the roster would mint a case that can never be focused.
    fileprivate enum GameField: Hashable {
        case event, site, round, white, black, date
        case board, timeControl
    }

    /// A refused per-field edit, as the rendered sentence - cause-to-prose belongs beside the exhaustive switch.
    fileprivate struct FieldRefusal: Identifiable {
        let title: String
        let message: String
        var id: String { title + message }
    }
}

// MARK: Subject

extension GetInfoWindow {

    /// What the window found, vs. what it was asked for. Separate from the request: a request is
    /// `Codable` scene state that outlives the launch; a `@Model` never is (`Error.duplicate`'s split).
    fileprivate enum Subject {
        case game(PGN)
        case live(LiveGame)
        case player(Player)
    }

    /// A refused retag: the store's `Sendable` payload - identifiers and names, never models.
    fileprivate struct Refusal: Identifiable {
        let collisions: [PGNStore.HashCollision]
        var id: PersistentIdentifier { collisions[0].gameID }
    }

    /// Cast paired with `isDeleted`, per the standing invariant: `model(for:)` hands back a tombstone
    /// and every property read on one traps. Falling to unavailable is the truth.
    private func resolve() {
        switch request {
        case .game(let id):
            guard let pgn = modelContext.model(for: id) as? PGN, !pgn.isDeleted else {
                subject = nil
                return
            }
            seedGameDrafts(from: pgn)
            subject = .game(pgn)

        case .live:
            // From the session, not the request: a request holding it would put a @MainActor class in Codable scene state.
            guard let live = session.liveGame else {
                subject = nil
                return
            }
            subject = .live(live)

        case .player(let key):
            // Predicated: `normalizedName` is the key, so at most one row matches.
            var descriptor = FetchDescriptor<Player>(
                predicate: #Predicate { $0.normalizedName == key }
            )
            descriptor.fetchLimit = 1
            guard let player = try? modelContext.fetch(descriptor).first, !player.isDeleted else {
                subject = nil
                return
            }
            // Stored **tag** form (`tagName ?? name`). Seeding from `name` would put a display form in a
            // field that stores a tag - the first commit writes it into every game's `[White]` (the trap).
            draftTag = player.tagName ?? player.name
            subject = .player(player)

        case .none:
            subject = nil
        }
    }

    /// Seeds drafts from stored state, beside the fetch. **Tag form in, verbatim**, `?` included -
    /// these fields edit what export writes byte for byte. Round is a String draft: the empty
    /// field must be expressible.
    private func seedGameDrafts(from pgn: PGN) {
        draftEvent = pgn.event
        draftSite = pgn.site
        draftRound = pgn.round.map(String.init) ?? ""
        draftWhite = pgn.white
        draftBlack = pgn.black
        draftDate = pgn.date
        // Empty string for nil, not the export's `?` / `-` - a field pre-filled with `-` invites editing
        // around a placeholder. The commit maps empty back to nil.
        draftBoard = pgn.board ?? ""
        draftTimeControl = pgn.timeControl ?? ""
    }

    private var title: String {
        switch subject {
        case .game(let pgn):     pgn.name
        case .live:              "Recording"
        case .player(let player): PlayerName.displayForm(of: player.tagName ?? player.name)
        // The unresolved arm names the affordance, not the category - "Get Info" is what the menu
        // item and the scene title say (21 Aug 2026).
        case .none:              "Get Info"
        }
    }
}

// MARK: Content

extension GetInfoWindow {

    @ViewBuilder
    private func content(for subject: Subject) -> some View {
        switch subject {
        case .game(let pgn):      gameForm(pgn)
        case .live(let live):     liveForm(live)
        case .player(let player): playerForm(player)
        }
    }

    /// An archived game. Three tabs since **the split is by authorship, not topic**:
    /// Details = the nine exported tags the reader can rewrite, File = what the app derived (read-only),
    /// Move Text = the editor - named "Move Text", not "PGN", because it shows half the file.
    /// Move Text exists on the game form only: a live game has no stored movetext.
    /// `.tabItem`, not the 2027 `Tab(role:)` spelling - beta.
    private func gameForm(_ pgn: PGN) -> some View {
        TabView {
            detailsTab(pgn)
                .tabItem { Label("Details", systemImage: "list.bullet.rectangle") }

            moveTextTab(pgn)
                .tabItem { Label("Move Text", systemImage: "text.line.first.and.arrowtriangle.forward") }

            fileTab(pgn)
                .tabItem { Label("File", systemImage: "doc.text.magnifyingglass") }
        }
        .padding(.top, 8)
        .accessibilityIdentifier(AccessibilityID.getInfoGame)
    }

    /// The editor, hosted. Commit model differs from Details on purpose: per-field vs.
    /// accept-whole-or-reject-whole. `.id(pgn.persistentModelID)` is load-bearing - the editor seeds in `init`.
    private func moveTextTab(_ pgn: PGN) -> some View {
        MovetextEditorView(pgn: pgn) { proposed in
            applyMovetext(proposed, to: pgn)
        }
        .id(pgn.persistentModelID)
        .accessibilityIdentifier(AccessibilityID.getInfoGameMoveText)
    }

    /// The nine exported tags, editable. Native controls make invalid states unreachable
    /// rather than validated (a `Picker` cannot produce a foreign result, a `DatePicker` 2026-02-31);
    /// the one rule no widget knows - result vs. final position - is checked.
    private func detailsTab(_ pgn: PGN) -> some View {
        Form {
            Section("Seven Tag Roster") {
                TextField("Event", text: $draftEvent)
                    .focused($focusedField, equals: .event)
                    .onSubmit { commitField(.event, on: pgn) }
                    .accessibilityIdentifier(AccessibilityID.getInfoGameField("event"))

                TextField("Site", text: $draftSite)
                    .focused($focusedField, equals: .site)
                    .onSubmit { commitField(.site, on: pgn) }
                    .accessibilityIdentifier(AccessibilityID.getInfoGameField("site"))

                dateRow(pgn)

                TextField("Round", text: $draftRound)
                    .focused($focusedField, equals: .round)
                    .onSubmit { commitField(.round, on: pgn) }
                    .accessibilityIdentifier(AccessibilityID.getInfoGameField("round"))

                seatRow("White", text: $draftWhite, field: .white, on: pgn)
                seatRow("Black", text: $draftBlack, field: .black, on: pgn)

                resultRow(pgn)
            }

            // The other two of the nine, in exported order. Their own section: `SevenTagRosterSection`
            // renders from `allCases` precisely so the roster cannot quietly grow to nine.
            Section("Equipment") {
                TextField("Board", text: $draftBoard)
                    .focused($focusedField, equals: .board)
                    .onSubmit { commitField(.board, on: pgn) }
                    .accessibilityIdentifier(AccessibilityID.getInfoGameField("board"))

                TextField("Time Control", text: $draftTimeControl)
                    .focused($focusedField, equals: .timeControl)
                    .onSubmit { commitField(.timeControl, on: pgn) }
                    .accessibilityIdentifier(AccessibilityID.getInfoGameField("timecontrol"))
            }
            // Commits the row the keyboard just left - `focusedField` is already nil or the next case, so
            // `previous` names the field whose draft is the one to write.
            .onChange(of: focusedField) { previous, _ in
                if let previous { commitField(previous, on: pgn) }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoGameDetails)
    }

    /// Date row with its own "no date" arm: a bare `DatePicker` cannot express nil, and nil is real -
    /// the exporter writes `????.??.??` for it.
    @ViewBuilder
    private func dateRow(_ pgn: PGN) -> some View {
        if let bound = draftDate {
            LabeledContent("Date") {
                HStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { bound },
                            set: { draftDate = $0; commitField(.date, on: pgn) }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    Button("Clear") {
                        draftDate = nil
                        commitField(.date, on: pgn)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.getInfoGameField("date"))
        } else {
            LabeledContent("Date") {
                Button("Set Date…") {
                    draftDate = Date()
                    commitField(.date, on: pgn)
                }
            }
            .accessibilityIdentifier(AccessibilityID.getInfoGameField("date"))
        }
    }

    /// A seat row. **The most dangerous rows in this window, and they look like the least**: editing
    /// White here rewrites this game's tag (blast radius one); the player tab rewrites every linked
    /// game. The derived line beneath is the only thing saying the value is a tag.
    private func seatRow(
        _ label: String,
        text: Binding<String>,
        field: GameField,
        on pgn: PGN
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                TextField(label, text: text)
                    .focused($focusedField, equals: field)
                    .onSubmit { commitField(field, on: pgn) }

                seatMenu(for: text, field: field, on: pgn)
            }

            // Only when it differs from the field, so the ordinary case carries no line repeating itself.
            if PlayerName.displayForm(of: text.wrappedValue) != text.wrappedValue {
                Text("Shown as \(PlayerName.displayForm(of: text.wrappedValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.getInfoGameField(label.lowercased()))
    }

    /// Known-player menu trailing a seat field - `LiveGameRosterForm.playerMenu`'s shape,
    /// deliberately not shared: that menu only fills (a sheet has Save); this one must commit on pick
    /// or the choice sits uncommitted with no Save to land it. Picking creates no `Player`.
    @ViewBuilder
    private func seatMenu(
        for text: Binding<String>,
        field: GameField,
        on pgn: PGN
    ) -> some View {
        if !knownPlayers.isEmpty {
            Menu {
                ForEach(knownPlayers, id: \.persistentModelID) { player in
                    // Insert the remembered *tag* form; the label shows the string it inserts.
                    let tag = player.tagName ?? player.name
                    Button(tag) {
                        text.wrappedValue = tag
                        commitField(field, on: pgn)
                    }
                }
            } label: {
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.borderless)
            .fixedSize()
            .help("Choose a known player")
            .accessibilityIdentifier(
                AccessibilityID.getInfoSeatPicker(field == .white ? "white" : "black")
            )
        }
    }

    /// Result picker, checked against the final position on change. `*` deliberately not
    /// offered: an imported `*` can be decided here and never set back - the right asymmetry.
    private func resultRow(_ pgn: PGN) -> some View {
        Picker(
            "Result",
            selection: Binding(
                get: { pgn.result },
                set: { commitResult($0, on: pgn) }
            )
        ) {
            ForEach(GameResult.allCases.filter { $0 != .ongoing }, id: \.self) { result in
                Text(result.rawValue).tag(result)
            }
        }
        .accessibilityIdentifier(AccessibilityID.getInfoGameField("result"))
    }

    /// Everything the app derived about the row - read-only by the authorship split.
    /// Hash and identifier are selectable and monospaced: an MD5 you cannot copy answers nothing.
    private func fileTab(_ pgn: PGN) -> some View {
        Form {
            Section("Library") {
                // The ordinal row.
                LabeledContent(
                    "Index",
                    value: pgn.libraryIndex.map(String.init) ?? RosterSummary.displayUnknown
                )
                LabeledContent("Name", value: pgn.name)
                LabeledContent("Imported", value: Self.stamp(pgn.importedAt))
                LabeledContent("Plies", value: "\(pgn.moves.count)")
                LabeledContent(
                    "Moves",
                    value: pgn.moves.isEmpty ? RosterSummary.displayUnknown
                                             : "\((pgn.moves.count + 1) / 2)"
                )
            }

            Section("Identity") {
                LabeledContent("Content Hash") {
                    Text(pgn.contentHash)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                // Seats as *resolved* - a different question from the seats as *tagged* one tab over, and the
                // only place in the app the difference is visible (an unlinked row the backfill has not reached).
                LabeledContent(
                    "White Player",
                    value: pgn.whitePlayer?.name ?? RosterSummary.displayUnknown
                )
                LabeledContent(
                    "Black Player",
                    value: pgn.blackPlayer?.name ?? RosterSummary.displayUnknown
                )
            }

            Section("Classification") {
                LabeledContent("ECO", value: pgn.opening?.code ?? RosterSummary.displayUnknown)
                LabeledContent("Family", value: pgn.ecoFamily ?? RosterSummary.displayUnknown)
                LabeledContent("Variation", value: pgn.ecoVariation ?? RosterSummary.displayUnknown)
                LabeledContent(
                    "Checkmate Type",
                    value: pgn.specialCheckmate?.displayName ?? RosterSummary.displayUnknown
                )
            }

        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoGameFile)
    }

    /// The live roster. No file facts and no File tab: it has none until it archives, and empty rows
    /// would describe the archived game this one is going to become. Read-only - the live roster's
    /// editor is `EditLiveGameDetailsSheet`.
    private func liveForm(_ live: LiveGame) -> some View {
        let roster = RosterSummary(live.roster, result: live.result)
        return Form {
            Section("Seven Tag Roster") {
                ForEach(SevenTagRoster.allCases, id: \.self) { tag in
                    LabeledContent(tag.rawValue, value: roster[tag])
                }
            }

            Section("Recording") {
                LabeledContent("Plies", value: "\(live.sanMoves.count)")
                LabeledContent("Board", value: live.roster.board ?? RosterSummary.displayUnknown)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoLive)
    }

    /// A player. **Three tabs since 18 Aug 2026, when the Matchup window merged in here**: that
    /// window and this form described one player through two doors - a double-click reached the
    /// profile, ⌘I reached the rename - and neither could see the other's edits, so a rename left a
    /// stale name in the open profile beside it. The doors survive; they now arrive at one window.
    ///
    /// Tab order is Info, Profile, Matchup, and the cost sits on the other door now: a double-click
    /// used to open straight onto the profile and opens onto the rename form instead, one tab away
    /// from what it asked for. ⌘I keeps landing where it always did.
    private func playerForm(_ player: Player) -> some View {
        PlayerInfoTabs(
            playerKey: player.normalizedName,
            playerName: PlayerName.displayForm(of: player.tagName ?? player.name)
        ) { stats, rating in
            playerIdentityTab(player, stats: stats, rating: rating)
        }
        .accessibilityIdentifier(AccessibilityID.getInfoPlayer)
    }

    /// The registry row, the folded numbers, and the app's one rename door. Tag form above display
    /// form, in that order - names travel tag → display, never back.
    private func playerIdentityTab(
        _ player: Player,
        stats: PlayerStats?,
        rating: Glicko1.Rating?
    ) -> some View {
        Form {
            Section("Name") {
                // **The seat rows' shape, adopted 18 Aug 2026 by request**: a caption under the
                // field rather than a `LabeledContent` row of its own. Two rows made the display
                // form look like a second thing to edit; a caption reads as what the field above
                // will produce, which is what it is. Same rule as `seatRow` - printed only when it
                // differs from what was typed, so the ordinary case carries no line repeating
                // itself.
                VStack(alignment: .leading, spacing: 2) {
                    // Commit on Return only - each commit is `retag`, a rewrite across every linked game. Focus loss
                    // would fire on a mere click away, which is not a decision the reader made.
                    TextField("Tag", text: $draftTag)
                        .onSubmit { commitRename(for: player) }
                        .accessibilityIdentifier(AccessibilityID.getInfoPlayerTagField)

                    if PlayerName.displayForm(of: draftTag) != draftTag {
                        Text("Shown as \(PlayerName.displayForm(of: draftTag))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // The 4 × 2 grid, moved here from the other tab (Bera, 18 Aug 2026). It reads as
            // identity rather than performance - Games, Record, Rating, the two dates - and it left
            // that tab holding two charts and nothing to compete with them.
            //
            // Omitted rather than zeroed when the fold finds nothing: a grid of eight dashes states
            // less than its absence, and the registry row above still says the player exists.
            if let stats {
                Section("Statistics") {
                    PlayerStatsGrid(stats: stats, rating: rating)
                }
            }

            Section("Library") {
                // Counted off relationships, not the `PlayerStats` fold - this asks a smaller
                // question than the grid above. **"Linked" is load-bearing** (18 Aug 2026): before
                // the merge these two counts lived in two windows and nobody held them side by side;
                // now they are adjacent sections, and "Games" up there and "Games" here would read
                // as the same number while differing - a game the seat backfill has not linked is
                // counted there and not here. The label is the difference, made visible.
                LabeledContent("Linked Games", value: "\(player.whiteGames.count + player.blackGames.count)")
                LabeledContent("As White", value: "\(player.whiteGames.count)")
                LabeledContent("As Black", value: "\(player.blackGames.count)")
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoPlayerIdentity)
    }

    /// One state for every way a subject can be absent - the causes differ, the remedy does not, and
    /// splitting them would explain a deletion the reader performed.
    private var unavailable: some View {
        InspectorEmptyState(
            title: "Nothing to Show",
            systemImage: "questionmark.circle",
            message: "The game or player this window was opened for is no longer available.",
            identifier: AccessibilityID.getInfoEmpty
        )
        .padding(Self.contentPadding)
    }
}

// MARK: Player Tabs

/// The player subject's tab host. **Profile and Matchup arrived whole from `PlayerMatchupWindow`**
/// (deleted 18 Aug 2026, this file is where it went); every number still rides the shared folds -
/// `PlayerStats.index`, `Glicko1.histories` - so nothing here can disagree with a destination.
///
/// Its own type, and the `@Query` is the reason: folding the Library belongs to the player subject
/// alone. Declared on the window it would run for every game and live info window too - the whole
/// library fetched to render nine roster rows.
///
/// The identity tab is passed in rather than built here. The rename's draft, refusal and alert are
/// window state (`resolve()` seeds `draftTag`, the alert hangs off the window's body), and moving
/// the app's widest write - a retag rewrites every linked game - into a child to save one closure
/// would buy tidiness with ownership.
private struct PlayerInfoTabs<IdentityTab: View>: View {

    // MARK: Stored Properties

    /// `Player.normalizedName`, which is also `PlayerStats.key` - one key space, or the folds below
    /// silently match nothing and the player reads as having no games.
    let playerKey: String
    let playerName: String

    /// **Handed the folded stats**, because the Info tab prints the 4 × 2 grid (Bera, 18 Aug 2026 -
    /// it lived on the other tab for a day). The window that builds this closure cannot fold: it
    /// holds a `Player` row, and Games / Win % / Rating / Mates / the two dates all come off the
    /// Library fold that lives here. Nil means the fold found nothing, and the grid is omitted -
    /// a registry row with no games is ordinary.
    @ViewBuilder let identityTab: (PlayerStats?, Glicko1.Rating?) -> IdentityTab

    /// Unsorted and unfiltered: both folds take the whole Library and key it themselves. Fetch-all
    /// -and-map per render, the destinations' own cost family - censused, not optimised ahead of a
    /// measurement.
    @Query private var games: [PGN]

    // MARK: Derived
    private var records: [GameRecord] { games.map(\.gameRecord) }

    private var stats: PlayerStats? {
        PlayerStats.index(of: records).first { $0.key == playerKey }
    }

    private var history: [Glicko1.Sample] {
        Glicko1.histories(from: records)[playerKey] ?? []
    }

    // MARK: Body

    /// `Tab(_:systemImage:)`, where the game form one file up uses `.tabItem` - the two spellings
    /// are the two ages of this file, not a distinction. Neither is the beta `Tab(role:)`.
    var body: some View {
        TabView {
            // **Info leads** (Bera, 18 Aug 2026 - the merge's second pass): the first tab is what
            // both doors land on, and this is the window called Get Info. It also restores what ⌘I
            // did before the merge, which the first arrangement had cost; the double-click pays the
            // tab instead, and it is the cheaper of the two to make pay.
            Tab("Info", systemImage: "info.circle") {
                identityTab(stats, history.last?.rating)
            }
            // **"Performance", not "Profile"** (18 Aug 2026): with the grid gone to Info and the
            // monogram and name gone entirely, what is left is the record and the rating over
            // games - how the player has done, not who they are. "Profile" named the tab when it
            // held the identity; Info holds that now. "Record" was the other candidate and lost to
            // the grid cell of that name now sitting one tab away, where the two would read as the
            // same scope.
            Tab("Performance", systemImage: "chart.line.uptrend.xyaxis") {
                performanceTab
            }
            Tab("Matchup", systemImage: "person.line.dotted.person") {
                ScrollView {
                    PlayerMatchupView(
                        playerKey: playerKey,
                        playerName: playerName,
                        records: records
                    )
                    // The hosts' standing rule: without it the previous subject's opponent lingers
                    // when the window is re-pointed.
                    .id(playerKey)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier(AccessibilityID.getInfoPlayerMatchup)
            }
        }
        .padding(.top, 8)
    }

    /// **Two charts and nothing else** (Bera, 18 Aug 2026): the career record as a donut and the
    /// rating over games. The monogram and the name line went with the grid - a window whose title
    /// bar and whose Info tab both already name the player was introducing him a third time, and
    /// the tab is stronger as two pictures than as a portrait with pictures under it.
    ///
    /// A player with a registry row but no folded games is reachable and ordinary - the row outlives
    /// the games that made it, and every game of theirs may still be ongoing.
    @ViewBuilder
    private var performanceTab: some View {
        if let stats {
            ScrollView {
                VStack(spacing: 24) {
                    // The same `RecordChart` the Matchup tab draws, so a record is drawn one way in
                    // this window whichever tab is showing.
                    RecordChart(wins: stats.wins, draws: stats.draws, losses: stats.losses)

                    if !history.isEmpty {
                        RatingTrendChart(history: history)
                            .frame(maxWidth: 460)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(AccessibilityID.getInfoPlayerPerformance)
        } else {
            ContentUnavailableView(
                "No Games Yet",
                systemImage: "person.crop.circle.dashed",
                description: Text("\(playerName) has no games in the Library.")
            )
            .accessibilityIdentifier(AccessibilityID.getInfoPlayerPerformance)
        }
    }
}

// MARK: Rename

extension GetInfoWindow {

    /// The movetext write door (moved with the affordance). `.rejected` here means this window's
    /// Save gate and the store's validator disagreed - impossible, both call `MovetextEdit.validate`;
    /// logged as a breadcrumb. Unlike its Board ancestor it rebuilds no cached `Game`.
    fileprivate func applyMovetext(_ proposed: [String], to pgn: PGN) {
        do {
            let outcome = try PGNStore(modelContext: modelContext)
                .applyMovetextEdit(to: pgn, proposed: proposed)
            if case .success = outcome {
                Self.logger?.info("Movetext edit applied to '\(pgn.name, privacy: .public)'")
            } else {
                Self.logger?.error("Movetext edit unexpectedly rejected at commit")
            }
        } catch {
            Self.logger?.error(
                "Movetext edit failed to persist: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Commits one roster field through `applyEdit`. Two guards ahead of the door, both
    /// load-bearing: unchanged returns early ("nothing happened" and "rewritten identically" look the
    /// same from outside); emptied Event/Site reverts - `""` exports as neither a name nor an unknown.
    fileprivate func commitField(_ field: GameField, on pgn: PGN) {
        let store = PGNStore(modelContext: modelContext)
        do {
            switch field {
            case .event:
                let proposed = draftEvent.trimmingCharacters(in: .whitespaces)
                guard !proposed.isEmpty else { draftEvent = pgn.event; return }
                guard proposed != pgn.event else { return }
                try store.applyEdit(to: pgn) { $0.event = proposed }

            case .site:
                let proposed = draftSite.trimmingCharacters(in: .whitespaces)
                guard !proposed.isEmpty else { draftSite = pgn.site; return }
                guard proposed != pgn.site else { return }
                try store.applyEdit(to: pgn) { $0.site = proposed }

            case .round:
                let trimmed = draftRound.trimmingCharacters(in: .whitespaces)
                // Non-numeric reverts rather than clearing: reading "quarterfinal" as nil would discard what was
                // typed under the spelling an intentional clear uses.
                let proposed: Int? = trimmed.isEmpty ? nil : Int(trimmed)
                guard trimmed.isEmpty || proposed != nil else {
                    draftRound = pgn.round.map(String.init) ?? ""
                    return
                }
                guard proposed != pgn.round else { return }
                try store.applyEdit(to: pgn) { $0.round = proposed }

            case .white:
                let proposed = seatValue(draftWhite)
                guard proposed != pgn.white else { return }
                guard !Player.seatsNameOnePlayer(proposed, pgn.black) else {
                    draftWhite = pgn.white
                    fieldRefusal = Self.sameSeatRefusal(proposed)
                    return
                }
                try store.applyEdit(to: pgn) { $0.white = proposed }
                draftWhite = proposed

            case .black:
                let proposed = seatValue(draftBlack)
                guard proposed != pgn.black else { return }
                guard !Player.seatsNameOnePlayer(proposed, pgn.white) else {
                    draftBlack = pgn.black
                    fieldRefusal = Self.sameSeatRefusal(proposed)
                    return
                }
                try store.applyEdit(to: pgn) { $0.black = proposed }
                draftBlack = proposed

            case .date:
                guard draftDate != pgn.date else { return }
                try store.applyEdit(to: pgn) { $0.date = draftDate }

            // Both clear to nil, unlike Event and Site: they are `String?`, and "no board" is a value a game
            // can honestly have where "no event" is not.
            case .board:
                let proposed = optionalValue(draftBoard)
                guard proposed != pgn.board else { return }
                try store.applyEdit(to: pgn) { $0.board = proposed }

            case .timeControl:
                let proposed = optionalValue(draftTimeControl)
                guard proposed != pgn.timeControl else { return }
                try store.applyEdit(to: pgn) { $0.timeControl = proposed }
            }
        } catch {
            Self.logger?.error(
                "Info edit failed to persist: \(error.localizedDescription, privacy: .public)"
            )
            seedGameDrafts(from: pgn)
        }
    }

    /// An emptied seat becomes PGN's `?`, written back into the draft so the field shows what it
    /// stored rather than inviting a second identical commit.
    private func optionalValue(_ draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func seatValue(_ draft: String) -> String {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? RosterSummary.unknownTag : trimmed
    }

    /// Names the player, not the rule - the reader can see the rule from the two fields.
    private static func sameSeatRefusal(_ tag: String) -> FieldRefusal {
        FieldRefusal(
            title: "Can’t Set Both Seats to One Player",
            message: "\(PlayerName.displayForm(of: tag)) is already the other seat. "
            + "A game needs two players; give one seat a different name, or "
            + "clear it to “\(RosterSummary.unknownTag)” if it isn’t known."
        )
    }

    /// Commits a result, refusing what the final position disproves. Reuses
    /// `MovetextEdit.validate` - stored moves are canonical, so replay can only fail on the result
    /// arms. Resignations, agreed draws, wins on time all stay settable.
    fileprivate func commitResult(_ proposed: GameResult, on pgn: PGN) {
        guard proposed != pgn.result else { return }

        switch MovetextEdit.validate(pgn.moves, claimedResult: proposed) {
        case .success:
            do {
                try PGNStore(modelContext: modelContext)
                    .applyEdit(to: pgn) { $0.result = proposed }
            } catch {
                Self.logger?.error(
                    "Result edit failed to persist: \(error.localizedDescription, privacy: .public)"
                )
            }
        case .failure(let rejection):
            fieldRefusal = FieldRefusal(
                title: "Can’t Change Result",
                message: Self.resultMessage(rejection)
            )
        }
    }

    /// Exhaustive over `MovetextEdit.Rejection` so a future case is a compile error, not a swallowed
    /// refusal. Three arms are unreachable from this caller (stored moves cannot be illegal).
    private static func resultMessage(_ rejection: MovetextEdit.Rejection) -> String {
        switch rejection {
        case .checkmateResultMismatch(let expected, _):
            "The game ends in checkmate, so the result must be \(expected.rawValue)."
        case .stalemateRequiresDraw:
            "The final position is stalemate, so the result must be a draw."
        case .resultRequiresDecision:
            "An archived game needs a decided result."
        case .claimsCheckmateButPositionIsNot(let san):
            "The last move (\(san)) is written as checkmate but the position is not."
        case .illegalMove(let index, let san, _):
            "The stored moves don’t replay, ply \(index + 1) (\(san)) is illegal."
        case .splicedGames(let token):
            "The stored movetext contains more than one game (at “\(token)”)."
        }
    }

    // MARK: File Tab Formatters

    /// Date *and* time, unlike every date elsewhere - two imports minutes apart are what this row
    /// exists to tell apart (deliberately not `RosterSummary.displayDate`, which is a playing day).
    private static func stamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// The transport; every consequence belongs to the store door. Two failure sinks: a refusal is a
    /// value the reader sees, a save failure is a logged error. Two no-op guards ahead of the door -
    /// empty tag reverts (never reaches `.emptyTag`), unchanged tag skips a full rehash.
    fileprivate func commitRename(for player: Player) {
        let proposed = draftTag.trimmingCharacters(in: .whitespaces)
        guard !proposed.isEmpty else {
            draftTag = player.tagName ?? player.name
            return
        }
        guard proposed != (player.tagName ?? player.name) else { return }

        do {
            try PGNStore(modelContext: modelContext).retag(player, to: proposed)
        } catch let rejection as PGNStore.RetagRejection {
            present(rejection, revertingTo: player)
        } catch {
            Self.logger?.error("Rename failed: \(error.localizedDescription, privacy: .public)")
            draftTag = player.tagName ?? player.name
        }
    }

    /// `.emptyTag` cannot reach here (`commitRename` guards it), so this is the collision case
    /// only; a third rejection arrives as a compile error. The field reverts on refusal.
    private func present(_ rejection: PGNStore.RetagRejection, revertingTo player: Player) {
        switch rejection {
        case .wouldCollide(let collisions):
            refusal = Refusal(collisions: collisions)
        case .emptyTag:
            Self.logger?.error("Retag refused for an empty tag, the field's guard let one through")
        }
        draftTag = player.tagName ?? player.name
    }

    /// Names the games - "would create a duplicate" is unactionable otherwise. Capped: an alert is not a report.
    fileprivate static func refusalMessage(_ collisions: [PGNStore.HashCollision]) -> String {
        let shown = collisions.prefix(3).map { "“\($0.gameName)” and “\($0.existingName)'" }
        let lead = "This would make these games identical: " + shown.joined(separator: "; ") + "."
        let more = collisions.count > shown.count
            ? " And \(collisions.count - shown.count) more."
            : ""
        return lead + more + " Delete or edit one of each pair first, nothing has been changed."
    }
}

// MARK: Previews

/// The branch a reader hits by accident, and the one state needing no resolved subject - the
/// content forms need a model in a container, and a preview building one tests SwiftData, not layout.
#Preview("Unavailable") {
    GetInfoWindow(request: nil)
        .frame(width: 460, height: 520)
        .modelContainer(for: [PGN.self, Player.self], inMemory: true)
        .environment(DGTLiveSession())
}

/// All three game tabs on a fixture rich enough to make the File tab say something and
/// give Move Text a real score sheet. The fixture sets classification directly - fine in a
/// preview that never runs in the app, and the reason those fields are absent from `PGN.init`
/// (`classify` stays the single door).
#Preview("Game, Three Tabs") {
    let container = try! ModelContainer(
        for: PGN.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let pgn = PGN(
        event: "DGT USB eBoard",
        site: "Hasselt, Limburg BEL",
        round: 47,
        white: "Senol, Bera",
        black: "Heylen, Christophe",
        moves: ["e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5", "d4", "Nf6",
                "Nf3", "c6", "Bc4", "Bf5", "Bd2", "e6", "Qe2", "Bb4",
                "O-O-O", "Nbd7", "Kb1", "O-O"],
        result: .blackWins
    )
    container.mainContext.insert(pgn)
    pgn.libraryIndex = 47
    pgn.date = Date(timeIntervalSince1970: 1_773_000_000)
    pgn.board = "DGT 3000448278"
    pgn.timeControl = "600+5"
    pgn.ecoCode = "B01"
    pgn.ecoFamily = "Scandinavian Defense"
    pgn.ecoVariation = "Main Line, Mieses Variation"
    // Twelve of twenty, on purpose - see the doc above.
    pgn.evaluations = (0..<20).map { ply in
        ply < 12 ? Evaluation.centipawns((ply % 5) * 40 - 60) : nil
    }

    return GetInfoWindow(request: .game(pgn.persistentModelID))
        .frame(width: 460, height: 560)
        .modelContainer(container)
        .environment(DGTLiveSession())
}

/// The live form - the one content branch a canvas reaches without a container, and the only
/// place `LiveGame.Roster`'s projection renders outside the live inspector.
#Preview("Recording") {
    let session = DGTLiveSession()
    session.startNewGame(
        roster: LiveGame.Roster(
            event: "Club Championship",
            site:  "Antwerp",
            date:  Date(timeIntervalSince1970: 1_720_000_000),
            round: 101,
            white: "Senol, Bera",
            black: "Reinaud, Lorenzo"
        )
    )
    return GetInfoWindow(request: .live)
        .frame(width: 460, height: 520)
        .modelContainer(for: [PGN.self, Player.self], inMemory: true)
        .environment(session)
}
