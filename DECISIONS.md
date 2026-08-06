# DGT Studio Pro — Decisions

*Split out of `PROJECT-INSTRUCTIONS.md` on 6 August 2026 (M14), **verbatim and
append-only**. Nothing here was rewritten in the move: a decision re-worded
while being relocated is a decision silently re-decided, and this project has
caught smaller versions of that repeatedly.*

*Why the whole set moved rather than only the superseded entries: "which
anchors are still cited daily" is a judgement that needs re-making every
sitting, and a rule that needs re-judging is one this project replaces with a
mechanism wherever it can. Superseded entries (D22′'s two placeholders, D40′'s
sweep, D54′'s door, D38′'s merge half) stay in place, struck where they were
overturned, because the reasoning that produced them is the reason the
replacement is trusted.*

*`PROJECT-INSTRUCTIONS.md` is the owner of everything else and cites D-numbers
without restating them. **This file is now the owner of the next-free
number** — one owner, per the rule the header of the other document had to
learn twice.*

*Two checks belong to this split and are named in ROADMAP.md's M14 gate: the
milestone counter-grep now reads all three documents, and every D-number cited
in a source must resolve to an anchor that exists here.*

---

Locked product decisions #1–#8 and their interpretation flags were recorded in the retired roadmap document §2 and remain in force. The two that are load-bearing daily are restated inline where used, so this document stands alone: #1 — the physical board is truth and the live game is append-only (no takebacks; Discard lives in the inspector); #3 — * is never a finished result and never archives.

Old milestone and finding tags (M7.2, M-prs.1, F1–F9…) survive in code comments and below as provenance only — they identify where a decision came from; they schedule nothing.

D-numbers are sequential and never reused. Next free number: **D65′**. (D64′ minted 6 Aug 2026 for M13's layout — the last entry in this file.) (This line said D47′ until the 3 Aug audit — it had not been advanced since the M6 revision while the header above was; the header is the owner and this line now just repeats it.)

### D9′ — Player is a machine-managed @Model

Player { name, normalizedName, tagName } with optional PGN.whitePlayer / blackPlayer relationships (inverses whiteGames / blackGames, .nullify). One creation door: PGNStore.resolvePlayer(named:).

Identity is the display form lowercased with whitespace collapsed — the content hash's folding philosophy. Diacritics deliberately preserved ("Bücher" ≠ "Bucher"); first-seen casing wins; "?" and empty resolve to no player, never to a player named "?". Since M2 the row also remembers its first-seen **tag form** (D29′).

**The "no user CRUD" clause is discharged.** This decision recorded rename/merge/delete as "the future feature which justifies having a model at all instead of derived grouping". M5 built it — D37′, D38′ — and the justification held up in a way worth recording: the feature turned out to need a *stored* row not for the name it carries but for the **relationship**, because scoping a rename by `whiteGames`/`blackGames` is what keeps it from being a string sweep over the whole Library.

What survives unchanged: `resolvePlayer` is still the single creation door, and the retag door creates its target *through* it rather than constructing a row (pinned by `retagCreatesTargetThroughTheResolver`). **Orphans no longer linger — D60′ repealed that half** (5 Aug 2026). A row nothing references is deleted by every door that can strand one, because the PGN files are the source of truth and a linkless row is describing nobody. What survives from this decision is the part that mattered: one creation door, and identity that follows the tags.

**"A manual door for them, not a collector" was the right phrase and the wrong surface**, which the epilogue found and D40′ fixed. M5 attached it to the profile menu, where an orphan can never appear: this destination's rows come from a fold over `GameRecord`s, whose sides are the *resolved links*, so a linkless row is in no view mode and selectable through nothing. The door is now a toolbar sweep over the registry, still strictly user-invoked, and its confirmation dialog is the only place in the app an orphan's name is ever rendered.

Rejected: #Unique (can't express case-insensitive identity) and derived-only players (the model was wanted first).

### D10′ — pure cores over projection

PlayerStats, Glicko1, TagRule, and PairingRound consume GameRecord (a Sendable value) and never import SwiftData. Models touch the cores only at the PGN.gameRecord seam (PGN+GameRecord.swift, the LiveGame+Draft split pattern). Core suites run nonisolated with no fixtures.

GameRecord.chronologicalOrder — ascending date ?? importedAt, then importedAt, then contentHash — is the recorded ordering contract for every fold. A fold's output is only as deterministic as its order, so the chain down to a total tiebreak is the contract, not a nicety.

The effective-date rule (date ?? importedAt) belongs to GameRecord for the pure folds and to PGN.effectiveDate for view-layer sorts over models. Those are the only two implementations.

M4's shape exception restated: `ECOClassifier` and `GameClassification` take **moves and an injected table**, not a `GameRecord` — the second deliberate exception after `SpecialCheckmate`. A record is a projection of what the Library *knows about* a game, and classification is what produces that knowledge; putting movetext on `GameRecord` would have made every `PlayerStats` and `Glicko1` fold carry full movetext for nothing. `GameRecord` gained the **stored** result instead.

**M5 adds no core and deliberately so.** Retag is store surgery over relationships and stored hashes — there is no value-typed question hiding inside it, and the one piece that looked pure (the collision pre-flight) needs the Library to answer. It is suited through an in-memory container instead, the `PGNStoreArchiveTests` shape.

### D11′ — Rankings order is total wins; Glicko-1 is the secondary stat *(the **default** order since D62′, not the only one — the comparator and its argument are unchanged)*

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
- The dialog's spacing is named and HIG-derived (DGTConnectionView.Metrics): 20 pt margins, 12 pt sibling spacing, 4 pt caption, 260 pt info table and the 420 × 380 frame as sizing. **M5's sheets borrowed these three numbers by name-and-reason rather than by import** (the rename sheet still does; merge's went with D52′) — see D37′'s execution notes.
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

**Surface narrowed to the Library by D54′ (4 Aug evening).** Everything above is unchanged — the validator, the store door, the accept-whole rule, the splice refusal, the five identifiers. What changed is where the pencil is: M10 removed the Board's, live and review, and for one commit this decision's entire machinery was reachable from nothing. D54′ is where the door landed and why.

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

~~Two distinct placeholders, deliberately: unknownTag (?) means this game doesn't say; the section's em-dash (—) means there is no game to ask. Dates use ????.??.??. Each placeholder has its own preview.~~ **Superseded by D55′ (4 Aug 2026): one display glyph, the em dash, for every unknown.** The rest of this entry stands, and so does the display/export split above — which is what made the collapse safe to make at all.

Rows are driven by SevenTagRoster.allCases; labels are the PGN tag names verbatim, deliberately unlocalized. The action slot is a @ViewBuilder so each host keeps its own title and identifier. noGamePlaceholder stays a computed static var (generic types can't have stored statics).

M4's sibling, `OpeningSection`, is the same idea for the classified opening and differs twice on purpose: its **row count varies** (the seven tags are fixed by the *standard* while these rows are ours), and it had **one placeholder where the roster needed two** (an opening is not a PGN tag and has no `?` vocabulary). Since D55′ the roster needs one too, so that second difference is gone and `OpeningSection` turns out to have been right first — the em dash it chose for having no `?` vocabulary is the mark the whole panel now uses. Its constant stays its own: two sections' two decisions that agree today, which is the same reason it was separate when they disagreed.

### D55′ — one display glyph for every unknown; export keeps the PGN vocabulary

`RosterSummary.displayUnknown` — an em dash — is what every display surface shows for an absent value. `?`, `????.??.??` and an archived `*` all fold to it. **`tagValue(for:)` is untouched and must stay that way.**

**Shipped inside M10 and given a number here**, because it overturns D22′'s two-placeholder rule, which was a recorded decision. The collapse was argued properly at the declaration; what it did not do was reach either document or the four tests that pinned the old contract — see below.

**The argument, which is a use argument rather than a modelling one.** D22′'s distinction is real: `?` means "this game doesn't say" and the em dash means "there is no game to ask". It is also invisible in use. A reader sees one inspector at a time and cannot tell which question a glyph is answering, while four spellings on one panel — `?`, `????.??.??`, `*`, `—` — read as four different *kinds of problem*. One mark says "nothing here" once. The em dash rather than a hyphen (which was tried for one revision) because it is visibly a placeholder rather than possibly a value, which matters most where a short mark sits beside `1-0`.

**The split is what makes it safe.** D24′ pins export to the reference files byte for byte, where an unknown *is* `?`, a missing date *is* `????.??.??`, and `*` is a real result token. `subscript(_:)` folds; `tagValue(for:)` does not. Two near-identical switches sitting in one type is exactly the duplication a future reader would collapse, so the separation now has its own pin (`exportVocabularyIsUntouchedByTheDisplayFold`) rather than resting on the reference-byte tests noticing indirectly.

**`isRecording` is the one genuinely new piece of state, and it is a display flag rather than a fact about the game.** The same `*` means two things: on the live projection it is *true* — the game is ongoing — while on a stored game it arrived through the import door, which admits `*` deliberately (Decision #3 refuses it only at the archive door), and there it means "this file didn't say". Only the constructor knows which, so only the constructor sets it: `init(_:result:)` passes `true`, the `PGN` projection never does. A `var` with a default rather than a `let`, so the synthesized memberwise init keeps its shape for every fixture and preview.

**What this decision costs, recorded rather than discovered:** a game whose Event genuinely *is* the character `?` is now indistinguishable from one with no Event. Accepted at one Mac and one reader, and it is the honest price of the fold — `shown(_:)` compares against `unknownTag` rather than parsing intent, and no parse could do better.

Rejected: **keeping D22′'s two placeholders** (it is the more precise model, and the precision is unobservable — the reader has one panel, not two); **a hyphen** (shorter, and it can be mistaken for content beside `1-0`); **folding `tagValue(for:)` too** (one switch instead of two, and it puts an em dash in a file the ecosystem reads as fact — D24′'s whole subject); **leaving `*` unfolded everywhere** (truthful for live, and it makes an imported unknown look like a live game on the one surface that shows both).

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

`.checkmateType` — spelled `.matePattern` until 5 Aug 2026, when the user-facing vocabulary became **Checkmate Type** everywhere and the motif names went title case ("Back Rank", not "Back rank") — is the first field whose subject is an optional **enum**, taking a new `Kind` case with `equals` / `notEquals`. It inherits D30′: an absent type matches neither direction. A nil type means either "classified, and it's an ordinary mate" or "not classified yet", and the rule cannot tell them apart — reading nil as "not smothered" would make "checkmate type is not smothered" quietly true for every unclassified game.

**The rename kept the stored raw value, and that is the only part of it that could have broken anything.** `Field` is `String, Codable` and its raw values are encoded into every saved tag's rule blob, so `case checkmateType = "matePattern"` is hand-written for the reason `InspectorSection`'s raw values are: a rename that reads as a refactor must not reset stored state. Letting the implicit value follow the Swift name would have dropped the rule from every tag that used it — *silently*, because this decision's own defaulting decoder is built to tolerate a missing key rather than fail loudly. Pinned by `theCheckmateTypeFieldKeepsItsStoredRawValue`, asserted on the literal, which is one of the few places a hard-coded string is the correct thing to test.

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

**Merge removed 4 Aug 2026 (D52′, surface simplicity).** The retag-not-link-surgery finding above outlives the feature: it constrains any future door that moves players between rows. Delete-is-orphan-only and the D40′ sweep stand untouched.

### D52′ — merge-into is removed, whole

By decree, 4 Aug 2026 evening; motive on the record: **surface simplicity** — the profile header's ellipsis menu existed to hold this one item (D40′ had already taken Delete out of it), and a menu of one is chrome for a verb rename already speaks. Removed: `PGNStore.merge(_:into:)`, `MergePlayerSheet` (file and its three-identifier registry family), the actions menu and its two identifiers, `PlayerEditor`'s second case (the enum collapsed to a `RenameRequest` struct — a one-case enum is a struct in costume), the same morning's `RetagRefusal.Operation` (a full same-day circle, noted at the site for the next shared-refusal door), and the four merge pins.

What stands and why it suffices: a duplicate spelling is fixed by **renaming** the misspelt player to the canonical tag — the same `retag` door merge called, relinking by resolution and refusing collisions identically (D39′ still guards it, and the batch-internal collision source stays reachable through rename). D38′'s core finding — link surgery without tag rewriting is undone by `applyEdit`'s unconditional re-resolve — survives at its anchor. The D50′ cascade and the D40′ sweep keep the registry clean without a merge.

Rejected: **keeping the store door test-only** (a door with no surface is the D40′ lie one layer down); **moving merge to Assumed-never** (nothing about the concept is forsworn — it is removed as surface, and the mechanism any future version needs is the door rename still uses).

**Postscript, 4 Aug evening (D53′).** This decision's own rejection list contains the sentence "a door with no surface is the D40′ lie one layer down" — written the same evening M10 removed the rename pencil and left exactly that. `retag` kept its surface for a few hours and lost it, and the argument that had just been used to justify *deleting* merge sat one paragraph away while rename quietly became the thing it warned about. Neither this anchor nor the milestone noticed, because the two were written by the same hand on the same night and each was individually right. That is the case for a sweep between milestones stated in one paragraph.

### D53′ — Get Info is one window over three subjects, and the app's rename door

M10's centrepiece, recorded here rather than where it shipped because it shipped with no record at all.

**The window.** `GetInfoRequest` is an enum — `.game(PersistentIdentifier)`, `.live`, `.player(key:)` — feeding one `WindowGroup`. One group and not three, twice over: it pays D46′'s wrapper cost once instead of three times, and it makes the three Get Info windows *one group*, so macOS tabs them with each other rather than with the boards. Two rosters side by side is a comparison; an info window tabbed behind a board is a window you lost.

**The wrapper is the trap worth keeping.** `openWindow(value:)` routes by the value's **type**. The main `WindowGroup` is declared `for: PersistentIdentifier.self` with five call sites depending on it, so a second group over that type would make all five unspecified — and unspecified here means opening a game from the Library opens an info window. D46′ minted `EvaluationGraphRequest` for exactly this; D53′ is the second instance, which is what makes it a pattern rather than a quirk.

**`.live` carries nothing, and that asymmetry is load-bearing.** A live game is not in the store and has no identifier until it archives, so the request is an enum rather than a struct with an optional id — an optional would make "no game" and "the live game" the same value. It resolves from the session instead, which is also why the window observes `session.liveGame` rather than resting on `.task(id: request)`: a `.live` request never changes, so without that observation the window keeps rendering a retained `LiveGame` under "Recording" long after it archived. The unavailable state's doc claimed to cover "a live game that ended" while nothing could produce it — a claim no caller was positioned to contradict, D44′'s species, and the fix is the observation rather than a narrower comment.

**Rename is here, and this is the half that discharges D37′ rather than replacing it.** The player form already had D37′'s exact arrangement read-only — tag above, derived display form below, game count in the next section — so the whole change is the top row becoming a `TextField`. The derived line updates live as you type, which is D37′'s move of turning D23′'s one-way rule into the form's own explanation. Seeding is `tagName ?? name` (D29′'s fallback); seeding from `name` would put a display form in a field that stores a tag, and the first commit would write "Bera Şenol" into every affected game's `[White]`.

Commit is **on Return only** — not per keystroke, not on focus loss. Each commit is `retag`: a rewrite across every linked game with an MD5 and a re-resolve, in one transaction. Two guards sit ahead of the store door: an empty tag reverts rather than reaching `.emptyTag`, and an unchanged tag is a no-op rather than a full rehash to write bytes already stored — the store's own fold-equivalence check would accept that silently, which is exactly why it is worth stopping, since "nothing happened" and "everything was rewritten identically" look the same from outside. D39′'s refusal alert moved here whole and reverts the field, which the sheet never had to do because it closed.

**The cost statement stopped being prose.** D37′'s sheet said "Rewrites the name stored in 42 games" because nothing else on screen did. Here the game count sits two rows below the field permanently, which says the same thing without a sentence that can go stale against the number beside it.

**One behaviour did not survive the move, recorded rather than left to be found.** `PlayersDestination.rename` followed a successful retag with `selectedKeys = [newKey]`, because a stats key is derived from the name. A separate window cannot reach a destination's selection, so a rename performed while Players is open now clears the selection rather than following it. Accepted: the row is one click away under the name you just typed, and it is the price of one door serving three destinations instead of a pencil serving one.

**The Board's door was minted before it was built.** `getInfoBoardMenuItem` existed in the registry and `GetInfoWindow`'s doc said "the Board's copy lives in `GameNavigationCommands`". It did not — zero Get Info references anywhere in `Game/` — so `.live` was constructible and nothing constructed it. Built now, as the Game menu's item, which forced one shape note: a `Commands` scene has no `openWindow` any more than it has a `modelContext` (`DiagnosticsCommands` records the latter), so the item publishes a trigger binding and `BoardDestination` opens the window — `SmartTagCommands`' arrangement, third use. The trigger is published as nil when the front tab has no subject, so the item's `disabled(_:)` reads a condition producible both ways: the D40′ check applied at minting rather than at the next sweep.

Scope, stated because the first version of this window's doc did not and was wrong for it: it called itself "the one editable surface behind every inspector's subject" while every row in all three forms was a `LabeledContent`. It edits **one** thing — a player's tag. The game and live forms are read-only, which is a current fact rather than a permanent one, and the doc now says so.

Rejected: **three request types and three scenes** (no wrapper needed, and it tabs three windows apart and pays D46′'s cost three times); **a sheet or popover** (D46′'s field-proven finding taken as settled — a companion surface that dismisses when you click the thing it describes is not a companion); **leaving rename on the Players pencil and making Get Info read-only** (smallest, and it keeps five pencils where the point was to stop having five); **a second `WindowGroup` over `PersistentIdentifier`** (no new type, silently breaks five existing calls).

### D54′ — movetext is read-only everywhere except the Library *(superseded by D59′ — the door is Get Info's Move Text tab; this entry stands for the Decision #1 argument that put it off the Board)*

M10 removed the Board's Edit Moves pencil and left `onEditMoves` wired from `BoardDestination` to nothing, with a site comment saying the situation "needs a decision rather than this comment". This is the decision: **read-only on the Board in both branches; the editor is the Library's.**

**Live was always the stranger of the two.** Decision #1 says the physical board is truth and the live game is append-only — no takebacks, ever — and an editor that could rewrite movetext mid-game was the one surface in the app that could contradict the board it mirrors. That is not a preference; it is the locked decision, and the editor had been quietly outside it since D18′.

**Review is the weaker case and lands the same way.** A game on the board is a game being *read* — the scrub position, the evaluation bar, the arrow keys are all reading instruments — and the Library is where a game's bytes are managed. Splitting the verb across both destinations would mean two doors into one transaction, which is the shape D40′ and D52′ both argue against.

**Where it went, and why that header.** The Library inspector's **PGN section**, whose body renders the movetext, so the pencil is adjacent to its subject exactly as `InspectorEditButtonView`'s own argument requires. The roster header would have been the wrong neighbour — that section is identity and tags. The label is "Edit Moves" rather than "Edit PGN" because the editor is D18′'s movetext validator and touches no tag; the label is the only thing separating the two readings of a pencil in a header called PGN, which is why it names the narrower one.

**Nothing about D18′ changes.** The replay validator, accept-whole-or-reject-whole, the per-ply error, the splice refusal, the re-classification on accept, `PGNStore.applyMovetextEdit` and the five `movetext.editor.*` identifiers are all untouched. Only the door moved. What did *not* move is the Board's cache rebuild: `applyEditedMovetext` used to nil `tabState.boardGame` and reload, because the moves had changed under a cached `Game`. The Library has no such cache, and the recorded consequence is that **a Board window already reviewing an edited game keeps showing the pre-edit moves until it reloads** — accepted at one Mac and one reader, named here so it is a decision rather than a surprise.

Registry consequence: `board.editMoves` **removed** with the affordance it named, successor `library.editMoves` — the `players.inspector.deleteItem` and `library.inspector.pgn.disclosure` precedent, and this one is a rename wearing a removal's clothes. `onEditMoves` is gone from `BoardInspectorView` entirely rather than kept as a seam: a request no destination will answer is the thing this decision exists to stop.

Rejected: **restoring the pencil in review only** (keeps D18′'s validator earning its keep on the Board, and it puts an editing verb on the app's one reading surface); **restoring it in both branches** (a straight revert, and it re-opens the Decision #1 contradiction above); **taking the machinery with the decree** — deleting `MovetextEdit`, the store door, the sheet and D18′'s whole validator (the largest, cleanest deletion, and it discards a suited replay validator because its *button* was in the wrong place); **leaving it wired and scheduling the answer** (the status quo, and the status quo was a closure nothing called).

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

**The decision, since removed — see D60′.** Delete moved off selection and onto the Players toolbar, as a Maintenance menu holding **Delete Unused Players…**, disabled when there were none. That surface is gone: collection is automatic now, so the item could never enable, and this decision's own rule about un-producible guards is what retired it. The reasoning below stands as the record of why orphans need a door at all when they cannot be selected — which is still true, and is now answered by having no door rather than a special one. Orphans were real and unrenderable through the index — deleting a game nullified its links and the player's row stayed (D9′'s no-GC rule, as it then was). Both halves of that have since been closed from the other end: D50′ made a game deletion collect what it strands, and D60′ made every door do it. The alert lists them by name, capped at five, because it is the only place in the app an orphan is ever shown and a bare count would ask Bera to approve deleting things he has never seen.

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

**Two warnings remain, waived at the declaration.** `Binding(present:)` captures a non-`Sendable` `Binding<T?>` in `Binding.init(get:set:)`'s `@Sendable` closures. `T: Sendable` would fix it and lock out the `@Model` call sites, which are most of the seven; the alternatives are opt-outs this codebase has none of. The diagnostic stays a **warning** under mode 6 rather than becoming an error, which reads as the compiler treating it as framework-side friction rather than a defect here. The 2027 SDK's `.alert(item:)` / `.confirmationDialog(item:)` retire every call site and the helper with them (the figure here read "seven"; it was eleven when checked on 6 Aug 2026, and the count belongs in `grep -rn 'Binding(present:' DGTStudioPro/` rather than in this sentence), so the waiver expires by deletion rather than by being lifted.

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

~~**The chevron leads the actions slot**~~ — **reversed 2 Aug 2026** (`772ecb3`, the pass that also widened `actionsInset` 10 → 12): the chevron now **trails** the actions, so the disclosure sits at one fixed distance from the edge in every section whatever the arity before it, and the fold affordances read as one column down the inspector. The accepted cost is the original order's whole argument — action glyphs are no longer the rightmost thing in sections that collapse. As first decided, the chevron led, which is what the Library's bespoke disclosure had claimed to do and did not: its doc read "Leading of the copy button, which keeps the *action* glyph rightmost" while the `HStack` listed copy first and the chevron second. The 3 Aug audit found the reversal had recreated that exact defect one level up — the body comment still asserted "leading, finally executed" over an `HStack` listing actions first — and reconciled docs-follow-code; the comment at the site now carries the new order and its price.

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

**The 4 Aug 2026 round trip — recorded whole, because it is the strongest evidence this decision will ever have.** By request, the magnifier went popover: split by host at midday (Library popover, Board window — the popover rejection above was Board-scoped reasoning applied app-wide, and the Library has nothing to scrub), then popover everywhere by evening once the two presentations had been seen side by side, the window deleted whole with its request type, scene and floating delta, the dismiss-on-step price accepted in writing with eyes open. **Reverted the same night: the price that read fine on paper was not livable in use.** The window returned everywhere, exactly as this decision originally built it — so the rejection list above is no longer argument but field test, and the next time a popover looks tempting here, this paragraph is the record that it was tried, whole, for a day, by the person it would serve. What the day-trip paid for and kept: `EvaluationGraphContent` briefly served two presenters and proved the reading can't fork from its presentation; the reversal cost only call sites because of it.

### D47′ — pieces animate under proven identity; the mirror never guesses

M6, whole. One piece layer above the square grid, one pure resolver deciding what every piece animates *as*, and one rule doing all the work: **identity is proven or absent, never guessed** — and the animation contract falls out of identity alone, because a persisting key glides while a churned key can only fade.

**The goal lost to the constraint, and recording why is most of the decision.** The roadmap's goal line said "pieces glide on the mirror"; its constraint line said the mirror renders the *physical* board and animation is "never speculation". Those cannot both hold for the ordinary move: a lift-then-place renders as two truthful states with the piece honestly in a hand between them — there is no jump to glide, and manufacturing one means either drawing a piece the board doesn't have (the mirror lying) or guessing that the pawn appearing on e4 is the pawn that left e2 (speculation, which is `DGTReconstructor`'s job precisely because it is not trivial). The constraint wins. What the mirror does instead: **proven moves glide, everything else fades, and a fade is the *correct* rendering of a piece leaving for a hand** — not a degraded one.

**Identity has three sources, in order.** *Parity*: a square whose physical piece equals the game's last committed position vouches for the tracker's identity there — per square, not per board, so one lifted piece doesn't strip the other thirty-one. *Early reconstruction*: for what parity can't explain, the resolver runs the **same** `DGTReconstructor.reconstruct` the session will settle with — full-position verification included — and keys a recognized move's landing squares with the *origin's* identity. That is proof, not speculation: the reconstructor answers only when exactly one legal move explains the whole board, and the session's own commit re-derives the same answer 300 ms later. A slid pawn, a snappy capture, a fast castle — anything whose origin and destination change inside one render — glides under its real `PieceID` before the game has committed it. *Anonymous*: everything else keys `(square, piece)` — stable while the piece stands still, incapable of gliding, exactly the right capability for a piece nobody can name.

**The hand-off is invisible, and the design balances on it.** The identity early reconstruction hands out is the identity `PieceTracker.applyMove` will put on that square at commit — origin's ID onto destination — so the proven render and the post-commit parity render carry the *same key* and the eye sees one uninterrupted piece. Pinned by `theProvenIdentityIsStableAcrossTheCommit`.

**The occupancy property is the invariant, restated as a function.** The resolver's output is the rendered position, verbatim — every occupied square exactly one entry, no unoccupied square any. "The mirror renders the physical board. Always" stops being a doc sentence and becomes `verified(_:against:)`, asserted across every fixture in `PieceIdentityTests`. The feared mis-key (the reason the mirror passed `.empty` for four months) is structurally out: a square whose physical piece disagrees with the game's never inherits the stale identity — pinned by `aForeignPieceNeverInheritsTheSquaresOldIdentity`.

**Mechanism: a layer, not `matchedGeometryEffect`.** MGE pairs an insertion with a removal across two views — a namespace through 64 clipped, overlaid cells — and has no vocabulary for "this change must not animate", which the board-dump case needs. Identity churn expresses it for free: a dump re-keys wholesale, so thirty-two pieces fade in rather than flying from wherever they last stood. The layer sits between the squares and the wood grain (pieces keep the texture they always rendered under) and inside the `.clipped()` (a glide can't escape the grid). Squares keep chrome, highlights, accessibility identifiers, and the ghost — which therefore *cannot* animate, satisfying that constraint by construction rather than by flag. `PieceGlyph` gives the glyph one home for the layer and the ghost both, killing the 6%-padding twin at birth. The glide was 0.22 s — under the 300 ms quiescence, so a glide had always finished before the settle that confirms it. **That sentence stopped being true on 2 Aug 2026, and it is corrected here rather than quietly rewritten**, because it is the *fourth* species in a new costume: a claim that was true when written and decayed when something adjacent changed. The duration became a user preference in the same burst that this document recorded feature-by-feature without re-reading the anchors those features touched. `BoardPieceLayer.durationRange` is **0.1–1.0 s, clamped on every read**, with 0.22 as the default — a range that deliberately does *not* stop at the quiescence window, so above 0.3 s a glide can still be in flight when the settle confirms the move. The consequence is **visual only**, and the declaration argues it properly at the site: the animation retargets mid-flight, and nothing about commit timing reads the animation. Accepted as the price of making the speed a preference. Worth one more line, because it is the transferable part: the *code* corrected itself at the declaration and this anchor did not, which is the reverse of the usual failure — docs-follow-code works only if somebody re-reads the decision the code just narrowed, and the burst that shipped the preference had no reason to open D47′. Reduce Motion drops the animation, not the layer.

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

### D49′ — an unexplained board earns one dump before recovery does

Closes the 1 Aug audit's C4. The field-update stream is not lossless — the framer's MSB resync exists precisely because adapters drop bytes — and one lost update leaves `physicalBoard` permanently wrong by one square, after which the next quiescence reconstructs against a `before` no legal move reaches, `.unresolved` fires, and the recovery surface guides Bera to "fix" a board that is already correct. The well-built checklist pointing at the wrong thing was the audit's whole case.

**The gate: first divergence asks, second escalates.** `settlePlaying`'s `.unresolved` arm routes through `escalateOrResync`: one shot per divergence requests a full dump through a new settable hook (`session.requestBoardResync`, wired once in `App.init()` to `connection.requestBoardResync()` — `sendBoard` doesn't change the board's mode, which is what makes the strategy free). The dump replaces `physicalBoard` through the existing `.boardDump` handling, publishes, settles fresh — and a board the *dump* also can't explain escalates into recovery having spent the debt, so recovery is always reachable. Any explained settle retires the debt (per divergence, not per game); `startNewGame` and `discardGame` clear it; `clearPlayingOverlays` deliberately does **not** (it runs at the top of every settle, and clearing there would re-arm the dump forever). The F5 commit-refused guard still enters recovery directly — an internal logic divergence is not a lost-update symptom, and a dump has nothing to say about it.

**Strictly additive.** Nil hook — headless suites, unwired builds — means `.unresolved` enters recovery immediately, exactly as before; the fire-and-forget send means a dead port cannot strand the gate (the next unresolved settle escalates regardless); D13′'s alert fires only at real recovery, so the resync attempt is silent. Pinned by four session tests including the nil-hook contract from the side that would break.

Rejected: **a periodic dump every few seconds** (the audit's optional extra — machinery running always to cover a case the on-demand dump already answers; revisit only if field sessions show divergences the one-shot misses); **routing the F5 guard through the gate** (above); **retrying the dump on send failure** (the escalation path is the retry).

### D50′ — deleting a game collects the players it strands

Landed in `b972b5a` (3 Aug), recorded 4 Aug — the burst's recording debt, paid late. **This narrows the no-collector half of D9′ for exactly one cause: a game deletion the user just confirmed.** Everything else about no-GC stands, and the D40′ sweep survives as the user-invoked backstop for rows orphaned before this landed.

**Why this works where the roadmap's old "delete-player = nullify + delete" could not.** `.nullify` leaves the games' seat tags intact, so the next `backfillPlayerLinks()` resolves the same tags and mints the row straight back — D40′ recorded that as the reason per-player delete had to be orphan-only. Deleting the *game* takes its seat tags with it: nothing is left to re-resolve, so the row stays gone. The same mechanism, read in the direction it actually runs.

**The driver was a counted claim coming up false.** D40′ said the sweep's alert is the only place an orphan is ever rendered. Counted at the site (`PlayersDestination.sweepMessage`, the correction kept visible rather than rewritten): four `@Query`s stand over the registry and two of them render unfiltered lists, so every orphan was being offered as a New Game seat and as a merge target. The cascade is what stops new orphans reaching either picker; filtering both pickers instead would be the twin-read-site pattern with a liveness rule inside it.

Execution, per the door's own doc: `playersOrphaned(byDeleting:)` computes the cascade **before** the first `modelContext.delete` and applies it after — asking afterwards bets on SwiftData having already propagated the nullify, and "the array still looks fine" is the trap named at the site. One transaction, one save; the singular door forwards to the batch door so the cascade has exactly one implementation. Pinned in `PGNStoreRetagTests` (the prospective-orphan fold and the collect-on-delete round trip).

Rejected: **strict no-GC with filtered pickers** (two more sites asking "is this row real" — the pattern D40′ exists to kill); **a launch-time GC pass** (runs unasked at the one moment nothing can explain what vanished); **collecting inside `deleteOrphanedPlayers` instead** (that door acts on a snapshot the user approved; widening it to unapproved rows breaks its "deletes exactly what was confirmed" contract).

### D51′ — the UI test target is deleted

`b2f3c32` (committed 4 Aug; the tree's own comments date the act 3 Aug, and `b972b5a` checkpointed it by name). **The suite had crossed from protecting work to blocking it.** The proximate fight is § Zero: three Players flow tests failing with the pencil and menu unresolvable by identifier while the identifier one line away resolved fine — the shadowing explanation disproved, the cause never found, the hierarchy instrument planted and never affordably harvested. Behind it, the hermetic-launch saga: persisted window state turning post-crash launches into restoration launches that restored zero windows, defeating `.defaultLaunchBehavior(.presented)`, with the File ▸ New Window fallback carrying every such run eight seconds late. The 2 Aug hermetic-windows agreement was minted against that and retired the next day with the suite. One person, one Mac: a witness that costs more runs than it protects is net negative, and ⌘U plus the manual checklists were already carrying the load.

**What went with it**, listed so nothing reads as an oversight: the target and its one source (884 lines); `UITestSeed` and the seeded in-memory container branch in the App — every real launch always took the plain path that remains; `SeedGameName`; the hermetic-windows launch argument; and the register's every UITest witness, each affected row now naming its manual check, edited in place below.

**What deliberately stayed.** The ~143 identifiers and the registry, on a stated bet the `AccessibilityID` header owns: nothing automated consumes them today, they are what a future suite or an AX audit needs on day one, and sweeping them is a large mechanical diff for no functional gain. The String-only signature rule stays with them — re-typing sixteen signatures buys type safety nothing checks. **What this weakens, stated rather than implied:** identifiers are no longer a tested contract; a rename or removal breaks nothing at any automated layer, so registry discipline is carried by the sweep's grep alone.

**§ Zero closes unresolved.** The site comment in `PlayersInspectorView` carries the expectation forward: a future suite should expect the same three failures for the same unfound cause.

Rejected: **keeping the suite disabled-but-compiling** (a check that always passes by never running — the `.disabled(…)` lesson as a whole target); **fixing § Zero first** (every diagnostic run cost the same unreliable launch the saga was about); **trimming to a smoke test** (the launch *was* the flaky half, and every test pays it).

### D56′ — Open takes the set, and is the one bulk action that confirms on count

By request, 4 August 2026 (late). `GameActionsMenu.onOpen` becomes `([PGN]) -> Void`, joining the other three; Open leaves the singular branch and grows a counted plural; the list's double-click and ⌘O answer the same question the same way; and above **ten** games the destination asks first.

**The sentence this reverses was true and reasoned to the wrong end.** It read: *"Single-game only, and that is a product decision rather than a limitation: one window per game, so Open over a selection of nine would mean nine windows or an arbitrary pick."* Both facts hold. Nine windows *is* what it means — and that is Finder's answer to the same gesture, not a failure mode. The arbitrary pick was the real hazard, and the decision had been protecting against it by refusing the whole verb rather than by resolving the set, which is the same shape as declining a feature because one of its two outcomes is bad. Worth recording rather than quietly rewriting, because the site doc was **well argued and wrong**, which is the hardest kind to catch: nothing about it reads as unconsidered.

**The arbitrary pick was real, and it was live in exactly one place.** `LibraryListView`'s `primaryAction` did `ids.first` — over a multi-selection, "some row, in `Set` order", a game wearing another game's face. That is the defect `selectedPGN(in:)` refuses one file over and the columns detail refuses one file the other way, and it survived because a double-click on a multi-selection is a gesture nobody makes deliberately. `primaryAction` hands over the selection when a *selected* row is double-clicked and the single row otherwise, so Finder's rule arrives for free the moment the closure stops taking `.first`.

**The threshold is the only genuinely new rule, and Open is the only action in the destination that needs one.** Delete confirms because it destroys. Analyze does not, because the queue has a visible progress item and a Stop All. Export does not, because it writes into one folder the user chose. Open has *neither* property — windows are not a queue, there is no Stop All for them, and closing four hundred tabs is manual work with no undo. That gap is what ⌘A turned from theoretical into one keystroke away, the same hour ⌘A landed: **⌘A then ⌘O is the whole Library**. Ten is a judgement call and is documented as one at the constant rather than given a fabricated derivation — what it is calibrated against is that the sets you *mean* to open (a rivalry, a round, a morning) are single digits while the sets that arrive by accident are the whole Library, and the threshold sits in the wide empty gap between those two populations. The exact value matters much less than that one exists.

**Two things the window system already gave us, which is why the plural is safe at all.** `openWindow(value:)` **dedups** — re-opening a game that has a tab focuses it rather than making a second — so a set containing already-open games opens fewer windows than its count, and the dialog says so rather than promising a number it cannot keep. And tabbing is the user's own "Prefer Tabs: Always", unchanged and unconsulted here; this decision adds no window policy, it just stops refusing to use the one that exists.

**Get Info is now the only singular item on the menu, and that is a fact about D53′ rather than a leftover.** Its window resolves one subject; a set has no roster, no opening and no result to show. Named at the site, because after this change "why is *this* one still gated?" is the obvious question and the answer is not the rule Open just left behind.

**Where each host stands, since the adaptations differ and the differences are load-bearing.** `LibraryColumnsView` forwards Analyze / Export / Delete with a per-game `forEach` and deliberately does **not** do that for Open: those fan out to per-game doors, while Open's door owns the threshold, and a host calling it N times would walk straight past the guard. `LibraryIconsView` spells Finder's double-click rule by hand (`open(_:)`) because a grid has no `primaryAction` to inherit it from, and skipping it would mean right-clicking a rubber-banded sweep opened six while double-clicking inside that same sweep opened one. `LibraryGalleryView` needed the signature only — its selection is single by construction, so the rule degenerates. `LibraryGameCardView` needed nothing: its closures are argument-free and its menu always holds one game.

Rejected: **no guard at all** (consistent with Analyze and Export, which are unguarded — and both have a recovery path this does not); **a silent cap at N** (never shows a dialog, and does something other than what was asked without saying so, which is the failure mode this document keeps naming); **keeping Open singular and adding a separate "Open All" item** (leaves the arbitrary pick in `primaryAction`, and puts two verbs on one menu where the count already distinguishes them); **confirming on consequence rather than count** (there is no consequence to describe — the dialog is about volume, which is why it is not `role: .destructive`).

### D57′ — Get Info is two tabs, and the Details tab is where an archived game's roster is edited *(three tabs since D59′)*

By request, 4 August 2026 (late). The game form becomes `TabView { Details, File }`; the seven roster tags become native controls committing one field at a time through `PGNStore.applyEdit`; Result is checked against the final position by `MovetextEdit.validate`; and the Board review inspector's **Edit Info pencil is removed**.

**The split is by authorship, not by topic, and that is the whole reason it is legible.** Details is what the reader wrote and can rewrite — which is exactly the **nine** tags export puts on disk (D24′): the Seven Tag Roster, then Board, then TimeControl. File is what the app derived, stamped or measured: import time, content hash, resolved player links, classification, analysis coverage. Nothing on File is editable and no comment is needed to say so, because nothing there is a value a person holds an opinion about.

**Amended the same evening, and the amendment is this entry's most useful paragraph.** As first shipped, Details held **seven** tags and File held `board` and `timeControl` under the argument that they are "equipment facts the archive door stamps" — *while this very entry's sentence above said "the nine tags"*. The sentence and its own next sentence disagreed. Both read well; neither is checkable by any grep this project runs; and the thing that caught it was Bera opening the running app and asking for the two rows to move. The argument was also wrong on its merits: `board` is stamped by D28′ only for games *played* here, neither is stamped for an imported file that carried them, and both are exported tags — so a window whose Details tab is defined as "what lands on disk" has to hold all nine or the split has no rule behind it. Recorded rather than quietly fixed, because it is the fourth species of unchecked claim (a true-sounding statement about a **set**) appearing inside the decision that defines the set, one message after being written.

They keep their own `Equipment` section rather than joining the roster's, because `SevenTagRosterSection` renders from `SevenTagRoster.allCases` precisely so the standard cannot quietly grow (D22′), and one section would make the roster look like it has nine members. Both clear to nil rather than reverting, unlike Event and Site, and the model is what makes that non-arbitrary: they are `String?`, and D24′ already writes an absent one as `?` / `-`. "No board" is a value a game can honestly have; "no event" is not.

**Native controls are a correctness argument before they are an aesthetic one.** A `Picker` over `GameResult` cannot produce a result outside the enum; a `DatePicker` cannot produce 2026-02-31. Making each row the control its tag actually *is* deletes a class of validation rather than performing it, which leaves exactly one rule that no widget can know — whether the final position agrees with the result — and that one is checked. The date row carries its own Clear / Set Date… arm because a bare `DatePicker` cannot express nil and nil is a real, common, exportable state (`????.??.??`).

**Per-field commit, with two guards that are the point.** Return or focus loss, one `applyEdit` per field. An unchanged value returns before the door: `applyEdit` would accept it silently — re-resolve, recompute the same MD5, rewrite the same bytes — and "nothing happened" and "everything was rewritten identically" are indistinguishable from outside, which is `commitRename`'s argument arriving at a second site. An emptied Event or Site reverts, because D24′ prints all nine tags always and an unknown is `?`, so `""` is the one value that exports as neither a name nor an unknown. Seats and Round may legitimately empty and have somewhere honest to go: a seat clears to `?`, which `resolvePlayer` reads as no player (D9′), so clearing unlinks rather than minting a player named `?`; Round clears to nil, which D31′ already exports as `?`.

**Focus loss commits here and deliberately does not on the player tab — same window, two rules, and the difference is blast radius.** A game edit writes one row. A rename rewrites every game the player appears in (D37′), so committing that because the window lost focus would make clicking away a forty-game rewrite. Stated at both sites rather than reconciled, because reconciling them would mean picking one and being wrong for the other.

**The two seat rows are the most dangerous thing in the window and they look like the least.** Editing White on Details rewrites *this game's* tag and `applyEdit` re-resolves the seat, so the game moves to a different player and may mint one. Editing the field on the player tab rewrites *every* game that player appears in. Same-looking text field, same-looking name, blast radius of one versus forty. The derived "Shown as" line under each seat — rendered only when it differs from the field — is the only thing on screen that says the value is a tag rather than a name.

**Result reuses D18′'s validator rather than restating it.** The stored moves are canonical and legal, so replaying them can only fail on the result arms: the trailing-`#` check, Decision #3, checkmate-forces-the-winner, stalemate-forces-a-draw. A second, smaller "is this plausible" check here would be two spellings of one question and the smaller one would drift. A resignation, a draw by agreement, a win on time all stay freely settable — anything a non-terminal position cannot disprove — which is most real corrections. `*` is not offered: the validator refuses it outright, so an imported `*` game can be **decided** here and cannot be set back, and that asymmetry is correct rather than a gap.

**The pencil's removal completes a sequence rather than starting one.** `board.editMoves` went at M10 with `library.editMoves` as successor; `players.inspector.rename` went at D53′ with `getinfo.player.tag`; `board.editInfo` goes here with the `getinfo.game.field.*` family. All three are a pencil on a panel giving way to a door on the thing itself, which makes them one decision arriving in instalments. **The Board now presents no editor at all** — `BoardEditor` and `activeEditor` are gone, and the enum's own doc is the epitaph worth keeping: it argued for staying an enum at one case because "a second editor is one case away", and the traffic went the other way until it reached zero without ever reaching two. The argument was sound; only the forecast was wrong.

Registry: **140**, up from 138 — three added (`getinfo.game.details`, `getinfo.game.file`, `getinfo.game.field.*`), one removed. `getinfo.game` now names the tab container, which is a widening rather than a rename and so takes no successor entry.

Live keeps `EditLiveGameDetailsSheet` and gains no File tab. Both for the same reason: a live game has no stored row, so there is nothing to hash, classify or stamp, and its roster is written through the session and the draft sidecar rather than through `PGNStore`. Different target, different door — and a File tab there would be five sections of em dashes describing the archived game it is going to become.

Rejected: **keeping the Board pencil** (a fourth surface editing the fields two others already edit, which is the situation D53′ was written to end); **Save/Revert buttons instead of per-field commit** (one transaction for the form, and it gives one window two commit models plus an unsaved-changes state a companion window can lose when you click away); **Result read-only** (matches the archive sheet's Decision #4 rule, and leaves a wrong result with no door at all); **Result editable unchecked** (simplest, and it lets `1-0` be recorded on a game the board shows as mate for Black, which then exports as fact and rots the Glicko fold silently); **tabs on the live and player forms too** (uniform, and both would be a tab of em dashes or a tab of one section).

### D58′ — the library index is read off the filename, and it is the weaker of two identities

By request, 4 August 2026 (late). `PGN.libraryIndex: Int?` — the ordinal a game's PGN file carries on disk, the `47` in `47. Bera Senol vs Christophe Heylen.pgn`. Parsed at the import door, shown as the Library table's leading column and on Get Info's File tab, and used by export in place of the batch position. The MD5 content hash is unchanged and remains what the app actually dedupes, links and reasons with.

**The direction is the entire decision, and the request corrected the question.** This was scoped as "how should the app assign a stable ordinal" — stored high-water mark, `max + 1`, or derived position — and all three were wrong, because the numbering already exists: a folder on disk has been numbering these games since before this app did. Inventing a parallel run would give every game two ordinals and make the app's the one that disagrees with the filesystem. So the app **reads** rather than assigns, which is the same posture D24′ takes toward the reference exports and D34′ takes toward the lichess table: the external artifact is the authority, and our job is to not transcribe it.

**Two identities, and the weaker one is named as such at the declaration.** The hash is content — it answers "is this the same game". The index is *filing* — it answers "which file is this". They are allowed to disagree, and they will: the same game filed under two numbers is one game, and the import door refuses the second copy as a duplicate regardless of its ordinal. The index is therefore outside the content hash, necessarily and for a sharper reason than `board` and `timeControl` are: those describe the play's circumstances, while this describes a directory. Pinned behaviourally in `PGNStoreRetagTests` rather than as a digest comparison, because `contentHash` is private to the store and widening a door to suit a test is the wrong trade.

**The parser reads the ordinal and nothing else, and that is load-bearing rather than lazy.** `PGNSerializer.fileName` writes *given* names (`1. Bera vs Reinaud.pgn`); the folder this was built for uses full display names (`1. Bera Senol vs Christophe Heylen.pgn`). A round-trip check against the game's seats would therefore reject exactly the files this exists to read. The ordinal is the only part the two conventions agree on and the only part being claimed. **This also surfaces a discrepancy worth recording on its own**: D24′'s filename row says "given names only", read off the reference exports, and the working folder does not follow it. Both can be true — the reference files and the working folder are different sets — but the app writes one and reads the other, and that is now a stated fact rather than an unnoticed one.

**Reader and writer are one convention with one home.** `libraryIndex(fromFileName:)` sits on `PGNSerializer` beside `fileName(white:black:index:)`, not on `PGNParser`, because the type that owns a convention owns both directions — the mirror of `RosterSummary` reaching into `PGNParser.pgnDateString` for the writer half of the parser's one date formatter. The round-trip pin asserts the reader against **the writer's own output** across magnitudes rather than against literals, which is the assert-against-the-shared-source rule and matters here because the two functions sit twenty lines apart and look independent.

**Requiring the period is the guard that earns its keep.** `1961 Candidates.pgn` reads as unnumbered rather than as game 1961 — digits with no period after them are a year in a title, and reading it otherwise would file a whole tournament under invented numbers near the top of the run. Pinned.

**Export adopts it (by request), and this changes bytes D24′ pinned.** A game that came from a numbered file goes back out under the number it came in with, so export → re-import is a round trip through the filesystem rather than a renumbering of it; a game with no ordinal still falls back to its position in the batch, because it has to be called something. The justification within D24′'s own terms: that pin reads the reference files as the authority on *shape*, and the shape has an ordinal in it whose **source** the pin never specified. Reading it off the folder is the strictest available reading of "where the standard and the files disagree, the files win." The standing open item — whether the numbering matches DGT's own convention — is untouched and still unconfirmed. Named consequence: a multi-game export can now write non-contiguous filenames (47, 48, 91) or repeat one, since indices are neither gapless nor unique; that is the folder's own state reflected, and D32′ already decided a same-named file is overwritten silently.

**The archive door takes `max + 1`, with its cost stated.** A game played here has no file yet, so it takes the number the file it is going to become would carry, keeping the run unbroken on export. That is a high-water mark's weaker cousin: delete the newest game and the next one reuses its number. Accepted at one Mac — the folder is the authority, so a number reused there is a number the user reused — and a stored mark would be a second source of truth for a value whose first source is a directory listing.

**The gap this ships with, stated rather than found later: every game already in the Library gets nil.** The app never stored the URL it imported through, so there is nothing to recover an ordinal *from*, and re-importing is refused as a duplicate — which means the existing archive cannot be backfilled by any door that exists today. Until something fills them, the column and the File row read em dashes for every pre-D58′ game. The obvious remedy is a folder scan that matches files to rows by content hash and stamps the index, which is small and reuses the import pipeline's hashing; it is **not built here** and is not scheduled, because scope was one column and one row.

Rejected: **a stored high-water mark** (never reuses, and it is a second source of truth for a number the filesystem already owns); **`max + 1` as the *import* rule too** (would overwrite the file's own ordinal with a guess — the whole error this decision exists to avoid); **deriving the index from chronological position** (no schema change, gapless, self-healing, and it is a position rather than an id: importing one old game renumbers everything after it); **enforcing uniqueness** (two folders can legitimately reuse a number, and refusing an import over a filename while the game itself is fine is a door failing for the wrong reason); **verifying the players in the filename** (would reject the exact folder this reads).

### D59′ — Get Info is three tabs, and it is the only place a game is edited

By request, 5 August 2026. The Move Text tab holds D18′'s movetext editor; the Library inspector's Edit Moves pencil is **removed**; and every surface that edits a seat tag gains the known-player menu.

**This reverses D54′ one day after it was made, and the reversal is the interesting part.** D54′ moved the editor off the Board and onto the Library inspector's PGN header, arguing that a pencil belongs adjacent to its subject and that the Library is where a game's bytes are managed. Both halves are still true. What outranked them is a question D54′ never asked: *where does a reader go to change something about a game?* By the time it landed, the answer was already Get Info — D57′ had put the nine exported tags there the same evening — so the app shipped a state where a game's Event was edited in a window and its moves in a modal over a sidebar. The split was invisible from inside either change, because each was locally right.

**The cost, paid deliberately:** the editor is no longer adjacent to a rendering of its subject. The Library's PGN section still shows the movetext and no longer offers to edit it, which is exactly the arrangement D54′ rejected. Accepted because adjacency is worth less than one door: a reader who wants to change *anything* about a game now opens Get Info, and there is no second place to learn.

**The tab is named "Move Text", not "PGN", and the label is a decision rather than a style.** The section it came from is called PGN and shows exactly this, so the shorter name was available and would have gone stale on contact — a tab called PGN beside a Details tab holding the nine tags claims to be the whole file while showing half of it. This is D54′'s own "Edit Moves rather than Edit PGN" argument, applied one level up to a tab instead of a pencil.

**The tab exists on the game form only, and the absence is the locked decision rather than a gap.** A live game has no stored movetext and Decision #1 forbids the concept outright — the physical board is truth, the game is append-only. Expressing that as a *missing tab* rather than a disabled one is D40′'s rule at minting: an affordance that cannot act should not exist.

**Two commit models in one window, on purpose.** Details commits per field on Return or focus loss, because each of the nine tags is independently valid. Movetext is accept-whole-or-reject-whole (D18′), so it takes an explicit Save gated on the validator. Making them agree would mean either committing half-typed movetext or making the reader press Save to change an Event.

**`MovetextEditorSheet` is deleted, not adapted.** Its one presenter was the pencil; with the door in a tab there is nothing to present a sheet *from*, and a sheet type with no `.sheet(item:)` is D52′'s "door with no surface" one layer down. What survives as `MovetextEditorView` is the whole contract — the replay validator, accept-whole, the splice refusal, the per-ply copy, all five `movetext.editor.*` identifiers — and what went is chrome: the title block, the fixed frame, `dismiss`, and **Cancel, which became Revert**. A sheet's Cancel meant "close without saving" and the closing did the work; a tab cannot close, so the same button had to become "put the text back". `Save` also lost `.keyboardShortcut(.defaultAction)`, because Return inside a `TextEditor` is how you add a move and a default action would have made the most ordinary keystroke in the field commit the game.

**Seat menus everywhere a seat is edited**, which is now three surfaces: the New Game sheet (D16′, unchanged), the archive confirmation sheet, and Get Info's Details tab. All three insert `tagName ?? name` (D29′) and label each item with the string it inserts, because a menu showing "Bera Senol" while writing "Senol, Bera" lies about its own effect. Free text still works everywhere — the menu only fills, and picking creates nothing; `resolvePlayer` stays the single creation door.

Two shape notes the pass forced, both about *where the list comes from*:

- **`EditGameInfoSheet` takes strings; `GetInfoWindow` queries.** The obvious move was a `@Query` in both. That sheet's doc says it "never touches SwiftData", which reads like discipline and is a **capability**: both its previews build it with no `modelContainer`, so a query would have trapped the canvas on first render. The presenter has a context; the sheet takes the strings. Get Info already carries a container and resolves a `Player` through `modelContext`, so querying there buys reactivity a passed snapshot would not have.
- **Get Info's menu commits; the sheet's only fills.** On a sheet, choosing a name and closing without saving changes nothing. On Get Info's Details tab there is no Save, so a choice that only filled the field would sit uncommitted until the row happened to lose focus — a value looking committed and not being it. The menu writes the draft *and* calls `commitField`, which is what makes it agree with the `onSubmit` beside it. That difference is also why the two menus are **not** extracted into one type: same six lines of SwiftUI, two different contracts about when the value lands, and a shared type would need a commit closure to paper over it. The `OpeningSection` em-dash call — two surfaces that agree today, each owning its reason.

Registry: `library.editMoves` **removed** one day after being minted, with **no successor control** — the fourth in the pencil-to-door rhyme (`board.editMoves`, `players.inspector.rename`, `board.editInfo`), and the first whose replacement the registry structurally cannot name, because a tab is selected rather than pressed. New: `getinfo.game.movetext` for the tab and `getInfoSeatPicker(_:)` for the two menus. Consequence recorded at the symbol: **`InspectorEditButtonView` is down to one production consumer**, the live inspector's Edit Details — not dead, but a shared component with a single caller, which is the state where "shared" starts describing history.

Rejected: **a PGN tab showing the whole serialized file** (best answers "what is in this file", and it renders the nine tags a second time one tab over from where they are edited — the twin-read-site shape); **full PGN editable as raw text** (one surface for everything, and it bypasses D57′'s per-field validation and D24′'s byte contract, turning a `DatePicker` back into a string nobody checks); **keeping the pencil and adding the tab** (discoverable from both, and it is two doors into one transaction, which D40′ and D52′ both argue against); **leaving the editor on the Library and moving nothing** (the status quo, and the status quo was a game edited in two places).

### D60′ — orphaned players are always collected; the PGN files are the source of truth

By decree, 5 August 2026. A `Player` row that no game references is deleted, unasked, by every store door that can strand one. D40′'s manual sweep is **removed** with its menu, its alert, its write door and its two identifiers.

**The premise is the decision.** The Library's games come from PGN files imported from outside, and those files are authoritative. A `Player` exists only to give a seat tag an identity; a row nothing references is describing nobody, and the archive it was derived from has already forgotten it. So there is nothing to preserve, and D9′'s "no user CRUD, no GC" half is **repealed** rather than narrowed the way D50′ narrowed it for one cause.

**Safe because `resolvePlayer` has exactly two callers and both link immediately** — `resolvePlayers(for:)` and `backfillPlayerLinks()`. Checked rather than assumed: there is no path that mints a row and attaches it later, so a linkless row is always a leftover and never a row in transit. That is the whole safety argument, and it is also the tripwire — a future door that wants to create a player *before* linking it will find `collectOrphanedPlayers` deleting the row mid-flight, loudly.

**What actually generated them, which is not what the rule's wording suggests.** Not game deletion — D50′ closed that. The generator is **re-spelling a seat**: `applyEdit` re-resolves both seats unconditionally (D18′), `resolvePlayer` is a creation door (D9′), and Get Info commits per field on Return or focus loss. So every distinct spelling ever committed minted a row, and correcting a typo left the old one behind forever. The comma is what makes it bite, because identity is keyed on the *display* form: `Baelus Lorenzo` folds to `baelus lorenzo` while `Baelus, Lorenzo` displays as `Lorenzo Baelus` and folds to `lorenzo baelus`. Two keys, two rows, one player.

**Found by looking at a dropdown.** The seat pickers render an unfiltered `@Query` over `Player`, so the backlog was on screen in three pairs — `Bera` beside `Senol, Bera`, `Lorenzo` and `Baelus Lorenzo` beside `Baelus, Lorenzo`. D50′ had *recorded* that orphans reach the pickers and treated it as acceptable because the cascade stopped new ones; what it did not have was a second generator, and the seat-edit path is one.

**Four collection sites, and the differences between them are the content.** `applyEdit` and `retag` collect **after** re-resolving and **before** their save, so the whole edit is one transaction. `backfillPlayerLinks` collects **after** its relink loop — never before, or it would delete the rows that pass is about to attach games to — and that arm is what heals the pre-existing backlog, since nothing else ever touches a row that no door strands. `delete(_ pgns:)` keeps D50′'s **prospective** cascade unchanged: it computes strandees before the first delete because `.nullify` propagation cannot be relied on to have happened afterwards, which is a trap the post-hoc collector would walk straight into.

**Save-free by contract**, the `resolvePlayers` discipline — every caller already ends in a save and one inside would double each door's transaction count.

**D40′ retired itself by its own rule.** With collection automatic, `orphans.isEmpty` is permanently true, so the Maintenance item could never enable — and "a disabled affordance whose guard can never be true is a lie with a green build" is D40′'s own sentence. What survives from it is `isOrphaned`, still the single spelling of the question, now with one caller instead of three.

**Two costs, named rather than discovered.** A row's remembered tag form (D29′) dies with it, so clearing a seat and retyping the same name gives the row whatever spelling was typed second rather than the first-seen one. And collection is fetch-all-and-scan, necessarily — `isOrphaned` reads relationships, which SwiftData cannot put in a `#Predicate`, the same reason `backfillPlayerLinks` fetches everything. It joins the known-costs census, bounded by running only on doors a person invoked.

**A registry consequence worth watching rather than acting on**: this is the second removal in two days with no successor control, after `library.editMoves`. Both replaced an affordance with something that is not an affordance — a tab, and now an automatic rule. If it keeps happening, the accessibility registry is tracking a shrinking share of what the app does, and the header's stated bet is what would need re-reading.

Rejected: **filtering the seat pickers through `isOrphaned`** (leaves the rows in the store and puts a liveness rule in three view-layer queries — D50′'s twin-read-site objection, still correct); **keeping the manual sweep as a backstop** (a menu item that can never enable, which is the thing D40′ forbids); **collecting only on seat edits** (fixes the observed generator and leaves the backlog, which is most of what was on screen); **committing seats on Return only** (narrows how easily a half-typed name reaches the store and does nothing about the rows already there).

### D61′ — Get Info refuses to put one player on both seats; import still admits it

By request, 5 August 2026. Committing a seat that would name the player already sitting in the other seat is refused, the field reverts, and an alert says why. **The import door is untouched.**

**The asymmetry is the decision, and it has a precedent this project already lives with.** Decision #3 refuses `*` at the *archive* door while `importPGN` admits it deliberately, because a file is allowed to say things the app would never author. Self-play is the same shape: a PGN on disk may legitimately record one person on both sides — an engine match against itself, a training file, a mis-tagged scoresheet — and refusing it at import would make the app unable to read files it did not write. What the edit door refuses is *creating* one by hand, which is almost always a typo in the seat you are not looking at.

**Self-play stays representable everywhere else, and that is deliberate rather than an oversight.** `PGNStore.retag` builds a `Rewrite` **per game with both seat flags** precisely so a player holding both sides rewrites once rather than twice — pinned by `selfPlayRewritesBothSeats`, which this decision does not touch. `PlayerStats.headToHead` returns nil for a player against themselves, pinned by `headToHeadIgnoresSelfPlay`. Both remain correct: the store can still hold such a game, and the folds still know what to do with one. Only one door stopped minting them.

**Identities, not strings, which is the whole of the guard.** `"Lopez, Ruy"` and `"Ruy Lopez"` are one player under D23′'s one-way transform, so a raw `!=` between the two fields would let the seats be spelled differently and still name the same person — the failure that looks most like the guard working. `Player.identity(forTag:)` is asked instead, which is the resolver's own answer.

**Two unknown seats are two absences, not one player.** `?` is the *absence* of a player (D9′), so a nil identity can never collide. Without that exemption a game with both seats unknown — the commonest shape in an imported archive — would refuse every edit to either seat, which would have been a spectacular way to make the window useless on exactly the games most in need of editing.

**`Player.identity(forTag:)` was extracted, not written.** The placeholder rule and the identity fold were three lines inline in `PGNStore.resolvePlayer(named:)`, which was the only thing that knew them. The guard needs the same answer *without creating a row*, and restating it in a view is how two spellings of "same player" begin. The resolver calls it now, so there is still exactly one — the extraction removed a future duplicate rather than adding a type.

~~**Scope, stated because it is narrower than "the app":** this guards **Get Info's Details tab only**…~~ **Closed 6 August 2026 (M12.2), exactly where this paragraph said it belonged.** The gap was real for a day: the same three surfaces gained the known-player menu one request earlier under "everywhere a seat is edited", so the sets were deliberately different and a reader would reasonably have expected otherwise.

**The rule now has one home and three consumers.** `Player.seatsNameOnePlayer(_:_:)` sits beside `identity(forTag:)` — the predicate, stated once — with `LiveGame.Roster.seatsNameOnePlayer` forwarding for the shape the forms hold (D39′'s one recipe, two spellings). `GetInfoWindow.seatsCollide` is **deleted**: a rule living inside one of its consumers is what let the gap open, and the extraction is the fix rather than a tidy-up.

**Same predicate, two shapes, and the difference is the commit model rather than taste.** Get Info commits per field on Return or focus loss, so by the time it can object the value is already going to the store and the only honest response is to revert and raise the alert. The two sheets stage everything behind one button, so nothing is committed and there is nothing to revert — reverting a field the reader is still typing into would be the rudest reading of the same rule. They get an inline warning under the seat fields plus a disabled primary button. This is D57′'s pattern (one window, two commit models, one reason) applied across three surfaces.

**Gating the archive sheet is safe, and the opposite would have been a trap.** `EditGameInfoSheet` appears *after* the game is archived, so a disabled Save strands nothing: the game is already in the Library and **Done** dismisses unconditionally. What is blocked is *introducing* a collision by editing, which is this decision's scope — one door minting them, not the concept. A game that already holds one still archives, still exports, and still opens.

**D61′ shipped with no test of its own, and that was the more useful find.** `PlayerIdentityTests` pinned the guard's *input* and nothing pinned the predicate — so the case that matters, two different spellings of one player colliding, was unasserted, and a raw `!=` would have passed everything in the suite. Six pins now, including both unknown-seat exemptions and the accessor asserted *against* the predicate rather than against a literal, so the two cannot drift while both stay green.

Registry: **one** new identifier, `formSeatConflict(_:)`, prefixed like the rest of the family. Named because it is the only evidence the guard fired on these two sheets — Get Info raises an alert a reader cannot miss, while here the refusal is a line of text and a disabled button, and a disabled button with no visible reason is the thing the identifier exists to let a future suite prove is present.

Registry: no new identifiers. The refusal reuses the Details tab's existing alert — `ResultRefusal` became `FieldRefusal` with a `title`, because a second field refusing is what turned the heading from a literal into a value. One struct of two fields beats two structs of one plus two alerts on one view.

Rejected: **filtering the seat menu to exclude the other seat's player** (preventive and prettier, and free text still reaches the store, so the commit guard is needed anyway — two mechanisms for one rule); **refusing at the store door** (covers every surface at once, and it would break `selfPlayRewritesBothSeats` and make imported self-play games uneditable, which is the import asymmetry backwards); **allowing it with a warning** (a warning nobody can act on is a dialog tax).

### D63′ — logging has one owner, one policy and one grammar; the test host is silent

Twenty-five types held their own `Logger(subsystem:category:)`. The subsystem string was written twenty-five times, the *policy* — emit or don't — was written nowhere, because there wasn't one, and the message grammar had drifted to roughly forty opening words across 164 sites. `AppLog` owns all three.

**The gate is `Logger?`, and nil-means-silent is this project's own idiom rather than a new one.** `AppLog.logger(_:)` returns nil when suppressed, so a call site reads `Self.logger?.info(…)` and optional chaining short-circuits the whole postfix expression — a suppressed call never even interpolates its message. That is verbatim what `sessionLog`, `onGameFinished`, `onDesync`, `boardIdentity` and `requestBoardResync` already do, and the invariant naming them says so in as many words: *nil hooks mean unit tests run headless by construction*. Logging was the one channel that had never been given the same treatment.

**Silent under the test host, re-armed by `DGT_LOG=1`.** A ⌘U run is the one context where the app's narration is somebody else's output, and it was drowning it: one `@Test` drives 2,100 `record` calls through the session log's ring-buffer cap and every one mirrored to Console, while the engine suites reprinted Stockfish's whole option advertisement once per start. The escape hatch is the half that makes this a defensible trade rather than merely quiet — suppressing diagnostics is only safe while they are one scheme checkbox away, and an escape hatch nobody can find is the same as none, so the variable is named at its constant, in `AppLog`'s doc, and in the manual checks.

**`TestHost` was extracted because the probe acquired a second reader**, which is the moment D25′ says a value needs an owner. `DGTStudioProApp.init` has asked "am I under XCTest?" since M1 to keep the host hermetic; `AppLog` now asks the same thing. Two copies of an environment check would agree today and stop agreeing the first time Apple renames a marker, with the only symptom being a suite that quietly stops being hermetic.

**Both policy questions have pure twins, and that is D44′ rather than taste.** `AppLog.isEnabled` is `false` in every process a test runs in and `TestHost.isActive` is `true` in every one, so a suite asserting either confirms only the arm it is standing in — the "check that could never fail" shape this document keeps cataloguing. `isEnabled(in:)` and `isActive(in:)` take the environment as a parameter, which is what makes the arm a real launch takes reachable from a place it could come out wrong. `logger(_:enabled:)` carries the same seam for the same reason.

**One finding came out of this that is not about volume.** `UCIProtocol.parse` returns nil for three different reasons and `StockfishEngine` logged all three at **error**, under a comment reading *"only log non-empty unparseables so we can spot real engine drift"*. Stockfish advertises about twenty-five options at every start and the app ignores them **by recorded invariant** — so the channel meant for spotting drift was roughly 96% expected traffic. The comment never failed; it just never came true. `UCIProtocol.isDeliberatelyIgnored(_:)` now splits known-and-ignored from unrecognized, and the error arm's floor in normal use is one line per start (Stockfish's pre-handshake banner), named at the site so a reader knows what normal looks like. This is the `.DS_Store` finding wearing a protocol hat: a check whose output always contains noise is a check being read past.

**The grammar rule was very nearly the opposite of what it says, and the correction is the useful part.** From a distance the tense scatter looked like chaos and the first draft flattened everything to past tense. Reading the call sites showed the tense was already tracking something real — participles log *before* the work, past tense *after* it. Flattening would have made half the lines claim a thing had happened at the moment it was attempted, which is worse than inconsistent: it is wrong, and wrong only on the failure path, which is the one path anybody reads a log on. The rule as written keeps the distinction and names the actual defect — a participle whose failure path is silent. The seven rules live at `AppLog`, which is the only file every log line has in common.

What was genuinely wrong and got fixed: sixteen messages opening with a function name (`search():`, `loadIfNeeded:`, `analyze()`, `beginAnalysis`, `writeLine`, `open()`, `send()`, `commit`, `modelContext.save()`), one pair of curly quotes where every other site uses straight ones, three `[N plies]` brackets where the house form is `plies=N`, and two lowercase starts left standing on purpose — `recv:` / `send:` are wire-direction markers every UCI transcript uses, and capitalizing them would make this app's engine log the one that needs translating.

**Categories are typed, deliberately unlike `AccessibilityID`.** That file argues the opposite and the difference is worth one line: its signatures stayed `String` because they were shared with a target that could not see the app's types, and nothing is shared here. What a typed category buys is the answer to "which categories exist" — a question the manual checks ask by name, since three of them (`uci`, `eco`, `players`) are spelled inside `log stream` predicates in written procedures. Those three raw values are pinned on literals, which is rare and correct: nothing else in the app would notice if one moved, and the alternative discovery path is somebody standing at the board with a cable in their hand.

Rejected: **a struct wrapping `Logger` with `String` parameters** (reads better at the declaration, and `OSLogMessage` is compiler-synthesized and cannot be forwarded, so every message would flatten to an already-interpolated `String` and every `privacy: .public` in the app would become decoration — free only until the first site that wanted redaction); **suppressing `.info` and `.debug` but always keeping `.error`** (a failing test prints why with no scheme change, and it means no run is ever fully quiet, which is most of what was being bought); **leaving it on and fixing only the UCI defect** (the smallest honest change, and it leaves 2,100 lines from one test in the console); **flattening the message tense to past everywhere** (above); **injecting `TestHost.isActive`** (it is a fact about the process a test is running in, and a test that could set it to `false` would be a test lying about where it lives).

### D62′ — the ladder's ordering is a user choice; D11′ becomes the default rather than the only answer

By request, 5 August 2026. A toolbar menu on Players offers **Rank by Wins**, **Rank by Win %** and **Rank by Rating**, persisted. The chosen method decides what rank **1** means — the number on the badge — and is recomputed for every player on every render, as ranks always have been.

**D11′ is not overturned; it is elected.** That decision fixed wins ↓, win rate ↓, key ↑ and argued for it: a ladder should reward showing up and winning, not a percentage a three-game player tops. Every word of that still holds, which is why `.wins` is the shipped default and why its case **delegates to `PlayerStats.rankingOrder`** rather than restating the chain — that function's production caller today is this enum. What changed is that the other two readings became reachable instead of being arguments in a document.

**Ranking is not sorting**, and keeping them separate is the whole reason this fits. A column sort decides the sequence rows appear in; the method decides the badge, which travels with the player into every ordering — D48′'s sentence, unchanged. Both can be active at once and they answer different questions. The one place they must agree is the *defaults*, and `defaultSortReproducesTheLadder` now pins exactly that: `PlayersDestination.defaultSortOrder` (rank ascending) against `PlayerRanking.wins`. Change either alone and it goes red, because a ladder whose default sort disagrees with its default ranking opens on a list that looks shuffled.

**A rating is not a stat, and that is the structural finding.** `PlayerStats.rankingOrder` takes two `PlayerStats`, and a rating comes from `Glicko1.histories` — a separate fold over the same records. So the third method cannot be expressed in that signature at all. The comparator therefore takes a pair, `(stats, rating?)`. Widening `PlayerStats` to carry a rating was the alternative and was rejected at D10′'s line: the two folds are independent by design, and merging them so one comparator could see both would give every `PlayerStats` consumer a Glicko dependency it has no use for.

**Unrated players rank last under `.rating`, never as 1500.** A nil rating is *no opinion*, not a low one — the player has no decided games against another named player, so the fold has never had an input for them. Sorting them at the starting value would drop them mid-ladder, ahead of real players who have earned less, which reads as a bug rather than a rule.

**Every method ends in the same total tiebreak** — `key` ascending, unique per player and locale-free. D10′'s rule is that a fold is only as deterministic as its ordering; a method bottoming out in win rate would reorder two identical players between launches. Pinned per method rather than once, from shuffled input compared against a second shuffle.

**Persisted, where the column sort deliberately is not**, and the difference is the point: a sort is the question being asked right now, a ranking method is a standing statement about what the ladder measures. New `StorageKeys.playersRanking` rather than reusing the retired `playersSortOrder` — that key's stale `rank`/`name` values are still in defaults, and reading one as an unknown method would be a migration disguised as a coincidence.

Registry: `players.rankingPicker`, the first identifier minted after two consecutive removals with no successor. Worth the line — the run of "replaced by something that is not an affordance" turned out to be a run rather than a trend.

Rejected: **a segmented control** (D48′'s reasoning for the picker that used to stand here: two segmented controls side by side read as one broken one, and the view-mode picker is already segmented); **ranking by rating with unrated players at 1500** (above); **making the method change the sort too** (it would collapse the distinction the badge depends on, and D48′'s "rank is a fact about the player" is the sentence that would have to go).


### D64′ — the app is grouped by what a file serves, not by what it knows

M13, 6 August 2026. `App/` is the shell; `Features/{Board,Library,Players,SmartTags,GetInfo}/` are the surfaces; `Shared/{Inspector,Collection}/` is what more than one feature consumes; and `Chess/ DGT/ Engine/ Game/ PGN/` stay top-level as the substrate. Thirteen folders where there were twelve, 92 files moved, no code changed.

**Chosen over a purity axis, which was the obvious alternative and is the one worth arguing.** `Core/ Model/ Feature/` would have made D10′ visible in the filesystem — pure `Sendable` value types in one place, SwiftData in another, SwiftUI in a third. It was declined twice over. The purity invariant names **types, not folders**, which D34′ already had to say out loud when `ECOClassifier` and `ECOTable` were filed together and the rule survived it intact. And a layer axis scatters every feature across three directories, so working on Players means three open at once — it optimizes for the diagram rather than for the person doing the work.

**Get Info is a feature, not chrome.** It has a window group, three subjects, and four decisions behind it (D53′, D57′, D59′, D61′); it is not a shared component. `MovetextEditorView` lives with it because D59′ made the editor a tab rather than a sheet.

**The live-game split is the one placement with a rule behind it.** `LiveGame`, its draft sidecar and store, `Game`, `GameHeadline`, `SessionPhase` and `OpenGamesRegistry` are model read by four areas, so they stay a domain folder; the sheets, HUD and commands are surfaces and followed the Board. A type read by Board *and* DGT *and* PGN is not the Board's.

**Where it strains, named rather than smoothed.** `Recovery/`'s two files went to `Features/Board/`, and `SessionSidebarPanel` — which stays in `App/`, because D15′ makes the sidebar the master of session info — reads `RecoveryGuidance` across that boundary. No filing removes that: the guidance is computed in two places by decision, so wherever it sits, one consumer is elsewhere. Accepted, not hidden.

**Safe because of a project fact worth restating:** two `PBXFileSystemSynchronizedRootGroup`s with **no membership exceptions**, so target membership follows location and a move needs no project edit. The corollary is the risk — a file moved *out* of a target's root leaves that target silently, which is why a folder move is gated on a cold build rather than on ⌘U.

**What the move cost in documentation was almost nothing, and that is a finding about the code.** The path sweep expected a hundred stale citations and found **one**. **Zero source comments cite a folder at all** — the codebase names types, so a reorganization cannot invalidate it. A proposal to "stop citing paths in docs" turned out to describe what the code already did.

Rejected: **`Core/ Model/ Feature/`** (above); **nesting the substrate under `Domain/`** (most symmetric top level — three entries — and it rewrites every anchor that names a folder for no gain a reader feels); **no `Features/` level at all**, leaving the five surfaces beside the five substrate folders (smallest diff, and it leaves the distinction implicit, which is the thing this decision exists to make explicit); **feature-owned everything**, where Board keeps its own pure types (fewest cross-folder hops, and it puts `PieceIdentity` and the evaluation readings out of reach of the purity argument that governs them).
