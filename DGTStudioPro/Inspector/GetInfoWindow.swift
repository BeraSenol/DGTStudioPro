//
//  GetInfoWindow.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 04/08/2026.
//

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
/// lives in `GameNavigationCommands` instead — it has one subject and no list
/// to right-click, so the menu bar is its only door.
internal struct GetInfoMenuItem: View {

    // MARK: Stored Properties
    internal let request: GetInfoRequest
    internal let identifier: String

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Body
    internal var body: some View {
        Button {
            openWindow(value: request)
        } label: {
            Label("Get Info", systemImage: "info.circle")
        }
        .keyboardShortcut("i", modifiers: .command)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Window

/// M10 — the one editable surface behind every inspector's subject.
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
    /// after `RenamePlayerSheet` and the merge sheet that D52′ retired. Two
    /// dialogs' two decisions that agree today; a shared constant would claim
    /// they must agree forever.
    private static let contentPadding: CGFloat = 20

    // MARK: Stored Properties

    /// Optional because `WindowGroup(for:)` binds an optional value — a
    /// restored window whose subject is gone arrives here as nil, and the
    /// unavailable state is the honest answer rather than a bug to guard.
    internal let request: GetInfoRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(DGTLiveSession.self) private var session

    @State private var subject: Subject?

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
                // The Index row lands with `PGN.libraryIndex` (M10 batch 1).
                // Deliberately absent rather than stubbed: a row reading "—"
                // for every game in the Library would be a field the reader
                // learns to ignore before it ever carries a value.
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

    /// The registry row, and the games it is reached through.
    ///
    /// The tag form is shown above the display form deliberately, in that
    /// order: D23′ says names travel tag → display and never back, and a
    /// dialog that puts the derived value first invites editing the wrong one.
    /// D37′'s rename sheet makes the same arrangement its own explanation.
    private func playerForm(_ player: Player) -> some View {
        Form {
            Section("Name") {
                LabeledContent("Tag", value: player.tagName ?? player.name)
                LabeledContent("Shown as", value: PlayerName.displayForm(of: player.tagName ?? player.name))
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
