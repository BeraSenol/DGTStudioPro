import os
import SwiftData
import SwiftUI

// MARK: - Window

/// M10 — one gesture on the thing itself, and the app's rename door.
///
/// **Scope, because an earlier version of this comment got it wrong:** it edits
/// exactly one thing, a player's tag name. The game and live forms are
/// read-only — a current fact rather than a permanent one, but a doc describing
/// the destination instead of the code is the shape this project keeps
/// catching itself in.
///
/// **It replaces five pencils rather than joining them.** D26′ kept five edit
/// affordances from drifting by making them one type; what it could not do is
/// make them one *surface*. Get Info is one gesture on the subject itself,
/// which is what lets rename stop being a special case rather than a pencil
/// rehomed.
///
/// The rename machinery moved here **whole**: a sheet opened from this window
/// would be a modal over a companion window, and a door left in the destination
/// with the field here would be two surfaces for one write. D37′'s argument
/// survived intact — the player form already had that shape and only needed its
/// top row to become a field.
///
/// **A window, not a popover or sheet** — D46′ taken as settled, having been
/// field-tested against a popover and reverted inside a day. You edit an event
/// name while reading the board, so this must survive a click elsewhere.
///
/// Resolution is `@State` written by `.task(id:)` rather than computed: a store
/// lookup does not belong on a render path, and this body should re-run when
/// the request or subject changes, not when a text field does.
internal struct GetInfoWindow: View {

    // MARK: Static Constants

    /// Borrowed from `DGTConnectionView.Metrics` by name and reason rather than
    /// imported: two dialogs' two decisions that agree today, where a shared
    /// constant would claim they must agree forever.
    private static let contentPadding: CGFloat = 20

    /// `players`, not a category of this window's own: the retag lines this
    /// door emits are the same lines the sweep and the old sheet emitted, and
    /// splitting them would make `log stream --predicate 'category ==
    /// "players"'` — which the manual checks name — stop showing renames.
    private static let logger = AppLog.logger(.players)

    // MARK: Stored Properties

    /// Optional because `WindowGroup(for:)` binds an optional value — a
    /// restored window whose subject is gone arrives here as nil, and the
    /// unavailable state is the honest answer rather than a bug to guard.
    internal let request: GetInfoRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(DGTLiveSession.self) private var session

    /// The registry, for the Details tab's seat menus (5 Aug 2026).
    ///
    /// A `@Query` here where `EditGameInfoSheet` takes strings, and that is not
    /// inconsistency: the sheet is deliberately container-free so its previews
    /// can build it, while this window already carries a container. Querying
    /// buys reactivity a passed snapshot would not. Sorted by `name`, matching
    /// both other seat menus. D59′.
    @Query(sort: \Player.name) private var knownPlayers: [Player]

    @State private var subject: Subject?

    /// The tag being edited, seeded by `resolve()` and committed on Return.
    ///
    /// A draft rather than a binding onto `Player.tagName` (D37′): a rename is
    /// a rewrite across every linked game, each with an MD5 and a re-resolve,
    /// and a binding would run that per keystroke.
    @State private var draftTag = ""

    /// D39′'s refusal, held for the alert. Nil is the normal state; a value
    /// means the last retag was refused whole and nothing was written.
    @State private var refusal: Refusal?

    // MARK: Game Details Drafts (D57′)

    /// The six text-shaped roster tags, held as drafts and committed one at a
    /// time — the player tab's arrangement, widened.
    ///
    /// Drafts rather than bindings onto the model: a commit is
    /// `PGNStore.applyEdit`, which re-resolves both seats and recomputes the
    /// MD5, and a binding would run that per keystroke.
    ///
    /// Separate `@State`s rather than a draft struct, because the field is the
    /// unit of work — `commitField(_:on:)` writes exactly the property its case
    /// names, so a stray edit cannot ride along with another row's Return. A
    /// struct would make "which changed?" a diff, the shape D18′ rejected at
    /// `applyEdit`.
    @State private var draftEvent = ""
    @State private var draftSite = ""
    @State private var draftRound = ""
    @State private var draftWhite = ""
    @State private var draftBlack = ""
    @State private var draftDate: Date?

    /// The two tags D24′ writes *after* the roster — `Board` and `TimeControl`
    /// — which are editable on Details as of the same-evening amendment to
    /// D57′. Optional-backed in the model, so an emptied field is a legitimate
    /// nil here in a way it is not for Event or Site.
    @State private var draftBoard = ""
    @State private var draftTimeControl = ""

    /// Which row holds the keyboard, so a commit can fire on focus loss as
    /// well as on Return.
    ///
    /// **Focus loss commits here and deliberately does not on the player tab.**
    /// The difference is blast radius: a game edit writes one row, a rename
    /// rewrites every game the player appears in, so committing that on focus
    /// loss would make clicking away a forty-game rewrite. Two rules in one
    /// window, stated at both sites. D57′.
    @FocusState private var focusedField: GameField?

    /// A refused field edit, held for its alert. Two causes reach it: a result
    /// the final position disproves (D57′, carrying the validator's own
    /// sentence rather than a second opinion about the same position) and a
    /// seat that would put one player on both sides (D61′).
    @State private var fieldRefusal: FieldRefusal?

    // MARK: Body
    internal var body: some View {
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
        // Re-resolves when the live game ends, which `.task(id: request)`
        // cannot: a `.live` request never changes, so without this the window
        // keeps rendering a retained `LiveGame` under "Recording" long after it
        // archived. This is what makes the unavailable state's "a live game
        // that ended" claim reachable rather than merely plausible.
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
        // D57′. Separate from the rename refusal rather than one alert widened
        // to carry both: two doors refusing two different things, and the one
        // thing a refusal must do is name what it refused.
        .alert(
            fieldRefusal?.title ?? "",
            isPresented: Binding(present: $fieldRefusal),
            presenting: fieldRefusal,
            actions: { _ in Button("OK", role: .cancel) {} },
            message: { refusal in Text(refusal.message) }
        )
    }
}

// MARK: - Game Fields

extension GetInfoWindow {

    /// The editable roster rows, as focus identities and as commit targets.
    ///
    /// Deliberately **not** `SevenTagRoster`: that is the *display* order of
    /// seven tags including Result, and Result is a `Picker` with no focus state
    /// and no draft. Reusing it would mint a case that can never be focused —
    /// the "guard that can never be true" shape. Every case here is real.
    fileprivate enum GameField: Hashable {
        case event, site, round, white, black, date
        case board, timeControl
    }

    /// A per-field edit this form refused, rendered as an alert.
    ///
    /// Carries the rendered sentence rather than the underlying rejection: the
    /// alert needs one string, and cause-to-prose belongs beside the switch
    /// that is exhaustive over it.
    ///
    /// The `title` is a value rather than a literal because D61′ added a second
    /// refusing field — one struct of two fields beats two structs of one plus
    /// two alerts on one view.
    fileprivate struct FieldRefusal: Identifiable {
        let title: String
        let message: String
        var id: String { title + message }
    }
}

// MARK: - Subject

extension GetInfoWindow {

    /// The resolved counterpart of `GetInfoRequest` — what the window found
    /// when it looked, as opposed to what it was asked for.
    ///
    /// Separate from the request because a request is `Codable` scene state
    /// that outlives the launch it was made in, and a `@Model` is never
    /// `Sendable` and never survives one. `Error.duplicate`'s split, same
    /// reason.
    fileprivate enum Subject {
        case game(PGN)
        case live(LiveGame)
        case player(Player)
    }

    /// A refused retag, rendered as an alert.
    ///
    /// Holds the store's `Sendable` collision payload — identifiers and names,
    /// never models — so the alert names the games without resolving anything.
    /// `Identifiable` off the first collision: a refusal always has one pair.
    fileprivate struct Refusal: Identifiable {
        let collisions: [PGNStore.HashCollision]
        var id: PersistentIdentifier { collisions[0].gameID }
    }

    /// The cast paired with an `isDeleted` check, per the standing invariant:
    /// `model(for:)` hands back a tombstone for a row deleted while this window
    /// was open, and every property read on one traps. Falling to the
    /// unavailable state is the truth — the subject is gone.
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
            // From the session rather than the request: a request holding it
            // would put a `@MainActor` class inside `Codable` scene state.
            guard let live = session.liveGame else {
                subject = nil
                return
            }
            subject = .live(live)

        case .player(let key):
            // Predicated rather than fetched-and-scanned: identity is a stored
            // column, so a `FetchDescriptor` answers this whole.
            // `normalizedName` is D9′'s key, so at most one row matches.
            var descriptor = FetchDescriptor<Player>(
                predicate: #Predicate { $0.normalizedName == key }
            )
            descriptor.fetchLimit = 1
            guard let player = try? modelContext.fetch(descriptor).first, !player.isDeleted else {
                subject = nil
                return
            }
            // Stored **tag** form — `tagName ?? name`, D29′'s fallback. Seeding
            // from `name` would put a display form in a field that stores a
            // tag, and the first commit would write "Bera Şenol" into every
            // affected game's `[White]`. D37′'s trap, one keystroke away; it is
            // why the seeding lives beside the fetch, not in the form.
            draftTag = player.tagName ?? player.name
            subject = .player(player)

        case .none:
            subject = nil
        }
    }

    /// Seeds the drafts from stored state, beside the fetch rather than in the
    /// form — the player tab's placement, for its reason.
    ///
    /// **Tag form in, verbatim**, `?` placeholders included: these fields edit
    /// what export writes byte for byte (D24′), so they must show the stored
    /// string rather than `RosterSummary`'s rendering of it, which folds
    /// "Senol, Bera" to "Bera Senol" and every unknown to an em dash (D55′).
    /// D37′'s trap in a second place.
    ///
    /// Round is a `String` draft, not an `Int?` binding: the empty field has to
    /// mean "no round" (D31′), and a numeric `TextField` with a nil formatter
    /// makes empty and zero the same gesture.
    private func seedGameDrafts(from pgn: PGN) {
        draftEvent = pgn.event
        draftSite = pgn.site
        draftRound = pgn.round.map(String.init) ?? ""
        draftWhite = pgn.white
        draftBlack = pgn.black
        draftDate = pgn.date
        // Empty string for nil, not the export's `?` / `-`: those are what the
        // *file* says, and a field pre-filled with `-` invites editing around a
        // placeholder. The commit maps empty back to nil — nil → "" → nil.
        draftBoard = pgn.board ?? ""
        draftTimeControl = pgn.timeControl ?? ""
    }

    private var title: String {
        switch subject {
        case .game(let pgn):     pgn.name
        case .live:              "Recording"
        case .player(let player): PlayerName.displayForm(of: player.tagName ?? player.name)
        case .none:              "Info"
        }
    }
}

// MARK: - Content

extension GetInfoWindow {

    @ViewBuilder
    private func content(for subject: Subject) -> some View {
        switch subject {
        case .game(let pgn):      gameForm(pgn)
        case .live(let live):     liveForm(live)
        case .player(let player): playerForm(player)
        }
    }

    /// An archived game: what you can change, and what the app knows about the
    /// row (D57′).
    ///
    /// Three tabs since D59′, and **the split is by *authorship*, not topic.**
    /// **Details** is what the reader wrote and can rewrite — exactly D24′'s
    /// nine exported tags (the roster, then Board, then TimeControl). **Move
    /// Text** is what the reader *played*, rewritable under D18′'s validator.
    /// **File** is what the app derived, stamped or measured, and nobody
    /// rewrites it — which is why no row there needs a read-only comment.
    ///
    /// Move Text sits in the middle because it is content; File is last because
    /// it is the only tab about the row rather than the game.
    ///
    /// **Named "Move Text", not "PGN"** — a PGN tab beside a Details tab holding
    /// the nine tags claims to be the whole file while showing half of it.
    /// D54′'s "Edit Moves rather than Edit PGN", one level up.
    ///
    /// Move Text is on the game form only: a live game has no stored movetext
    /// and Decision #1 forbids the concept, so the absence expresses the locked
    /// decision as a missing tab rather than a disabled one.
    ///
    /// `.tabItem`, not the 2027 `Tab(role:)` spelling — beta (D27′).
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

    /// D18′'s editor, hosted rather than reimplemented.
    ///
    /// **The commit model differs from Details' and that is not an
    /// inconsistency to iron out.** Details commits per field because each of
    /// the nine tags is independently valid; movetext is
    /// accept-whole-or-reject-whole (D18′), so it takes an explicit Save gated
    /// on the validator. Making them agree would mean either committing
    /// half-typed movetext or pressing Save to change an Event.
    ///
    /// The `.id(pgn.persistentModelID)` is load-bearing: the editor seeds its
    /// text in `init`, so without it a second game opened while this window
    /// lives would keep the first game's moves under the second game's title.
    /// D53′'s `.live` staleness, arriving through view identity instead.
    private func moveTextTab(_ pgn: PGN) -> some View {
        MovetextEditorView(pgn: pgn) { proposed in
            applyMovetext(proposed, to: pgn)
        }
        .id(pgn.persistentModelID)
        .accessibilityIdentifier(AccessibilityID.getInfoGameMoveText)
    }

    /// D24′'s nine exported tags, editable: the roster in one section, Board and
    /// Time Control in another (D57′).
    ///
    /// Each row is the native control for what the tag *is* rather than a text
    /// field throughout. Not decoration — it makes invalid states unreachable
    /// rather than validated: a `Picker` cannot produce a result outside the
    /// enum, a `DatePicker` cannot produce 2026-02-31. The only rule left to
    /// *check* is the one no widget can know, whether the position agrees with
    /// the result.
    ///
    /// Rows read off drafts and commit one at a time — see `commitField`. The
    /// non-text rows have no draft and no focus: a `Picker` and a `DatePicker`
    /// have no Return, so their commit point is the change itself.
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

            // The other two of D24′'s nine, in the order the exported tag block
            // writes them. They are *exported tags*, so whatever this window
            // lets you rewrite should be the set that lands on disk — seven of
            // nine is a split with no rule behind it.
            //
            // Their own section rather than nine in one, because the Seven Tag
            // Roster is a *named standard* (D22′ renders it from
            // `SevenTagRoster.allCases` precisely so it cannot quietly grow).
            // One section would make the roster look like it has nine members.
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
            // Commits whichever row the keyboard just left, which is why it
            // reads `previous`: `focusedField` goes nil leaving the form and to
            // the next case between rows, so the old value is the one to write.
            .onChange(of: focusedField) { previous, _ in
                if let previous { commitField(previous, on: pgn) }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoGameDetails)
    }

    /// The date row, with its own "no date" arm.
    ///
    /// A bare `DatePicker` cannot express nil, and nil is real and common here —
    /// D24′ writes `????.??.??` for it. Picker plus Clear when there is a date,
    /// a Set button when there is not, so "this game doesn't say" stays
    /// reachable in both directions.
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

    /// A seat row, plus the sentence that keeps it from being mistaken for the
    /// player tab's field.
    ///
    /// **The most dangerous rows in this window, and they look like the least.**
    /// Editing White here rewrites *this game's* tag — `applyEdit` re-resolves
    /// afterwards, so the game moves to a different player and may mint one.
    /// The same-looking field on the player tab rewrites *every* game that
    /// player appears in (D37′). Blast radius of one versus forty. The derived
    /// line beneath is the only thing on screen saying the value is a tag.
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

            // Only while it says something different from the field, so the
            // ordinary "Bera" case does not carry a line repeating itself.
            if PlayerName.displayForm(of: text.wrappedValue) != text.wrappedValue {
                Text("Shown as \(PlayerName.displayForm(of: text.wrappedValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.getInfoGameField(label.lowercased()))
    }

    /// The known-player menu trailing a seat field (5 Aug 2026, by request) —
    /// `LiveGameRosterForm.playerMenu`'s shape, deliberately reproduced rather
    /// than shared.
    ///
    /// **Not extracted into one shared type**: the other menu fills a `Roster`
    /// draft committed wholesale on a sheet's Save; this one fills a field that
    /// commits *itself* through `applyEdit`. Same six lines of SwiftUI, two
    /// contracts about when the value lands, and sharing them would need a
    /// commit closure to paper over it. The `OpeningSection` em-dash call —
    /// two surfaces that agree today, each owning its reason.
    ///
    /// **Picking commits.** On the sheet, choosing a name and closing without
    /// saving changes nothing; here there is no Save, so a choice that only
    /// filled the field would look committed without being it. The menu writes
    /// the draft *and* calls `commitField`, agreeing with `onSubmit` above.
    ///
    /// Hidden when the registry is empty, so a fresh install shows a plain
    /// field rather than a menu of nothing. Free text always works: the menu
    /// only fills, and picking creates no `Player` — `resolvePlayer` stays the
    /// single creation door and fires inside `applyEdit`'s re-resolve.
    @ViewBuilder
    private func seatMenu(
        for text: Binding<String>,
        field: GameField,
        on pgn: PGN
    ) -> some View {
        if !knownPlayers.isEmpty {
            Menu {
                ForEach(knownPlayers, id: \.persistentModelID) { player in
                    // D29′ — insert the remembered *tag* form, never the
                    // derived display form. The label shows the string it
                    // inserts, because a menu showing "Bera Senol" while
                    // writing "Senol, Bera" would be lying about its own effect.
                    let tag = player.tagName ?? player.name
                    Button(tag) {
                        text.wrappedValue = tag
                        commitField(field, on: pgn)
                    }
                }
            } label: {
//                Image(systemName: "chevron.up.chevron.down")
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

    /// Result, as a picker over the enum, checked against the final position on
    /// change (D57′).
    ///
    /// `*` is deliberately **not** offered. Decision #3 says it is never a
    /// finished result, `MovetextEdit.validate` refuses it outright, and the
    /// import door is the only thing that ever puts one in the Library. The
    /// recorded consequence: an imported `*` game can be *decided* here and
    /// cannot be set back, which is the right asymmetry — un-deciding a game is
    /// not a correction anyone needs, and offering the case would put a state
    /// on the menu that the validator one line down always rejects.
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

    /// Everything the app knows about the row that the reader did not write
    /// (D57′) — read-only throughout, by the authorship split `gameForm`
    /// states.
    ///
    /// Four sections, and the grouping is the one the reader would ask in: when
    /// did this arrive and what is it called; what does it dedupe as; what did
    /// the classifier make of it; how far did the engine get.
    ///
    /// (Five until the D57′ amendment moved Equipment to Details. Worth the
    /// parenthesis because the count is the kind of number this project has
    /// watched decay repeatedly, and it decayed here within a day of being
    /// written.)
    ///
    /// **Hash and identifier are `.textSelection(.enabled)` and monospaced**,
    /// which is the whole reason they are worth showing: an MD5 you cannot copy
    /// answers no question. Both are the strings you would paste into a `log
    /// stream` predicate or a `grep` over an export folder while working out why
    /// two games did or did not dedupe (D24′, and the one-hash invariant).
    ///
    /// Rows that can be absent print `RosterSummary.displayUnknown` rather than
    /// being hidden, so the section's shape is constant and a nil reads as an
    /// answer instead of as a missing row — the tag block's rule (D24′'s
    /// "always all nine tags"), applied to a panel.
    private func fileTab(_ pgn: PGN) -> some View {
        Form {
            Section("Library") {
                // D58′, and this row is what the old read-only form's comment
                // reserved a place for — "if `PGN` ever grows a stored library
                // index, this section is where it surfaces". It observed rather
                // than promised, correctly, and the observation turned out to
                // name the right section.
                //
                // Above Name, because it is the stronger half of what this game
                // is *called* on disk: the ordinal is the part that identifies,
                // and the players are the part that describes.
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
                // The seats as *resolved*, which is a different question from
                // the seats as *tagged* one tab over — and the only place in
                // the app the difference is visible. A game whose tag says
                // "Senol, Bera" and whose link says nothing is a row the
                // backfill has not reached, and that is worth being able to
                // see rather than infer from a player missing in Players.
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

            Section("Analysis") {
                // One spelling of "analyzed?", `AnalysisGlyph`'s — the same
                // predicate the glyphs, the toolbar aggregate and the search
                // chips read (`LibraryDestination` hands it to
                // `LibrarySearchToken.admit`). A bare `evaluations.isEmpty`
                // here would be a second opinion about the one question this
                // app asks most.
                //
                // Since D67′ that predicate is `PGN.hasScoredPly`, and since
                // D68′ so is `GameRecord.hasAnalysis` — so the smart-tag rule
                // joins this list and the sentence above is now true of every
                // surface without exception. It was true when written; the
                // one door that had drifted was the tag rule, which is not
                // named here and was never claimed.
                LabeledContent(
                    "Analyzed",
                    value: AnalysisGlyph.isAnalyzed(pgn) ? "Yes" : "No"
                )
                LabeledContent("Evaluated Plies", value: Self.evaluatedPlies(pgn))
                LabeledContent("Best For White", value: Self.extreme(pgn, white: true))
                LabeledContent("Best For Black", value: Self.extreme(pgn, white: false))
            }

            // An `Equipment` section stood here for one evening, holding `board`
            // and `timeControl`. Both moved to Details in the D57′ amendment:
            // they are two of D24′'s nine exported tags, and this tab's rule is
            // that nothing on it is a value a person holds an opinion about.
            // They were the two rows that failed that rule, which is why they
            // were also the two this tab's doc had to describe as "equipment
            // facts" rather than as derived truth.
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoGameFile)
    }

    /// The live game's roster. No index and no library facts: it has neither
    /// until it archives, and showing empty rows for them would describe the
    /// archived game this one is going to become rather than the one on the
    /// board.
    ///
    /// **No tabs, and no File tab in particular** (D57′). A live game has no
    /// row, no import stamp, no hash and no classification — a File tab here
    /// would be five sections of em dashes describing the archived game this
    /// one is going to become, which is the same argument this form's existing
    /// doc already makes about the Library section it does not have. It is also
    /// still read-only: the live roster's editor is `EditLiveGameDetailsSheet`,
    /// reached from the live inspector, and it writes through the session and
    /// the draft sidecar rather than through `PGNStore`. Different target,
    /// different door.
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

    /// The registry row, the games it is reached through, and the app's one
    /// rename door.
    ///
    /// The tag form is shown above the display form deliberately, in that
    /// order: D23′ says names travel tag → display and never back, and a
    /// dialog that puts the derived value first invites editing the wrong one.
    /// The editable row is the tag and the derived row updates live beneath it
    /// as you type, which is D37′'s move of turning the one-way rule into the
    /// form's own explanation — kept verbatim from the sheet this replaced,
    /// because it is the part that made the sheet worth having.
    ///
    /// **The cost statement is the Library section rather than a sentence.**
    /// D37′'s sheet said "Rewrites the name stored in 42 games" because
    /// nothing else on screen did; here the game count is two rows below the
    /// field, permanently, which says the same thing without a line of prose
    /// that can go stale against the number beside it.
    private func playerForm(_ player: Player) -> some View {
        Form {
            Section("Name") {
                // Commit on Return only — not on every keystroke, and not on
                // focus loss. Each commit is `retag`: a rewrite across every
                // linked game with an MD5 and a re-resolve each, inside one
                // transaction. Per-keystroke would run that per character, and
                // on focus loss it would fire when the window is merely
                // clicked away from, which is not a decision the reader made.
                TextField("Tag", text: $draftTag)
                    .onSubmit { commitRename(for: player) }
                    .accessibilityIdentifier(AccessibilityID.getInfoPlayerTagField)
                LabeledContent("Shown as", value: PlayerName.displayForm(of: draftTag))
            }

            Section("Library") {
                // Counted off the relationships rather than folded through
                // `PlayerStats`: the fold is the destination's currency and
                // costs a pass over every record to answer one row. This
                // window asks a smaller question than the profile does.
                LabeledContent("Games", value: "\(player.whiteGames.count + player.blackGames.count)")
                LabeledContent("As White", value: "\(player.whiteGames.count)")
                LabeledContent("As Black", value: "\(player.blackGames.count)")
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoPlayer)
    }

    /// One state for every way a subject can be absent — deleted between the
    /// gesture and the render, a live game that ended, a window restored from
    /// a previous launch. The causes differ and the remedy does not, and
    /// splitting them would explain a deletion the reader performed.
    ///
    /// `InspectorEmptyState`'s second non-inspector host, after D46′'s graph
    /// window. Noted rather than renamed: the contract it enforces is about
    /// *layout* — centred, filling, outside any `List` — which is as true of a
    /// window as of a sidebar.
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

// MARK: - Rename

extension GetInfoWindow {

    /// The movetext write door, moved here from `LibraryDestination` with the
    /// affordance (D59′).
    ///
    /// `applyMovetextEdit` re-validates internally, so the `.rejected` arm is
    /// reachable only if this window's Save gate and the store's validator
    /// disagree — which they cannot, both calling `MovetextEdit.validate`.
    /// Logged rather than surfaced for that reason: an internal-divergence
    /// breadcrumb, not a user-facing state. The settle machine's F5 guard is
    /// the precedent.
    ///
    /// **What this does not do, which its Board ancestor did:** rebuild a
    /// cached on-board `Game` — neither this window nor the Library holds one.
    /// D54′'s recorded cost carries over: a Board window already reviewing this
    /// game shows pre-edit moves until it reloads.
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

    /// Commits one roster field through `PGNStore.applyEdit` (D57′).
    ///
    /// **One field per transaction, and the two guards ahead of the door are
    /// the point.** An unchanged value returns before reaching the store, which
    /// would otherwise accept it silently — re-resolve, recompute the same MD5,
    /// write the same bytes — and "nothing happened" and "everything was
    /// rewritten identically" look identical from outside. An emptied Event or
    /// Site reverts rather than storing `""`: D24′ always prints all nine tags
    /// and an unknown is `?`, so `""` exports as neither a name nor an unknown.
    ///
    /// Seats and Round may legitimately empty. A seat clears to `?`, which
    /// `resolvePlayer` reads as no player (D9′), so clearing unlinks rather
    /// than minting a player named `?`. Round clears to nil — D31′'s exported
    /// `?`.
    ///
    /// `applyEdit` does the rest unchanged: the closure writes, both seats
    /// re-resolve unconditionally, `refreshHash` recomputes and saves, one
    /// transaction (D18′). Re-resolving on an Event edit is a documented no-op
    /// rather than waste — it is what keeps this door from rotting the links.
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
                // Non-numeric text reverts rather than clearing: D31′ makes nil
                // mean "no round", and reading "quarterfinal" as nil would
                // silently discard what was typed under the same spelling an
                // intentional clear uses.
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

            // Both clear to nil rather than reverting, unlike Event and Site
            // and for a reason visible in the model: these are `String?`, and
            // D24′ already writes an absent one as `?` / `-`. "No board" and
            // "no time control" are values a game can honestly have, where
            // "no event" is not — PGN's roster is mandatory and its unknown is
            // spelled `?`, which the tag block prints for an empty `event`
            // anyway. So the empty field means different things in the two
            // sections, and the model is what makes that non-arbitrary.
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

    /// An emptied seat becomes PGN's own unknown rather than `""` — see
    /// `commitField`. Written back into the draft after a commit so the field
    /// shows the `?` it stored, rather than staying blank and inviting a second
    /// identical commit.
    /// An emptied optional-backed field is nil, not `""` — see `commitField`'s
    /// `.board` arm. Separate from `seatValue` because they map the same
    /// gesture to different values (`?` versus nil) for different columns, and
    /// one shared helper would have to take a flag saying which.
    private func optionalValue(_ draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func seatValue(_ draft: String) -> String {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? RosterSummary.unknownTag : trimmed
    }

    /// The refusal, in the reader's terms — naming the player rather than the
    /// rule, because the reader can see the rule from the two fields.
    private static func sameSeatRefusal(_ tag: String) -> FieldRefusal {
        FieldRefusal(
            title: "Can’t Set Both Seats to One Player",
            message: "\(PlayerName.displayForm(of: tag)) is already the other seat. "
            + "A game needs two players; give one seat a different name, or "
            + "clear it to “\(RosterSummary.unknownTag)” if it isn’t known."
        )
    }

    /// Commits a result change, refusing what the final position disproves
    /// (D57′).
    ///
    /// **Reuses `MovetextEdit.validate` rather than restating its rules**, and
    /// that is the whole design: the stored moves are already canonical and
    /// legal, so replaying them can only fail on the result arms — the trailing
    /// `#` check, Decision #3, checkmate-forces-the-winner, stalemate-forces-a
    /// draw. Writing a second, smaller "is this result plausible" check here
    /// would be two spellings of one question, and the smaller one would be the
    /// one that drifts. The cost is a full replay per result change, which at
    /// personal scale is a few dozen plies against an alert nobody wants to be
    /// wrong.
    ///
    /// What it deliberately still allows: a resignation, a draw by agreement, a
    /// win on time — anything a non-terminal final position cannot disprove.
    /// That is D18′'s rule verbatim and it is most of the real corrections.
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

    /// The refusal, in the reader's terms.
    ///
    /// Exhaustive over `MovetextEdit.Rejection` on purpose, `present(_:)`'s
    /// reason: a future case arrives as a compile error rather than as a
    /// swallowed refusal. Three of the five arms are unreachable from *this*
    /// caller — the moves are stored canonical, so they cannot be illegal,
    /// spliced, or claim a mate the position lacks — and they are spelled
    /// anyway rather than folded into a default, because "unreachable from here"
    /// is a fact about this call site that a `default` would hide the day a
    /// second caller appears.
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

    /// Date *and* time, unlike every other date in the app.
    ///
    /// `RosterSummary.displayDate` is the app's one short-date rendering (D22′)
    /// and it is deliberately not used here: that formats a game's **playing**
    /// date, which is a day, while this is a filesystem-ish stamp where the
    /// time is the informative half — two imports of the same PGN minutes apart
    /// are exactly what this row exists to tell apart.
    private static func stamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// "48 of 58" — how much of the game the engine actually scored.
    ///
    /// The two numbers differ more often than the glyph suggests: a skipped or
    /// cancelled batch leaves a partial array, and `AnalysisGlyph.isAnalyzed`
    /// answers yes for *any* non-nil entry. This is the row that says how much.
    private static func evaluatedPlies(_ pgn: PGN) -> String {
        let scored = pgn.evaluations.count { $0 != nil }
        guard scored > 0 else { return RosterSummary.displayUnknown }
        return "\(scored) of \(pgn.moves.count)"
    }

    /// The best evaluation either side reached, in the bar's own grammar.
    ///
    /// Rendered through `EvaluationBarReading.label` rather than formatted here,
    /// so this panel and the bar cannot disagree about what "+1.3" or "M4"
    /// looks like — D33′ pinned that grammar and D46′'s window already reuses
    /// it rather than restating it.
    private static func extreme(_ pgn: PGN, white: Bool) -> String {
        let scored = pgn.evaluations.compactMap { $0 }
        guard !scored.isEmpty else { return RosterSummary.displayUnknown }
        let best = white
            ? scored.max(by: { $0.whiteWinProbability < $1.whiteWinProbability })
            : scored.min(by: { $0.whiteWinProbability < $1.whiteWinProbability })
        guard let best else { return RosterSummary.displayUnknown }
        return EvaluationBarReading(best).label
    }

    /// D37′. Every consequence — the rewrite across linked games, the
    /// re-resolve, the rehash, D39′'s refusal — belongs to the store door. This
    /// is transport plus two deliberately different failure sinks: a refusal is
    /// a *value* the reader must see, a save failure is a logged error. The
    /// split `applyMovetextEdit` draws.
    ///
    /// Two no-op guards ahead of the door, both load-bearing. An empty tag
    /// would reach the store as `.emptyTag`, turning a stray ⌫-then-Return into
    /// an alert; an unchanged tag would spend a full rehash across every linked
    /// game to write what is already stored. D39′'s fold-equivalence check
    /// would accept that second one silently, which is why it is stopped here.
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

    /// `.emptyTag` cannot reach here — `commitRename` guards it — so the alert
    /// is D39′'s collision case only. A future third rejection arrives as a
    /// compile error in this switch rather than as a silently swallowed
    /// refusal.
    ///
    /// The field reverts on refusal, which the sheet did not have to do
    /// because it closed. D39′'s refusal is all-or-nothing and names nothing
    /// as changed; leaving the rejected text in a field that describes stored
    /// state would be the one place in the app showing a name no game carries.
    private func present(_ rejection: PGNStore.RetagRejection, revertingTo player: Player) {
        switch rejection {
        case .wouldCollide(let collisions):
            refusal = Refusal(collisions: collisions)
        case .emptyTag:
            Self.logger?.error("Retag refused for an empty tag, the field's guard let one through")
        }
        draftTag = player.tagName ?? player.name
    }

    /// Names the games, because "this would create a duplicate" is
    /// unactionable otherwise. Caps the list: a rename over a double-imported
    /// set can collide many times, and an alert is not a report.
    fileprivate static func refusalMessage(_ collisions: [PGNStore.HashCollision]) -> String {
        let shown = collisions.prefix(3).map { "“\($0.gameName)” and “\($0.existingName)'" }
        let lead = "This would make these games identical: " + shown.joined(separator: "; ") + "."
        let more = collisions.count > shown.count
            ? " And \(collisions.count - shown.count) more."
            : ""
        return lead + more + " Delete or edit one of each pair first, nothing has been changed."
    }
}

// MARK: - Previews

/// The branch a reader hits by accident — a window restored onto a game that
/// is gone, or opened and then the subject deleted underneath it. Reachable in
/// a canvas because it is the one state that needs no resolved subject, which
/// is exactly why it is the one worth pinning here: the three content forms
/// each need a model *inserted in a container* before `resolve()` can find
/// them, and a preview that builds one is testing SwiftData rather than this
/// view's layout.
#Preview("Unavailable") {
    GetInfoWindow(request: nil)
        .frame(width: 460, height: 520)
        .modelContainer(for: [PGN.self, Player.self], inMemory: true)
        .environment(DGTLiveSession())
}

/// The game form, both tabs, on a fixture built to make the File tab say
/// something (D57′).
///
/// **This preview exists because the argument against it expired.** The head
/// doc said the game form was "deliberately not previewed: reaching them means
/// inserting a model and letting `resolve()` fetch it, which witnesses
/// SwiftData rather than this view's layout." That was right about a form of
/// seven `LabeledContent` rows. It is wrong about a form with two tabs, six
/// text fields, a `DatePicker` with its own no-date arm, a `Picker`, and a
/// second tab of five sections — that is layout, it is heterogeneous, and the
/// canvas is the only place it can be looked at. The container round trip is
/// the price rather than the subject.
///
/// The fixture is deliberately *rich*: evaluations that stop short of the last
/// ply (so "Evaluated Plies" reads `12 of 20` rather than agreeing with the
/// total and hiding the distinction that row exists for), a classification, a
/// board, and a time control. A fixture where every optional is nil would
/// render five sections of em dashes and witness nothing.
///
/// Classification is assigned directly here, which `PGNStore.classify` is
/// otherwise the single door for (D34′). A preview fixture is not a second
/// door — it never runs in the app — but it is worth naming, because the
/// reason those fields are absent from `PGN.init` is exactly to make this
/// assignment visible when it happens.
#Preview("Game, Details & File") {
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
    // Twelve of twenty, on purpose — see the doc above.
    pgn.evaluations = (0..<20).map { ply in
        ply < 12 ? Evaluation.centipawns((ply % 5) * 40 - 60) : nil
    }

    return GetInfoWindow(request: .game(pgn.persistentModelID))
        .frame(width: 460, height: 560)
        .modelContainer(container)
        .environment(DGTLiveSession())
}

/// The live form — the one content branch a canvas can reach without a
/// container: its subject comes from the session, so seeding it is one object.
///
/// It is also the branch with no automated witness anywhere else — the game
/// and player forms are `RosterSummary` and `Player` rows that other suites
/// cover, while this one is the only place `LiveGame.Roster`'s projection is
/// rendered outside the live inspector. **And it is the tabless one**, which
/// this canvas is now the standing witness for: a live game has no file, and
/// a Recording window that grew a File tab would be showing five rows of em
/// dashes about a row that does not exist yet.
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
