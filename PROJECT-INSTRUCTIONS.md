# DGT Studio Pro — Project Instructions

Revision 2 August 2026 (second) — **M9 delivered whole**: Players and Rankings merged into one destination, by Bera's request, as **D48′** — the ladder becomes Players' default sort with a persisted name toggle, rank and rating render in every mode, one profile grid states each fact once, and the Rankings folder's six files retire. Three open items close with them (the Wins-twice row, both P-vs-R parity residues). Base: the first 2 August revision (M6/D47′) plus this pass. Written by editing the file at its anchors.

Earlier the same day — **M6 delivered whole** (D47′, three new source files, ⌘U reported green), the roadmap's schedulable half having emptied until M9 arrived by request: only M7's two gated items remain (Instruments-with-board; the ~September GM re-read). That pass also recorded and tracked the day's two audit documents and their applied fixes. Everything the earlier revisions recorded stands except where corrected below.

The pass opened on a tree carrying the earlier audit pass's own uncommitted work (its two flagged Players-file edits and both untracked audit documents) plus one deliberate edit of Bera's; every piece found its owner and its commit *before* M6 began, so M6 itself started clean — `git status` first, as always, and for once the findings were all explained rather than forgotten.

M6's through-line, recorded up front because it is the day's lesson: **the milestone's goal sentence and its own constraint line disagreed, and nobody had noticed for four days.** "Pieces glide on the mirror" requires an identity at the exact render where the mirror may not have one; the constraint "never speculation" is the reason it may not. The resolution is D47′'s whole content — glide what is proven, fade what is honest — and the near-miss is the fifth-species shape again: a quantified goal ("all four shapes animate on the mirror") whose set nobody had sized against the invariants that bound it.

Next free number: **D49′**.

## What the app is

A macOS SwiftUI daily-driver for a DGT USB chessboard: play over the board while the app records SAN live, finished games archive automatically into a SwiftData-backed PGN Library, and everything is reviewable and analyzable there (bundled Stockfish). One unified WindowGroup parameterised by PersistentIdentifier gives native window-tabs.

Three destinations since D48′: Board, Library, Players — Rankings merged into Players, whose default sort *is* the D11′ ladder (a persisted toggle switches to name order, and rank/rating render in every mode either way). The two collection destinations share the same four CollectionViewModes (icons / list / columns / gallery, one @AppStorage key each). The sidebar carries user-editable, rule-based smart tags (Apple Music smart-playlist shape) that filter the Library, and pins the session panel — the single surface for connection and session status. The stage above the board stays clear.

This app is for one person, one Mac, one board. No release, no App Store, no other users. That is a standing input to every trade-off below: the App Store submission floor is irrelevant, personal-scale libraries are the performance envelope, and "would confuse a user" arguments carry no weight — "would annoy Bera in six months" is the test.

## Where things stand

Tree at delivery: **`889d070`** (M9), ninth commit of the day on `c540d4f` — the audit recording, the review fixes, E1, PlayerCardView, M6 and its two record commits, then the merge. Checked with `git ls-files` and `git status`, not assumed. **214 sources (131 app, 82 unit-test, 1 UITest)** — up to 220 with M6's three, then down six with Rankings' retirement.

**The build is Swift language mode 6 as of D43′.** Two warnings remain in the whole project, both on `Binding(present:)`, both waived in writing at the declaration with a sunset condition. M8 added none, and that is worth one line rather than none: six new files including a new `@Observable @MainActor` class injected into a `WindowGroup`, a new scene, and two new pure value types, all under complete concurrency, all silent. The mode-6 flip is now load-bearing rather than ceremonial — it is checking new code, not just certifying old code.

`.DS_Store` had been **tracked** since before the roadmap existed, so it was permanently the one dirty entry in `git status` — which matters more than a hygiene nit, because `git status` is now the first command of every sweep by standing agreement, and a check whose output always contains noise is a check being read past. Its `.gitignore` line also revealed the file had no trailing newline, so `xcuserdata/` was silently one append away from becoming `xcuserdata/.DS_Store` and ignoring nothing — which is exactly what happened on the first attempt and is recorded here rather than quietly fixed. No TODO / FIXME / HACK markers, no note-to-self arrows, no commented-out code anywhere in production sources; no DispatchQueue, no Combine, no NotificationCenter, no Thread.sleep, no `@unchecked Sendable`, no `nonisolated(unsafe)` anywhere in the app target.

Built and in use — the daily loop end to end (Library import/dedupe/four modes/analysis → mirror → reconstruction → live surface → crash-safe drafts → archive-first with confirmation sheet → recovery guidance), connection QoL (auto-connect policy, silent launch connect, mid-game reconnect with once-per-failure logging), the Diagnostics and Game menus, batch analysis (pure queue + per-tab controller + toolbar popover), Players / Rankings / SmartTags on pure folds, movetext editing by full replay (splice-refusing), PGN export pinned to the DGT reference shape, the D26′ inspector chrome with an Edit Info surface for both live and loaded games, idle-sleep inhibition behind the Energy preference, board coordinates, the illegal-move sound, live archives carrying the `Board` tag (D28′), the New Game seat picker inserting tag form (D29′), the vertical evaluation bar on the review board's leading edge (D33′), every archived game knowing its opening and mate motif engine-free and filterable as smart-tag rules (D34′–D36′). **New with M5:** players can be renamed and merged through one store door that keeps identity following the tags — and, since the epilogue, orphaned registry rows can be swept from the Players toolbar (D40′), which is the only affordance that can reach them. **New with M8:** every inspector section folds shut and remembers it across launches (D45′), and the evaluation graph opens full-size in its own window with the ply under the pointer named beside it (D46′). **New with M6 (2 Aug):** pieces animate — glides under proven identity on both boards, honest fades everywhere else, with the mirror's truth untouched (D47′).

Test target: expected green — never claimed; ⌘U runs locally and Bera reports. M1 closed the vacuity class structurally; every milestone since has added its own pins (M5's inventory is in the waiver register's "closed as covered" list).

## Decisions

Locked product decisions #1–#8 and their interpretation flags were recorded in the retired roadmap document §2 and remain in force. The two that are load-bearing daily are restated inline where used, so this document stands alone: #1 — the physical board is truth and the live game is append-only (no takebacks; Discard lives in the inspector); #3 — * is never a finished result and never archives.

Old milestone and finding tags (M7.2, M-prs.1, F1–F9…) survive in code comments and below as provenance only — they identify where a decision came from; they schedule nothing.

D-numbers are sequential and never reused. Next free number: **D47′**.

### D9′ — Player is a machine-managed @Model

Player { name, normalizedName, tagName } with optional PGN.whitePlayer / blackPlayer relationships (inverses whiteGames / blackGames, .nullify). One creation door: PGNStore.resolvePlayer(named:).

Identity is the display form lowercased with whitespace collapsed — the content hash's folding philosophy. Diacritics deliberately preserved ("Bücher" ≠ "Bucher"); first-seen casing wins; "?" and empty resolve to no player, never to a player named "?". Since M2 the row also remembers its first-seen **tag form** (D29′).

**The "no user CRUD" clause is discharged.** This decision recorded rename/merge/delete as "the future feature which justifies having a model at all instead of derived grouping". M5 built it — D37′, D38′ — and the justification held up in a way worth recording: the feature turned out to need a *stored* row not for the name it carries but for the **relationship**, because scoping a rename by `whiteGames`/`blackGames` is what keeps it from being a string sweep over the whole Library.

What survives unchanged: `resolvePlayer` is still the single creation door, and the retag door creates its target *through* it rather than constructing a row (pinned by `retagCreatesTargetThroughTheResolver`). Orphaned players still linger by decision — no GC.

**"A manual door for them, not a collector" was the right phrase and the wrong surface**, which the epilogue found and D40′ fixed. M5 attached it to the profile menu, where an orphan can never appear: this destination's rows come from a fold over `GameRecord`s, whose sides are the *resolved links*, so a linkless row is in no view mode and selectable through nothing. The door is now a toolbar sweep over the registry, still strictly user-invoked, and its confirmation dialog is the only place in the app an orphan's name is ever rendered.

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
- InspectorSectionHeader — String (not LocalizedStringKey, the title is data), textCase(nil), lineLimit(1), a @ViewBuilder actions slot with an EmptyView convenience. M4's `OpeningSection` is its first fixed-label consumer, which is fine — the type takes a String because titles are *usually* data, not because they must be. Since D45′ it also carries the optional section identity and draws the chevron.
- InspectorEditButtonView — the shared header pencil: one LocalizedStringKey label feeding both .help and .accessibilityLabel, identifier required with no default. ~~Its trailing inset is now stated here and nowhere else.~~ **Corrected by M8 — see below.** It keeps the *hit target*, which was the half that genuinely belonged to it, and `.font(.body)` is now the only thing sizing it.

The point is the set: five inspectors were each free to disagree about what "empty" looks like and how a section header truncates; now a divergence is a compile-visible choice. **The audit proved the mechanism works only as far as the components' own discipline goes** — a padding added inside the shared type still diverged, because one host had a local one already. The failure was invisible unless two inspectors were open side by side, which is the argument for the sweep rather than against the component.

**M8 found the mechanism's reach was smaller than this entry claimed, in two ways, and closed both.**

*The set was never complete.* Fifteen inspector section headers exist and **eight** went through `InspectorSectionHeader`; the other seven were raw `Text`, and one — Board's Moves — was a hand-rolled `HStack` reimplementing the shared type and disagreeing with it on three counts (`Spacer(minLength: 0)` against 8, no `textCase(nil)`, no `lineLimit(1)`). D26′ said "five inspectors were each free to disagree… now a divergence is a compile-visible choice", which was true of the headers that *used* the type and silent about the ones that didn't. All fifteen do now, including the two previews that simulate an inspector.

*The inset was one number doing two jobs.* `InspectorEditButtonView` carried `.padding(.trailing, 10)` under a doc reading "stated here and nowhere else" — true of the number, false of the job. It insetted the header's trailing control **and** widened the pencil's hit target, and those coincide only while the pencil is *last*. M5's Players header put a menu after it, at which point the edge inset silently transferred to a control carrying none: **three distances from one edge** — 10 pt at the four lone pencils, 8 pt at the Library's PGN glyph pair which had quietly added its own, and 0 pt at the actions menu, flush. The post-M4 audit had fixed the *stacking* version of this and left the number where it was, so this is the same defect surviving its own correction.

`InspectorSectionHeader.actionsInset` owns it now, applied to the whole row, which is what makes a host unable to get it wrong regardless of what or how much it passes into the slot. Computed rather than stored — **generic types cannot have stored static properties**, which `SevenTagRosterSection` records at `noGamePlaceholder` and which got re-learned from the compiler anyway.

**The family gained two members and stayed deliberately un-generalised.** `EvaluationMagnifierButton` (D46′) is the third open-coded glyph button beside the Library's Copy-PGN, and three is the point at which it is worth stating that the family is deliberate rather than neglected: extracting a shared `IconButton` would collapse exactly the distinction this decision buys, which is that `InspectorEditButtonView` hardcodes the pencil so five edit affordances cannot drift. What the open-coded siblings do share is the pair that must not drift — `.font(.body)`, and one label feeding both `.help` and `.accessibilityLabel`.

**M5's addition to the family.** The Players profile header carries the pencil *plus* an ellipsis menu for merge and delete. Widening the pencil to also mean those would turn a named affordance into a generic icon button and lose exactly the guarantee this decision buys — the same argument `LibraryInspectorView` already makes for its Copy-PGN button not being one. The header's actions slot now has a two-control precedent in two places, so a third is a layout question already answered.

(Related default: every section in the app now defaults open, including the Library inspector's PGN section — Bera's 30 July reversal of the M1 collapsed default.)

### D27′ — the build target is the shipping toolchain; beta API is a forward note

The project builds against Swift 6.3 and Xcode 26.x, both shipping. Swift 6.4, SwiftUI and SwiftData for the 2027 releases, and Xcode 27 are beta (Xcode 27 at beta 4) and are not adopted in delivered code.

The rule: a platform feature is usable in a delivery when it ships. Until then it is recorded in Toolchain forward notes against the decision or invariant it would change, and nothing schedules it.

Audit note (30 July): upheld, and re-verified twice — after M4 and again in the post-M4 conformance sweep, which checked the full announced surface (withContinuousObservation, weak let, @diagnose, ToolbarOverflowMenu, sectionBy, visibilityPriority, swipeActionsContainer, reorderContainer, appearsActive, mapKeyedValues, MutableRef, withTaskCancellationShield, anyAppleOS, ContentBuilder, Writable/ReadableDocument, @Attribute(.codable), ModelResultsObserver, HistoryObserver). All empty. M4's one new language surface was a manual `init(from:)`, as old as Codable; M5 added none.

~~Recorded fact (29 July), decision deferred: the project builds in Swift language mode 5.~~ **Superseded 31 July by D43′ — SWIFT_VERSION = 6.0 on all three targets.** The rest of that paragraph stands and is the current configuration: SWIFT_APPROACHABLE_CONCURRENCY = YES, upcoming-feature MemberImportVisibility, and SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated on the app target. Deployment target is macOS 26.2; sandbox on; the serial entitlement (com.apple.security.device.serial) is the operative hardware grant — ENABLE_RESOURCE_ACCESS_USB = NO is correct and should not be "fixed".

The sentence that was retired deserves a note, because it was *true and misleading at once*: "the codebase is written as if mode 6, but the compiler is not yet enforcing mode-6 semantics." Both halves were accurate. What neither half revealed is that the gap between them was **one static property** — which meant the claim could have been checked at any point in the preceding month by a single command, and instead sat in this document as a standing description of an unmeasured distance. D43′ records what the distance actually was.

Note also what this does **not** change: mode 6 is a *language* mode, and D27′'s subject is the *toolchain*. Swift 6.3 and Xcode 26.x remain the build target, every 6.4 / 2027 surface remains beta and unadopted, and the forward notes below are untouched by this. Reaching language mode 6 on a shipping compiler is the opposite of adopting beta API; it is the shipping compiler finally being asked to check what the code already claimed.

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

**Delete is orphan-only, and this corrects the roadmap.** The roadmap proposed "delete-player = merge-into-nobody (nullify + delete)". That does not work: `.nullify` leaves the games' seat tags intact, and the Library's next `backfillPlayerLinks()` resolves those same tags and recreates the row. A delete the app undoes within one navigation is worse than no delete.

*Orphan-only stands; the surface it was given does not — see D40′.* M5 spelled it as a refusing singular door (`deleteOrphanedPlayer`, returning `false`) behind a per-player menu item disabled for the same condition. The two guards agreeing was the point, and they did agree — on a value that could never be the other one. Both are gone: the rule is `PGNStore.isOrphaned`, one static predicate; the door is a sweep.

Surface: the profile header's D26′ pencil renames; an ellipsis menu beside it holds Merge Into…, and since D40′ that is all it holds. `MergePlayerSheet` states the asymmetry with both names in one sentence, because merges are not symmetric and a misread direction silently rewrites the wrong forty games. It stays a separate sheet from the rename one — it is model-bearing by necessity, and widening the value-typed string editor to sometimes query would cost the property that makes it previewable three ways without a container.

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

### D40′ — orphan deletion is a destination-scoped sweep, because orphans have no row

**The finding.** M5's per-player Delete could never be enabled, and the chain is airtight: `GameRecord.Side` is built from the resolved `whitePlayer` / `blackPlayer` links, so `PlayerStats.index(of:)` only ever emits players holding at least one game; all four view modes render that index, so `selectedKey` can only be a key the index emitted; and `canDelete` read `recentGames.isEmpty`, filtered on the same links. "Appears in the list" and "is deletable" were exact complements — no player satisfied both. The manual-check step M5 wrote for it ("delete that player's only game, revisit Players, confirm the item is now enabled") could not be performed: deleting the last game removes the player from the list rather than enabling anything.

**The decision.** Delete moves off selection and onto the Players toolbar, as a Maintenance menu holding **Delete Unused Players…**, disabled when there are none. Orphans are real — deleting a game nullifies its links, and a player whose last game goes keeps its row (D9′, still no GC) — they are simply unrenderable through the index. The alert lists them by name, capped at five, because it is the only place in the app an orphan is ever shown and a bare count would ask Bera to approve deleting things he has never seen.

**Where it lives, and why not the menu bar.** A `Commands` scene has neither a `modelContext` nor a presentation surface — `DiagnosticsCommands` records the second point in its own doc, and `SmartTagCommands` works around both by publishing a binding from the view. The destination already owns the context, a query and a dialog presenter, so the toolbar costs no focused-value plumbing. It sits after the view-mode picker and before the `ToolbarSpacer`: it acts on content, so it belongs on the content side of the break.

**One rule, one source.** `PGNStore.isOrphaned(_:)` is now the single spelling of "nothing points at this row". Three sites asked it independently before this: the old delete guard, `merge`'s post-retag assertion — which predated the epilogue and was the twin-read-site pattern in behavioural clothes — and the inspector's `canDelete`. Two now call the predicate; the third went with the item it guarded.

**Store owns the rule, the query owns the rows.** `PlayersDestination` filters its own `@Query(sort: \Player.name)` through `isOrphaned` rather than calling a fetching door. The fetching door was written first and deleted: the sweep removes `Player` rows and nothing else, so a body driven off the `PGN` query alone would have left the toolbar naming rows it had just removed. Two queries in one destination is the cost, and it buys reactivity on the only two things that can change the answer.

**The write door takes the snapshot.** `deleteOrphanedPlayers(_:)` receives the rows the dialog named rather than re-querying, so it deletes exactly what was confirmed — and re-checks each one, the merge survivor's `isDeleted` lesson: a list held across a confirmation is stale by construction, and acting on it here would nullify live links. A skip logs. One transaction for the sweep, because N saves for N rows leaves a half-swept registry behind any mid-loop failure.

**Registry consequence, recorded rather than done quietly:** `players.inspector.deleteItem` is **removed** from `AccessibilityID`. A removal is as breaking as a rename, and it gets no successor in that group — the replacement is destination-scoped, under two new identifiers on the toolbar.

Rejected: putting orphans in the Players list (it makes per-player delete honest, but `PlayerStats.firstPlayed` / `lastPlayed` are non-optional by documented invariant — "a player only exists through at least one record" — so a zero-game row forces either optional dates rippling into Rankings and both detail grids, or a parallel row type, and Rankings folds the same index so the two destinations would stop sharing their input); dropping the item entirely and leaving the store door test-only (honest, smallest, and M5 would have shipped two of three operations with orphans permanently unreachable); recording the defect and leaving the dead item on screen.

### D41′ — `Player.createdAt` is deleted, because the better answer was already on screen

A stored column on a `@Model`, assigned in `init`, **read by nothing in 211 sources**. `SmartTag` carries the same field legitimately — `ContentView` sorts the sidebar by it — and `Player` was that shape copied without its consumer.

**Why deleting rather than surfacing, which is the part worth recording.** The field looks like it answers "since when have I played this person?", and that is a question the Players inspector could reasonably show. It doesn't answer it. `createdAt` is when the *row* was minted, which is when the game was **imported**; for an archive back-filled from old PGNs it names a day in 2026 for a rivalry from 2019. `PlayerStats.firstPlayed` already answers the real question by folding game dates, and it is on screen. Surfacing `createdAt` beside it would have put two dates in one profile that disagree, one of them meaningless — a new confusion rather than a closed item.

So this is not the `DGTSerialPort.isOpen` disposition. That symbol is a plausible future consumer away from earning its place; this one was **structurally redundant with a better sibling**, which is what makes deletion the honest call rather than the tidy one. The standing open item is restored to accuracy by the deletion: `isOpen` is once again the app target's *one* symbol with no consumer.

Migration: the app builds its `ModelContainer` with no `VersionedSchema` or `SchemaMigrationPlan`, so SwiftData infers the attribute removal as a lightweight migration. One Mac, one local store — the assumed-never scale is doing real work here, and is why this needed no plan.

The field's absence is commented where it lived, per the deletion-comment rule, and the comment carries the trap: re-adding it needs a reader first.

Rejected: keeping it on the open-items list as a second `isOpen` (the shape the sweep first proposed — cheap, and it would have left a schema column alive on the strength of a question it answers wrongly); giving it a "Known since …" row in the profile.

### D42′ — swift-format is declined; the aligned house style is the reason

**The premise had to be corrected first.** This document's open-items list said "swift-format — decided, `.swift-format` committed, never run", and ROADMAP M7 scheduled the run. The file does not exist: not tracked, not in any commit on any branch, never in history, and no `swift-format-ignore` mark anywhere in 211 sources. So there was no pending *run* — there was an undecided *decision*, sitting on the list wearing the costume of scheduled work. It is decided here.

**What the codebase actually contains.** 314 hand-aligned lines of code across 37 files — 215 in the app target, 99 in the suites — in five recognisable classes: static-let tables (71), switch case bodies (67), aligned assignments (63), call-site labels (29), enum raw-value tables (29). Not incidental, and not confined to one author's mood on one afternoon: it is the same convention in `AccessibilityID`'s registry, `DGTProtocol`'s wire-byte columns, `Piece`'s twelve-constant matrix, `RosterSummary`'s call labels, and the Square/Piece/protocol fixtures in the suites.

**Why the tool cannot keep it.** swift-format has no alignment support and no setting that could acquire one — column padding is whitespace between tokens, which is the pretty-printer's business, not a maskable rule. The one preservation mechanism is a bare `// swift-format-ignore` (the form without `: RuleName`, which is what also suppresses pretty-printing), and per `RuleMask` it attaches to exactly three node kinds: the file, a code-block item, a member-block item. A run of aligned *members* therefore cannot be marked as a run — the mark goes on the enclosing declaration and takes its methods with it. Marking `enum PieceType` to protect six aligned cases also stops formatting `fenByte`, `notation` and `fenCharacter(for:)`. Coverage becomes swiss cheese while the config still has to be carried.

**And the half of the item with lasting value dies with it.** `swift format lint --strict` as a habit was the point; lint reports where the formatter *would* change things, so it would report those 314 lines forever. A linter that is permanently wrong about 2% of the repo is one you learn to scroll past, which is worse than no linter — the `.disabled(…)` lesson in a different costume: a check that always fires teaches you to stop reading checks.

**The standing input does the rest of the work.** A formatter's primary value is mechanical agreement between contributors who would otherwise argue. One person, one Mac, no other users: that value is zero here, and what remains is a trade of a deliberate readable property against tool coverage of a codebase nobody else reads.

**The counterargument, recorded because it is real and not merely balance.** Alignment is a maintenance tax: one `AccessibilityID` entry longer than its column re-pads eleven lines whose meaning did not change, which is mechanical churn riding a feature commit — the exact shape "mechanical changes travel alone" exists to prevent. That cost is accepted on two grounds. It is *localised* to tables already read as tables, and the project already hand-maintains these registries anyway: the registry is grep-audited at every sweep, so a re-padded column is inside work that was happening regardless. (This sentence said "the 144 identifiers" until the 1 Aug review — M8 had moved the count to 148 without touching it, D43′'s species in the document that defines it. Countless form now; the number lives in the grep, where it can't go stale: `grep -c 'static let\|static func' DGTStudioPro/App/AccessibilityID.swift`.)

Sunset condition, because this decision is contingent rather than principled: a second contributor, or a toolchain that learns to preserve alignment, reverses the reasoning rather than the taste. Re-read it then — not at the Xcode 27 GM re-read, which D27′ owns and which has nothing to say about this.

Rejected: adopting and letting the 314 lines flatten (one mechanical commit, full coverage afterwards, and it discards a property maintained deliberately in 37 files); adopting with ~37 ignore marks (preserves the tables, and buys a config plus a large diff in exchange for a formatter that no longer formats the code around them); leaving the item on the list as scheduled work (the status quo, and it is the false-premise entry this decision exists to correct).

### D43′ — the project builds in Swift language mode 6

`SWIFT_VERSION = 6.0` on all three targets, six configurations. The endpoint was chosen by the compiler, not in advance: the agreed option was *fix the sites, re-probe, land wherever it comes back clean*, and mode 6 came back clean.

**The measurement, which is most of the decision.** Three cold builds of all three targets (`build-for-testing` with the full test plan, against a scratch derived-data path so every source actually recompiles):

| Setting | Warnings | Errors |
|---|---|---|
| As configured (mode 5, strict concurrency at the default) | **0** | 0 |
| Mode 5 + `SWIFT_STRICT_CONCURRENCY=complete` | **230** (+165 notes) | 0 |
| `SWIFT_VERSION=6` | — | **1**, build stopped at 144 of 239 phases |

**The distribution is the finding, not the total.** The 230 sat in **three files**. 226 of them in `DGTStudioProUITests.swift` — one file, one cause, eight message shapes refracting the single fact that the suite was nonisolated while every `XCUIElement` member it touches is main-actor. Two in `UITestSeed.scratchDefaults`. Two in `Binding(present:)`. And **zero across all 79 unit-test sources** — the "@MainActor suites for @MainActor types, nonisolated for pure value types" agreement turns out to be compiler-verified, not merely written down. That negative result is what made the positive one credible: the app target had *four* warnings, so "written as if mode 6" was accurate to within one static property.

**Three changes closed it.**

- `@MainActor` on the UITest class — 226 gone in one attribute. Driving an app's UI is main-actor work; the annotation states what was already true.
- `@MainActor` on `UITestSeed.scratchDefaults` — the mode-6 error. Both readers are `.defaultAppStorage(…)` inside `App.body`, already main-actor, so it costs nothing at the call sites. **`nonisolated(unsafe)` was rejected**: one keyword, silences it equally, and would have been the first such opt-out in the app target — a standing invariant the sweep greps for, spent to avoid typing seven characters of isolation.
- `setUpWithError` / `tearDownWithError` → `setUp() async throws` / `tearDown() async throws`. Forced by a rule worth keeping: **a synchronous override cannot add isolation its superclass declaration lacks** — the superclass may call it from anywhere and there is nowhere to put the hop — while an *async* override can, because there is a suspension point to hop on.

**Two warnings remain, waived at the declaration.** `Binding(present:)` captures a non-`Sendable` `Binding<T?>` in `Binding.init(get:set:)`'s `@Sendable` closures. `T: Sendable` would fix it and lock out the `@Model` call sites, which are most of the seven; the alternatives are opt-outs this codebase has none of. The diagnostic stays a **warning** under mode 6 rather than becoming an error, which reads as the compiler treating it as framework-side friction rather than a defect here. The 2027 SDK's `.alert(item:)` / `.confirmationDialog(item:)` retire all seven call sites and the helper with them, so the waiver expires by deletion rather than by being lifted.

**What this is not.** Mode 6 is a *language* mode; D27′'s subject is the *toolchain*. Swift 6.3 and Xcode 26.x remain the build target and every 6.4 / 2027 surface remains beta and unadopted. Reaching mode 6 on a shipping compiler is the opposite of adopting beta API — it is the shipping compiler finally being asked to check what the code already claimed.

**Two shape notes the pass forced.**

- **A doc comment asserting a guarantee was introduced *during* an audit for that exact anti-pattern.** The first version of the UITest annotation's comment said the overrides inherit the class's isolation. The next build disproved it in three warnings. The comment now carries the real rule and why it forced the `async` spelling. Nobody is above the pattern; the defence is the build, not the care taken while writing.
- **`Binding(present:)`'s caller count has been wrong twice, in opposite directions.** Its doc said five (stale the moment M5 and D40′ each added a site); the forward note below said six (it caught M5's and missed D40′'s). It is seven. Both corrected, and the count now carries a note that it is the enumerated-caller-list anti-pattern, kept only because the forward note needs to know how much disappears.

Rejected: **fixing the sites but leaving the build settings alone** (burns warnings nobody would ever see again, and leaves the enforcement question exactly where it was); **`SWIFT_STRICT_CONCURRENCY=complete` in language mode 5 as the endpoint** (keeps the checking, avoids mode 6's other upcoming-feature semantics — a real hedge, and it was declined because the measurement had already shown mode 6 clean, so the hedge would have been protecting against a risk that had been priced); **recording the measurement and changing no code** (cheapest and fully honest, and it would have left 230 diagnostics latent behind a setting nobody has on, which is how the 295 became unfalsifiable in the first place).

### D44′ — `RosterSummary`'s live projection comes off the main actor

The attribute is deleted. `RosterSummary.init(_ roster: LiveGame.Roster, result:)` is nonisolated, and the open item M7 had been carrying since the roadmap was written is closed.

**The premise was false, and it was a claim about the language.** The doc comment read: "`@MainActor` because `Roster` is nested in a `@MainActor` class and inherits that isolation." A global actor isolates a type's **members**; it does not isolate types **nested** inside it. SE-0449 spells out this exact shape in its own motivation — a globally-isolated struct with a `Nested` type that is explicitly *not* isolated. `LiveGame.Roster` has been nonisolated since the day it was written, so the attribute bought nothing and cost the init the right to be called from anywhere.

**Why a green build never caught it, which is the transferable part.** Every other site that constructs a `LiveGame.Roster` — `LiveGameTests`, `LiveGameResumeTests`, `DGTLiveSessionTests`, `DGTLiveSessionArchiveTests`, `PGNStoreArchiveTests` — is `@MainActor` already, correctly and for `LiveGame`'s sake. So the codebase contained no context from which the claim *could* fail. D43′ recorded that a comment asserting a language rule is a hypothesis until something compiles it; D44′ is the sharper form: **compiling is not enough — something has to compile it from the side where it would break.** An unexercised claim and a true claim are indistinguishable from the build log.

**The pin is structural.** `theLiveProjectionIsReachableOffTheMainActor` lives in `RosterSummaryTests`, which is nonisolated, and builds a `Roster` there before projecting it. Restoring the attribute — or annotating `Roster` — is a **compile** error, not a red assertion, which is the correct severity: this is a fact about isolation, and isolation is checked at compile time or not at all. The suite's own doc now says its nonisolation is load-bearing rather than stylistic, so a future reader tidying annotations has been warned at the site.

**Mode 6 is what made this worth running rather than guessing (D43′).** Under mode 5 the deletion would have compiled about as quietly as the attribute did. The experiment was only ever going to mean something against a compiler that checks isolation for real, which is why the roadmap paired the two and why this one waited.

Deliberately **not** touched: `LiveGameDraft`'s doc, which says the file "stays free of `@MainActor` types so its coding tests run nonisolated." That sentence looks like the same claim and is not — the `@MainActor` type it stays free of is `LiveGame` itself, which genuinely is one, and the roster is flattened there for the JSON-contract reason stated beside it. Checked rather than assumed, and recorded so the next sweep does not re-open it.

Rejected: **keeping the attribute and fixing only the comment** (harmless at runtime, and it would have left a main-actor constraint standing on a reason known to be false — the same shape as a waiver with no expiry); **annotating `LiveGame.Roster` as `@MainActor` to make the original sentence true** (it type-checks, and it is backwards: `Roster` is `Sendable` value data that travels into the draft sidecar and out of it, so isolating it would be inventing a constraint to justify a comment); **closing the open item as "won't do"** (the experiment was one line and the answer was load-bearing for how much the mode-6 flip is trusted).

### D45′ — every inspector section collapses, on one persisted key

All fifteen sections fold shut from a chevron in their header and remember it across launches. `InspectorSectionCollapse` owns the state; `InspectorSection` is the identity; `CollapsibleSection` is the only door.

**An owning type, not `@AppStorage`, and D25′'s reason applies literally rather than by analogy.** The header draws the chevron and the host decides whether to render its body, so an `@AppStorage` design puts one question in two places. They would have agreed — the way D40′'s two orphan guards agreed perfectly on a value neither could ever produce. `SleepInhibitor` is the precedent followed down to the injectable defaults, and `StorageKeys` had already written that this was "the shape the other three should eventually take".

**The injection is load-bearing, not tidy.** This value reaches every inspector, and `.defaultAppStorage(_:)` redirects the *property wrapper* — it has nothing to say about a `UserDefaults` an object was handed at construction. So the App builds it with the same `UITestSeed.isActive ? scratch : .standard` expression the `WindowGroup` applies, because a seeded UI run reading the developer's own collapsed sections would fail on a section that is present, correct, and folded. That is M1's ambient-`UserDefaults` leak, which a hand-constructed `UserDefaults` does not inherit protection from.

**The stored set is the collapsed sections, not the expanded ones**, and that is what makes "sections default open" free: an absent key and an empty set are the same state, so the default is a property of the representation rather than a fourth `?? true` on `StorageKeys` with a twin-read-site warning attached. An unknown raw value is dropped on read and evicted by the next write, so retiring a section needs no migration — at the cost, recorded rather than discovered, that a section which ever comes back comes back expanded.

**Identity is what a section shows, not which inspector shows it.** Folding Opening on the Board folds it in the Library, because that gesture is about openings. Shared sections take one case across their hosts: `.roster` in all three inspectors, `.opening` in both, `.moves` live and in review.

**Titles cannot supply the identity, and this is the pair that proves it.** The live inspector's "Game" section holds Resign / Agree Draw / Discard, while the section actually *about* the game is the roster above, titled with the game's name. Two sections called Game, neither of them the game, and a title-derived key would have merged them. Players' and Rankings' profiles are separate cases for the converse reason: same kind of header, different content underneath — one folds games and win rate, the other rank and rating.

**`CollapsibleSection` exists to make one defect unrepresentable.** A collapsible section is two facts that must agree — which section the chevron toggles, and which one the body checks — and at fifteen hand-written call sites those are two arguments that can differ. `.moves` in the header and `.evaluation` in the guard compiles, renders, and fails only when a reader folds one section and watches another disappear. M5's agreement is *a guard in two places must be computed from one source*; D40′ sharpened the remedy to "one predicate, called twice"; this is the structural form: **one argument, used twice, by a type the host cannot route around.** It also keeps the environment read in two files instead of nine — a host holding the store is a host that can be tempted to write to it.

**The chevron leads the actions slot**, which is what the Library's bespoke disclosure had claimed to do and did not: its doc read "Leading of the copy button, which keeps the *action* glyph rightmost" while the `HStack` listed copy first and the chevron second, putting the app's one disclosure in the slot every other inspector reserves for a verb. The shared header implements the comment.

Two behaviour changes, both priced rather than discovered. PGN expansion **no longer resets per game** — the old flag was `@State` under `.id(pgn.id)` and the store is app-wide; the doc that justified the reset argued the alternative needed machinery the affordance didn't earn, and that machinery now exists for nine other sections. And **collapsing the Library's Evaluation section also hides Review and Analyze**, which live in its body; promoting them to the header to keep them reachable would put two more glyphs beside a chevron to guard against a state the reader chose and can undo with one click.

One section is deliberately not collapsible: the Library's `identitySection` has no header, because it has nothing to name — it is empty except while a rename is in progress. A chevron there would hide something already invisible.

Registry consequence: `library.inspector.pgn.disclosure` **removed** — breaking, the `players.inspector.deleteItem` precedent — with a successor, since the identifier moved from a constant naming one section to a function naming any of them.

Rejected: **`@AppStorage` in the header** (the twin read site D25′ names); **fifteen individual keys** (matches the view-mode keys most literally, and mints fifteen `StorageKeys` entries in a namespace M4 and M5 each added zero to); **`TabState`** (per-tab, which is wrong — folding a section is a preference, not a thing about the window it was made in); **per-inspector `@State` reset on selection** (the shipped behaviour nobody complained about, and it makes the gesture unrememberable by construction).

### D46′ — the evaluation graph opens in its own window, with a hover read-out

A magnifying glass in both Evaluation section headers opens the curve at window size, with the ply under the pointer named beside it.

**A window, not a popover or a sheet**, chosen for what the enlarged graph is *for*: reading the curve while stepping through the game beside it. A popover dismisses the moment you click the board and a sheet takes the window over — both are right for "glance bigger, dismiss fast", and both make the one use that needed more room impossible. The app already opens games this way, so the gesture is not new here.

**`EvaluationGraphRequest` exists to keep `openWindow(value:)` unambiguous, and this is the trap worth keeping.** That call routes by the value's **type**. The main `WindowGroup` is already declared `for: PersistentIdentifier.self` and three call sites depend on it, so a second group over the same type would make all three unspecified — and unspecified here means *opening a game from the Library opens a graph*. A one-field wrapper makes the routing a fact about the type system rather than about which scene was declared first. The alternative was passing `id:` at every call site and trusting the untagged calls elsewhere to keep resolving as before.

**Hover read-outs are the feature, not a garnish.** A 100 pt strip in a sidebar has no room to say which ply is which; at window size the curve is legible enough that "which move was that?" becomes the obvious next question. Bigger does not make it better — bigger makes a different question askable. `.onContinuousHover` because the question is *where* the pointer is, which `onHover`'s bare `Bool` cannot answer; the ended phase clears the read-out, because a stale ply left on screen after the pointer leaves is a read-out describing nothing.

**Two pure mappings, both with nonisolated suites, both extracted for a reason rather than on principle.**

`EvaluationGraphGeometry` exists because this milestone gave ply↔x a **second consumer pointing the other way**: the view places points, the window hit-tests them. Left open-coded those are one relationship stated twice in two files, agreeing only while both are edited together — D25′'s twin read site in its geometric form, and the eval bar's width already cost this project 2 pt of bleed for a month. The round trip is the property neither consumer can check alone, so the suite walks a whole 63-ply curve rather than sampling, where an off-by-one survives at the endpoints.

`EvaluationGraphReading`'s evaluation label is `EvaluationBarReading`'s **verbatim**, and the test asserts against that type rather than against a literal — a literal would keep passing while the two grammars diverged, which is exactly the disagreement being prevented and one only visible with the bar and the window open at once. Its `move` is a display form ("12. Nf3", "12… Nf6") and deliberately not the file form: `PGNSerializer` owns what a move number looks like on disk (D24′, byte-pinned), and this is the one surface in the app that must name a single black ply on its own, which the serializer's full-move lines never do.

On the Board the magnifier renders only over a game the Library knows about and otherwise **doesn't exist** rather than sitting greyed out — `onEditInfo`'s rule applied to the same condition, since a live game has no `PGN` to resolve until it archives. The window's own empty state folds two causes into one — no analysis, or the game is gone — because the remedy is identical and splitting them would explain a deletion the reader performed.

`InspectorEmptyState` gains its first non-inspector host, noted at the type rather than renamed: the contract it enforces is about *layout* — centred, filling, outside the `List` — which is as true of a window as of a sidebar.

Rejected: **a popover anchored to the header** (the roadmap's own lean, and it cannot be open while you scrub); **a sheet** (most room, and it takes the window over for something that is fundamentally a companion view); **a second `WindowGroup` over `PersistentIdentifier`** (no new type, and it silently breaks three existing `openWindow` calls); **teaching `EvaluationGraphView` to draw its own read-out** (fewer types, and it would put pointer state inside a view the inspectors render at 100 pt where no pointer question exists).

### D47′ — pieces animate under proven identity; the mirror never guesses

M6, whole. One piece layer above the square grid, one pure resolver deciding what every piece animates *as*, and one rule doing all the work: **identity is proven or absent, never guessed** — and the animation contract falls out of identity alone, because a persisting key glides while a churned key can only fade.

**The goal lost to the constraint, and recording why is most of the decision.** The roadmap's goal line said "pieces glide on the mirror"; its constraint line said the mirror renders the *physical* board and animation is "never speculation". Those cannot both hold for the ordinary move: a lift-then-place renders as two truthful states with the piece honestly in a hand between them — there is no jump to glide, and manufacturing one means either drawing a piece the board doesn't have (the mirror lying) or guessing that the pawn appearing on e4 is the pawn that left e2 (speculation, which is `DGTReconstructor`'s job precisely because it is not trivial). The constraint wins. What the mirror does instead: **proven moves glide, everything else fades, and a fade is the *correct* rendering of a piece leaving for a hand** — not a degraded one.

**Identity has three sources, in order.** *Parity*: a square whose physical piece equals the game's last committed position vouches for the tracker's identity there — per square, not per board, so one lifted piece doesn't strip the other thirty-one. *Early reconstruction*: for what parity can't explain, the resolver runs the **same** `DGTReconstructor.reconstruct` the session will settle with — full-position verification included — and keys a recognized move's landing squares with the *origin's* identity. That is proof, not speculation: the reconstructor answers only when exactly one legal move explains the whole board, and the session's own commit re-derives the same answer 300 ms later. A slid pawn, a snappy capture, a fast castle — anything whose origin and destination change inside one render — glides under its real `PieceID` before the game has committed it. *Anonymous*: everything else keys `(square, piece)` — stable while the piece stands still, incapable of gliding, exactly the right capability for a piece nobody can name.

**The hand-off is invisible, and the design balances on it.** The identity early reconstruction hands out is the identity `PieceTracker.applyMove` will put on that square at commit — origin's ID onto destination — so the proven render and the post-commit parity render carry the *same key* and the eye sees one uninterrupted piece. Pinned by `theProvenIdentityIsStableAcrossTheCommit`.

**The occupancy property is the invariant, restated as a function.** The resolver's output is the rendered position, verbatim — every occupied square exactly one entry, no unoccupied square any. "The mirror renders the physical board. Always" stops being a doc sentence and becomes `verified(_:against:)`, asserted across every fixture in `PieceIdentityTests`. The feared mis-key (the reason the mirror passed `.empty` for four months) is structurally out: a square whose physical piece disagrees with the game's never inherits the stale identity — pinned by `aForeignPieceNeverInheritsTheSquaresOldIdentity`.

**Mechanism: a layer, not `matchedGeometryEffect`.** MGE pairs an insertion with a removal across two views — a namespace through 64 clipped, overlaid cells — and has no vocabulary for "this change must not animate", which the board-dump case needs. Identity churn expresses it for free: a dump re-keys wholesale, so thirty-two pieces fade in rather than flying from wherever they last stood. The layer sits between the squares and the wood grain (pieces keep the texture they always rendered under) and inside the `.clipped()` (a glide can't escape the grid). Squares keep chrome, highlights, accessibility identifiers, and the ghost — which therefore *cannot* animate, satisfying that constraint by construction rather than by flag. `PieceGlyph` gives the glyph one home for the layer and the ghost both, killing the 6%-padding twin at birth. The glide is 0.22 s — under the 300 ms quiescence, so a glide has always finished before the settle that confirms it. Reduce Motion drops the animation, not the layer.

**`SquareView.pieceID` retired**, closing the standing open item, and the reason belongs in the record: a square that knows its piece's identity still can't glide anything — gliding is a relationship between two squares, and only a layer sees both. The parameter was threaded toward a consumer that, when it finally arrived, was structurally unable to live where the parameter pointed.

**Review board: parity is total, everything glides.** Stepping, jumping, and the perspective flip all animate from the same resolution; the four gate shapes are watchable in the *Four Shapes — Interactive* preview, which drives `LibraryGamePreviewState.compute` — the exact pairing the review board renders — through a scripted line containing e4, the en-passant capture, the promotion morph (pawn's ID, `applyMove`'s reuse rule made visible), and O-O's crossing pair.

Accepted costs, priced rather than discovered: a multi-ply review jump glides every changed piece at once (identity persists, so it animates — the classic GUI behaviour, kept); the promotion glyph swaps at glide start rather than crossfading mid-flight (one identity, instant content); and the mirror's slow, deliberate move animates as two fades, which is the truth of it.

Rejected: **`matchedGeometryEffect`** (above); **rendering the committed game on the mirror and animating commits as glides** (the only way to glide every move, and it makes the mirror lie for up to the quiescence window — the exact surface desync detection needs truthful); **pairing vacate/place by piece type without verification** (speculation lite; the reconstructor exists because it is not trivial); **keeping `SquareView.pieceID` for a square-level animation** (a square sees one square).

### D48′ — Players absorbs Rankings: one destination, the ladder as its default sort

M9, by request. `RankedPlayer` (rank under D11′, rating riding along) becomes every mode view's row currency in **both** orderings — rank is a fact about the player, not a position in the current sort, so an alphabetical list still shows #14 beside the name. `PlayersSortOrder` (rank / name) persists under one new `StorageKeys` entry; the default is rank, because the ladder is the richer read and name order is for finding someone.

**Each fact once.** The merged profile grid is Rank, Games, Record, Win Rate, Rating, Uncertainty, Rated Games, Mates, First/Last Played — Record's first component absorbs the old separate Wins row, which closes the RankingsInspectorView Wins-twice open item by deleting the duplication rather than the row. The trend chart and Recent Games follow as their own sections. The gallery's stat grid gets the same treatment, which retires both recorded P-vs-R parity residues (the differing stat grids, the differing spacings) by leaving one grid where two disagreed.

**The grouping follows the ordering.** Columns mode groups by initial letter under name sort and by win band under rank sort — the retired Rankings view's own argument ("a ranked list grouped alphabetically would fight its own sort"), honoured in both directions by one view instead of two files.

**Section identity: `.rankingProfile` retired, `.ratingTrend` kept.** The two profile grids became one grid, so two cases would be two names for one section (D45′'s identity-follows-content rule cuts both ways); the trend section shows the same thing from a new host, so its identity survives the move. A stored collapse under the retired raw value evicts on the next write — the retirement path D45′ designed.

**Registry: the `rankings.*` group (seven constants) removed** — removals are as breaking as renames, recorded at the group's old anchor. `rankingRow(rank:name:)` survives, re-homed on the merged table's **Rank cell**, while the Player cell keeps `playerRow(name)` for the rename/merge flows: two cells, two currencies, because one element cannot carry both. The sidebar case is deleted at the enum, so a stale rankings selection is unrepresentable rather than handled. `TabState.rankingsInspectorPresented` and `StorageKeys.rankingsViewMode` retire with deletion comments; the stored view-mode value lingers in defaults unread, accepted rather than migrated.

**UITest consequences.** The ladder-order pin retargets to Players (same assertions, same seeded expectations — the ladder is the default sort, so the test's subject moved without its claims changing); the rankings view-mode and inspector-selection tests are deleted, their coverage owned by the Players twins; the sidebar round-trip loses its rankings leg.

Rejected: **a segmented control for the sort** (two segmented pickers side by side read as one broken control — it's a menu picker); **rank chrome only under rank sort** (two looks for one destination, and the question "what rank is this player?" doesn't stop being asked in name order); **keeping Rankings as a saved 'view' of Players** (a lens system is machinery no second lens exists to justify); **migrating the orphaned `rankingsViewMode` default** (a cleanup pass the leftover doesn't earn).

**Perf note, honestly carried:** the merged body folds `Glicko1.histories` every render (Rankings' cost, now paid on the Players surface too). It joins the known-costs census below rather than being optimized ahead of M7's Instruments pass.

## Architecture invariants

- **The compiler enforces mode 6 (D43′).** `SWIFT_VERSION = 6.0` on all three targets, so isolation and `Sendable` claims below are checked rather than asserted. This changes the standing of every concurrency invariant in this list: they used to be conventions the code followed, and they are now conditions the build imposes. Two consequences worth stating. The `@unchecked Sendable` / `nonisolated(unsafe)` prohibition is no longer only a grep at sweep time — reaching for either is now the visible act of opting *out* of enforcement, which is why D43′ declined it for one static property. And the "@MainActor suites for @MainActor types, nonisolated for pure value types" rule is self-policing: the 79 unit-test sources produced zero diagnostics under complete concurrency before anything was fixed, which is the evidence that the rule was being followed rather than merely written down. The two waived `Binding(present:)` warnings are the whole of the residue.
- Chess-core purity. Position, GameState, Move, FEN, Square, CastlingRights and friends are pure Sendable value types — logger-free, I/O-free, actor-free (sole Foundation import: CharacterSet trimming in the SAN layer). The invariant names **types, not folders** — which is why `ECOClassifier` and `ECOTable` sit in the same directory. Board geometry offsets live on Square, one copy; queenDirections is spelled out despite equalling kingOffsets.
- Move generation defends against hand-edited state. Castling is generated only when the rook actually sits on its home square. Same boundary hardening in FEN parsing.
- LiveGame is an I/O-free @Observable @MainActor final class. Append-only: no takebacks, no rollback() API, ever (Decision #1).
- Single-Mode state machine, honestly scoped. DGTLiveSession's one private Mode derives liveGame, awaitingPhysicalSetup, needsRecovery. Three published members are deliberately not Mode-derived but Mode-guarded.
- Settable-hook wiring. sessionLog, draftStore, onGameFinished, onBoardChanged, onDesync, boardIdentity, and shouldAutoReconnect are wired exactly once in App.init(). Nil hooks mean unit tests run headless by construction. recordError is the one door for must-reach-somewhere errors.
- Auto-connect decisions are pure; transport is not.
- Idle-sleep inhibition is App-owned, preference-gated, transport-only. Display sleep intentionally left alone — structural via .userInitiated. observe() is re-entry-guarded.
- The mirror renders the physical board. Always. Only overlays come from the game. **Since D47′ this is a tested property, not a sentence**: `PieceIdentity`'s output occupancy is the rendered position verbatim, asserted across every fixture — the resolver decides *keys*, never *presence*.
- **A piece glides only under a proven identity (D47′).** Parity vouches for the settled; the reconstructor's own verification vouches for the in-flight move; everything else is anonymous and can only fade. No view, overlay, or future surface may pair a vacate with a place by inference — that inference has one home, `DGTReconstructor`, and one standard, full-position verification.
- The stage above the board stays clear; the sidebar owns session info (D15′).
- id→model resolution guards tombstones, and **a snapshot held across a dialog is the same hazard without the cast**. Five sites pair the cast with an isDeleted check: two in AnalysisQueueController, two in BoardDestination, and M5's merge survivor — whose picker was built from a `@Query` snapshot, so a row deleted between presentation and Merge would otherwise be merged *into*. D40′'s sweep is the sixth in spirit: it holds `[Player]` between offer and confirmation, so the door re-checks `isOrphaned` per row and skips anything that gained a link in between.
- Recovery guidance is view-computed, session-gated, one spelling.
- DGTBoardDiff.vacated and .placed are disjoint, decided by end-occupancy.
- Reconstruction returns .inProgress before generating moves.
- One draft, one JSON sidecar. Atomic writes, schemaVersion-guarded, flattened fields; additive **optional** fields are non-breaking by the D28′ stance — a limit D36′ makes explicit for the other Codable-on-a-model type.
- Archive-first, exactly once, never lost. No * result ever archives (archive door; the import door admits * deliberately).
- **One content hash, one recipe, two spellings.** MD5 over normalize(event) | normalize(site) | hashDateString(date) | round | normalize(white) | normalize(black) | result.rawValue | moves joined by spaces. The model-typed `contentHash(for:)` forwards to a field-taking twin (D39′); there is still exactly one arrangement of the recipe, and changing its order, separator, normalization or digest un-dedupes the archive against itself. Any in-place edit must call `refreshHash(of:)` — or, for a retag, rehash inside the same transaction. timeControl, board and all four classification columns are deliberately outside it; PGN.name is too.
- Player links are store-owned (D9′). resolvePlayer(named:) is the single creation door; both doors link on insert; backfillPlayerLinks() heals pre-schema rows, followed by backfillPlayerTagNames(). applyEdit re-resolves unconditionally; applyMovetextEdit deliberately does not.
- **Stored seat tags change through one door (D37′, D38′).** `PGNStore.retag(_:to:)` is the only place `PGN.white` / `PGN.black` are rewritten outside a user's own metadata edit; merge is its caller, not its sibling. The pre-flight refuses before writing (D39′), and the rehash rides the rewrite rather than waiting for a later `refreshHash` — a retagged game whose hash lags is a dedupe rot with a delay fuse.
- **"Orphaned" has one spelling (D40′).** `PGNStore.isOrphaned(_:)` — static, context-free — answers it for `merge`'s post-retag assertion, for the sweep's write door, and for the `@Query` the Players toolbar filters. The predicate is store-owned; the rows are whoever fetched them. A second spelling of this question is the twin-read-site pattern in behavioural clothes, which is exactly how it existed before the epilogue.
- **An orphaned player is unreachable through selection, permanently and by construction (D40′).** The three collection destinations render folds over `GameRecord`s, and a record's sides come from resolved links — so a linkless registry row appears in no view mode. Any future affordance that must act on one belongs on a toolbar or a menu, never in an inspector; anything gated on the *selected* player having no games is dead code with a green build.
- Classification is store-owned and derived (D34′). `PGNStore.classify` is the single write site for all four columns. The fields are deliberately absent from `PGN.init` — the whitePlayer/blackPlayer precedent.
- Player names render through PlayerName.displayForm(of:), once (D23′). Tag form is stored; display form is shown; there is no inverse — and D37′ is the surface that proves the rule survives a rename dialog.
- Movetext edits validate by replay, accepted whole or rejected whole (D18′), structurally.
- PGN export is byte-pinned to the reference files (D24′). Classification is not exported.
- Pure cores are GameRecord-typed (D10′), with two recorded shape exceptions: SpecialCheckmate and the M4 classifiers.
- SmartTag matching is model-stored, value-decided. Matching is an in-memory fold, never a #Predicate — a stored-Codable rule array can't be queried in the store; load-bearing.
- SmartTag.self in the container is load-bearing. No relationships, so schema inference from PGN never pulls it in.
- **A collapsible section is one argument, not two (D45′).** `CollapsibleSection` is the only door: it takes one `InspectorSection` and uses it for both the chevron and the body gate, so "the header toggles X while the body checks Y" is unrepresentable rather than merely unlikely. `InspectorSectionHeader.section` is the parameter it drives and has no other intended caller — a header given a section outside this type gets a chevron toggling state nothing reads. The store is read in exactly two files, both in `Inspector/`; no destination or inspector holds it.
- **Section identity is what a section shows, not where it is shown (D45′).** One `InspectorSection` case per *kind* of content, shared across hosts — `.roster` in three inspectors, `.opening` in two. Two sections that merely share a title are not the same section: the live inspector's "Game" is `.lifecycle`, and the section actually about the game is the roster. Deriving identity from a title would merge them, which is why this is an enum with hand-written raw values.
- **The accessibility registry compiles into the UI test target, so it speaks only in `String` (M8).** `AccessibilityID.swift` is shared membership by design — that is the whole of F8's "separate module — keep in sync" fix — so every function there takes a raw value: `boardSquare` algebraic notation, not a `Square`; `sidebarDestination` a raw value, not a `Destination`; `inspectorSectionDisclosure` a section's raw value, not an `InspectorSection`. A signature naming an app type compiles perfectly in the app and breaks the other target. Where that costs a type-safety guarantee, buy it back at the call site — one caller, holding the real type.
- Collection-destination parity, now with shared metrics — two destinations since D48′ (`PlayersColumnsView` absorbed `RankingsColumnsView`, both groupings reading `CollectionGridMetrics.spacing` / `.inset`, which is what `LibraryColumnsView`'s card grid already did). The `.adaptive(minimum: 160, maximum: 200)` sizing stays local by decision — a detail pane beside a group list is not as wide as a whole destination — so the type governs the icons grids' geometry and only the columns grids' gutters. Known parity residue (unscheduled, narrowed by D48′): Library-vs-Players gallery empty-selection still answers opposite ways.
- Destructive Library actions confirm, whichever route reaches them. **M5's are the first destructive actions outside the Library**, and they confirm differently on purpose: rename and merge confirm *by being sheets that state their consequence*; the D40′ sweep takes an alert in the `pendingBatchDeletion` mould, because unlike the other two it acts on rows the user has not seen and cannot otherwise see, so the dialog is doing the showing as well as the asking.
- Accessibility identifiers are a tested contract. Dotted lowercase, all in AccessibilityID; renaming one is a breaking change, and **so is removing one** (D40′ retired `players.inspector.deleteItem` with the affordance it named, recorded at the symbol); a raw string in a view is a defect — including parameter defaults. A repo-wide grep is clean, every entry referenced. Note the Library table's row identifier rides the **White** column's cell, so inserting a column elsewhere leaves it unmoved — but moving the White column would be an accessibility-contract change. Note also that `board` now identifies the container holding the eval bar *and* the board, not the `BoardView` alone; no UITest does coordinate math on it, but the widening is recorded rather than discovered.
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
- @diagnose remains the per-declaration warning-control tool. **Its headline use here is spent**: `@diagnose(ErrorInFutureSwiftVersion, as: error)` was recorded as the staged lever for the language-mode-6 migration, and D43′ made that migration in one pass without needing to stage anything — the gap was one static property, so there was nothing to walk through declaration by declaration. What survives is the smaller use: scoping a single deprecation or a `StrictMemorySafety` diagnostic to one declaration with a mandatory reason. Worth remembering the lever exists if a *future* language mode has a wider gap than this one did.
- .confirmationDialog(item:) / .alert(item:) remove the Bool-plus-optional pairing class. **Seven `Binding(present:)` sites** — four in LibraryDestination, one in ContentView, two in PlayersDestination (M5's refusal alert and D40′'s orphan sweep). This count was wrong here as "six" until D43′ counted them: it caught M5's addition and missed D40′'s, which is the enumerated-caller-list anti-pattern surviving inside the very list of things to fix later. The `RetagRefusal` wrapper exists only to give an array an `Identifiable` conformance the item-based API would supply, so it is the site that would disappear most completely — and the helper itself is where D43′'s two waived warnings live, so this migration retires a waiver as well as seven call sites.

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

- **Code is truth.** Docs follow code; when they disagree, fix the doc. The roll of instances now includes: D18′'s stated reason; D14′'s recorded options; the setoption window; Evaluation.drawn; five decisions landing in code without reaching this document; the 29 and 30 July harvests; M2's resolvedKey find; M4's three; **the audit's three plus M5's one** — the eval bar's two width numbers, the pencil's stacked padding, the ECO column reading past its invariant, and the roadmap's delete-player proposal that the link backfill would have undone; and **the epilogue's one, which is the largest so far**: D38′'s replacement delete shipped behind a guard that could never be true, and both this document and M5's manual-check list described it working. The useful pattern across all of them: a comment that *asserts* a guarantee ("named so any future reader agrees") is where to look first, because it reads as settled and is exactly as checkable as anything else. The epilogue adds a second place to look — **a claim about what the user can do**, in a doc or a check-list, is a claim about a code path, and the path is walkable. **D43′ adds a third, and it caught the author in the act**: the comment introduced to explain the `@MainActor` annotation asserted that overrides inherit class isolation, and the next build disproved it in three warnings — written *during* a pass whose whole subject was unchecked claims. The defence is not care while writing; it is the build. If a comment states a rule about the language rather than about this code, it is a hypothesis until something compiles it. **D44′ adds the fourth and sharpens that last sentence, because the version above is too weak**: `RosterSummary`'s `@MainActor` comment made a language claim that compiled cleanly for a month. Compiling is not the test — being compiled *from the side where the claim would break* is. Both of the isolation comments this project has now caught were adjacent to a true rule (members do inherit; a superclass does constrain an override), which is what let them read as expertise rather than as guesses.
- **Sweep between milestones, not only within them.** (New, M5; first run as its own pass 30 July.) Three of the post-M4 audit's four findings were introduced by the two milestones that had just landed green, and none was visible from inside the change that caused it — the pencil divergence in particular is invisible unless two inspectors are open side by side. A grep-level conformance pass costs minutes and is the only thing that catches the class. **What the first standalone run taught: the sweep's most valuable output was not a finding but a commit.** Its headline discovery was that the epilogue — code, tests and both documents — was sitting *unstaged* while both documents described it as delivered. Everything the greps checked came back clean; the thing nobody had checked was whether the delivery existed. Run `git status` first, before any grep.
- A test that pins a factory is a change-detector, and editing the factory means editing the test in the same change.
- The compiler outranks any platform reference, including this document's forward notes. Corollary: do not infer an API name from its neighbours. M4's variant: do not infer a data row either. **M5's variant: do not infer a function's contract from its name.** `importPGN` *throws* on a duplicate rather than returning the existing row, and `Player.normalizedKey(for:)` takes a **display** form — handing it a comma tag yields a key no row carries, so every lookup written that way returns nil and passes an "it's gone" assertion for entirely the wrong reason. Both were found by reading the declaration, both would have been plausible either way.
- **A discarded working tree is a discarded delivery.** (29 July; three further instances.) 30 July's variant: resources can die without a reset — a file a committed test requires is part of the delivery. **The hazard is currently discharged**: everything is committed, the sweep's three commits on `3f785a3` plus this document's own. It recurred twice more since that was written. Once as a folder reorganization leaving two reference PGNs as unstaged deletes plus untracked copies, which `git status` shows and a casual glance does not. And once in its purest form yet — **the M5 epilogue was never committed at all**, so a ⌘U-green delivery of six source files and two rewritten documents existed only in the working tree, while this document's own header said "the tree stays committed" and named a base the epilogue was not part of. The sweep found it with its first command. The lesson sharpens the rule: *this sentence* is the one most likely to be stale, because it is written at the moment of committing and never re-read afterwards. Treat a claim that the tree is clean exactly like a comment asserting a guarantee — check it, don't trust it. Doc-form corollary: rebuilding a document from a stale synced base silently discards the revisions in between — name the base and the carried deltas when forced to do it, as this revision's header does. **31 July extends the rule from "clean" to "there" (D42′):** the open-items list asserted `.swift-format` was committed and it had never existed in any commit on any branch. Same class, same one-command check — `git ls-files` for the existence claim, `git status` for the cleanliness one. Generalised: **any sentence in these documents that contains a path is a checkable claim about the filesystem**, and an item resting on a file nobody verified can read as scheduled work indefinitely, because nothing about it ever fails. **31 July, second pass, extends it once more — from "there" to "current" (D43′):** the open items claimed a warning count of 295, which no measured setting reproduces and whose provenance cannot be reconstructed. A number decays worse than a path, because a path is either there or not while a stale count stays *plausible* forever. And the recurrence itself is now the finding: **this pass, like the two before it, opened by discovering its predecessor's delivery uncommitted** — D42′ was sitting in the working tree while the document above it described it as landed. Three consecutive passes, one rule written three times, zero preventions. Writing it down has never once stopped it; running `git status` has caught it every single time. Treat the rule as a reminder to type the command, not as a substitute for typing it. **1 August is the sixth instance in seven passes**: D44′ was uncommitted while the revision above it described the delivery as landed, and `git status` found it first thing again. The rule has now been written four separate ways and prevented it zero times; the command has caught it six times out of six. Stop expecting the prose to work.
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
- **A guard that exists in two places must be computed from one source.** (New, M5; sharpened by D40′.) M5 wrote this about the Delete menu item and the store door reading the same games so they could not disagree — and they didn't. They agreed on a value neither could ever produce. Agreement between two guards is not evidence that either is right; it is only evidence that they'll be wrong together. The rule survives with its remedy strengthened: not "make them read the same data" but **one predicate, called twice** — `PGNStore.isOrphaned` is what that looks like.
- **A disabled affordance whose guard can never be true is a lie with a green build.** (New, D40′.) It costs nothing at runtime, fails no test, and reads as a considered edge case, which is the same signature as the audit's comments that *assert* a guarantee. The grep is cheap and worth running at each sweep: for every `disabled(...)` over a derived condition, ask what supplies the condition and whether that supply can produce the enabling value at all. The one found here was two milestones' worth of reasoning resting on a premise nobody had checked — that the thing being deleted could be selected. **Re-run in full by the 30 July sweep across every `.disabled(…)` site — all enabling values producible, so D40′'s was the only one — and again by the 1 Aug review with the same clean result** (17 code sites; the one added since is D40′'s own `orphans.isEmpty`, producible). Worth stating as a positive result — the grep's value is that it is *cheap*, and a clean run is what makes the one dirty run credible. The sweep's own count here read "fifteen" with no recorded method, and no grep reproduces it — `grep -rn '\.disabled(' --include='*.swift' DGTStudioPro/` finds 18 matches (17 code sites plus one doc comment at `BoardInspectorView:28`) at head *and* at the sweep's commit. A count without its method is the 295 again, smaller; the method now travels with the number, and the next re-run should expect that denominator.
- **A milestone's own manual-check list is a claim, and claims get checked.** (New, D40′.) The step "delete that player's only game, revisit Players, confirm the item is now enabled" was written in good faith and was impossible to perform. Written checks are as much "code is truth" material as doc comments — arguably more, because nothing compiles them.
- Re-sync project knowledge after each integration. Sync artifact: + in filenames arrives as _ (PGN+Export.swift → PGN_Export.swift); file contents are unaffected, so anchors stay exact. **And the reason this one is not housekeeping (31 July, third pass):** `ROADMAP.md` and `PROJECT-INSTRUCTIONS.md` are tracked files *and* synced documents, so each has two copies — and the synced copy is a snapshot that decays silently while the tracked one moves. The D44′ pass opened by reading the synced roadmap, which was four revisions stale, and stated on that basis that four milestones were unrecorded. They were recorded; the repo's copy was current all along. That is D25′'s twin-read-site pattern with a document instead of a constant, and it has the same remedy: **the tracked file is the owner, the sync is a projection.** Read the repo's copy, then re-sync — never the reverse. Note this failure is worse than a stale constant, because the two copies disagree without either being malformed, and the stale one is the more convenient to reach.
- **A sentence that says "every" is a claim about a set, and the set has a size.** (New, M8, and the fourth species of unchecked claim after *the file is there*, *the number is current*, and *the rule is real*.) The roadmap said "every `InspectorSectionHeader` grows a chevron", which reads as a complete instruction; eight of fifteen inspector section headers used that type. **The sentence was entirely true** — that is what makes this species different from the other three and harder to catch. It quantified correctly over a smaller set than its reader assumed, and a true statement never fails. The check is a one-line grep and nobody runs it, because "every" already sounds like somebody counted. The habit to build: when a plan quantifies over a category, count the category *before* believing the plan's scope, especially when the plan was written by someone who could see the category and didn't enumerate it.
- **A constraint obeyed by every instance and stated by none reads as taste.** (New, M8.) Every function in `AccessibilityID` took a `String`; the reason — shared membership with the UI test target — was written nowhere, so it looked like a house style and got broken by a signature that was strictly better in the only target I was thinking about. The remedy is not more discipline, it is one sentence at the first instance: a pattern with a *reason* attached survives contact with someone improving it, and a pattern without one is an invitation.
- **A claim is only checked by a test that could have failed** — the fourth member of a family this project keeps rediscovering. The `.disabled(…)` guard that could never be true, the two guards agreeing on a value neither could produce, the measurement taken from a build that compiled nothing, and now (D44′) an isolation claim no caller was positioned to contradict. Every one of them was green, cheap to check, and wrong. The question that catches all four is the same: *what would it take for this to fail, and does that situation exist anywhere in the tree?* If the answer is "nothing does that", the check is decorative and the claim is untested no matter how many times it has passed.
- **A measurement must carry proof that it measured.** (New, D43′.) A number extracted by grepping a build log is only as good as the build, and a build that did nothing produces a beautifully clean log. This happened twice in one pass: an incremental re-run recompiled nothing and reported zero warnings, and a shell-quoting slip sent an empty argument to `xcodebuild` so *both* probes failed instantly and reported `diagnostics=0` — a plausible answer, arrived at by doing no work. Neither was caught by reading the number. The remedy is to report a **corroborating count from the same log** alongside the answer: `SwiftCompile` phases, or distinct sources compiled, or the `** BUILD SUCCEEDED **` line. 239 and 211 are this project's numbers; anything less means read the log before believing anything in it. The general form is the `.disabled(…)` lesson again — a check that can pass without exercising its subject will eventually pass while telling you nothing, and the tell is always available if you ask for it.
- **Never write a prohibited token verbatim in a comment.** (D43′, found by the verification pass of the same change that caused it. **Swept for the first time on 1 August and it found four pre-existing violations** — three spelling the accessibility-identifier token while *describing the enforcement grep it breaks*, and one in `Binding(present:)`'s doc, which states this very rule, says it spelled the concurrency tokens around on purpose, and then spells the beta-API tokens three lines later. The rule had been applied to the grep its author was thinking about and not to the grep in the next section of the same sweep. Both greps return zero now. An agreement minted but never swept for is an agreement that only governs the person who wrote it, on the day they wrote it.) The sweep enforces the standing prohibitions — `@unchecked Sendable`, the unsafe-`nonisolated` opt-out, `DispatchQueue`, `Combine`, `NotificationCenter`, `Thread.sleep` — by grepping for the tokens. D43′'s two new doc comments *explained why those opt-outs were rejected*, spelling them exactly, and thereby planted three permanent false positives in the grep that guards them. Spell around it: "the unsafe-`nonisolated` opt-out", "unchecked-`Sendable`". This is the `.DS_Store` finding in a new costume, three passes later and self-inflicted while writing up that very finding — a check whose output always contains noise is a check being read past, and the fastest way to add the noise is to document the rule inside the thing the rule scans.
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
- **Generic types cannot have stored static properties.** (M8.) `InspectorSectionHeader<Actions>` is generic, so `static let actionsInset` doesn't compile; `static var actionsInset: CGFloat { 10 }` does. This was *already written down* — `SevenTagRosterSection` records it at `noGamePlaceholder`, in a file the same milestone had open on its way here — and got re-learned from the compiler anyway. Kept because the recurrence is the lesson: a recorded constraint only helps someone who thinks to look it up, and nobody looks up "may I write this line" before writing it. The build is the check; the memory is not.
- **A signature is a contract with every target that compiles the file.** (M8.) `AccessibilityID.inspectorSectionDisclosure` was typed to `InspectorSection`, which the app target can see and the UI test target cannot. Every function already in that file took a `String` and none of them said why, so the constraint was visible in every instance and stated in none — which reads as a style preference right up until you break it. When a file has shared target membership, its API surface is limited to what the *narrowest* target can see, and that fact belongs in a comment because nothing else announces it.
- **A global actor isolates a type's members, not the types nested inside it.** (D44′.) `@MainActor class Outer { struct Inner { } }` leaves `Inner` nonisolated — SE-0449 uses this exact shape in its own text. The trap is that the *members* rule is true and adjacent, so "nested things inherit isolation" reads like a restatement of something correct. It cost this codebase one unnecessary `@MainActor` on `RosterSummary`'s live projection for a month, invisibly, because every caller was main-actor for an unrelated and legitimate reason.
- **A synchronous override cannot add actor isolation its superclass declaration lacks; an async override can.** (D43′.) The superclass may call a synchronous method from anywhere, so there is nowhere to put the hop; an async one has a suspension point to hop on. This is why `@MainActor` on an `XCTestCase` subclass covers its own methods but leaves `setUpWithError` / `tearDownWithError` nonisolated, and why the fix is the `setUp() async throws` / `tearDown() async throws` spellings rather than an annotation on the overrides.
- Cold-build invocation, for any future measurement: `xcodebuild -scheme DGTStudioPro -testPlan DGTStudioPro -destination 'platform=macOS,arch=arm64' -derivedDataPath <scratch> build-for-testing`, with the scratch path **deleted first**. `build-for-testing` with the full plan is what compiles all three targets — the app scheme's build action alone covers only the app target, so a plain ⌘B misses 80 of the 211 sources. The scratch path keeps Xcode's own DerivedData intact so ⌘U afterwards isn't a cold rebuild. Settings can be overridden per-run (`SWIFT_VERSION=6`) without touching the project file, which is strictly better than the branch a migration would otherwise need.
- Verification tips: pmset -g assertions shows the held activity by its reason string; log stream --predicate 'category == "uci"' shows the setoption send order; `category == "eco"` shows the table's row count at load; `category == "players"` shows M5's retag / merge / delete lines; stockfish resident memory should track configured Hash.

## Assumed-never (do not design for these)

Chess960; two same-colour kings; mid-game board flips; occupied-only boards; Bluetooth boards; live engine eval during play; DGT clock support / move timestamps; takebacks of committed legal moves.

Player rename / merge / delete has left this list *and* the roadmap — it is built (D37′, D38′, D39′, D40′). **Automatic orphan collection stays on this list**, deliberately and now with a surface beside it: D9′'s no-GC decision is untouched by the sweep, which never runs unasked. A document-based architecture stays not-applicable rather than assumed-never.

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

**M8's four new view-bearing types are not on this table either.** `CollapsibleSection` and `EvaluationMagnifierButton` are witnessed through the surfaces that render them — every inspector preview, and `InspectorSectionHeader`'s *Actions — Every Arity*, which is the one that matters: it shows all four arities the app passes (lone pencil, chevron plus glyph, pencil plus menu, and collapsible-with-nothing), stacked so their trailing edges read against each other. That preview is the standing witness for `actionsInset`, and it exists because the type previously had four witnesses all passing a lone pencil — the one arity where the broken arrangement happened to be right.

`EvaluationGraphWindow` ships one preview covering the branch a reader hits by accident (the magnifier on an unanalysed game) and no others, because **its two read-out states both require a pointer** and a canvas has none. Named here rather than waived: the hover behaviour is on the M8 manual-check list, which is the honest witness, and `EvaluationGraphGeometry` — the part that decides *which* ply the pointer found — is suited in full.

**M5's two sheets are not on this table** — both ship previews (three and two), the store door they drive is suited, and since the epilogue the *flow* is witnessed too: four UITests cover the header controls' hittability, the rename round trip, the merge, and D40′'s sweep. The hittability test stood alone deliberately, because both header controls are borderless inside a `List` section header — the shape M1 proved AX-invisible for the sidebar's + button — so that if the finding transferred, one test would name it instead of three failing obscurely. **It passed.** The finding does not transfer: an *inspector* section header's borderless controls are AX-visible on macOS where a *sidebar* header's + button is not. The pencil and the actions menu need no menu-bar remedy, and the test keeps its place as the standing witness that they stay reachable.

`PlayersDestination`'s own preview does not reach the sweep's alert (an empty container has no orphans, and seeding linkless `Player` rows in a preview would be a fixture built for one branch). Named here rather than waived: the branch is covered by the UITest end to end, which is the stronger witness of the two.

Closed as covered, not waived: DGTProtocol wire bytes; menu commands; the AnalysisQueue extraction; engine integration; parser rejections and tag helpers; the session's ghost/correction arms; the recorder ring; player resolution/backfill/edit; GameRecord chronology and projection; PlayerStats; Glicko1; TagRule / SmartTag (incl. the M1 quantifier pin, the D30′ semantics pins, and M4's six); the onDesync edge; the pairing fold; the movetext validator + store door (incl. the M2 splice refusals ×4 and M4's re-derive pin); the mate classifier plus its displayName tripwire; DGTBoardDiff's shape contract; GameHeadline; RosterSummary (including D44′'s isolation pin, which is a compile-time witness rather than an assertion); PlayerName; the sleep preference; LibraryGamePreviewState; Game; drafts; OpenGamesRegistry; Evaluation; EngineConfiguration; UCIProtocol; framer/decoder/field bijection; reconstructor per-move-class; recovery guidance; auto-connect policy; connection status machine; castling rights-without-rook ×3; FEN hardening rejections; PGNSerializer reference-byte round trip; the drain-race controller suite; the live session's board-identity stamp; the archive door's board threading + hash-exclusion dedupe; the M3 bar reading; M4's four suites; **and M5's `PGNStoreRetagTests` (18 since the epilogue: the tag rewrite and its hash cost, the unrelated-games scope, the self-play both-seats pass, the placeholder refusal ×3, both collision sources, the fold-equivalent non-collision, the refusal payload, merge's relink-and-delete, merge surviving applyEdit, merge-into-self, a colliding merge, target creation through the resolver, the renamed-export round trip, and D40′'s three: a linked player is never *listed*, an orphan is listed and swept, and a row relinked between listing and confirming is skipped); plus the four Players-editing UITests.** **And M8's two suites: `InspectorSectionCollapseTests` (10 — the empty default and that construction writes nothing, the round trip through a reload rather than through memory, independence, both halves of the retired-section rule, a wrong-typed stored value, the sorted written form, and distinct raw values, which is the one thing the compiler cannot check about hand-written raw values); `EvaluationGraphGeometryTests` + `EvaluationGraphReadingTests` (13, sharing a file — the `ECOTableTests` shape — covering the degenerate widths, full-width spanning, the ply↔x round trip across a whole 63-ply curve, nearest-not-floor, end clamping, the move-number grammar in both colours, and the evaluation label asserted *against `EvaluationBarReading`* rather than against a literal).** **And M6's `PieceIdentityTests` (12, nonisolated — every fixture routed through the occupancy-verbatim helper, plus the review arm's total tracking, per-square parity, the lift that strips no neighbour, the proven move carrying the origin's identity, its stability across the commit, promotion's pawn-ID reuse, both castle placements, the mid-castle split, the correctable en-passant, the mis-key guard, and key uniqueness — the layer's `ForEach` requirement).**

**M6's two new view-bearing types are witnessed by their own previews** — `PieceGlyph` and `BoardPieceLayer` carry the migrated glyph-set and size-scaling previews plus *Four Shapes — Interactive*, and every `BoardView` preview exercises the layer since it is the only thing that draws pieces. The interactive preview is the standing witness for the glide/fade contract the way *Actions — Every Arity* is for `actionsInset`: the canvas is where the claim is visible, and the suite pins the resolution it renders.

`ECOTable` is deliberately not on the waiver table: `ECOTableTests` (which shares `ECOClassifierTests`' file) drives it end to end against the real shipped asset. What is unexercised is its three failure arms — resource missing, file unreadable, row malformed — each of which logs and degrades rather than throwing.

Test-only by decision, not gaps: FEN.legalMoves(); CastlingRights' no-arg init; Square.dgtField; DGTBoardDiff.changedSquares; Evaluation's eval-tag emitting half; DGTSessionLog.clear().

**Compiler warnings are waived here too, and the register has exactly one entry (D43′).**

| Site | Diagnostic | Reason | Expires |
|---|---|---|---|
| `Binding.init(present:)`, ×2 | capture of non-`Sendable` `Binding<T?>` in a `@Sendable` closure | `Binding` is not `Sendable` while its own initializer demands `@Sendable` closures. `T: Sendable` would fix it and lock out the `@Model` call sites, which are most of the seven; the alternatives are opt-outs this codebase has none of. Stays a *warning* under mode 6 rather than becoming an error — the compiler treating it as framework friction rather than a defect here. | By deletion, not by lifting: the 2027 SDK's `.alert(item:)` / `.confirmationDialog(item:)` retire all seven call sites and the helper with them. |

The waiver is written at the declaration as well as here, per the two-homes rule. A second entry appearing on this table is a signal worth attending to — the app target went from 230 diagnostics to two in three annotations, so a *new* warning is far more likely to be a real finding than an unavoidable one.

## Known open items — unscheduled

Everything scheduled lives in ROADMAP.md. This list is only what is known, real, and deliberately not scheduled.

- **`GameRecord.endedInMate` spells "did this end in mate" as `hasSuffix("#")` while D18′ and `GameClassification` spell it `contains("#")`** — so `Qd2#!` reads as mate to one and not the other. Left alone deliberately: changing it moves every saved Checkmate tag's matching, a D30′-shaped decision rather than a rider. One line, once decided.
- **`DGTSerialPort.isOpen` is the app target's one symbol with no consumer.** (New, audit; re-verified by the 30 July sweep, which scanned all 495 private declarations and found no others.) Either it earns one or it joins the test-only-by-decision list — a decision, not a deletion. Note it is *not* D41′'s disposition: `createdAt` was deleted because a better sibling already answered its question, and `isOpen` has no such sibling.
- ~~The two galleries answer empty-selection opposite ways, each documented as correct.~~ **Narrowed by D48′** to Library-vs-Players only (the P-vs-R half merged away); still open in that form.
- ~~RankingsInspectorView shows Wins twice (own row + first component of Record).~~ **Closed by D48′** — the merged grid states Record once and the duplicating row is gone with its file.
- ~~Gallery stat grids and columns detail paddings still diverge.~~ **Closed by D48′** — one gallery, one grid.
- **The chevron's gap to the actions slot rests on `EmptyView` not being laid out.** (New, M8.) `InspectorSectionHeader`'s trailing cluster is `HStack(spacing: 12) { chevron; actions() }`, and for a collapsible section with no actions that slot is a bare `EmptyView` — which should be flattened out of the `ViewBuilder` list and contribute no subview, hence no spacing. That is the one thing in D45′ written from reasoning rather than read off a compiler. It compiles either way, so ⌘U cannot answer it; the *Collapsible, No Actions* row in the **Actions — Every Arity** preview is where it becomes visible, and the remedy if it is wrong is to move the 12 pt onto the chevron under a condition. Noted rather than fixed pre-emptively, because guarding against it unconditionally would put 12 pt of dead space into every actionless header to avoid looking at a preview once.
- ~~RosterSummary's @MainActor live-projection init invites its own removal — delete the attribute and build.~~ **Closed by D44′, and the invitation was right for the wrong reason.** The entry read as a tidy-up whose worst case was "the attribute turns out to be load-bearing". It wasn't load-bearing and it was never *able* to be: the reason written at the declaration — that a nested type inherits its enclosing type's global-actor isolation — is not how the language works. Third struck entry in three consecutive passes, all three resting on a claim nobody had checked, and this is the one that argues hardest for the greps being cheap: a missing file and a stale count can at least be *suspected*, while a false statement about the language reads as expertise.
- FEN / GameState collapse. A rename-scale mechanical change.
- ~~SquareView.pieceID is threaded and unread — kept deliberately as M6's currency.~~ **Closed by D47′, and the currency metaphor held with a twist**: the value was spent, but not where the parameter pointed — identity keys the *layer's* `ForEach`, because a square that knows its piece's identity still can't glide anything. The parameter is retired with the reason recorded at the site.
- BoardView.selectedSquare — built capability for a surface that has never been decided.
- Import batches are uncancellable — either implement cancellation or relabel.
- Known costs, deferred until measured (M7 measures; none scale-critical at personal size): parseSAN generates all legal moves per ply; Glicko1.histories builds every player's full sample array to answer one player's question; backfillPlayerLinks is fetch-all-and-scan × three onAppears (**backfillClassifications left this list — it carries a predicate now**); the ECO table's ~3,800-row parse, warmed off-actor but never measured; `ECOClassifier.opening(for:)`'s quadratic prefix re-join, bounded at 36 plies; **`retag`'s per-game re-resolve and rehash, which is O(linked games) with an MD5 each and runs inside a modal save**; UCIProtocol.parse allocates ~3 arrays per info line; Position's [Piece] storage heap-allocates per applying; the New Game sheet folds games.map(\.gameRecord) per seat edit; Players/Rankings destinations fold once per body; **the merged Players body folds `Glicko1.histories` every render (D48′ — Rankings' cost on Players' surface)**; **three more from the 1 Aug review**: the Library's active tag filter builds a `GameRecord` per game per body pass (`LibraryFilter.matches` — the same family as the destination folds, and the most invalidation-prone surface carrying it); the Library inspector's PGN section re-serializes the game per body pass while expanded (documented at the site, collapse-gated since D45′); and pawn movegen builds its two-element capture-offset array per pawn per call in the `legalMoves()` hot path — the one non-static offset table, mechanical to fix, but it touches `Chess/`, so it inherits the deep-perft landing gate and waits for M7.
- Log-format leftovers from 20 July, still unverified against a live session.
- File-menu Export — horizon; unblocked on appetite.
- StockfishEngine.swift lives in PGN/ — filing quirk. Same for PairingRoundTests (in Chess/), MovetextEditTests (in Players/), PieceTrackerTests (in DGT/).
- Export filename numbering is unconfirmed against DGT's own convention.
- ~~swift-format — decided, .swift-format committed, never run.~~ **Closed by D42′, and the entry was false in both halves**: the config was never committed, and "decided" described a decision nobody had made. Declined. Nothing here is outstanding; the line survives struck because the *shape* of the error is the lesson — an item can sit on an open-items list for weeks reading as scheduled work while resting on a file that does not exist.
- ~~Warning triage — count (last known 295), bucket, burn, waive.~~ **Closed by D43′, and this entry was false the same way its neighbour above was.** There is no 295 and there never was one that anybody can point to: the project's own settings emit **zero** compiler diagnostics on a cold build of all three targets. The number's provenance cannot be reconstructed, so it is recorded as unattributed rather than as superseded — claiming 200-odd warnings got fixed along the way would be inventing a history to make the old number true. Two struck entries in two consecutive passes, both resting on an unverified claim, is the argument for the sweep's greps being cheap: **the expensive part was never the checking, it was that nobody had checked.** What the item was *actually* worth is recorded in D43′ — the 230 diagnostics the project had never asked for, and the mode-6 flip that now asks for them.

## Manual checks

Need the board: launch auto-connect on/off; remembered-board-absent is a silent no-op; mid-game cable pull reconnects silently; discard mid-outage stands the loop down; recording start → cable pull → stop-and-export produces a coherent file; illegal move audible with the toggle on, silent off; no idle-sleep across a long think while the display dims; Energy toggle off means the Mac does idle-sleep mid-game; a recording survives an idle window; one desync worked through from the sidebar checklist; New Game with two known players prefills Round correctly; a game played and archived this build exports a `[Board "DGT …"]` matching the connected board's serial, and the same game resumed from a draft after a relaunch still carries it; stockfish resident memory tracks the configured Hash.

Boardless: batch analysis (queue 3+, drain count, skip mid-pass, delete waiting + running, Stop All exits the process, forced failure persists a warning until Dismiss); movetext edit accept/reject round trip (evals gone on accept, opening re-derived on accept, Save disabled with first-ply message on reject, and a pasted two-game splice shows the splice message); export one game out and back in clean; multi-selection into a folder, numbered; open a Library game and confirm it loads; stepping through an analyzed game moves the bar with the graph, the toolbar flip button flips it, an unanalyzed game shows no bar; single-game delete asks from toolbar, ⌫, and row menu; ⎋ during import keeps the sheet up; Edit Info on a loaded game round-trips through applyEdit; the sidebar Tags header's + button opens the editor.

**M8's own (boardless).** The collapse mechanism is UITestable in principle and deliberately untested there for now — the identifiers exist (`inspector.<section>.disclosure`) and the seeded run starts with an empty collapsed set, so a future test has everything it needs. What is on this list is what a test would not catch:

- Fold a section in the Board inspector, quit, relaunch: still folded. Fold Opening on the Board, go to the Library: folded there too — that is D45′'s shared-identity decision, and seeing it once is worth more than the paragraph.
- Fold the live inspector's **Game** section (Resign / Draw / Discard) and confirm the roster section above it is unaffected. Two sections titled Game, and this is the check that they are not one section.
- The **Players profile header now carries three controls** — chevron, pencil, menu. Confirm the pencil and the menu are still hittable and that the chevron leads them, and glance at the Library's PGN header in the same session: its copy glyph and chevron have swapped places, which is D45′ implementing what that section's own doc always claimed.
- The trailing-edge check, which is the whole of M8's prep: open the Players inspector and the Library inspector side by side and confirm every header's outermost control sits the same distance from the edge. Before this pass they sat at 10, 8 and 0.
- The **Actions — Every Arity** preview, once, in the canvas — specifically whether the *Collapsible, No Actions* chevron lines up with the ones above it. That is the open item about `EmptyView` layout, and the canvas is the only place it can be settled.
- **D46′'s routing check, and it is the one worth doing first:** with an evaluation-graph window already open, open a game from the Library. A game window must appear. If a second graph appears instead, `EvaluationGraphRequest` failed at the only job it has.
- Magnifier from both inspectors on the same game: one window, and it must **not** tab with the game windows. Sweep the pointer across the curve — the move label tracks, black plies read `12… Nf6`, and leaving the graph blanks the read-out rather than freezing it on the last ply. Then open the magnifier on an unanalysed game and on a live game: the first shows "No Analysis", the second has no magnifier at all.
- Delete a game while its graph window is open: "No Analysis", not a trap.

**M9's own (boardless).** Sort toggle round-trips and persists across a relaunch; rank badges and the Rating column show in *name* order too; columns mode swaps its left column's vocabulary with the sort (letters ↔ win bands); the profile shows one grid + trend + recent games with no duplicated stat; rename and merge still work from the merged header; the Maintenance sweep still enables on an orphaned registry.

**M6's own.** Boardless first: step the *Four Shapes — Interactive* preview end to end — e4 glides, exf6 glides diagonally while the f5 pawn fades from the odd square, gxh8=Q leaves g7 as a pawn and lands a queen without breaking motion, O-O crosses king and rook. Then on a real archived game: arrow through moves (each ply glides), jump ten plies from the move list (a multi-piece glide, accepted in D47′), flip the board (everything glides through the flip), and toggle Reduce Motion (positions update, nothing slides). With the board: a *slid* pawn glides on the mirror; a deliberate lift-think-place fades out and in with no false glide between; a fast O-O animates; connect-time board dump **fades** in — if thirty-two pieces fly, the anonymous-key rule is broken; force a desync and confirm the recovery overlays and ghost never animate while pieces fade honestly; and the whole session at real settle cadence shows no hitching — eyeball now, Instruments owns the number (M7).

M4's own (boardless): first Library appearance after a fresh launch is not perceptibly stalled; the Library's ECO column populates for existing games after one Library visit, and `log stream --predicate 'category == "eco"'` reports the table's row count once and the backfill's count once; the inspector's Opening section shows three rows for a variation, two for a bare family, and an em dash for a moveless game; a smart tag on `opening contains` filters the Library; a hand-built `mate pattern is smothered` tag finds a smothered mate and not an ordinary one. And the one only a pre-existing install can run: after this build, every smart tag saved before M4 still exists with its rules intact.

**M5's own (boardless).** The flow now has four UITests, so these are the checks XCUITest still can't make — the ones about *stored bytes* and *the real store* rather than about which controls respond:

- Rename a player with several games: the sheet opens seeded with **tag form** (comma order), the "Shown as" line updates as you type, and the summary names the right game count. After Save, the Library rows and the Players list both show the new name, and the ECO/roster columns are otherwise untouched.
- Export one of those games and re-import it: refused as a duplicate. Export a game *before* renaming and re-import after: imports as a new row — that is D37′'s accepted price, and seeing it once is worth more than the doc paragraph.
- Merge two spellings of one opponent: the sheet's sentence names both, the loser disappears from Players, its games now list under the survivor, and the survivor's game count is the sum. Then edit any merged game's Event through Edit Info and confirm the loser does **not** come back — that is D38′'s whole reason, and the only check that exercises it against the real store.
- Force D39′: import the same game twice under two spellings of Black, then merge them. The alert names both games and says nothing was changed; confirm in the Library that nothing did.
- **D40′'s sweep, on the real library rather than the seed:** the Players toolbar's Maintenance menu is disabled on a healthy library. Delete a game whose opponent you never played again, come back, and the item enables; the alert names that opponent — which is the only time you will ever see the row. Sweep, and confirm the menu goes quiet. *(This entry replaces M5's original delete check, which asked for the per-player item to become enabled and could never be performed — see D40′.)*
- `log stream --predicate 'category == "players"'` shows one retag line per operation with the game count, the refusal line on a blocked merge, and one delete line per swept row plus a skip line if a row was relinked between the offer and the confirmation.

Only if the toolchain moves (D27′): Liquid Glass screenshot pass over the board chrome and all four view modes × three destinations; the full UITest suite; pmset -g assertions across a live game if the observation rewrite is ever taken.

## Reference material worth pinning as fixtures

The 20 July field session's two DESYNC positions — pinned as DGTReconstructorTests' two field-desync fixtures, with Swift Testing PNG attachments so a failure hands you rendered boards rather than 64 sorted squares. The three DGT reference exports are pinned as PGNSerializerTests' bundled resources, committed, and now filed under `DGTStudioProTests/PGN/PGNs/`. M4's five lichess ECO volumes are the first data asset the *app* ships rather than the test target, filed under `DGTStudioPro/Chess/ECOs/`; the same rule applies to them — fetched from source, never transcribed, and not landed until tracked.
