//
//  GetInfoWindow.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 04/08/2026.
//

import os
import SwiftData
import SwiftUI

// MARK: - Request

/// What a Get Info gesture asks for: one subject, named by what it is.
///
/// **An enum rather than three request types, and a wrapper rather than a bare
/// `PersistentIdentifier` — both for the same reason, which is worth stating
/// once here because it is the trap this whole file is arranged around.**
/// `openWindow(value:)` routes by the value's *type*. The app's main
/// `WindowGroup` is already declared `for: PersistentIdentifier.self` with five
/// call sites relying on it, and `EvaluationGraphRequest` (D46′) exists purely
/// because a second group over that type would have made all five ambiguous —
/// "open a game from the Library" silently becoming "open a graph".
///
/// Three subjects could have been three request structs and three scenes. One
/// enum and one scene is better twice over: it pays D46′'s cost once instead of
/// three times, and it makes the three Get Info windows *one group*, so macOS
/// tabs them with each other and not with the game windows. Two info windows
/// side by side is a comparison; an info window tabbed behind a board is a
/// window you lost.
///
/// `.live` carries nothing because a live game is not in the store — it has no
/// `PersistentIdentifier` to carry until it archives. That asymmetry is real
/// rather than an oversight, and it is why this is an enum and not a struct
/// with an optional identifier: an optional would make "no game" and "the live
/// game" the same value.
internal enum GetInfoRequest: Codable, Hashable, Sendable {

    /// An archived game, from the Library or the Board's review branch.
    case game(PersistentIdentifier)

    /// The game currently being recorded. Reached from the Board only, and
    /// only while one is in progress.
    case live

    /// A player, named by `Player.normalizedName`.
    ///
    /// **A key and not a `PersistentIdentifier`, unlike the game case, and the
    /// asymmetry is the destination's rather than this type's.** Players'
    /// view modes render `PlayerStats` — a fold over `GameRecord`s whose
    /// `ID` *is* the normalized key — so no row on that screen holds a
    /// `Player` model to take an identifier from. Requiring one would make
    /// every call site fetch a model in order to name something it can
    /// already name.
    ///
    /// D40′'s consequence rides along for free: a linkless registry row
    /// appears in no view mode, so no key reaching here can name an orphan.
    case player(key: String)
}

// MARK: - Menu Item

/// The Get Info menu item, everywhere it appears.
///
/// **One type rather than a line per context menu, and this is D26′'s
/// argument applied to a verb instead of a glyph.** There are six context
/// menus across the Library's and Players' view modes, and a hand-written item
/// in each is six chances to disagree about the label, the symbol, the
/// keyboard shortcut, or — worst and least visible — which subject the request
/// names. `InspectorEditButtonView` hardcodes the pencil so five edit
/// affordances cannot drift; this hardcodes the verb so six doors cannot.
///
/// It owns `openWindow` itself rather than taking a closure, which is the
/// arrangement `PlayersInspectorView` and `PlayersColumnsView` already use for
/// the game-window route. Six new closure parameters threaded from two
/// destinations would be the same wiring with more places to get it wrong.
///
/// ⌘I is attached here so the shortcut travels with the item. The Board's copy
/// lives in `GameNavigationCommands`, which is why this type has two doors
/// rather than one: a `Commands` scene has no `openWindow`, so the menu-bar
/// item can only *ask* a view to open it (`SmartTagCommands`' trigger-binding
/// shape). Both spellings render the same label, symbol and shortcut, which is
/// the whole point — the alternative was a hand-written seventh item in the
/// Game menu, drifting from the six this type exists to keep identical.
internal struct GetInfoMenuItem: View {

    // MARK: Door

    /// How this item reaches the window. Not a public distinction: callers
    /// pick an initializer and never name this.
    private enum Door {
        /// A view that can open the window itself.
        case opens(GetInfoRequest)
        /// A command menu that must ask one to. Nil means no front-tab
        /// subject, which is the item's own disabled condition.
        case requests(Binding<Bool>?)
    }

    // MARK: Stored Properties
    private let door: Door
    private let identifier: String

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Initializers

    /// The context-menu form: this item owns the window route, the same
    /// arrangement `PlayersInspectorView` and `PlayersColumnsView` use for the
    /// game-window one. Six closure parameters threaded from two destinations
    /// would be the same wiring with more places to get it wrong.
    internal init(request: GetInfoRequest, identifier: String) {
        self.door = .opens(request)
        self.identifier = identifier
    }

    /// The menu-bar form: the item sets a flag the Board observes.
    internal init(requesting trigger: Binding<Bool>?, identifier: String) {
        self.door = .requests(trigger)
        self.identifier = identifier
    }

    // MARK: Body
    internal var body: some View {
        Button {
            switch door {
            case .opens(let request):   openWindow(value: request)
            case .requests(let trigger): trigger?.wrappedValue = true
            }
        } label: {
            Label("Get Info", systemImage: "info.circle")
        }
        .keyboardShortcut("i", modifiers: .command)
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
    }

    /// Only the menu-bar form can be disabled: a context menu is raised *from*
    /// the row it describes, so its subject exists by construction.
    private var isDisabled: Bool {
        if case .requests(let trigger) = door { return trigger == nil }
        return false
    }
}

// MARK: - Window

/// M10 — one gesture on the thing itself, and the app's rename door.
///
/// **Scope, stated first because the earlier version of this comment did not
/// and was wrong for it.** This window called itself "the one editable surface
/// behind every inspector's subject" while every row in all three forms was a
/// `LabeledContent`. It edits exactly one thing today: a player's tag name.
/// The game and live forms are read-only, and that is a current fact rather
/// than a permanent one — but a doc that describes the destination instead of
/// the code is the comment-asserting-a-guarantee shape this project keeps
/// catching itself in, so it describes the code.
///
/// **Why this replaces five pencils rather than joining them.** D26′ bought a
/// guarantee by hardcoding the pencil: five edit affordances could not drift
/// apart because they were one type. What it could not do is make them one
/// *surface* — Edit Info, Edit Details and Rename Player opened three
/// different editors reached three different ways, all of them a header
/// control on a panel the reader had to already be looking at. Get Info is one
/// gesture on the thing itself, which is what lets rename stop being a special
/// case: it is not a pencil rehomed, it is the Players instance of the same
/// verb the Library and Board already have.
///
/// **The rename machinery moved here whole rather than being reached from
/// here.** `RenamePlayerSheet`, `RenameRequest` and `PlayersDestination`'s
/// `beginRename` are gone: a sheet opened *from* this window would be a modal
/// over a companion window, and leaving the door in the destination while the
/// field lives here would be two surfaces for one write. What survived intact
/// is D37′'s argument, because the player form already had its exact shape —
/// tag above, derived display form below, game count in the next section —
/// and only needed the top row to become a field.
///
/// **A window, not a popover or a sheet**, and this is D46′'s finding taken as
/// settled rather than re-argued. That decision built a popover on 4 Aug, lived
/// with it for a day, and reverted to the window the same night: a companion
/// surface that dismisses when you click the thing it describes is not a
/// companion. Get Info is that shape exactly — you edit an event name while
/// reading the board, or compare two games' rosters side by side, and both
/// need the window to survive a click elsewhere.
///
/// Resolution is `@State` written by `.task(id:)` rather than a computed
/// property: a store lookup does not belong on a render path, and this body
/// should re-run when the request or the resolved subject changes, not when a
/// text field does. `EvaluationGraphWindow`'s arrangement, for its reason.
internal struct GetInfoWindow: View {

    // MARK: Static Constants

    /// The three HIG-derived numbers `DGTConnectionView.Metrics` names, cited
    /// by name and reason rather than imported — the third dialog to do so,
    /// after the rename and merge sheets that M10 and D52′ retired. Two
    /// dialogs' two decisions that agree today; a shared constant would claim
    /// they must agree forever.
    private static let contentPadding: CGFloat = 20

    /// `players`, not a category of this window's own: the retag lines this
    /// door emits are the same lines the sweep and the old sheet emitted, and
    /// splitting them would make `log stream --predicate 'category ==
    /// "players"'` — which the manual checks name — stop showing renames.
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "players"
    )

    // MARK: Stored Properties

    /// Optional because `WindowGroup(for:)` binds an optional value — a
    /// restored window whose subject is gone arrives here as nil, and the
    /// unavailable state is the honest answer rather than a bug to guard.
    internal let request: GetInfoRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(DGTLiveSession.self) private var session

    @State private var subject: Subject?

    /// The tag being edited, seeded by `resolve()` and committed on Return.
    ///
    /// A draft rather than a binding straight onto `Player.tagName`, for the
    /// reason D37′ gives the sheet it replaces: a rename is not a label change
    /// but a rewrite across every linked game, each with an MD5 and a
    /// re-resolve. Writing on every keystroke would run that per character.
    @State private var draftTag = ""

    /// D39′'s refusal, held for the alert. Nil is the normal state; a value
    /// means the last retag was refused whole and nothing was written.
    @State private var refusal: Refusal?

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
        // would keep rendering a retained `LiveGame` under "Recording" long
        // after it archived. The unavailable state's doc claims to cover "a
        // live game that ended" — this is what makes that claim true rather
        // than merely plausible, and it was written for a branch nothing could
        // reach until the Board grew its own Get Info door.
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
    }
}

// MARK: - Subject

extension GetInfoWindow {

    /// The resolved counterpart of `GetInfoRequest` — what the window found
    /// when it looked, as opposed to what it was asked for.
    ///
    /// Separate from the request rather than the request carrying its own
    /// model, because a request is `Codable` scene state that outlives the
    /// launch it was made in, and a `@Model` is never `Sendable` and never
    /// survives one. The same split `Error.duplicate` makes for the same
    /// reason.
    fileprivate enum Subject {
        case game(PGN)
        case live(LiveGame)
        case player(Player)
    }

    /// A refused retag, rendered as an alert.
    ///
    /// Holds the store's `Sendable` collision payload — identifiers and names,
    /// never models — so the alert can name the games without resolving
    /// anything. `Identifiable` off the first collision's game identifier: a
    /// refusal is always about at least one pair. Moved here with the rename
    /// door it belongs to; `PlayersDestination` kept nothing of it.
    fileprivate struct Refusal: Identifiable {
        let collisions: [PGNStore.HashCollision]
        var id: PersistentIdentifier { collisions[0].gameID }
    }

    /// The cast paired with an `isDeleted` check, per the standing invariant:
    /// `model(for:)` hands back a tombstone for a row deleted while this
    /// window was open, and every property read on one traps. The window then
    /// shows its unavailable state, which is the truth — the thing it was
    /// opened to describe is gone.
    private func resolve() {
        switch request {
        case .game(let id):
            guard let pgn = modelContext.model(for: id) as? PGN, !pgn.isDeleted else {
                subject = nil
                return
            }
            subject = .game(pgn)

        case .live:
            // Resolved from the session rather than carried in the request:
            // the live game is a singleton the session owns, and a request
            // holding it would be a second reference to a `@MainActor` class
            // inside `Codable` scene state.
            guard let live = session.liveGame else {
                subject = nil
                return
            }
            subject = .live(live)

        case .player(let key):
            // Predicated rather than fetched-and-scanned: identity is a
            // stored column, so this is one of the questions a
            // `FetchDescriptor` can answer whole. `normalizedName` is the
            // D9′ identity key, so at most one row can match.
            var descriptor = FetchDescriptor<Player>(
                predicate: #Predicate { $0.normalizedName == key }
            )
            descriptor.fetchLimit = 1
            guard let player = try? modelContext.fetch(descriptor).first, !player.isDeleted else {
                subject = nil
                return
            }
            // Seeded with the stored **tag** form — `tagName ?? name`, the
            // seat picker's fallback (D29′) for a pre-schema row. Seeding with
            // `name` instead would put a display form in a field that stores a
            // tag, and the first commit would write "Bera Şenol" into every
            // affected game's `[White]`. D37′'s trap, one keystroke away, and
            // it is the reason this seeding lives beside the fetch rather than
            // in the form where the field is drawn.
            draftTag = player.tagName ?? player.name
            subject = .player(player)

        case .none:
            subject = nil
        }
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

    /// The seven tags in standard order, then what the Library knows that the
    /// tags do not.
    ///
    /// Rendered through `RosterSummary` rather than off `PGN`'s fields
    /// directly, so this surface inherits D22′'s display rules — tag form in,
    /// display form out, `?` for "this game doesn't say" — instead of becoming
    /// the one place that spells an unknown seat differently.
    private func gameForm(_ pgn: PGN) -> some View {
        let roster = RosterSummary(pgn)
        return Form {
            Section("Seven Tag Roster") {
                ForEach(SevenTagRoster.allCases, id: \.self) { tag in
                    LabeledContent(tag.rawValue, value: roster[tag])
                }
            }

            Section("Library") {
                // Em dash rather than "?" — the roster's `?` means "this game
                // doesn't say", which is a PGN tag's own unknown vocabulary,
                // and these rows are not PGN tags. `OpeningSection`'s
                // distinction, applied to its own field and one more.
                LabeledContent("Opening", value: pgn.opening?.fullName ?? RosterSummary.displayUnknown)
                LabeledContent("Plies", value: "\(pgn.moves.count)")
                // There is no Index row, and that is a decision rather than a
                // gap: a row reading "—" for every game in the Library would
                // be a field the reader learns to ignore before it ever
                // carries a value. If `PGN` ever grows a stored library index,
                // this section is where it surfaces.
                //
                // (This comment scheduled that work — "lands with
                // `PGN.libraryIndex`" — until the 4 Aug review pointed out
                // that a comment is not a roadmap and the roadmap had never
                // heard of it. The observation survives; the promise does
                // not.)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(AccessibilityID.getInfoGame)
    }

    /// The live game's roster. No index and no library facts: it has neither
    /// until it archives, and showing empty rows for them would describe the
    /// archived game this one is going to become rather than the one on the
    /// board.
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

    /// D37′. Every consequence — the rewrite across linked games, the
    /// re-resolve, the rehash, D39′'s refusal — belongs to the store door;
    /// this is transport plus the two failure sinks, which are deliberately
    /// different: a refusal is a *value* the reader must see, a save failure
    /// is a logged error. The same split `applyMovetextEdit` draws.
    ///
    /// Two no-op guards ahead of the door, both cheap and both load-bearing.
    /// An empty tag is refused by the store as `.emptyTag`, and letting it
    /// reach there would turn a stray ⌫-then-Return into an alert; an
    /// unchanged tag would spend a full rehash across every linked game to
    /// write what is already stored. The store's own fold-equivalence check
    /// (D39′) would accept that second one silently, which is exactly why it
    /// is worth stopping here — "nothing happened" and "everything was
    /// rewritten to the same bytes" look identical from the outside.
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
            Self.logger.error("Rename failed: \(error.localizedDescription, privacy: .public)")
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
            Self.logger.error("Retag refused for an empty tag — the field's guard let one through")
        }
        draftTag = player.tagName ?? player.name
    }

    /// Names the games, because "this would create a duplicate" is
    /// unactionable otherwise. Caps the list: a rename over a double-imported
    /// set can collide many times, and an alert is not a report.
    fileprivate static func refusalMessage(_ collisions: [PGNStore.HashCollision]) -> String {
        let shown = collisions.prefix(3).map { "“\($0.gameName)” and “\($0.existingName)”" }
        let lead = "This would make these games identical: " + shown.joined(separator: "; ") + "."
        let more = collisions.count > shown.count
            ? " And \(collisions.count - shown.count) more."
            : ""
        return lead + more + " Delete or edit one of each pair first — nothing has been changed."
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

/// The live form, which is the one content branch a canvas *can* reach: its
/// subject comes from the session rather than the store, so seeding it is one
/// object rather than a container round trip.
///
/// It is also the branch with no automated witness anywhere else — the game
/// and player forms are `RosterSummary` and `Player` rows that other suites
/// cover, while this one is the only place `LiveGame.Roster`'s projection is
/// rendered outside the live inspector.
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
