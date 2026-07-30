# DGT Studio Pro — Project Instructions

Revision 30 July 2026, fifth of the day (M5). Base named explicitly, per the working agreement about rebuilding from a stale synced copy: this is the **M4 revision (fourth of 30 July)** plus two carried deltas — the **post-M4 conformance audit** and **M5 — player rename and merge**. Everything the M4 revision recorded stands except where corrected below.

Three decisions minted at recording time: **D37′**, **D38′**, **D39′** — each chosen by Bera from concrete options before any diff. M5 landed in two reviewed batches with ⌘U green after each; the audit landed as one commit before them. Three files added — `PGNStoreRetagTests.swift`, `RenamePlayerSheet.swift`, `MergePlayerSheet.swift` — so the source count moves 208 → 211 (131 app, 79 unit-test, 1 UITest).

**The tree is now committed.** M3 and M4 no longer sit uncommitted on `f98cd6a`; the standing hazard the last three revisions carried is discharged. Current head is `0a21fc9`, with `415ef51` (M3), `06d15c9` (M4), `2187a37` (audit), `79e537f` (a mechanical resource move into `Chess/ECOs/` and `PGN/PGNs/`), `6a41bc9` and `0a21fc9` (M5) on top of `f98cd6a`.

Four claims were corrected at the symbol in this pass, all in the "code is truth" register. Three came from the audit — the evaluation bar's width, the shared pencil's inset, and the Library's ECO column reading past `PGN.opening`. The fourth is the roadmap's own: **delete-player as "nullify + delete" does not work**, because the link backfill recreates the row; delete is orphan-only now.

Next free number: **D40′**.

## What the app is

A macOS SwiftUI daily-driver for a DGT USB chessboard: play over the board while the app records SAN live, finished games archive automatically into a SwiftData-backed PGN Library, and everything is reviewable and analyzable there (bundled Stockfish). One unified WindowGroup parameterised by PersistentIdentifier gives native window-tabs.

Four destinations: Board, Library, Players, Rankings. The three collection destinations share the same four CollectionViewModes (icons / list / columns / gallery, one @AppStorage key each). The sidebar carries user-editable, rule-based smart tags (Apple Music smart-playlist shape) that filter the Library, and pins the session panel — the single surface for connection and session status. The stage above the board stays clear.

This app is for one person, one Mac, one board. No release, no App Store, no other users. That is a standing input to every trade-off below: the App Store submission floor is irrelevant, personal-scale libraries are the performance envelope, and "would confuse a user" arguments carry no weight — "would annoy Bera in six months" is the test.

## Where things stand

Tree at delivery: **clean at `0a21fc9`**. 211 sources (131 app, 79 unit-test, 1 UITest). No TODO / FIXME / HACK markers, no note-to-self arrows, no commented-out code anywhere in production sources; no DispatchQueue, no Combine, no NotificationCenter, no Thread.sleep, no `@unchecked Sendable`, no `nonisolated(unsafe)` anywhere in the app target.

Built and in use — the daily loop end to end (Library import/dedupe/four modes/analysis → mirror → reconstruction → live surface → crash-safe drafts → archive-first with confirmation sheet → recovery guidance), connection QoL (auto-connect policy, silent launch connect, mid-game reconnect with once-per-failure logging), the Diagnostics and Game menus, batch analysis (pure queue + per-tab controller + toolbar popover), Players / Rankings / SmartTags on pure folds, movetext editing by full replay (splice-refusing), PGN export pinned to the DGT reference shape, the D26′ inspector chrome with an Edit Info surface for both live and loaded games, idle-sleep inhibition behind the Energy preference, board coordinates, the illegal-move sound, live archives carrying the `Board` tag (D28′), the New Game seat picker inserting tag form (D29′), the vertical evaluation bar on the review board's leading edge (D33′), every archived game knowing its opening and mate motif engine-free and filterable as smart-tag rules (D34′–D36′). **New with M5:** players can be renamed and merged, and orphaned player rows deleted, through one store door that keeps identity following the tags.

Test target: expected green — never claimed; ⌘U runs locally and Bera reports. M1 closed the vacuity class structurally; every milestone since has added its own pins (M5's inventory is in the waiver register's "closed as covered" list).

## Decisions

Locked product decisions #1–#8 and their interpretation flags were recorded in the retired roadmap document §2 and remain in force. The two that are load-bearing daily are restated inline where used, so this document stands alone: #1 — the physical board is truth and the live game is append-only (no takebacks; Discard lives in the inspector); #3 — * is never a finished result and never archives.

Old milestone and finding tags (M7.2, M-prs.1, F1–F9…) survive in code comments and below as provenance only — they identify where a decision came from; they schedule nothing.

D-numbers are sequential and never reused. Next free number: **D40′**.

### D9′ — Player is a machine-managed @Model

Player { name, normalizedName, tagName, createdAt } with optional PGN.whitePlayer / blackPlayer relationships (inverses whiteGames / blackGames, .nullify). One creation door: PGNStore.resolvePlayer(named:).

Identity is the display form lowercased with whitespace collapsed — the content hash's folding philosophy. Diacritics deliberately preserved ("Bücher" ≠ "Bucher"); first-seen casing wins; "?" and empty resolve to no player, never to a player named "?". Since M2 the row also remembers its first-seen **tag form** (D29′).

**The "no user CRUD" clause is discharged.** This decision recorded rename/merge/delete as "the future feature which justifies having a model at all instead of derived grouping". M5 built it — D37′, D38′ — and the justification held up in a way worth recording: the feature turned out to need a *stored* row not for the name it carries but for the **relationship**, because scoping a rename by `whiteGames`/`blackGames` is what keeps it from being a string sweep over the whole Library.

What survives unchanged: `resolvePlayer` is still the single creation door, and the retag door creates its target *through* it rather than constructing a row (pinned by `retagCreatesTargetThroughTheResolver`). Orphaned players still linger by decision — no GC — and M5's delete is the manual door for them, not a collector.

Rejected: #Unique (can't express case-insensitive identity) and derived-only players (the model was wanted first).

### D10′ — pure cores over projection

PlayerStats, Glicko1, TagRule, and PairingRound consume GameRecord (a Sendable value) and never import SwiftData. Models touch the cores only at the PGN.gameRecord seam (PGN+GameRecord.swift, the LiveGame+Draft split pattern). Core suites run nonisolated with no fixtures.

GameRecord.chronologicalOrder — ascending date ?? importedAt, then importedAt, then contentHash — is the recorded ordering contract for every fold. A fold's output is only as deterministic as its order, so the chain down to a total tiebreak is the contract, not a nicety.

The effective-date rule (date ?? importedAt) belongs to GameRecord for the pure folds and to PGN.effectiveDate for view-layer sorts over models. Those are the only two implementations.

M4's shape exception restated: `ECOClassifier` and `GameClassification` take **moves and an injected table**, not a `GameRecord` — the second deliberate exception after `SpecialCheckmate`. A record is a projection of what the Library *knows about* a game, and classification is what produces that knowledge; putting movetext on `GameRecord` would have made every `PlayerStats` and `Glicko1` fold carry full movetext for nothing. `GameRecord` gained the **stored** result instead.

**M5 adds no core and deliberately so.** Retag is store surgery over relationships and stored hashes — there is no value-typed question hiding inside it, and the one piece that looked pure (the collision pre-flight) needs the Library to answer. It is suited through an in-memory container instead, the `PGNStoreArchiveTests` shape.

### D11′ — Rankings order is total wins; Glicko-1 is the secondary stat

Comparator: wins ↓, win rate ↓, key ↑ (PlayerStats.rankingOrder; the key tiebreak is locale-free by design).

Glicko-1 parameters: initial 1500 / RD 350, floor 30, cap 350, c = 0 (no wall-clock input — the rating is a pure deterministic fold), rating period = one game, draws 0.5, provisional while RD > 110. Rated = decided and both seats resolved; participants update simultaneously from pre-game states.

Reference values are pinned at full double precision — the paper's famous 1464.06 / 151.4 is rounded-intermediate arithmetic; the exact formulas (and the code) give 1464.1065 / 151.3989.

Rejected: staged-K Elo (a hand-rolled RD), Glicko-2 (iterative volatility, overkill), stored Elo tags (live games have none).

### D12′ — SmartTags are stored, rule-based, user-editable

SmartTag @Model { name, colorName, matchAll, rules: [TagRule], createdAt }; rules are Codable values on the model (the PGN.evaluations precedent); matching delegates whole to pure TagRule.evaluate.

Matching rules, recorded (string semantics revised by D30′; classification fields added by D36′): zero rules match nothing; an empty-text string rule matches nothing (a fresh row is inert, never select-all); string comparisons fold **both sides** through PlayerName.folded + lowercased(); unknowns never match, **negation included** (nil round fails numeric rules; undated games fail date rules; an unknown string subject fails .notEquals; an absent mate motif fails both directions); player means either seat.

A negated comparison over two seats flips the quantifier (27 July fix, verified landed). `player is not X` means neither seat is X — .notEquals takes allSatisfy, and a record with no resolved seat matches nothing, negation included.

The result picker still offers three cases. The recorded rationale was corrected on 29 July: Decision #3 is enforced at the archive door only — importPGN admits [Result "*"] deliberately. The reason that survives is that the app's own games never carry *, and offering it invites rules about a state the app treats as "not yet a result".

The editor is the Apple Music shape (name, colour palette, Match any/all, rows with −/+, Cancel/OK) working on a TagDraft value — Cancel never mutates a model. Deliberately dropped from the reference: Limit-to, checked-only, Live-updating (computed at render — live by construction).

The three former enum cases live on as seeded, fully editable defaults behind didSeedDefaultSmartTags (the flag, not tag count, guards the seed, so deletion sticks). One factory (SmartTag.defaultTags()) feeds both the production seed and the UI-test seed. M4 appended a fourth, "Smothered Mates" — appended, so the three existing positions are undisturbed; and because the seed fires once ever per install, an already-seeded install does not grow it. Its real audiences are a fresh install and the UI-test seed.

Tag CRUD is also the one Library write outside PGNStore, so its saves owe a trace: ContentView.saveTags(after:) logs failures instead of the bare try? the 30 July audit found there.

### D13′ — an illegal move plays an alert sound, fired from enterRecovery

enterRecovery(_:board:) is the single door into .recovering and the one recordDesync site, so the sound fires there — not from a view observing needsRecovery, which also flips on the manual-result recovery exit and re-fires on recompute. Both entries (.unresolved settles and the F5 commit-refused guard) route through the same door.

Settable hook session.onDesync: (() -> Void)?, wired once in App.init() beside onGameFinished / onBoardChanged. Nil in unit tests = silent = headless by construction. The App-side closure honours UITestSeed.isActive and is gated by StorageKeys.illegalMoveSoundEnabled (absent reads true; the ?? true twin-read-site pattern — see D25′ for the shape that escapes it). Sound is NSSound.beep() — respects the user's alert sound and volume; AppKit because SwiftUI has no sound-playback API.

Rejected: onChange(of: needsRecovery) in the mirror — couples the board surface to audio, fires on the manual-result exit too, and re-fires on recompute unless separately guarded.

### D14′ — a live game or an active recording inhibits idle system sleep

Predicate (dgtSession.liveGame != nil) || dgtConnection.isRecording — the union deliberately covers both readings of "recording" (live SAN capture and board-stream recording). D25′ gates the whole predicate behind a user preference; the live form is isEnabled && (…).

Held via one ProcessInfo.processInfo.beginActivity(options:, reason:) token, begun/ended on the predicate's edges by the App-owned @MainActor SleepInhibitor (a self-rescheduling withObservationTracking loop; begin/end idempotent on the edges). The token is an RAII ActivityToken whose deinit ends the activity, so begin/end pairing is a fact about object lifetime rather than two call sites that must agree.

Options are .userInitiated — the named composite carrying idle-system-sleep, automatic-termination and sudden-termination disabling — and deliberately not .idleDisplaySleepDisabled, so the "let the panel dim" non-goal is preserved by construction: breaking it would require naming a second option, not editing a comment.

Display sleep is deliberately NOT inhibited — long think-times with the user away from the Mac; the physical board is truth and the mirror a glance. "Logging off" is scoped honestly — a user-initiated logout or shutdown still proceeds; the draft sidecar plus archive-first already make a mid-game logout safe. What we prevent is idle sleep dropping the serial link mid-think, plus sudden termination while busy.

Rejected: raw IOKit IOPMAssertionCreateWithName; a permanent assertion; the hand-assembled option pair an earlier revision recorded (it omitted SuddenTerminationDisabled — the code's .userInitiated is the correction).

Execution consequences: DGTConnection.recorder is not @ObservationIgnored — isRecording must register for the tracking loop. The loop's closure captures the three @MainActor objects strongly, with a doc comment saying so — the @Sendable weak-capture lesson applied. observe(session:connection:) is guarded against a second external call: each call would arm an independent loop forever; the re-arm recurses through a private track past the guard, so the split is what keeps the guard from strangling the loop itself.

Forward note: the self-rescheduling loop is correct on the shipping toolchain. Swift 6.4's withContinuousObservation gives it a token-lifetime spelling — see Toolchain forward notes; D27′ governs when.

### D15′ — the sidebar is the master of session info; the stage stays clear

Everything that rendered above or over the board — the status HUD with its New Game affordance, the recovery checklist, the restored flash, and the boardLoadError banner — lives in the sidebar's SessionSidebarPanel, the single surface for connection and session status. The space above the board is kept clear so the board, the star of the show, gets the whole stage.

board.loaderror → sidebar.loaderror was a deliberate breaking rename through the AccessibilityID registry, and its witness gap is closed: test_deletingTheOpenGame_showsLoadErrorCard_andDismissClears pins presence and dismiss.

Rejected: a floating HUD over the board, and a split brain (some status above the board, some in the inspector).

Execution decisions:

- The panel pins via safeAreaInset(edge: .bottom) on the sidebar List — per tab; an empty guard keeps a disconnected, error-free sidebar exactly as it was.
- The new-game sheet's presenter stays BoardDestination. The sidebar's New Game button navigates to Board and requests the sheet via TabState.manualNewGameRequested; an unanswered request survives a destination round-trip and re-presents, deliberately.
- The auto-offer stays gated to the live branch inside the binding, so a tab reviewing a PGN isn't interrupted.
- The load-error card's Dismiss clears loadedGameID — unbinding is the real resolution.
- The board keeps its own recoveryGuidance computation for the attention/target overlays; the panel computes its own for the checklist. Both spell it RecoveryGuidance.current(session:connection:) — two computations was the decision, two spellings of it was not.
- hudPhase — the priority ordering between overlapping session flags (reconnecting → disconnected-nil → recovery → correction → awaiting-setup → archive-failed → finished → playing → idle) — lives in SessionSidebarPanel. LiveGameHUDView remains the banner (8 Phase cases, five exhaustive switches).
- The dialog's spacing is named and HIG-derived (DGTConnectionView.Metrics): 20 pt margins, 12 pt sibling spacing, 4 pt caption, 260 pt info table and the 420 × 380 frame as sizing. **M5's two sheets borrow these three numbers by name-and-reason rather than by import** — see D37′'s execution notes.
- The connect sheet's presentation: DGTConnectionToolbarModifier is deleted; DGTConnectionToolbarContent is a plain ToolbarContent (status as value, required identifier), and BoardDestination owns showConnectSheet state.

### D16′ — the New Game dialog's player fields are pickers over Player

The White/Black fields offer the full known-player list with free text still allowed — unknown names must keep working, and resolvePlayer stays the only creation door, firing at archive time, never from the dialog.

After both seats resolve to known players (text matched under the D9′ identity fold, routed through PlayerName.displayForm first), Round prefills with the latest round among archived games pairing those two players, plus one. No pairing history → Round stays empty. The query is PairingRound.nextRound, a pure fold over GameRecord. The fold matches the pair as a set; "latest" is the numeric maximum, so a late-imported old game can't wind the rivalry counter backwards; unknowns never inform. The prefill owns only its own writes.

Resolved (D29′): the picker inserts Player.tagName (first-seen raw tag), never a derived inverse.

StorageKeys persists defaultEvent / defaultSite / defaultWhitePlayer — deliberately no defaultBlackPlayer (White is the recurring seat; opponents rotate).

Rejected: creating Player rows from the dialog, and prefilling from a single resolved seat.

Witness note: the picker UITest is unreachable — the sheet gates on a connected board and UI runs are boardless by construction. Witness is the pure suite plus the manual check.

### D17′ — PGN export exists, pinned to the DGT reference shape

Superseded in its details by D24′. Retained for the part that did not change: export reads the same stored tags / result / moves the content hash covers, so an export after any accepted edit is consistent by construction; the serializer is a pure formatter; the panel is transport.

### D18′ — Library games are editable; movetext edits validate by full replay

Metadata edits are the trivial half (applyEdit — re-resolve plus refreshHash, one transaction). Both game kinds have a surface: the live inspector's Edit Details and the Board review inspector's Edit Info pencil, presenting the same EditLiveGameDetailsSheet through BoardDestination.activeEditor (an item-sheet whose two cases are mutually exclusive by construction). **M5's `PlayerEditor` is the third use of that shape** — one optional rather than two booleans, so "rename and merge are both open" is unrepresentable.

Movetext edits need no new legality algorithm — the chess core already is one. Parse the edited SAN and replay every ply through GameState move generation from the start position. The edit is accepted iff every ply is legal and the stated result is consistent with the final position where claimable:

- Checkmate on the board forces the mating side's win.
- A trailing # must actually mate.
- Stalemate forces a draw.
- \* is never a finished result (Decision #3).
- Anything a final position cannot disprove — a draw by agreement, a win by resignation from a non-terminal position — is accepted.

Check order: replay first (an illegal ply is reported before any result reasoning), then the trailing-# reality check, then *, then the position-forced results. "Decision #3 first" in the code comment is scoped to the result block only.

The mate-claim check tests last.contains("#"), not hasSuffix — the tokenizer drops move numbers and a trailing result token but not !/?, so Qd2#! still claims mate. Load-bearing, and since M4 it is the spelling `GameClassification` copies. `GameRecord.endedInMate` spells the same question `hasSuffix` and therefore answers *false* for `Qd2#!`; the divergence predates M4 and remains on the open-items list.

PGNParser.stripAnnotations removes only ! and ?; check and mate suffixes survive import verbatim. GameState.parseSAN discards them in its own cleaning step. The app has exactly these two strippers and they are meant to differ. M4's `ECOClassifier.foldedSAN` is deliberately **not** a third stripper — it is a *matching fold*, the SAN sibling of D30′'s string fold, which never touches stored text and exists only to build and probe dictionary keys.

Accepted movetext is stored canonical (san(for:) per ply). Accept whole or reject whole, with a per-ply error naming the first illegal ply, its SAN, and why. An accepted edit goes through PGNStore.applyMovetextEdit in one transaction: internal re-validation, refreshHash(of:), stored-evaluation invalidation, **re-classification** (M4's correction — engine-free classification re-derives rather than clears), and — deliberately — no player re-resolution, because a movetext edit cannot touch seats.

The splice defect is closed: MovetextEdit.tokenize throws(Rejection) when a result token has tokens after it. The asymmetry left in place: a trailing token that contradicts the claimed result is still dropped without comment. Since M4 the tokenizer has a second consumer: `ECOTable` tokenizes the bundled table's movetext with it rather than growing a second move-number stripper.

**M5's interaction with `applyEdit`, recorded here because it is this decision's machinery that forced D38′.** `applyEdit` re-resolves *both seats from the tag strings, unconditionally* — documented here as idempotent and cheaper than diffing which fields the closure touched, which is true, and which also means it will happily undo a relationship change that the tags don't justify. That is exactly what made a link-surgery merge unstable, and why merge rewrites tags. Pinned by `mergeSurvivesApplyEdit`.

Rejected: persisting free-form text raw, and per-move surgical patching.

### D19′ — ECO codes and special checkmates are classification (trigger revised by D34′)

Computed and stored on PGN:

(a) **ECO code** — longest-prefix match of the opening moves against a bundled ECO table. Pure core, engine-free, with its own suite. Built in M4 as `ECOClassifier` (pure, table-injected) plus `ECOTable` (bundle I/O, split out so the classifier stays inside the chess core's no-I/O contract). Stored columns are `ecoCode` / `ecoFamily` / `ecoVariation` — three, not two, because D35′ splits the source name.

(b) **SpecialCheckmate** — an enum when the result is mate, detected from the final position by pure Position / GameState predicates, no engine input. The case list is deliberately tight: smothered and backRank. Ordinary mates and non-mates classify nil. The classifier reads the final position only, and delegates to the shared Square offset tables and Position+Attack ray primitives. Wired in M4 through `GameClassification`, which replays via `GameState.replay` and only for a game that claims `#`.

Games predating the fields lack them until the backfill reaches them. Movetext edits re-derive both.

Revised by D34′: this decision recorded classification as *analysis-time* work. The second half of its reasoning stands (the doors still don't classify); the first half did not survive contact, because it made an opening name cost a full depth-18 pass over an already-analysed archive.

Rejected, and still rejected: classifying at import or archive; the loose "any mate on the back rank" reading; enumerating the long tail before a surface shows them.

### D20′ — the inspector headline is a pure formatter carrying the pairing

GameHeadline renders "Reviewing 1. Magnus Carlsen vs Ian Nepomniachtchi" over an archived game and "Recording 101. …" over a live one. A pure enum with a suite: the inspectors are different views onto the same grammar, and the grammar is the part worth pinning. The views stay dumb.

It deliberately carries the pairing, not PGN.name. Activity raw values are the user-facing verbs. An absent round omits the number entirely. A blank seat folds to ?.

### D21′ — the board frame carries optional coordinate labels

File letters and rank numbers on the board frame, behind StorageKeys.showBoardCoordinates. Absent reads as true; the two read sites — SettingsView's @AppStorage initial and BoardView's own — must agree on that default (the documented twin).

The preference is read inside BoardView because it has exactly one consumer; style stays injected because previews and the Settings swatches need to override it. The off branch renders Color.clear, not an absent view, so the board keeps its 10×10 grid, wooden border, and size at every setting.

### D22′ — the Seven Tag Roster is one object, rendered by one section

RosterSummary is a game's seven tags as a value; SevenTagRosterSection is the one view that renders them — all seven, standard order, formatted identically, on all three inspectors.

Values are stored in tag form; subscript(_:) is the single place the display rules live (it applies PlayerName.displayForm), and its raw sibling tagValue(for:) feeds export. RosterSummary.displayDate is the app's one short-date rendering.

Two distinct placeholders, deliberately: unknownTag (?) means this game doesn't say; the section's em-dash (—) means there is no game to ask. Dates use ????.??.??. Each placeholder has its own preview.

Rows are driven by SevenTagRoster.allCases; labels are the PGN tag names verbatim, deliberately unlocalized. The action slot is a @ViewBuilder so each host keeps its own title and identifier. noGamePlaceholder stays a computed static var (generic types can't have stored statics).

M4's sibling, `OpeningSection`, is the same idea for the classified opening and differs twice on purpose: its **row count varies** (the seven tags are fixed by the *standard* while these rows are ours), and it has **one placeholder where the roster needs two** (an opening is not a PGN tag and has no `?` vocabulary). Its em-dash is deliberately its own constant — two sections' two decisions that agree today.

### D23′ — player names render through one idempotent transform

PlayerName.displayForm(of:) is the single rendering of a player name: PGN carries "Last, First", every surface shows "First Last". Clients: PGNStore.resolvePlayer, RosterSummary, GameHeadline, PGN's display accessors, the draft-resume alert, and — since M5 — `RenamePlayerSheet`'s live preview.

Idempotent by construction — the output never contains a comma, so double application is a no-op, pinned across the whole fixture list. Whitespace folds via PlayerName.folded — the same fold Player.normalizedKey and PGNStore.normalize compose with lowercased(), so a display name and its identity key can never disagree.

The default game name is built once in PGN.defaultName(white:black:). backfillEmptyNames heals stale defaults and logs the healed names.

Rejected: a tagForm(of:) inverse — splitting a display name back into surname/given is undecidable. Names travel one way: tag → display. If tag form is needed somewhere, remember it — that is D29′'s Player.tagName.

**M5 is the strongest test this rule has had, and it held.** A rename dialog is exactly the place where an inverse feels necessary — the user is looking at "Bera Şenol" and wants to change it. D37′'s answer is to edit the **tag** and *show* the derivation live beneath the field, which turns the one-way rule from a constraint into the dialog's explanation of itself. The trap avoided, and worth naming because it is one keystroke away: seeding that field from `Player.name` instead of `tagName` would put a display form in a field that stores a tag, and the first Save would write "Bera Şenol" into every affected game's `[White]`.

### D24′ — PGN export is the DGT reference shape, byte for byte

Pinned to the three reference files the user actually interchanges, read off their bytes rather than off the standard. Where the standard and the files disagree, the files win.

The contract:

| | |
|---|---|
| Line endings | LF, not the standard's CRLF |
| Tags | Nine, fixed order: the Seven Tag Roster, then Board, then TimeControl |
| Names | tag form — [White "Senol, Bera"] |
| Separator | Exactly one blank line |
| Movetext | One full move per line; a white-only final line when the game ends on White's move |
| Result | Alone on the last line; file ends with a single \n |
| Unknowns | ?, ????.??.??, and - for no time control |
| Filename | 1. Bera vs Reinaud.pgn — ordinal, then given names only, White vs Black |
| Wrapping | None |
| Evaluations | Not written |

**Classification is likewise not written.** ECO and mate motif are derived truth, not interchange: the reference files carry no `[ECO]` tag, and adding one would put the app's own inference into a file the ecosystem reads as fact.

Moves are emitted verbatim from moves. Always all nine tags: a missing value prints PGN's own unknown vocabulary, so the tag block is a constant shape.

Multi-selection writes one numbered file per game into a chosen folder. Games are resolved against display order before numbering — LibraryDestination.gamesInDisplayOrder(_:) is the one resolution. Filenames sanitize / and : to -.

Correction (29 July, layering): PGNSerializer itself never calls the parser; RosterSummary.tagValue(for: .date) calls PGNParser.pgnDateString, which is the writer's half of the parser's one pinned formatter. One formatter, one convention; the reaching site is RosterSummary.

Consequences in force: PGN.board exists (deliberately outside the content hash), and since M2 the archive door threads it (D28′). Evaluation.evalTag / init?(parsingEvalTag:) are dead by decision, kept as the pinned round-trip pair.

**M5's consequence, and the gate sentence it earned.** Because export writes tag form byte for byte, a rename must reach the stored tags or export starts disagreeing with the Players list — that is the whole of D37′. The pin is `renamedGameExportRoundTrips`: a renamed game's export re-imports and is refused as a duplicate *of itself*, asserted on the identifier rather than on the bare fact of a throw, because a refusal naming some other game would pass a weaker test while meaning the opposite.

Witness status: PGNSerializerTests is landed and committed, with its resources — now filed under `DGTStudioProTests/PGN/PGNs/` (a mechanical move; bundle resources land flat at the Resources root whatever source folder they came from, so `Bundle(for:)` lookup is unaffected).

Rejected: emitting only the tags that carry values; the standard's wrapping; a tagForm derivation to fix the picker.

### D25′ — idle-sleep inhibition is a user preference

D14′'s behaviour is opt-out, behind StorageKeys.preventSleepDuringPlay with a Settings toggle in the Energy section. Absent reads as true, preserving pre-toggle behaviour.

The preference is an observable property on SleepInhibitor, not an @AppStorage read: the gate participates in the same withObservationTracking loop as the predicate, so switching it off mid-game releases the assertion on that edge. Settings binds through @Bindable.

The first preference in the app with no twin read site. The default is stated exactly once, in SleepInhibitor.init; every reader goes through the property. **The general rule, which the post-M4 audit found violated twice in view code: where a value has an owning type, that type should hold it. A twin is a symptom of ownerless state.** The evaluation bar's width was stated in both the view (20) and its caller (16) and the two never met; it now lives on `EvaluationBarView.width`, and the caller keeps only the *gap*, which describes a relationship between two views and belongs to neither alone. The shared inspector pencil's trailing inset was the same shape with a worse failure: 10 pt in the shared type stacking with the Library's own 8, putting one of five pencils at 18.

UserDefaults is injectable so the suite pins the contract against a scratch suite.

Rejected: KVO / UserDefaults.didChangeNotification, and an @AppStorage twin.

### D26′ — inspector chrome is shared: one empty state, one header, one pencil

Three shared components own the inspectors' common furniture:

- InspectorEmptyState — a ContentUnavailableView wrapper with a required accessibility identifier and a stated contract that the empty branch renders outside the List.
- InspectorSectionHeader — String (not LocalizedStringKey, the title is data), textCase(nil), lineLimit(1), a @ViewBuilder actions slot with an EmptyView convenience. M4's `OpeningSection` is its first fixed-label consumer, which is fine — the type takes a String because titles are *usually* data, not because they must be.
- InspectorEditButtonView — the shared header pencil: one LocalizedStringKey label feeding both .help and .accessibilityLabel, identifier required with no default. **Its trailing inset is now stated here and nowhere else**, with the rule that a host wanting different spacing changes the number for everyone rather than stacking a second one.

The point is the set: five inspectors were each free to disagree about what "empty" looks like and how a section header truncates; now a divergence is a compile-visible choice. **The audit proved the mechanism works only as far as the components' own discipline goes** — a padding added inside the shared type still diverged, because one host had a local one already. The failure was invisible unless two inspectors were open side by side, which is the argument for the sweep rather than against the component.

**M5's addition to the family.** The Players profile header carries the pencil *plus* an ellipsis menu for merge and delete. Widening the pencil to also mean those would turn a named affordance into a generic icon button and lose exactly the guarantee this decision buys — the same argument `LibraryInspectorView` already makes for its Copy-PGN button not being one. The header's actions slot now has a two-control precedent in two places, so a third is a layout question already answered.

(Related default: every section in the app now defaults open, including the Library inspector's PGN section — Bera's 30 July reversal of the M1 collapsed default.)

### D27′ — the build target is the shipping toolchain; beta API is a forward note

The project builds against Swift 6.3 and Xcode 26.x, both shipping. Swift 6.4, SwiftUI and SwiftData for the 2027 releases, and Xcode 27 are beta (Xcode 27 at beta 4) and are not adopted in delivered code.

The rule: a platform feature is usable in a delivery when it ships. Until then it is recorded in Toolchain forward notes against the decision or invariant it would change, and nothing schedules it.

Audit note (30 July): upheld, and re-verified twice — after M4 and again in the post-M4 conformance sweep, which checked the full announced surface (withContinuousObservation, weak let, @diagnose, ToolbarOverflowMenu, sectionBy, visibilityPriority, swipeActionsContainer, reorderContainer, appearsActive, mapKeyedValues, MutableRef, withTaskCancellationShield, anyAppleOS, ContentBuilder, Writable/ReadableDocument, @Attribute(.codable), ModelResultsObserver, HistoryObserver). All empty. M4's one new language surface was a manual `init(from:)`, as old as Codable; M5 added none.

Recorded fact (29 July), decision deferred: the project builds in Swift language mode 5 — SWIFT_VERSION = 5.0 on all three targets, with SWIFT_APPROACHABLE_CONCURRENCY = YES, upcoming-feature MemberImportVisibility, and SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated on the app target. The codebase is written as if mode 6, but the compiler is not yet enforcing mode-6 semantics. Migrating is scheduled as an evaluation item in ROADMAP M7. Deployment target is macOS 26.2; sandbox on; the serial entitlement (com.apple.security.device.serial) is the operative hardware grant — ENABLE_RESOURCE_ACCESS_USB = NO is correct and should not be "fixed".

Why this is a decision and not a passing fact: this document is the project's memory, and beta API is the single easiest way for a confident-sounding wrong answer to enter it — everything in the 2027 line was announced after the assistant's training cutoff, so the failure mode is a 2025-era pattern written fluently, or a beta-only API presented as available.

Adoption gates worth keeping on record: Xcode 27 beta is Apple-silicon-only and requires macOS Tahoe 26.4+. App Store floors are irrelevant to this app but recorded once so nobody re-derives them: uploads have required Xcode 26+ SDKs since 28 April 2026, no 27-SDK deadline announced.

Explicitly not forbidden: shipping 6.3 features, and evaluating the beta to answer a specific question, so long as no delivery requires it.

Rejected: adopting 6.4 concurrency/ownership work for the perft hot path before Instruments has ever run (M7 owns the measurement); dual-targeting with #if compiler(>=6.4) fences.

Sunset condition: when Xcode 27 reaches GM (expected around the September 2026 iPhone event) this decision is re-read, not automatically reversed.

### D28′ — live games capture the board identity at game start, on the Roster

The `[Board "…"]` tag value is composed by `DGTConnection.BoardInfo.identityTag` — `"DGT "` + the long serial, matching the reference exports byte for byte. On the value type, not the connection, so the composition is testable without a port.

The session gains a settable hook, `boardIdentity: (() -> String?)?`, wired once in App.init(). `startNewGame` consults it exactly once and stamps the answer onto `Roster.board`. The draft carries the field (additive optional — schemaVersion stays 1), resume restores it, and `PGNStore.archive` threads it to `PGN.board` — outside the content hash by D24′, so a boarded game still dedupes against its board-less pre-M2 twin.

Capture-at-start names the board that *played* the game: it survives a mid-game cable pull and a crash-resume. A nil hook leaves it nil.

The recorded draft-schema stance: additive optional fields are not breaking, because synthesized `Codable` reads a missing key as nil and `JSONDecoder` ignores unknown keys. M4 discovered the limit — it holds for *optional* fields only — and D36′ paid the debt for the other Codable-on-a-model type by making the guarantee structural.

Rejected: reading `boardInfo` at archive time via the hook; a `schemaVersion` bump; putting the field on `LiveGame` beside the roster.

### D29′ — Player.tagName: the picker inserts remembered tag form

D23′'s "no inverse, remember instead", made real. `Player` gains optional `tagName` — the first-seen raw tag, whitespace-folded via `PlayerName.folded` only, stamped by `resolvePlayer` at creation. First-seen wins, like `name`'s casing.

Existing rows heal eagerly: `backfillPlayerTagNames()` runs after `backfillPlayerLinks()` at the same three collection-destination onAppear sites. "First seen" for a pre-schema row is reconstructed as the seat tag of the earliest linked game. Linkless orphans stay nil and never re-report as work; readers fall back to `name`.

The New Game seat picker inserts `tagName ?? name`. Menu labels show the string they insert.

**M5 is the second beneficiary and the one that pays the groundwork off.** The rename sheet seeds from `tagName ?? name` — same fallback, same reason — and `merge` targets `survivor.tagName ?? survivor.name`. Without D29′ the merge would have had no honest tag to retag *to*: deriving one from the survivor's display name is precisely the inverse D23′ forbids. The roadmap's note that "M2 should precede M5" was correct for exactly this reason.

Rejected: lazy heal-on-next-resolve; an upgrade-to-comma-form rule; deriving tag form.

### D30′ — TagRule string semantics: one fold, and unknowns never match under negation

(a) String comparisons fold **both sides** through `PlayerName.folded` + `lowercased()`. Matching changes for already-saved tags; accepted at decision time.

(b) Unknowns never match, **negation included**, for the single-subject string fields. The guard is `.notEquals`-only: positive comparisons are deliberately untouched, so "Event is ?" still finds ?-event games. M1's documentation test was flipped into the decision's pin.

Rejected: the "anything but X, unknown included" reading (Apple Music's lean); a blanket unknown-guard over positive comparisons too.

Extended by D36′ to the two M4 fields, including the first optional-*enum* subject in the family.

### D31′ — rounds are integers; sub-rounds are recorded loss

PGN permits multipart rounds; this app does not model them. `PGNParser.parseRound`'s `Int(_)` is the contract: a sub-round imports as nil and exports as `[Round "?"]` — lossy, documented at the parser, pinned by `roundParsesIntegersOnly`.

Rejected: end-to-end sub-round support.

### D32′ — batch export overwrites same-named files silently

Re-exporting into last time's folder should refresh the files — the export is a pure function of the Library rows. The alternatives are worse: a skip silently exports less than was selected, a unique-suffix rename breaks the D24′ filename convention, and a per-file modal is the fifty-dialog batch. The single-game path keeps NSSavePanel's own replace prompt.

### D33′ — the evaluation bar: leading edge, flips with the board, label beneath

Three product choices: **leading edge**; **bottom tracks the near player**, so the bar reads physically from either seat; an **always-visible numeric label** in a fixed slot *below* the bar.

`EvaluationBarReading` is the pure mapping and its fraction is `whiteWinProbability` **verbatim** — the bar and the inspector graph share one projection, so agreement is structural and mates clamp exactly as the graph clamps. A nil per-ply evaluation folds to `Evaluation.drawn`. The reading stays white-relative and perspective-free; the flip is one boolean of geometry in `EvaluationBarView`. Label grammar, pinned: signed pawns to one decimal, unsigned `0.0` for anything that rounds to zero, mates in the `evalTagContent` spelling. (`String(format:)` and not `.formatted()`, deliberately: the latter localizes the decimal separator and would break the pinned grammar.)

Presence is game-level and lives at the wiring: `pgn.evaluations.isEmpty` gates the bar entirely, and only the review branch ever passes a reading. `boardSurface` builds the `BoardView` once and branches layout, with explicit `GeometryReader` math because `BoardView` is strictly square.

**Correction (audit).** The bar's width was stated twice and the two statements disagreed — `.frame(width: 20)` in the view, `evaluationBarWidth = 16` in the caller's geometry. It is now `EvaluationBarView.width`, stated once by the view that draws it; the caller frames height only and keeps `evaluationBarGap`. Note the caller's own doc had claimed the constants existed so "the geometry and any future reader agree", which is the kind of comment that reads as a guarantee and was describing a wish.

Rejected: white-always-from-bottom; a hover-only or absent readout; a second sigmoid at the bar; putting the bar inside `BoardView`.

### D34′ — classification is engine-free and backfills; the table is lichess's, bundled whole

The trigger is split: the analysis pass stamps, and so does a Library backfill, and neither needs the other.

`GameClassification.classify(moves:using:)` is the one pure entry point, producing the opening and the mate motif together because they are stamped, cleared and backfilled together. The two halves fail *independently*.

**Source and shape.** lichess-org/chess-openings — five TSVs by ECO volume, ~3,807 rows, CC0. Bundled as fetched, never transcribed, renamed `eco-a…eco-e.tsv` because bundle resources land flat at the Resources root. (Filed under `Chess/ECOs/` since 30 July; the prefix's reason survives the move — the folder organizes the *source* tree, the flat Resources root is still where a bare `a.tsv` would say nothing.) The dataset carries duplicate rows for common transpositions on purpose.

**Layering.** `ECOClassifier` is pure and table-injected; `ECOTable` owns the I/O and is filed beside it — the purity invariant names *types*, not folders.

**Write door and backfill.** `PGNStore.classify(_:using:)` is the single write site for all four columns, save-free by the `resolvePlayers` contract. `backfillClassifications(using:)` heals rows where `ecoCode == nil`, from the Library's `.task` only. The filter deliberately conflates "not yet classified" with "classified and unnamed", rather than minting a third stored state. That conflation costs almost nothing because **the table names all twenty legal first moves**, so "unclassified" means "moveless" — pinned by `everyPlayedGameGetsAName`.

**Predicated since the audit.** The backfill now carries `#Predicate { $0.ecoCode == nil }` rather than fetching everything and filtering in memory. It is the one member of the fetch-all-and-scan family that *can* be predicated — `backfillPlayerLinks` genuinely cannot, since a nil `whitePlayer` on a `"?"` row is correct rather than missing — and the converged case now fetches zero rows instead of materializing every game with its full `moves` array on every Library appearance.

**Off the main actor.** `ECOTable.warmed()` forces the parse through a detached task; the synchronous `bundled` default remains for `applyMovetextEdit`, which is synchronous by nature inside a sheet's save and finds the table warm.

Rejected: strict D19′; a manual-only Game-menu "Classify"; classifying at the import or archive doors; trimming the table to family names; a stored "already asked" flag.

### D35′ — the opening name splits into family and variation

`ECOOpening(code:name:)` splits at the **first** colon (subvariations nest after commas, never after a second colon), once per table row at load rather than once per surface at render. Stored as `ecoFamily` / `ecoVariation`. An empty remainder folds to nil, so nil is the only spelling of "no variation".

`fullName` is the inverse. The Library column shows the code alone; the inspector shows all three rows; `TagRule.opening` matches the full name.

Two initializers, two jobs: `init(code:name:)` *parses*; `init(code:family:variation:)` *rehydrates*. The parsing door has the shorter, more inviting label deliberately.

`PGN.opening` requires both a code and a family before rehydrating — an invariant check, not defensive nil-handling. **The audit found the Library's ECO column reading `ecoCode` directly, past that check**, which would have made it the one surface printing a code the rest of the app calls unclassified; it reads `opening?.code` now.

Rejected: one field holding the source string verbatim; code only.

### D36′ — TagRule grows two classification fields, and additive slots stop being a hazard

`.opening` is an ordinary string field over the **full** name. `opening is French Defense` matches only lines with no variation, `begins with` is the family-level query, `contains` is what most rules want. One subject for every comparison, deliberately.

`.matePattern` is the first field whose subject is an optional **enum**, taking a new `Kind` case with `equals` / `notEquals`. It inherits D30′: an absent motif matches neither direction. A nil motif means either "classified, and it's an ordinary mate" or "not classified yet", and the rule cannot tell them apart — reading nil as "not smothered" would make "mate pattern is not smothered" quietly true for every unclassified game.

**The hazard found while adding the slot.** `[TagRule]` is stored as one Codable blob on `SmartTag`. Synthesized decoding requires every non-optional key to be present, so the eighth slot would have failed every previously-saved tag's decode — the sidebar silently emptying. Paid structurally: explicit `CodingKeys` and a **defaulting** `init(from:)` whose fallbacks come from a default-constructed instance rather than a second list of literals. Pinned by `preM4RuleDecodesWithDefaults`.

Rejected: an optional `specialCheckmate` slot; per-motif boolean fields; matching the motif as a string.

### D37′ — renaming a player rewrites the games' seat tags

A rename reaches the **stored seat tags**, not the registry row. `PGNStore.retag(_:to:)` rewrites every game the player appears in, re-resolves its links, and rehashes it — one transaction.

**Why the games and not the registry.** `PGN.white` / `PGN.black` are what export writes byte for byte (D24′) and what the content hash folds; `Player.name` is *derived* from them through `PlayerName.displayForm`. Renaming the registry alone would make `Player.name` a label that disagrees with every file the app writes. Rewriting the tags makes identity follow the tags, which is the direction D23′ says names travel.

**The edited field is tag form.** D23′ forbids the inverse transform, so a dialog editing the display name would have nothing legitimate to store. `RenamePlayerSheet` edits the tag and shows the derived display form live beneath it, which turns the one-way rule from a constraint into the dialog's own explanation. Seeding is `tagName ?? name` (D29′'s fallback); seeding from `name` would put a display form in a field that stores a tag, and the first Save would write it into every affected game's `[White]`.

**The accepted price, recorded so it is a decision rather than a surprise:** seat tags are inside the content hash, so every affected game's hash moves. An export taken *after* a rename re-imports and dedupes; one taken *before* no longer will. That is not a leak to engineer around — by the hash's own definition the players are part of what identifies the game. Pinned by `renameChangesTheHash` and `renamedGameExportRoundTrips`.

Execution notes: the sheet names the cost in the dialog ("Rewrites the name stored in 42 games") because a rename is not a label change and nothing else on screen says so. Its spacing borrows `DGTConnectionView.Metrics`' three HIG-derived numbers by name and reason rather than by import — two dialogs' two decisions that agree today, the `OpeningSection` em-dash precedent.

Rejected: a registry-only alias (cheap, hash-safe, and makes `Player.name` stop describing what export writes); rewriting tags while keeping an independently editable display label (flexible, and mints a second naming rule alongside D23′'s one-way transform).

### D38′ — merge is retag-then-delete; delete is orphan-only

**One door.** `merge(_:into:)` retags the loser's games to `survivor.tagName ?? survivor.name`, which relinks them by resolution, then deletes the row nothing points at.

**Merge has to be retag, and this is the finding that decided it.** `applyEdit` re-resolves both seats from the tag strings *unconditionally* (D18′, where that is documented as idempotent and cheaper than diffing — both true). So a merge that only moves relationships is undone by the first metadata edit on any merged game: the untouched tag resolves, fails to find the survivor, and mints the deleted player straight back. Rewriting the tags is what makes the merge survive the app's own existing doors instead of needing them weakened. Pinned by `mergeSurvivesApplyEdit`.

The merge asserts rather than assumes the loser is orphaned afterwards: a still-linked loser means the target tag didn't fold onto the survivor's key, and deleting it then would nullify live links. It logs and declines instead.

**Delete is orphan-only, and this corrects the roadmap.** The roadmap proposed "delete-player = merge-into-nobody (nullify + delete)". That does not work: `.nullify` leaves the games' seat tags intact, and the Library's next `backfillPlayerLinks()` resolves those same tags and recreates the row. A delete the app undoes within one navigation is worse than no delete. `deleteOrphanedPlayer` refuses a linked player and returns `false` so the surface can say rename-or-merge instead of appearing to work; the menu item is disabled for the same condition, computed from the same games the inspector lists so the disabled state and the visible reason cannot disagree.

Surface: the profile header's D26′ pencil renames; an ellipsis menu beside it holds Merge Into… and Delete Player. `MergePlayerSheet` states the asymmetry with both names in one sentence, because merges are not symmetric and a misread direction silently rewrites the wrong forty games. It stays a separate sheet from the rename one — it is model-bearing by necessity, and widening the value-typed string editor to sometimes query would cost the property that makes it previewable three ways without a container.

Rejected: link surgery with a re-resolve guard on `applyEdit` (cheaper, hash-preserving, and it weakens the "re-resolving unconditionally is idempotent" contract that three other doors rely on).

### D39′ — a retag that would collide content hashes is refused, whole, naming the games

Two rows with the same event / site / date / round / seats / result / moves hash identically. A retag can *create* that: the double-imported game under two spellings of a name is exactly what a merge is for.

The refusal is **pre-flight and all-or-nothing** — every prospective hash is computed before a single field is written, so a rejected retag is indistinguishable from one never attempted. `RetagRejection.wouldCollide` carries the pairs, and the alert names up to three of them and says nothing was changed.

**Two collision sources, and missing the second is the easy bug.** A rewritten game can collide with a row already in the Library, *or* with another game in the same batch — and in the batch case neither copy is in the store under its future hash yet, so a Library-only probe finds nothing. Both are pinned (`collidingRenameIsRefusedWhole`, `batchInternalCollisionIsCaught`). A game colliding with *itself* — a fold-equivalent rename that doesn't move the hash — is not a collision, guarded by an identity check and pinned by `foldEquivalentRenameIsAllowed`.

Blocking rather than auto-deduping was chosen deliberately over offering to delete the twin in the same transaction: a merge that silently destroys a game is the failure that cannot be undone, and the Library's existing delete path is one navigation away.

Two shape notes the implementation forced, both worth keeping:

- `contentHash` gained a **field-taking twin**, so the pre-flight can ask what hash a row *would* carry without either mutating-and-reverting (a door that briefly writes a lie into the model it is validating) or transcribing the recipe a second time (the one-hash invariant, broken by the check meant to protect it). One recipe, two spellings.
- `Rewrite` is **per game with both seat flags**, not per seat. A player can hold both sides of one row; asked seat-wise, the pre-flight computes two hashes for such a game and neither is the one it reaches. Pinned by `selfPlayRewritesBothSeats`.

`HashCollision` carries identifiers and names, never models — `Error.duplicate`'s precedent, because `Swift.Error` refines `Sendable` and a live `@Model` never is.

Rejected: offering to dedupe inside the merge sheet; reporting and keeping both.

## Architecture invariants

- Chess-core purity. Position, GameState, Move, FEN, Square, CastlingRights and friends are pure Sendable value types — logger-free, I/O-free, actor-free (sole Foundation import: CharacterSet trimming in the SAN layer). The invariant names **types, not folders** — which is why `ECOClassifier` and `ECOTable` sit in the same directory. Board geometry offsets live on Square, one copy; queenDirections is spelled out despite equalling kingOffsets.
- Move generation defends against hand-edited state. Castling is generated only when the rook actually sits on its home square. Same boundary hardening in FEN parsing.
- LiveGame is an I/O-free @Observable @MainActor final class. Append-only: no takebacks, no rollback() API, ever (Decision #1).
- Single-Mode state machine, honestly scoped. DGTLiveSession's one private Mode derives liveGame, awaitingPhysicalSetup, needsRecovery. Three published members are deliberately not Mode-derived but Mode-guarded.
- Settable-hook wiring. sessionLog, draftStore, onGameFinished, onBoardChanged, onDesync, boardIdentity, and shouldAutoReconnect are wired exactly once in App.init(). Nil hooks mean unit tests run headless by construction. recordError is the one door for must-reach-somewhere errors.
- Auto-connect decisions are pure; transport is not.
- Idle-sleep inhibition is App-owned, preference-gated, transport-only. Display sleep intentionally left alone — structural via .userInitiated. observe() is re-entry-guarded.
- The mirror renders the physical board. Always. Only overlays come from the game.
- The stage above the board stays clear; the sidebar owns session info (D15′).
- id→model resolution guards tombstones. Five sites now pair the cast with an isDeleted check: two in AnalysisQueueController, two in BoardDestination, and M5's merge survivor — whose picker was built from a `@Query` snapshot, so a row deleted between presentation and Merge would otherwise be merged *into*.
- Recovery guidance is view-computed, session-gated, one spelling.
- DGTBoardDiff.vacated and .placed are disjoint, decided by end-occupancy.
- Reconstruction returns .inProgress before generating moves.
- One draft, one JSON sidecar. Atomic writes, schemaVersion-guarded, flattened fields; additive **optional** fields are non-breaking by the D28′ stance — a limit D36′ makes explicit for the other Codable-on-a-model type.
- Archive-first, exactly once, never lost. No * result ever archives (archive door; the import door admits * deliberately).
- **One content hash, one recipe, two spellings.** MD5 over normalize(event) | normalize(site) | hashDateString(date) | round | normalize(white) | normalize(black) | result.rawValue | moves joined by spaces. The model-typed `contentHash(for:)` forwards to a field-taking twin (D39′); there is still exactly one arrangement of the recipe, and changing its order, separator, normalization or digest un-dedupes the archive against itself. Any in-place edit must call `refreshHash(of:)` — or, for a retag, rehash inside the same transaction. timeControl, board and all four classification columns are deliberately outside it; PGN.name is too.
- Player links are store-owned (D9′). resolvePlayer(named:) is the single creation door; both doors link on insert; backfillPlayerLinks() heals pre-schema rows, followed by backfillPlayerTagNames(). applyEdit re-resolves unconditionally; applyMovetextEdit deliberately does not.
- **Stored seat tags change through one door (D37′, D38′).** `PGNStore.retag(_:to:)` is the only place `PGN.white` / `PGN.black` are rewritten outside a user's own metadata edit; merge and delete are its callers, not siblings. The pre-flight refuses before writing (D39′), and the rehash rides the rewrite rather than waiting for a later `refreshHash` — a retagged game whose hash lags is a dedupe rot with a delay fuse.
- Classification is store-owned and derived (D34′). `PGNStore.classify` is the single write site for all four columns. The fields are deliberately absent from `PGN.init` — the whitePlayer/blackPlayer precedent.
- Player names render through PlayerName.displayForm(of:), once (D23′). Tag form is stored; display form is shown; there is no inverse — and D37′ is the surface that proves the rule survives a rename dialog.
- Movetext edits validate by replay, accepted whole or rejected whole (D18′), structurally.
- PGN export is byte-pinned to the reference files (D24′). Classification is not exported.
- Pure cores are GameRecord-typed (D10′), with two recorded shape exceptions: SpecialCheckmate and the M4 classifiers.
- SmartTag matching is model-stored, value-decided. Matching is an in-memory fold, never a #Predicate — a stored-Codable rule array can't be queried in the store; load-bearing.
- SmartTag.self in the container is load-bearing. No relationships, so schema inference from PGN never pulls it in.
- Collection-destination parity, now with shared metrics. Known parity residue (unscheduled): the two gallery stat grids still differ, the Players/Rankings columns detail grids carry literal .padding(16), and the two galleries answer empty-selection opposite ways.
- Destructive Library actions confirm, whichever route reaches them. **M5's three are the first destructive actions outside the Library**, and they confirm differently on purpose: rename and merge confirm *by being sheets that state their consequence*, delete needs no confirmation because it only ever removes an orphan.
- Accessibility identifiers are a tested contract. Dotted lowercase, all in AccessibilityID; renaming one is a breaking change; a raw string in a view is a defect — including parameter defaults. A repo-wide grep is clean at 126 entries, all referenced. Note the Library table's row identifier rides the **White** column's cell, so inserting a column elsewhere leaves it unmoved — but moving the White column would be an accessibility-contract change. Note also that `board` now identifies the container holding the eval bar *and* the board, not the `BoardView` alone; no UITest does coordinate math on it, but the widening is recorded rather than discovered.
- StorageKeys is the single home for @AppStorage keys. M4 and M5 add none.
- Engine options are sent in the UCI window. Inbound option advertisements are deliberately ignored.
- Engine teardown must complete even when the surrounding work is cancelled — and must strand no waiter.
- [%eval …] parsing rejects what it cannot represent. The bundled ECO table is *trusted* content by contrast, so its parser skips malformed rows and logs rather than hardening against hostility.
- DGTSessionLog discipline. record buffers and Console-mirrors; capture buffers only; recordDesync for irreconcilable boards. Ring-bounded.
- Test hosts stay hermetic.

## Toolchain forward notes (Xcode 27 / Swift 6.4 / 2027 SDKs — all beta)

Governed by D27′: none of this is adopted, none of it is scheduled. Snapshot taken at Xcode 27 beta 4; the compiler outranks this list whenever they disagree.

**Strong — these restate arguments this document already makes**

- withContinuousObservation(options:) replaces the self-rescheduling loop (D14′, D25′). The replacement returns a token whose lifetime owns the subscription — verbatim the RAII argument D14′ makes for ActivityToken. Two cautions: D25′'s gate and D14′'s predicate must stay in the same closure; and Apple's sample spells the handler [weak self], which sits against this project's strong-capture lesson.
- withTaskCancellationShield { } guards engine teardown. Adjacent: 6.4 diagnoses catching an error inside a Task { } so it never reaches the caller.
- @diagnose is the warning-triage tool, and culturally exact. @diagnose(ErrorInFutureSwiftVersion, as: error) is the staged lever for the language-mode-6 migration (D27′ / M7).
- .confirmationDialog(item:) / .alert(item:) remove the Bool-plus-optional pairing class. **Six `Binding(present:)` sites now** — four in LibraryDestination, one in ContentView, and M5's refusal alert; that last one's `RetagRefusal` wrapper exists only to give an array an `Identifiable` conformance the item-based API would supply, so it is the site that would disappear most completely.

**Real, but wait for a measurement or a surface**

- Ownership and specialization for the perft hot path. Hard constraints: ~Copyable collides with chess-core purity; and generated move order is what the perft counts were taken against, so perft is both witness and veto. M7's Instruments pass gates all of it.
- ModelResultsObserver&lt;T&gt; / HistoryObserver (SwiftData 2027). The candidates are backfillPlayerLinks() and backfillPlayerTagNames() — **down from three**, since backfillClassifications now carries a predicate and is no longer the same fetch-all shape.
- @Attribute(.codable) names D12′'s arrangement rather than changing it. Counterweight: Apple's rule of thumb says use it for types you don't own. D36′ raises the stakes — now that the blob's decode path is hand-written and load-bearing, moving to `.codable` would have to preserve the defaulting decoder, not replace it.
- Toolbar composition for the crowded Library toolbar — with the standing hazard that UI tests address segments by SF Symbol.
- @Query(sort:, sectionBy:) native sectioning — a named candidate since M4 gave games an ECO identity.

**Small, cheap, no downside beyond being beta**

- CommandMenu icons via .labelStyle(.titleAndIcon).
- @Environment(\.appearsActive).
- Memberwise-init broadening — check, don't assume. GameRecord's hand-written init stays regardless.
- Dictionary.mapKeyedValues / MutableRef — PlayerStats counting shape. Ergonomics only.
- weak let where @unchecked Sendable papered over a mutable weak stored property. (Nothing in the app currently does; recorded for the next time it would be reached for.)
- Two-way XCTest ↔ Swift Testing interop.
- Liquid Glass arrives with no diff when built with 27 on a 2027 OS.
- Xcode 27 agent skills — this document's working agreements are the natural content for a custom one. Gated on GM.

**Considered and not applicable — recorded so it is not re-derived**

WritableDocument / ReadableDocument; @available(anyAppleOS 27, *); the @c attribute; AsyncImage caching; drag-to-reorder; cross-platform FilePath; module selectors; ProgressManager / Subprogress; ContentBuilder.

## Working agreements

- **Code is truth.** Docs follow code; when they disagree, fix the doc. The roll of instances now includes: D18′'s stated reason; D14′'s recorded options; the setoption window; Evaluation.drawn; five decisions landing in code without reaching this document; the 29 and 30 July harvests; M2's resolvedKey find; M4's three; and **the audit's three plus M5's one** — the eval bar's two width numbers, the pencil's stacked padding, the ECO column reading past its invariant, and the roadmap's delete-player proposal that the link backfill would have undone. The useful pattern across all of them: a comment that *asserts* a guarantee ("named so any future reader agrees") is where to look first, because it reads as settled and is exactly as checkable as anything else.
- **Sweep between milestones, not only within them.** (New, M5.) Three of the audit's four findings were introduced by the two milestones that had just landed green, and none was visible from inside the change that caused it — the pencil divergence in particular is invisible unless two inspectors are open side by side. A grep-level conformance pass costs minutes and is the only thing that catches the class.
- A test that pins a factory is a change-detector, and editing the factory means editing the test in the same change.
- The compiler outranks any platform reference, including this document's forward notes. Corollary: do not infer an API name from its neighbours. M4's variant: do not infer a data row either. **M5's variant: do not infer a function's contract from its name.** `importPGN` *throws* on a duplicate rather than returning the existing row, and `Player.normalizedKey(for:)` takes a **display** form — handing it a comma tag yields a key no row carries, so every lookup written that way returns nil and passes an "it's gone" assertion for entirely the wrong reason. Both were found by reading the declaration, both would have been plausible either way.
- **A discarded working tree is a discarded delivery.** (29 July; three further instances.) 30 July's variant: resources can die without a reset — a file a committed test requires is part of the delivery. **The hazard is currently discharged**: everything is committed at `0a21fc9`. It recurred once more in this session in a new shape — a folder reorganization left two reference PGNs as unstaged deletes plus untracked copies, which `git status` shows and a casual glance does not. Doc-form corollary: rebuilding a document from a stale synced base silently discards the revisions in between — name the base and the carried deltas when forced to do it, as this revision's header does.
- Never pencil a D-number for future work. Numbers are assigned at recording time, in this document, in sequence.
- Code edits arrive as SEARCH & REPLACE, always. Never prose naming call sites; never a whole-file replacement unless asked or labelled.
- Updates to this document arrive as a complete .md file. Same for ROADMAP.md.
- A correction has two homes. When a correction lands, fix the comment that originated the claim in the same pass.
- A comment describing a deletion lands in the same commit as the deletion.
- A test referencing API that doesn't exist is not a landed test. Its siblings: a fix without its pinning test is half-landed; a test whose resources aren't committed is not a landed test either.
- When a suite wants API that doesn't exist, decide rather than default.
- A view without a preview needs a written waiver; a preview must instantiate its own type. **Previews should cover the branches no fixture reaches by accident** — M5's two sheets ship five between them, including the no-comma tag (where the derived display line legitimately reads the same as the field, and "the preview looks broken" is the reading to pre-empt) and the one-player Library (where the merge picker is absent rather than disabled).
- Tests land in the same change as the behaviour they cover. Outcomes are expected, never asserted — ⌘U runs locally; deliveries never claim green.
- Actor isolation in tests: @MainActor suites for @MainActor types; pure-type suites nonisolated.
- Waivers are written, not implied — and the mirror: a type that gains a suite comes off the register in the same change.
- Mechanical changes travel alone. (The 30 July resource reorganization is the clean example; the pencil's padding, which rode two feature milestones, is the counterexample that cost a divergence.)
- Doc comments carry the why. Anti-patterns on record: enumerated caller lists on primitives, named consumers that don't consume, "shared" claims on private copies.
- Not every duplicate should be collapsed. The worked examples stand (HUD's five switches; BoardStyle's exhaustive switches; the memberwise init taxonomy; `OpeningSection`'s em-dash beside `SevenTagRosterSection`'s; and now M5's two sheets borrowing `DGTConnectionView.Metrics`' three spacing numbers by name-and-reason rather than by import).
- A synchronous parse of a bundled asset belongs off the main actor, and XCUITest will find it before Instruments does.
- **A guard that exists in two places must be computed from one source.** (New, M5.) The Delete menu item is disabled for a linked player and the store door refuses one; both read the same games, so they cannot disagree — and if they ever do, the destination logs it rather than no-opping silently. Two independent spellings of "is this player linked" would be the twin-read-site pattern in behavioural clothes.
- Re-sync project knowledge after each integration. Sync artifact: + in filenames arrives as _ (PGN+Export.swift → PGN_Export.swift); file contents are unaffected, so anchors stay exact.
- Manual checks stand in for what XCUITest can't reach.

## Build-diagnostic lessons

- A mass identical test failure is one death, fanned out. Clean build, ⌘R the host, target membership, then the crash report — in that order.
- Swift 6 capture discipline in @Sendable closures. A weak capture is a mutable box; capture @MainActor classes strongly and verify no cycle.
- With synchronized folder groups, target membership IS folder contents. Deleting a file from the project without deleting it from disk removes nothing. The flip side: dropping five `.tsv` files into the source tree bundled them as Resources with no project-file edit, and moving them into a subfolder changed nothing about the flat Resources root.
- **`Swift.Error` refines `Sendable`, so an error payload can never carry a `@Model`.** Recorded twice now: `PGNStore.Error.duplicate` carries `PersistentIdentifier` + `String`, and M5's `HashCollision` does the same for the same reason. If a rejection needs to *name* something in the store, read the names at the point where the models are in hand.
- Key paths do not reach tuple elements.
- os.Logger interpolation has no `Substring` overload.
- Result builders top out at ten statements.
- "Cannot find X in scope" after a diff usually means the wrong file.
- "Global 'let' requires an initializer" means a type declaration was lost.
- Typed throws propagate to every helper on the path.
- A suite full of "no member Y" is one missing production half.
- A new environment object breaks every preview that doesn't inject it. Inject scratch UserDefaults, never .standard.
- @testable import proves target membership.
- Verification tips: pmset -g assertions shows the held activity by its reason string; log stream --predicate 'category == "uci"' shows the setoption send order; `category == "eco"` shows the table's row count at load; `category == "players"` shows M5's retag / merge / delete lines; stockfish resident memory should track configured Hash.

## Assumed-never (do not design for these)

Chess960; two same-colour kings; mid-game board flips; occupied-only boards; Bluetooth boards; live engine eval during play; DGT clock support / move timestamps; takebacks of committed legal moves.

Player rename / merge / delete has left this list *and* the roadmap — it is built (D37′, D38′, D39′). A document-based architecture stays not-applicable rather than assumed-never.

## Waiver register

A waiver is a decision, not an omission. Views are out of scope by design and are not listed individually. A view with no preview does need its own entry:

| View | Reason no preview | Witness |
|---|---|---|
| BoardDestination | needs session, connection, log, queue registry and a container; a canvas would be a second app | live-play manual checks + the load-error UITest |
| DGTConnectionView (dialog body) | DGTConnection.status is private(set); only DeviceRow and the load-error arm are canvas-reachable | connect-flow manual checks |
| Inspector+Toolbar, DGTConnectionToolbarContent | toolbar content with no standalone visual | the destinations that apply them |
| AnalysisQueueStatusView | queue is private(set) on the controller by design | batch manual checklist |

| Type | Reason | Witness |
|---|---|---|
| TabState | plain state holder | BoardDestination + UITests |
| Serial transport (DGTSerialPort, DGTSerialDevice, DGTDeviceDiscovery) | hardware I/O; decisions extracted pure into DGTAutoConnectPolicy | manual hardware checks |
| DGTConnection (port/timer half) | status machine suited; serial half is transport | manual hardware checks |
| GameAnalysisDriver, AnalysisQueueController | engine + SwiftData transport; branching extracted pure into AnalysisQueue | AnalysisQueueTests, AnalysisQueueControllerTests, the analyze UITest |
| BoardStyle, CollectionViewMode, SquareHighlight, TagColor | presentation value types, exhaustive switches | compiler exhaustiveness; view-mode UITests |
| StorageKeys | constants namespace | compile-checked usage |
| DGTSessionLog.exportViaSavePanel(), DGTSessionRecording.exportViaSavePanel() | AppKit modal panels | export flow, run in anger 18 July |
| PGNExporter | AppKit panels + file writes; every byte from the pure serializer | PGNSerializerTests + the export/re-import manual check |
| LibraryFilter | model-bearing composition; logic delegates to TagRule.evaluate | tag-filter / chip UITests |
| Illegal-move audio transport | thin system-alert playback; the decision is the enterRecovery edge | onDesync spy test + audibility manual check |
| SleepInhibitor — inhibition half only | process-activity token over a bare predicate | manual checks + pmset -g assertions |

**M5's two sheets are not on this table** — both ship previews (three and two), and the store door they drive is suited. What is genuinely unwitnessed by XCUITest is the *flow*: the Players inspector's menu and both sheets are reachable in a boardless UI run, so a UITest is possible and simply isn't written; it is on the manual checklist below and is the honest gap.

Closed as covered, not waived: DGTProtocol wire bytes; menu commands; the AnalysisQueue extraction; engine integration; parser rejections and tag helpers; the session's ghost/correction arms; the recorder ring; player resolution/backfill/edit; GameRecord chronology and projection; PlayerStats; Glicko1; TagRule / SmartTag (incl. the M1 quantifier pin, the D30′ semantics pins, and M4's six); the onDesync edge; the pairing fold; the movetext validator + store door (incl. the M2 splice refusals ×4 and M4's re-derive pin); the mate classifier plus its displayName tripwire; DGTBoardDiff's shape contract; GameHeadline; RosterSummary; PlayerName; the sleep preference; LibraryGamePreviewState; Game; drafts; OpenGamesRegistry; Evaluation; EngineConfiguration; UCIProtocol; framer/decoder/field bijection; reconstructor per-move-class; recovery guidance; auto-connect policy; connection status machine; castling rights-without-rook ×3; FEN hardening rejections; PGNSerializer reference-byte round trip; the drain-race controller suite; the live session's board-identity stamp; the archive door's board threading + hash-exclusion dedupe; the M3 bar reading; M4's four suites; **and M5's `PGNStoreRetagTests` (17: the tag rewrite and its hash cost, the unrelated-games scope, the self-play both-seats pass, the placeholder refusal ×3, both collision sources, the fold-equivalent non-collision, the refusal payload, merge's relink-and-delete, merge surviving applyEdit, merge-into-self, a colliding merge, the linked-delete refusal, the orphan delete, target creation through the resolver, and the renamed-export round trip).**

`ECOTable` is deliberately not on the waiver table: `ECOTableTests` (which shares `ECOClassifierTests`' file) drives it end to end against the real shipped asset. What is unexercised is its three failure arms — resource missing, file unreadable, row malformed — each of which logs and degrades rather than throwing.

Test-only by decision, not gaps: FEN.legalMoves(); CastlingRights' no-arg init; Square.dgtField; DGTBoardDiff.changedSquares; Evaluation's eval-tag emitting half; DGTSessionLog.clear().

## Known open items — unscheduled

Everything scheduled lives in ROADMAP.md. This list is only what is known, real, and deliberately not scheduled.

- **`GameRecord.endedInMate` spells "did this end in mate" as `hasSuffix("#")` while D18′ and `GameClassification` spell it `contains("#")`** — so `Qd2#!` reads as mate to one and not the other. Left alone deliberately: changing it moves every saved Checkmate tag's matching, a D30′-shaped decision rather than a rider. One line, once decided.
- **`DGTSerialPort.isOpen` is the app target's one symbol with no consumer.** (New, audit.) Either it earns one or it joins the test-only-by-decision list — a decision, not a deletion.
- **The Players editing flow has no UITest** despite being boardless and therefore reachable. Manual checks cover it; see the register note above.
- The two galleries answer empty-selection opposite ways, each documented as correct. Parity says pick one and record it.
- RankingsInspectorView shows Wins twice (own row + first component of Record).
- Gallery stat grids and columns detail paddings still diverge.
- RosterSummary's @MainActor live-projection init invites its own removal — delete the attribute and build. Worth re-running on any toolchain move.
- FEN / GameState collapse. A rename-scale mechanical change.
- SquareView.pieceID is threaded and unread — kept deliberately as M6's currency.
- BoardView.selectedSquare — built capability for a surface that has never been decided.
- Import batches are uncancellable — either implement cancellation or relabel.
- Known costs, deferred until measured (M7 measures; none scale-critical at personal size): parseSAN generates all legal moves per ply; Glicko1.histories builds every player's full sample array to answer one player's question; backfillPlayerLinks is fetch-all-and-scan × three onAppears (**backfillClassifications left this list — it carries a predicate now**); the ECO table's ~3,800-row parse, warmed off-actor but never measured; `ECOClassifier.opening(for:)`'s quadratic prefix re-join, bounded at 36 plies; **`retag`'s per-game re-resolve and rehash, which is O(linked games) with an MD5 each and runs inside a modal save**; UCIProtocol.parse allocates ~3 arrays per info line; Position's [Piece] storage heap-allocates per applying; the New Game sheet folds games.map(\.gameRecord) per seat edit; Players/Rankings destinations fold once per body.
- Log-format leftovers from 20 July, still unverified against a live session.
- File-menu Export — horizon; unblocked on appetite.
- StockfishEngine.swift lives in PGN/ — filing quirk. Same for PairingRoundTests (in Chess/), MovetextEditTests (in Players/), PieceTrackerTests (in DGT/).
- Export filename numbering is unconfirmed against DGT's own convention.
- swift-format — decided, .swift-format committed, never run. Legal now; scheduled inside M7.

## Manual checks

Need the board: launch auto-connect on/off; remembered-board-absent is a silent no-op; mid-game cable pull reconnects silently; discard mid-outage stands the loop down; recording start → cable pull → stop-and-export produces a coherent file; illegal move audible with the toggle on, silent off; no idle-sleep across a long think while the display dims; Energy toggle off means the Mac does idle-sleep mid-game; a recording survives an idle window; one desync worked through from the sidebar checklist; New Game with two known players prefills Round correctly; a game played and archived this build exports a `[Board "DGT …"]` matching the connected board's serial, and the same game resumed from a draft after a relaunch still carries it; stockfish resident memory tracks the configured Hash.

Boardless: batch analysis (queue 3+, drain count, skip mid-pass, delete waiting + running, Stop All exits the process, forced failure persists a warning until Dismiss); movetext edit accept/reject round trip (evals gone on accept, opening re-derived on accept, Save disabled with first-ply message on reject, and a pasted two-game splice shows the splice message); export one game out and back in clean; multi-selection into a folder, numbered; open a Library game and confirm it loads; stepping through an analyzed game moves the bar with the graph, the toolbar flip button flips it, an unanalyzed game shows no bar; single-game delete asks from toolbar, ⌫, and row menu; ⎋ during import keeps the sheet up; Edit Info on a loaded game round-trips through applyEdit; the sidebar Tags header's + button opens the editor.

M4's own (boardless): first Library appearance after a fresh launch is not perceptibly stalled; the Library's ECO column populates for existing games after one Library visit, and `log stream --predicate 'category == "eco"'` reports the table's row count once and the backfill's count once; the inspector's Opening section shows three rows for a variation, two for a bare family, and an em dash for a moveless game; a smart tag on `opening contains` filters the Library; a hand-built `mate pattern is smothered` tag finds a smothered mate and not an ordinary one. And the one only a pre-existing install can run: after this build, every smart tag saved before M4 still exists with its rules intact.

**M5's own (boardless), and this is the milestone's real witness gap** — the flow is UITestable and isn't tested yet:

- Rename a player with several games: the sheet opens seeded with **tag form** (comma order), the "Shown as" line updates as you type, and the summary names the right game count. After Save, the Library rows and the Players list both show the new name, and the ECO/roster columns are otherwise untouched.
- Export one of those games and re-import it: refused as a duplicate. Export a game *before* renaming and re-import after: imports as a new row — that is D37′'s accepted price, and seeing it once is worth more than the doc paragraph.
- Merge two spellings of one opponent: the sheet's sentence names both, the loser disappears from Players, its games now list under the survivor, and the survivor's game count is the sum. Then edit any merged game's Event through Edit Info and confirm the loser does **not** come back — that is D38′'s whole reason, and the only check that exercises it against the real store.
- Force D39′: import the same game twice under two spellings of Black, then merge them. The alert names both games and says nothing was changed; confirm in the Library that nothing did.
- Delete: the menu item is disabled for a player with games. Delete that player's only game, revisit Players, and confirm the item is now enabled and the row goes.
- `log stream --predicate 'category == "players"'` shows one retag line per operation with the game count, and the refusal line on a blocked merge.

Only if the toolchain moves (D27′): Liquid Glass screenshot pass over the board chrome and all four view modes × three destinations; the full UITest suite; pmset -g assertions across a live game if the observation rewrite is ever taken.

## Reference material worth pinning as fixtures

The 20 July field session's two DESYNC positions — pinned as DGTReconstructorTests' two field-desync fixtures, with Swift Testing PNG attachments so a failure hands you rendered boards rather than 64 sorted squares. The three DGT reference exports are pinned as PGNSerializerTests' bundled resources, committed, and now filed under `DGTStudioProTests/PGN/PGNs/`. M4's five lichess ECO volumes are the first data asset the *app* ships rather than the test target, filed under `DGTStudioPro/Chess/ECOs/`; the same rule applies to them — fetched from source, never transcribed, and not landed until tracked.
