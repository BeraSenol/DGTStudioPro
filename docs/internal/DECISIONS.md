# DGT Studio Pro — Decisions

*Split out of `PROJECT-INSTRUCTIONS.md` on 6 August 2026 (M14), **verbatim and
append-only**. Nothing here was rewritten in the move, and nothing here is
rewritten now: a decision re-worded while being relocated is a decision silently
re-decided.*

***This file was deliberately left alone by the 7 August simplification pass**,
which trimmed every other document. Superseded entries — D22′'s two
placeholders, D40′'s sweep, D54′'s door, D38′'s merge half — stay in place,
struck where they were overturned, because the reasoning that produced a
decision is the reason its replacement is trusted. That is the opposite of the
revision narrative the other documents lost, which recorded how a **sentence**
changed rather than why a **decision** did. Only this preamble was touched.*

***This file owns the next-free number.*** `PROJECT-INSTRUCTIONS.md` owns
everything else and cites D-numbers without restating their arguments.

*Two checks belong to the split, named in ROADMAP.md's M14 gate: the milestone
counter-grep reads every document, and every D-number cited in a source must
resolve to an anchor that exists here.*

---

Locked product decisions #1–#8 and their interpretation flags were recorded in the retired roadmap document §2 and remain in force. The two that are load-bearing daily are restated inline where used, so this document stands alone: #1 — the physical board is truth and the live game is append-only (no takebacks; Discard lives in the inspector); #3 — * is never a finished result and never archives.

Old milestone and finding tags (M7.2, M-prs.1, F1–F9…) survive in code comments and below as provenance only — they identify where a decision came from; they schedule nothing.

D-numbers are sequential and never reused. Next free number: **D84′**. (D82′ minted 12 Aug 2026 with the cue sets, by request. D81′ minted 12 Aug 2026 with the board cues, by request. D80′ minted 10 Aug 2026 with the companion-window fix, by defect report. D79′ minted 9 Aug 2026 with the red-ply highlight, the game-98 sitting's feature. D74′–D78′ minted 9 Aug 2026, in the waste-audit sitting, *with* the work. D71′–D73′ minted 8 Aug 2026, in the release-audit sitting, *with* the work rather than after it. D69′ and D70′ were minted 8 Aug 2026 for the View Options panel and the memoized collection folds — both recording work that had already shipped into the working tree unnumbered, which is the failure their entries open by naming.) (This line said D47′ until the 3 Aug audit — it had not been advanced since the M6 revision while the header above was; the header is the owner and this line now just repeats it.)

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

### D14′ — a live game or an active recording inhibits idle system sleep *(batch analysis joined as a second, separately gated cause — D66′)*

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

(b) **SpecialCheckmate** — an enum when the result is mate, detected from the final position by pure Position / GameState predicates, no engine input. ~~The case list is deliberately tight: smothered and backRank.~~ **Widened to ten by D65′ (7 Aug 2026); the *tightness* was never the case count and it stands unchanged** — each case is still defined so it cannot false-positive on an unrelated mate, which is what makes a stored value mean something. Ordinary mates and non-mates classify nil. The classifier reads the final position only, and delegates to the shared Square offset tables and Position+Attack ray primitives. Wired in M4 through `GameClassification`, which replays via `GameState.replay` and only for a game that claims `#`.

Games predating the fields lack them until the backfill reaches them. Movetext edits re-derive both.

Revised by D34′: this decision recorded classification as *analysis-time* work. The second half of its reasoning stands (the doors still don't classify); the first half did not survive contact, because it made an opening name cost a full depth-18 pass over an already-analysed archive.

Rejected, and still rejected: classifying at import or archive; the loose "any mate on the back rank" reading. ~~Enumerating the long tail before a surface shows them~~ — **spent rather than reversed (D65′)**: this rejection was contingent on a condition, three surfaces arrived on 5 Aug that meet it, and the clause expired on its own terms.

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

### D25′ — idle-sleep inhibition is a user preference *(a second, independent preference added by D66′ for batch analysis; the shape below is what it was built from)*

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

### D33′ — the evaluation bar: leading edge, flips with the board, label beside *(label moved from beneath to beside, 7 Aug 2026 — see the amendment below)*

Three product choices: **leading edge**; **bottom tracks the near player**, so the bar reads physically from either seat; an **always-visible numeric label** ~~in a fixed slot *below* the bar~~ **in a fixed slot beside the bar, vertically centred**.

**Amendment, 7 Aug 2026, by request: the bar is the board's exact height, pinned to the destination's leading edge, and the label sits in the gap.** Three changes with one cause between them, and the cause is arithmetic rather than taste.

The bar was a `VStack { bar; label }` framed to the board's side length, so the *stack* got that height and the bar itself drew shorter than the board by the label plus its spacing. "A bar exactly as tall as the board" and "a label inside the bar's frame" are the same wish twice and only one can win. The label moved out to `BoardDestination`; `EvaluationBarView` is now only the bar.

The bar also stopped travelling with the board. It sat immediately beside it and drifted as the window resized; it is pinned to the leading edge now and the board moves instead. That forced a `ZStack` where an `HStack` had been: in an `HStack` the board's centre is the centre of *what is left over*, so it sits off the window's centre by half the bar column. Two overlays each taking their own alignment let the board be centred in the whole surface while the bar is pinned to the edge of it.

**What did not change is the part this decision argued hardest.** The label is still always visible (over hover-only and none), and it is still **not inside the bar** — a thin losing share swallows the text or forces a contrast dance, which is why the original put it below and why the new home is the gap rather than an overlay on the bar's trailing edge. Only the slot's owner moved.

Named cost: `BoardDestination.evaluationLabelWidth` is **reserved, not measured**. The board's side length is derived from the width left after the bar column, so a slot that grew with the text would resize the board every time the score crossed a digit — a board that breathes between `0.0` and `-12.3`. Sized for the longest label the grammar below can produce.

Named gap: the arrangement has **no preview witness**. It lives in `BoardDestination`, which is waived from previews, and `EvaluationBarView`'s previews now show the bar alone. The boardless checklist carries it, and `EvaluationBarView`'s preview doc says so rather than implying otherwise.

`EvaluationBarReading` is the pure mapping and its fraction is `whiteWinProbability` **verbatim** — the bar and the inspector graph share one projection, so agreement is structural and mates clamp exactly as the graph clamps. A nil per-ply evaluation folds to `Evaluation.drawn`. The reading stays white-relative and perspective-free; the flip is one boolean of geometry in `EvaluationBarView`. Label grammar, pinned: signed pawns to one decimal, unsigned `0.0` for anything that rounds to zero, mates in the `evalTagContent` spelling. (`String(format:)` and not `.formatted()`, deliberately: the latter localizes the decimal separator and would break the pinned grammar.)

Presence is game-level and lives at the wiring: ~~`pgn.evaluations.isEmpty` gates the bar entirely~~ — **`pgn.hasScoredPly` since D67′ (7 Aug 2026)**; the old spelling was true of a full-length all-nil array and put a 50/50 bar on a game that had scored nothing. Only the review branch ever passes a reading. `boardSurface` builds the `BoardView` once and branches layout, with explicit `GeometryReader` math because `BoardView` is strictly square.

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
| *(all three rows are **Debug** — see the narrowing below)* | | |
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

**Narrowed 6 August 2026: every number above is a *Debug* measurement.** `build-for-testing` with the test plan builds the test configuration, so "zero diagnostics on a cold build of all three targets" is true of Debug and was never a claim about Release — a distinction nobody drew at the time, including this entry, which reads as though it covered the project. It did not, and the gap was not academic: the app **had never been built in Release at all** until Instruments was opened on 6 Aug, and it failed to compile, because `#Preview` compiles in Release and `PreviewFixtures` was `#if DEBUG`. That is a whole configuration this decision's evidence never touched. The mode-6 conclusion stands — isolation and `Sendable` checking do not vary by optimization level — but the *diagnostic count* is Debug's, and a Release count has still never been taken.

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


### D65′ — the checkmate vocabulary grows to ten, and precedence is the decision

By request, 7 August 2026. `SpecialCheckmate` gains `anastasia`, `arabian`, `opera`, `boden`, `epaulette`, `gueridon`, `dovetail` and `hook`. No schema change, no new type, no new file — every consumer already drove off `allCases`, `displayName` and the raw value, so the picker, the Library column, Get Info and the tag rule all widened for free.

**This is D19′'s deferral expiring on its own terms rather than being overturned**, and the distinction is worth the sentence. That decision rejected "enumerating the long tail *before a surface shows them*" — a rejection with a condition attached, which is the rare kind that can be discharged instead of argued with. Three surfaces arrived on 5 Aug: the Library's Checkmate Type column, Players' Special Mates count, and `TagRule.checkmateType`'s picker. The condition was met two days before anyone noticed it had been.

**What did *not* change is the bar, which was never the case count.** D19′ said "deliberately small and tight", and the tightness is the half that mattered: each case is defined so it cannot false-positive on an unrelated mate. Ten cases held to that bar is the same decision as two; ten loose ones would be a different one.

**Precedence is the whole content of the widening.** A mate can honestly fit two shapes — an Arabian in the corner is also a rook check along a rank; an Opera mate is a back-rank rook mate with a bishop behind it — and the stored column holds one value. The order is narrowest-first, stated as an array rather than an `if`-chain so a reader can see it, and it is the thing a future edit is most likely to change without noticing.

Most pairs never collide: `smothered`'s checker is a knight, `boden`'s a bishop, `gueridon`'s and `dovetail`'s a queen, so none can reach the rook motifs; `anastasia` needs an edge file and `epaulette` two on-board rank neighbours, which an edge-file king cannot have. Three pairs do overlap and each has its own pin. **`arabian` before `hook` is a tie-break rather than a specificity call** — neither is a subset of the other, since Arabian adds the corner and Hook adds the pawn link — and the corner wins because it is the stronger visual signature and the older name. `aCornerHookIsCalledArabian` is the test to change if that call ever changes; it is the only place the choice is observable.

**The Boden recogniser was tightened by measurement, and that is the paragraph worth keeping.** As first written — bishop check, a crossing bishop, one friendly neighbour — it fired on **2.2% of a 1,500-mate sample, roughly five times any other named motif**. The samples were not Boden's mates: they were middlegame positions that happened to own two bishops while a queen did the actual work. Requiring *every* flight square to be self-blocked or bishop-covered says what the motif means, and drops it to 0.3%, in line with its siblings. **Reasoning produced the wrong recogniser and a distribution caught it** — the eight predicates all read equally plausible on the page, and only one of them was wrong.

**Every fixture was verified against an independent move generator before landing.** One near-miss position written by hand had its bishop covering one flight square instead of two, so the king could still run and the "mate" was not mate — a test that would have passed for entirely the wrong reason, since `classify` guards on `isCheckmate` and returns `nil` for an honest reason on a non-mate. That is this domain's standing hazard rather than a slip: a hand-made mate fixture fails silently, in the passing direction.

**Consequences, named rather than discovered.** Players' **Special Mates** count will rise on existing games — the field is derived and backfills, so an archive reclassifies without asking. `PlayerStats.specialMatesDelivered` counts `specialCheckmate != nil` and is unchanged; what changed is how often that is true. The standing open item it feeds — `endedInMate` spelling the mate question `hasSuffix` while the classifier spells it `contains` — is untouched and no more visible than it was. And `SmartTagEditorView`'s comment that "every motif the classifier can produce is a motif a game can carry, so none of them is a dead rule" was an unchecked claim when written and now has `everyCaseIsProducible` behind it.

Rejected: **storing a set of motifs per game** (truest — a mate really can be two things — and it is a schema change on `PGN`, a rewrite of the tag rule's equals/notEquals semantics, and a column that renders lists); **broadest-first precedence**, keeping `backRank` ahead of `opera` and `arabian` (fewer surprising labels, and the exotic names would then almost never appear, which is most of the reason for adding them); **the endgame workhorses** — supported-queen, box and ladder mates (by far the commonest in real play, and they would take Special Mates from a handful to most decided games, at which point the badge stops meaning "rare"; the basic queen mate is pinned as `nil` by `theBasicQueenMateIsNotSpecial` so the exclusion is deliberate rather than incidental); **deriving precedence from `allCases`** so the enum's order governs (one list instead of two, and it makes reordering the smart-tag picker silently change what games classify as).


### D66′ — batch analysis is a second sleep-inhibition cause, with its own gate

By request, 7 August 2026. `SleepInhibitor` holds its activity while a batch is draining as well as while a game is live, behind a **separate** preference — `StorageKeys.preventSleepDuringAnalysis`, absent reads true, its own Settings row.

**Two gates rather than one widened gate, and the reason is that the two causes share only their remedy.** Play is minutes and needs the *serial link* alive across a think; a batch is potentially hours and needs the *engine* alive across a drain. Someone who wants a queue to finish overnight and someone who wants the Mac asleep the moment they step away from the board are the same person on different evenings. Widening `preventSleepDuringPlay` would additionally have forced a choice between renaming that key — silently resetting every stored choice, the D36′ trap — and keeping a key whose name describes half of what it does.

**The predicate left the waiver, and that is the substantive change.** D14′'s was `isEnabled && (liveGame != nil || isRecording)` — one gate, two causes, nothing to extract, and the waiver register said exactly that. Two gates over two causes is a different animal: `allowsAnalysis && playing` compiles, reads plausibly, and means the analysis preference is guarding the board. That defect has no symptom until someone turns one toggle off and watches the wrong thing happen hours later, so the decision is now a pure function — `SleepInhibitor.activityReason(playing:analyzing:allowsPlay:allowsAnalysis:)` — with `gatesDoNotCross` running each cause against only the *other* gate. The waiver narrows to the `ProcessInfo` token, which is genuinely transport.

**It returns the reason rather than a `Bool`,** because the reason is not decoration: `pmset -g assertions` prints it, and that is this type's only diagnostic surface. A caller told "yes, inhibit" without being told why would have to re-derive the cause it had just computed. Both causes at once name both, joined — an activity held for two reasons that names one of them is the same lie in a smaller font, and it would only ever appear while analyzing during a live game, which is exactly the session nobody is watching Console for.

**A cause can now change while inhibition is continuously held**, which D14′ could not express and which is why `setInhibited` takes a reason instead of a `Bool`. The guard compares reasons, not held-versus-not, so a game archiving out from under a still-draining batch re-opens the activity under the new reason. `token = reason.map { ActivityToken(reason: $0) }` constructs the new token before releasing the old, so the process never sits un-inhibited across that handover; the obvious `token = nil` first would open exactly that window.

**This was only writable because the queue went app-global on 6 Aug** (controller decision 2). Against the per-tab controller, the inhibitor would have needed to ask "is *any* tab analyzing" and there was deliberately no door for that — the same absence that decision cites as its proximate cause. `AnalysisQueueController` moved from an inline `@State` default to `App.init()` to be wired, joining the DGT observables for their reason: an inline default cannot be read from `init()` before the stored properties are assigned.

**The `@ObservationIgnored` trap, checked rather than assumed.** D14′ records that `DGTConnection.recorder` must *not* be `@ObservationIgnored` or `isRecording` never registers with the tracking loop. `queue.isActive` has the identical requirement one level down, and the controller happens to carry no `@ObservationIgnored` at all. Verified rather than trusted, because the failure mode is a batch running with the Mac asleep and nothing on screen to suggest why.

**Display sleep is still not inhibited, under either cause** — inherited from D14′ rather than reopened. An overnight batch wants the panel dark more than a game does. Structural: breaking it takes naming a second `ProcessInfo` option.

Two renames rode along, both forced by the second instance rather than mechanical tidying — the D61′ move where `ResultRefusal` became `FieldRefusal` because a second refusing field turned a heading from a literal into a value. `SleepInhibitor.isEnabled` → `preventsSleepDuringPlay`, and the registry's `settingsPreventSleepToggle` → `settingsPreventSleepDuringPlayToggle`, recorded at the symbol. **Neither storage key moved.**

**Manual check, since the token stays waived:** start a batch of ten with the analysis toggle on, run `pmset -g assertions`, and confirm an assertion whose reason names engine analysis. Let it drain and confirm it lifts. Turn the toggle off mid-batch and confirm it lifts *on that edge* rather than at the end — that is the observable-property half of D25′ doing its job. Then, with both toggles on, start a batch during a live game and confirm the reason names both causes; archive the game and confirm the assertion survives with the reason narrowed to analysis alone.

Rejected: **one widened toggle** (one gate, one default, no new key — and it either renames the stored key or keeps a name describing half its job, and it makes an overnight batch and a five-minute game one policy); **no gate at all for analysis** (smallest change, defensible since a batch is user-initiated and finite, and it leaves one of two causes ignoring a preference the other honours, which is the kind of asymmetry that reads as a bug); **inhibiting display sleep during analysis** (a batch has nothing to look at, so this is strictly worse than the play case that already declined it); **a single reason constant naming both causes always** (no `heldReason`, no token handover, and `pmset` would report a live game during a batch that started after the game ended).


### D67′ — "is there analysis to show" has one spelling, and it is not `!isEmpty`

Found 7 August 2026 from a report that two analysed games drew "no data points, a flat line". `PGN.hasScoredPly` — `evaluations.contains { $0 != nil }` — is the question, and the evaluation bar and the graph window both ask it. `AnalysisGlyph.isAnalyzed` forwards rather than restating.

**The bug is that the old gate asked whether the array existed.** `GameAnalysisDriver` resets `evaluations` to `Array(repeating: nil, count: moves.count)` *before* it walks, so a pass that starts and scores nothing leaves a full-length, all-nil array. That array is not empty and contains no analysis. Every consumer mapped it through `?? 0.5` and drew a curve of pure fallback — lying exactly on the 50/50 midline `EvaluationGraphView` strokes unconditionally, which is indistinguishable from "the chart is broken".

**What makes this worth a number rather than a fix is the shape of the failure, not its size.** The symptom appears on the *drawing* surface while the fault is in the *engine* path, and the app simultaneously reports the game as analysed — so the report arrives as a chart bug and every instinct sends the reader to the chart code. D46′'s window already had a correct answer for this state and was walking past it to draw the fabricated one; the empty state existed and could not be reached.

**The comment that documented the divergence is the reason it survived.** `AnalysisGlyph` recorded both spellings by name, noted that they "disagreed on a non-empty all-nil array", and concluded that the bar/graph gate "keeps its own `isEmpty` on purpose: it asks 'is there anything to draw', not 'did a pass run'." The reasoning was right and the conclusion was backwards — an all-nil array has nothing to draw, so the gate claiming that question was the one drawing something. A comment that names a divergence and calls it deliberate is the hardest kind to re-examine, because it has already answered the question a reader would ask. Left visible at the site.

**A second finding was claimed here and was wrong; the retraction is left in place because it is the more useful of the two.** This entry originally said `GetInfoWindow`'s Analysis comment — "the same predicate the glyphs, the toolbar aggregate and the search chips read" — was false, on the grounds that `TagRule.analyzed` reads `GameRecord.hasAnalysis`. It isn't false. `LibraryDestination` hands `AnalysisGlyph.isAnalyzed($0)` to `LibrarySearchToken.admit`, so the chips read the correct spelling and always did. The comment named glyphs, toolbar and chips, and was accurate about all three.

What produced the error is worth more than the finding would have been: `TagRule.analyzed → hasAnalysis` was followed to its source, "chips" was read as covering it, and `admit`'s **caller** was never opened — the parameter is named `isAnalyzed` and takes a `Bool`, so nothing about the call site is visible from the function. That is this project's own recorded rule arriving from the inside: *a token cross-reference proves a name is used, never that a particular consumer reaches it.* It was written in a paragraph arguing that an assertion of unity gets read as evidence of unity, by someone who had just read an assertion of *dis*unity as evidence of disunity, one hour after writing the rule down.

**`GameRecord.hasAnalysis` was the one door still on the old spelling** — consumed by `TagRule.analyzed` alone, not by the chips. Left open here and closed the same hour by **D68′**.

**Scope, stated because it is narrower than "everywhere":** the Library inspector's inline 100 pt strip is untouched and still renders for every game. It has always drawn a bare baseline for an unanalysed one — `EvaluationGraphView` returns early below two points — so all-nil and never-analysed already look the same there, and gating it would remove a strip that reads correctly as "nothing here".

**Not restored by this:** the two games that prompted it. Their evaluations are gone — the reset destroyed them before the walk — and only re-analysing brings them back. What changed is that the next occurrence says so instead of looking like a drawing fault.

Rejected: **fixing only the graph window** (it is where the report came from, and the bar had the identical gate one file away); **making the `?? 0.5` fallback nil-aware per point** (draws gaps instead of a false line, more faithful per-ply, and it answers a game-level question at ply level — D33′ deliberately puts presence at the wiring); **changing `hasAnalysis` in the same pass** (closes the divergence completely, and it silently re-points every saved tag that filters on analysis — *taken up by D68′ within the hour, by request, which is the difference between riding a rendering fix and being asked for*); **leaving it and documenting the trap** (cheapest, and the trap had already been documented once, which is exactly how it survived).


### D68′ — the smart-tag rule joins the one spelling, and saved tags change meaning

By request, 7 August 2026, immediately after D67′ and reversing that entry's own rejection of doing it. `GameRecord.hasAnalysis` is `hasScoredPly` rather than `!evaluations.isEmpty`. `TagRule.analyzed` is its only consumer, so this is the last door on the old spelling and the only one that reaches stored user state.

**What changes:** a saved "Analyzed" smart tag stops matching a game whose pass scored nothing, and a "not analyzed" rule starts matching it. **Matching changes for already-saved tags; accepted at decision time** — D30′'s own sentence, and the second time this project has knowingly re-pointed live rules rather than grandfathering them.

**Why the reversal is legitimate rather than a same-hour flip-flop.** D67′ rejected this *as a rider* — "it silently re-points every saved tag" was an objection to doing it invisibly inside a rendering fix, not to doing it. Asked for directly, it is neither silent nor a rider: it gets its own entry, its own argument and its own line in the manual checks. The rejection stands as written for anyone tempted to fold it into an unrelated pass.

**The alternative was worse than the churn.** Leaving it meant a stalled game reading *analysed* to one surface and *unanalysed* to the other five — and the tag rule is the surface a person uses to go **find** such games. A smart tag called "Not Analyzed" that cannot see the games most in need of re-analysis is precisely wrong at the moment it matters.

**One stale pin, found by grepping the old rule's words rather than the door's name.** `GameRecordTests` asserted `record.hasAnalysis` against `evaluations = [nil, nil]` with the message *"a non-empty evaluations array means a pass ran"* — the repealed belief written out as prose, in a suite this pass had no reason to open. That is the `applyEditRelinksAndKeepsOrphanedPlayer` shape from D60′, and the same grep caught it: search for what the old rule **said**, not for what it was called.

Rejected: **grandfathering saved tags** (no machinery exists to version a rule's semantics, and inventing it for one boolean would be a migration system built for a bug); **a third state** — analysed / stalled / never-run, exposed as its own facet (most honest, and it mints vocabulary and a chip for a state that should be rare and is a *failure*, not a category); **leaving `hasAnalysis` alone** (D67′'s position, correct for D67′'s scope and wrong once the question was asked on its own terms).


### D69′ — View Options is one panel, and the collection sort becomes a preference

Recorded 8 August 2026, against work that shipped into the working tree on 7 August with **no D-number and no roadmap entry**. That is the failure this entry opens by naming, because it is the fifth species and the second time it has happened at this size: M10 shipped a window group, three affordance removals and two locked-decision reversals with zero references in either document, and the remedy minted then — the `M`-tag counter-grep — cannot catch this one, because no source here carries a milestone tag. A pass that reverses a recorded rule, mints four types, retires one, adds four `StorageKeys` entries, seven identifiers and a scene is a decision whatever it is filed under. `grep -ic 'view options' ROADMAP.md` returned **0** at the time of writing.

**The panel.** Finder's ⌘J for the two collection destinations: icon size, grid spacing, and the destination's sort field and direction. One `Window`, opened by `id` — the third scene in a row (after the analysis queue) to need no wrapper type, because it does not *take* a subject, it reads the front one. D46′ and D53′ each had to mint one to keep `openWindow(value:)` unambiguous; this sidesteps the trap rather than paying it a fourth time.

**One panel, not one per destination**, which is Finder's answer and the honest one: two panels that look identical while controlling different destinations is a worse failure than one that retargets, and the geometry half is shared between them anyway — an icon size is a statement about browsing, which is `collectionViewMode`'s own argument for a single key.

**The reversal, stated because it is one.** `LibraryDestination.sortOrder` read *"Not persisted: every launch opens on `#` descending"*, and `PlayersDestination` carried the matching note that the picker's choice survived a relaunch where the column sort deliberately did not. The argument behind both was real — a sort is the question being asked right now, where a ranking method is a standing statement about what the ladder measures. What broke it is the panel: the same choice now sits beside an icon size that *does* persist, and a panel where one control survives a relaunch and the one above it silently does not is not a subtle distinction, it is a bug report. **D62′'s half of that contrast is untouched and still why these are two keys** — the method decides what rank 1 *means*, the sort decides only what order rows appear in.

**A derived binding, not `@State`, so there is exactly one sort.** The table header writes comparators; the panel writes a field and a direction; both land in the same stored value and each renders what the other set. Local state kept in step with the panel would be the twin-read-site pattern with a round trip in it. The `set` arm **keeps the old sort when the round trip fails** rather than falling back to the default: a comparator `LibrarySortField` cannot name — a column added with a `sortUsing:` and no case — should leave the sort alone, not reset it to `#` under the reader's hands.

**`CollectionSortField` exists because a `Picker` cannot hold a `KeyPathComparator`.** While the only door was a table header, `[KeyPathComparator<Row>]` was a fine currency; a panel has to *offer* the choices, which need identity, a display name and a stable spelling, none of which is derivable from a key path. Raw values are hand-written and are a persistence contract — the D36′ trap in a new place.

**`CollectionGridMetrics` is retired, and `columnCount = 6` is why.** Six columns was a statement about width written as a constant, so a wide window spread six cards thin and a narrow one crushed them. It is derived from the container width now, which forces the grids off `.adaptive`: SwiftUI never reports the count an adaptive grid chose, and `IconGridSelection` needs that number to answer "where does ↓ land". One number, used twice, or the layout packs one count while the arrows step by another.

**⌘J is owned by the menu item alone**, corrected 8 August in the same pass as this recording. The shortcut shipped on `ShowViewOptionsButton`, which has five hosts — the View menu plus four grid backgrounds — so at least two copies were live whenever a collection was in front. `GameActionsMenu` names that outcome as the one to watch: not dead keys, but *live and ambiguous*. The shared type carries the verb; exactly one host claims the key, and it is the one whose enablement guard is producible both ways.

Rejected: **a panel per destination** (no retargeting logic, and two identical windows controlling different things); **a segmented control for the sort** (D48′'s reasoning, unchanged — two segmented controls side by side read as one broken one, and the view-mode picker is already segmented); **keeping the sort session-only** (the recorded rule, and it puts two controls with two persistence lifetimes in one `Form`); **`@AppStorage` for the four values** (four sites for two values is four chances to disagree about a default — D25′, `SleepInhibitor`'s answer applied again).

### D70′ — a collection fold is memoized on an explicit content key, and the key mirrors the projection

Recorded 8 August 2026, same tree and same omission as D69′.

**What it does.** Both collection destinations fold the whole Library in `body` — Players projects every game into a `GameRecord` and runs `Glicko1.histories` plus `PlayerStats.index`, the Library projects records for its tag filter and its backlog count. Those folds are correct and their inputs change rarely; what changed constantly is everything *else* that invalidates a destination body: a rubber-band drag writing selection per callback, a search keystroke narrowing downstream of the fold, and — sharpest — `GameAnalysisDriver`'s `modelContext.save()` once per ply, which invalidates every `@Query` in the app and re-folded the Library eighty times per game if Players happened to be open.

**Exact, not hashed.** A `Hasher` fingerprint is one `Int` to compare and one collision away from a silently stale ladder, and "silently" is the operative word because the failure renders perfectly and looks like data.

**The rule that matters is that `CollectionFoldKey.Row` mirrors `GameRecord` field for field**, and it is stated as a rule because the first version did not follow one. The key shipped as `contentHash` + `specialCheckmate`, and the reasoning was right as far as it went: it asked what `PlayerStats` reads, found the motif, and stopped. But `PGNStore.classify(_:using:)` writes **four** columns in one call, and the motif is nil for every game that is not a smothered or back-rank mate — so `backfillClassifications` stamped an ECO code, the hash did not move, the motif did not move, and the memo returned a record whose `opening` was still nil. An `opening contains Sicilian` rule failed to match a row whose ECO column, reading the model directly, showed the code.

**Three fields were missing, not one**, and the other two are worse than the ECO half:

- **`white` / `black`** — the *resolved links*. The hash folds the seat **tags**; the links are a relationship `backfillPlayerLinks()` fills in afterwards, and `PlayerStats.index(of:)` keys the entire ladder on them. That backfill runs from `PlayersDestination.onAppear` under a comment promising the ladder works on a cold launch, so the memo was defeating precisely the pass written to guarantee it.
- **`name`** — outside the hash, rewritten by `backfillEmptyNames()`, read by `TagRule.name`.
- **`isTimed`** — outside the hash by D24′, edited from Get Info's Equipment section, read by `TagRule.timed`.

**The remedy is the mirror, not more care.** "Did I think of everything?" has no answer; "does this argument list read against `PGN.gameRecord`'s?" does. `init(games:)` therefore passes every field explicitly despite the defaults, so the two lists can be read side by side, and the hash's own documented exclusion list (D24′, D58′) is the checklist. The suite gained the case it never had: `ecoStampMovesTheKeyOverModels` asserts the motif stays nil, and the link test asserts the hash does not move, so neither can pass for the wrong reason.

**The test titles were part of the defect.** `aChangedCheckmateMovesTheKey` was titled *"A classification backfill moves the key with no hash change"* — a true body under a title quantifying over a set three times its size, which is the fourth species and is exactly what let the gap read as covered. Retitled to what it checks.

**What the key still deliberately omits, and why that is the whole point.** `evaluations` is absent: it is not an input to either fold, so a running batch costs nothing here. A consumer that genuinely tracks analysis state must compose this key with a signal of its own — `LibraryDestination.FoldKey` is the worked example, and it uses the queue's own counters rather than re-reading the array this key skips.

**Two costs, named rather than discovered.** Building the key now faults both player relationships per game per render, where before only a cache *miss* paid it — bounded by the row cache, since `Player` rows number in dozens against hundreds of games. And the Library's backlog count now drops when a game *leaves the queue* rather than when its first ply is scored, which reads better and is still a change.

Rejected: **a `Hasher` fingerprint** (above); **an `LRU`** (both call sites read one value per pass); **`.onChange` into `@State`** (the handler runs after `body`, so every input change renders one pass stale — a destination painting last render's ladder for a frame after an import is a worse bug than the cost this replaces); **an explicit `invalidate()` called from each backfill** (fewer fields in the key, and it makes correctness a property of every future write door remembering to call it, which is the opposite of a mirror rule).


### D71′ — an analysis pass saves at its exits, never per ply

8 August 2026, from the release-audit sitting, on a report that the app still stuttered during a batch *after* D70′. `GameAnalysisDriver` persists once per exit — pass done, pass cancelled, or any failure — and the per-ply `modelContext.save()` is gone.

**This reverses the driver's own recorded contract**, which read "saves once per ply so partial progress survives a crash", and the reversal is why it takes a number: crash-durability granularity is an observable promise, and the queue window's cancelled row repeats half of it ("evaluations recorded before the stop were kept").

**The finding is that D70′ treated the symptom's largest muscle and left the nerve.** The memo pass made the *folds* indifferent to the per-ply save; what no memo can make indifferent is everything else a save invalidates — every `@Query` in every open window re-fetches, the Library re-sorts, the table re-diffs, Get Info's rows re-read, and SwiftData commits a transaction on the main actor, once per ply, at engine speed. An 80-ply game was still eighty full invalidation fan-outs; a 110-game batch was near nine thousand. The multiplier D70′ named as "the entire win" was still being paid by everything underneath the fold.

**What the per-ply cadence actually bought, examined and found empty.** Crash-durability of a *partial* pass sounds like a property worth paying for, and is not one: the walk resets `evaluations` to full-length nils before ply one, so a crash's partials are destroyed by the next pass anyway — while making the game read *analyzed* to every surface in the meantime, which is D67′'s exact false state, persisted deliberately. The one honest beneficiary was Skip: its partials are user-meaningful ("up to where I stopped it"), and the cancellation exit still saves them, so that promise survives at a cadence of once.

**Each failure exit saves *before* composing its message**, because every message claims something about the store ("earlier evaluations were kept") and D71′ makes that claim false until the save lands — so the message now branches on whether it did, and a refused save says "were lost" instead. The done path lands `.failed` rather than `.done` when its save is refused: a green result that vanishes at relaunch is the E1 shape (1 Aug review) the old three-strikes tolerance existed for, kept under the new cadence at one strike.

**What is genuinely given up, named:** a *hard crash* mid-game loses that one game's evaluations (the completed games before it were saved at their own exits), and other windows see a finished game's curve at the game's end rather than growing per ply. The inspector watching the running game loses nothing — an observed model's in-memory mutations still render; what stops is every *other* window re-fetching per ply.

**A rider with the same motive, below the D-threshold:** the Stockfish subprocess now launches at `.utility` QoS. A `Process` inherits its parent's class, so with Threads raised in Settings the engine's workers sat level with the main thread and every render during a batch fought a saturated core. Utility is the tier for exactly this work; `.background` was declined at the site because App Nap-class throttling on an overnight batch is a batch that quietly took three times as long.

Rejected: **throttling saves to every N plies or T seconds** (keeps a durability the next pass discards anyway, at the price of the fan-out merely slowing rather than stopping — and a tunable N is a knob whose right value is "the game's length"); **saving per ply into a background context** (moves the commit off the main actor and keeps every invalidation fan-out — the expensive half is the readers, not the writer); **batching UI invalidation instead** (no supported spelling: `@Query` has no coalescing contract, and inventing one means a private-API-shaped workaround in a project that has none); **leaving it and calling the stutter accepted** (the report this sitting opened with is the refutation).


### D72′ — analysis state is legible in every Library view mode

8 August 2026, by request: a green check or red x at the bottom-trailing of every card (icons and gallery filmstrip), the same glyph at the trailing edge of every columns row, and the spinning gear in both places while the engine has that game — the list's Analysis column, which already said all three, joins the same input.

**This reverses a recorded site argument and the reversal is the number's cause.** `LibraryColumnsView.row(for:)` argued its icon stays uniform because state on a row would be "a third encoding of facts the detail pane already states, and Finder's own list gets its plainness precisely from every row of a kind looking identical". The argument was sound about the *leading* icon and blind about the question: the detail pane states facts for the **selected** game, a browser's whole subject is the rows not yet clicked, and "which of these still needs the engine" was unanswerable from two of four modes without clicking every row in turn. The leading doc icon stays uniform; the trailing edge carries the one fact worth a glance.

**One projection feeds every badge, and that is the half with architecture in it.** The obvious spelling — each card asks `AnalysisGlyph.isAnalyzed(game)` — decodes `evaluations` per row per render, which is the exact per-row blob decode D70′ took out of the folds, smuggled back in through the leaves; the list's Analysis column had in fact been doing it all along, unnoticed, as the one per-row decode the memo pass left standing. Instead `LibraryDestination.coreContent` builds `analyzedIDs` once per render off the already-memoized records, every mode view takes the set, and a new `AnalysisGlyph.state(of:isAnalyzed:runningID:)` overload folds it with the ambient running id. The two overloads answering identically is pinned (`theProjectionOverloadAgreesWithTheModelOverload`) — driven through `\.gameRecord`, so it goes red if `hasAnalysis` and `hasScoredPly` ever stop being one spelling.

**One silhouette, two dressings.** `AnalysisGlyphIcon` is the palette arrangement extracted from `AnalysisLabel` (two copies of the badge-first layer order would drift independently); cards wrap it in `AnalysisStatusBadge`, whose material chip is load-bearing — the card's sheet is explicitly `.white` in both appearances and the running gear inherits `.foreground`, which in dark mode is white on that white — while table rows take the bare icon, because a chip per row reads as buttons down a column. The badge swallows no clicks and takes an accessibility label from the new `statusLabel` vocabulary, whose negative is verbatim `LibrarySearchToken.unanalyzed`'s chip: the badge and the filter that finds badged games speak one phrase, pinned.

**The gear's repeat is inherited, not settled.** `.symbolEffect(.rotate, options: .repeat(.continuous))` is the one motion (`AnalyzingGear`), and whether it loops is still on the owed manual checks; the badge adds two more surfaces that show the answer, not a second motion.

Rejected: **plain `checkmark.circle` / `xmark.circle` badges** (the literal request, and it would mint a second analysis vocabulary beside the gear family every other surface speaks — the request's *meaning* is the states, which the house glyphs already carry as a green check and a red x on the gear — **overruled the same day; see the postscript**); **per-card model reads** (above — the D70′ regression); **a `waiting` state for queued games** (the type doc's standing call, unchanged: a queued game is genuinely unanalyzed and the queue window says where it stands); **badging the columns detail pane instead of the rows** (it already had the labelled button; the rows were the gap).

**Postscript, same day, by request: the first rejection is reversed for the badge surfaces.** "I mean only a green check mark or red x in the icon view, not with the gear icon — only a gear icon during analysis." The literal request was the request. `AnalysisGlyph.badgeName(_:)` is the second vocabulary this entry declined to mint — `checkmark.circle.fill` green / `xmark.circle.fill` red, drawn by `AnalysisBadgeIcon` on the card corners and the columns rows — and the reason it is defensible where the original rejection feared drift: on a *card corner* the glyph is pure status, and field use found the gear silhouette reading as chrome around the mark that mattered, while on the action surfaces (the Analyze column's button, the chips, the menus, the queue toolbar) the gear **is** the meaning and stays. The two vocabularies share exactly one silhouette — the bare running gear — pinned by `badgeSymbolsArePlainMarksSharingTheGear`, so "the engine has this one" cannot fork. The `.fill` circles are the queue window's own finished-row marks, so the badge agrees with the surface that reports the same verdict in prose. Everything else in this entry — the projection, `analyzedIDs`, the chip, the accessibility vocabulary — is unchanged.


### D73′ — the analysis as data: its own window, and the only teller of coverage

By request, 8 August 2026, later the same sitting. Three moves that read as one: a **table window** — every ply, its move, the engine's evaluation and the projected white win probability — opened by a new button beside the magnifier in the Library inspector's Evaluation header; the queue window's **Depth fact holds still** (the configured target, not the climbing iteration); and Get Info's File tab **loses its Analysis section**, whose four summaries the table supersedes.

**The window pays the wrapper.** `AnalysisDataRequest` is the fourth member of the `openWindow(value:)` family (D46′, D53′) — this scene has a subject, so it cannot sidestep the routing trap the way the queue and View Options singletons did. Its own group, so two games' data windows tab with each other; deliberately **not** floating, unlike the graph one scene up — a table is scrolled and text-selected, so it takes focus, and the Get Info argument applies.

**The rows are a pure fold (`AnalysisDataRow.rows`), and its one sharp edge is the nil rule.** The move column is `EvaluationGraphReading`'s grammar and the evaluation column is `EvaluationBarReading`'s, both asserted against the shared source — but where the bar folds a nil evaluation to `.drawn` and prints "0.0" (a display surface must render every ply), the table carries nil and draws the house em dash. Printing "0.0" for a ply the engine never scored would manufacture the exact false reading D67′ was minted against, in the one window whose whole promise is stored truth. The divergence is deliberate and pinned (`unscoredPliesAreNilNotZero`), because a divergence without a red test is one refactor from being "unified".

**Coverage moved rather than vanished, and that is what makes the Get Info removal coherent.** D57′ filed "analysis coverage" under the File tab's derived facts; the request took it out, and the honest reading is that it never quite belonged — the File tab's rule is derived facts about the *file*, analysis is derived facts about the *play*, and the "48 of 58" fraction was four summaries of an array this window now shows whole. The em-dash rows are per-ply coverage, which is strictly more than the fraction said. `evaluatedPlies` and `extreme(_:white:)` went with their only consumer; the site comment carries the trail.

**The Depth fix is a reading correction, not a data change.** `Search.targetDepth` is what the window's Depth fact shows — the `18` in `go depth 18`, stable for the whole batch — where it showed `progress.depth`, the per-info-line iteration, which climbs 1→18 inside every ply and resets at the next. That spinning readout was the manual checks' own recorded expectation ("depth climbing and resetting per ply") and it read in use as the depth *setting* bouncing; the reached depth stays parsed and carried on `EngineProgress` for anything that ever wants the live figure back.

Registry: `analysisData.button`, `analysisData.window.table`, `analysisData.window.empty` — the button one identifier across future hosts, on `evaluationMagnifier`'s reasoning.

Rejected: **a fourth Get Info tab** (couples the data to one subject's window when its natural neighbour is the graph, and Get Info is already the app's largest view file); **rows inside the Evaluation section** (a hundred rows in a 335 pt sidebar is a scroll inside a scroll); **keeping the File tab's Analysis section alongside the window** (two tellers of coverage, one of them four summaries of the other — the twin-read-site shape as a product decision); **showing reached depth as "12 / 18"** (still spins, which is the complaint, and the progress bar one row up already carries the motion).

### D74′ — an analysis pass is a plan: the book is skipped, and re-analysis deepens

By the 9 Aug 2026 waste audit's ranking (A1+A3 — the one item that changes felt wall-clock by an integer factor). Two additive columns, one pure type, one reordered door.

**The finding that minted it:** the driver searched every ply of every game at full depth, book moves included, while `ECOClassifier` *already computed* the matched book prefix at classification time and threw the length away. And re-analysis always started from zero, structurally: `Evaluation` stores value with no depth, so "already scored at ≥ target" was unknowable.

**The schema.** `PGN.ecoDepth: Int?` — the matched prefix in plies, stamped by `classify` with the other four columns (D34′'s one door; `GameClassification` carries `openingPlies`, `ECOClassifier.match(for:)` returns the pair). `PGN.analysisDepths: [Int?]` — parallel to `evaluations`, same empty-or-`moves.count` invariant, written beside each evaluation, cleared with them by `applyMovetextEdit`. Both additive-optional/defaulted — lightweight migration, the D28′ stance.

**The plan is pure.** `AnalysisPlan.plan(moveCount:evaluations:depths:bookPlies:targetDepth:)` returns the searchable indices and whether storage resets. Rules, each pinned: plies below the book exit are never searched; a ply with an evaluation *and* a recorded depth ≥ target is kept; an unknown depth (legacy games — depths absent) is searchable but **not** a reset, so old scores survive until each ply is actually re-searched; only an evaluations-length mismatch resets (narrowing M1 9a's blanket reset, which destroyed the previous analysis on every pass).

**The door reordered.** `classify` now runs *before* engine start — the plan reads the freshly stamped `ecoDepth` — and a fully satisfied plan returns `.done` without ever spawning a subprocess. The M1 9a guard survives relocated: storage still resets only after a successful start.

**The estimator follows the unit.** `plyCounts` at enqueue are *searchable* plies (the same plan), or a skipped book registers as impossible speed; driver progress is searched/searchable; the queue window's row reads "N plies to search". An unclassified game estimates full-length and tightens after its first pass — recorded, not hidden.

**Costs, named:** the evaluation curve and the bar render the book prefix as unscored (the graph's `?? 0.5` midline through the book — visually honest for theory); the Analysis Data window shows em-dash rows there, which D73′'s vocabulary already means; a depth change in Settings re-opens every ply (deepen is the feature, not a leak).

Rejected: **storing depth inside `Evaluation`** (changing a stored Codable enum's payload breaks every existing blob's decode — the D36′ hazard as a certainty); **a Settings toggle for the skip** (a preference for "waste time on theory" is not a choice anyone makes on purpose; the data window shows exactly what was skipped); **skipping via a shallow pass over the book** (spends engine time to reproduce the table's own answer).

### D75′ — the player backfills retire behind a converged stamp

The waste audit's B1: `backfillPlayerLinks` + `backfillPlayerTagNames` ran fetch-all-and-scan on **every** Library and Players appearance, months after they last healed anything — the app's most-frequently-run redundant work, unpredicable by nature (a nil link on a `"?"` row is *correct*).

**The gate.** `PGNStore.healPlayersIfNeeded(defaults:)` — the one door both destinations now call. Stamped (`StorageKeys.playerBackfillsConverged`) only after a pass that healed **zero** rows; a healing pass leaves the stamp unset so the *next* appearance confirms convergence. Stamped, it returns before fetching anything.

**Why the gate is sound:** imports link at the door, archives link at the door, and D60′ collects rather than nullifies — no live door can re-create the work the backfills exist for. Erase Library clears the stamp with the store it described (a fresh library earns its own clean pass).

**The priced residue, asserted rather than assumed** (`stampSkipsAndClearingHeals` pins the skip *happening*): a row inserted around the doors after convergence stays unhealed until the stamp is cleared. Nothing in the app inserts around the doors; the recovery is deleting one default.

Rejected: **a version/count heuristic** (a changed count doesn't mean unhealed rows; an unchanged one doesn't mean none); **gating per-launch instead of persistently** (keeps one full scan per launch for nothing); **clearing the stamp on every import** (imports link at the door — clearing would re-run the scan for exactly the door that cannot need it).

### D76′ — orphan collection is scoped to the displaced rows at the editing doors

The audit's B5. D60′ chose the global fetch-all spelling for one-implementation simplicity; the amplification showed up at Get Info, where every per-field Return fetched **every** player and faulted relationships to find the one row a re-spelling might have stranded.

**The shape keeps D60′'s rule singular:** `collectOrphanedPlayers(among:)` is the core — the same `isOrphaned` predicate over a candidate list — and the global door delegates to it with the full fetch. `applyEdit` passes the two players it captured *before* re-resolving (the only rows that edit can strand); `retag` passes its source row (the rename's whole residue, per D60′'s own sentence). `backfillPlayerLinks` keeps the global sweep — the backlog is its job, which is also what keeps D75′'s gate honest: after convergence, every door that can strand self-collects, scoped.

A self-play edit passes one row twice; the `isDeleted` guard makes the second visit a no-op — the identifier-keyed-fold lesson from `playersOrphaned(byDeleting:)`, one door over.

**The behaviour change, stated:** an *unrelated* pre-existing orphan now survives a seat edit (pinned) — previously the edit swept it as a side effect. That sweep was load-bearing for nothing: the backlog was already healed, and the backfill still owns it.

Rejected: **scoping the backfill's arm too** (its candidates *are* everyone — that is what a backlog healer is); **a second predicate spelling at the doors** (the twin-read-site pattern D40′ retired; `among:` keeps one spelling with two callers).

### D77′ — the data window carries the swing

The audit's C3 — the highest product value per line of code on the list, because every input already existed: per-ply `whiteWinProbability` is stored, and the blunder signal is its first difference.

`AnalysisDataRow.swing` — the step against the ply before, in percentage points, white-relative like every number on the surface — with `swingIsMajor` at |Δ| ≥ 15 pp (a judgement call, documented as one). **Nil when either side of the step is unscored**: a D74′ book hole or a dead-engine gap must not produce a delta against a ply nobody scored, so the first scored ply after a gap carries no swing rather than a fake one. A flat step is `"+0"` — a real, zero swing, not an absence.

Rendered as a fifth column, emphasis by **weight, not colour**: the sign is white-relative, so red-means-bad would lie for one side of the board every time.

Rejected: **mover-relative sign** (every other number on the surface is white-relative; one column flipping per row is the confusion, not the cure); **a "largest swings" section** (the column *is* the fold; sorting can come to the table later without new data); **swing vs. the previous *scored* ply across gaps** (bridges positions many plies apart and calls the bridge a blunder).

### D78′ — narrowing and sort are memoized on the fold key's discipline

The audit's B2+B3, D70′'s pattern applied one stage downstream — ahead of the Instruments pass by choice, because the shape was already proven and the cost already censused (`filteredGames`' unconditional `sorted(using:)` per render, with the ECO comparator rehydrating `ECOOpening` per comparison; the smart-tag rule fold per game per render).

**One cache per destination, keyed on every input the stage reads.** The Library's `NarrowKey`: the projection's `FoldKey` (content + queue counters), the filter's `Signature`, query, tokens, sort. Players' `DisplayKey`: content key, ranking method, sort, query, tokens — the value carries ranked, displayed and searched together, so the ladder fold, the sort and the search re-run only when an input moves.

**`LibraryFilter.Signature` exists because a tag's rules are live-model state** — editable without any game's content moving — so the one input `CollectionFoldKey` cannot see is carried explicitly (tag id, `matchAll`, rules; player id for the player filter).

**A memo key's only defence is field-list completeness**, and that is the suite (`DestinationDisplayKeyTests`): every input moved singly must move the key — a field the key stops covering goes red there before it goes stale on screen. The action-time contract survives unchanged: `gamesInDisplayOrder` re-reads the cache, which recomputes iff an input moved — the same correctness as re-deriving fresh, cheaper.

Cost, accepted: the `NarrowKey` is built per render (O(n) over cheap fields — the price D70′ already pays for `CollectionFoldKey`), and cached values retain model references; every retaining key contains the games' content rows, so a deletion moves the key before a stale model could render.

Rejected: **sorting off stored `ecoCode` to cheapen the comparator** (trades away the both-or-neither accessor a recorded column note defends, to optimize a path the memo now makes cold); **memoizing inside the `Table`** (display order feeds export numbering, queue order and tab order through the destination — the sort must live where `filteredGames` applies it, which is the recorded reason it sits there at all).

### D79′ — the movetext editor paints the offending ply red

By request, 9 Aug 2026, out of the game-98 diagnosis: the status line named the failing ply ("Move 98 (Qf4+): no legal move matches") while the field showed a hundred identical monospaced rows, and the number it named was a *ply* wearing a full-move label — the reader's eye had nowhere to land.

**The mechanism.** The editor's binding becomes `AttributedString` — the macOS 26 `TextEditor` overload, shipping API inside the 26.2 target, not the 2027 beta line. Characters stay the data; colour is derived: after every character change (and once at init, so an imported game whose stored moves never replayed shows its ply red **on open**), a restyle pass clears `foregroundColor` over the whole string and paints only the `.illegalMove` index's SAN. Attribute-only writes never touch characters, so the caret stays put; the write re-enters `onChange` once and a last-styled-characters guard swallows the echo.

**Locating the ply is the grammar owner's job.** `MovetextEdit.characterRange(ofPly:in:)` walks by `tokenize`'s own rules — same whitespace splitter, same `<digits><dots>` prefix stripper, same result-token skip — and returns character offsets covering the SAN only, never its glued move number. Pinned over the real rendered score sheet: every ply's range extracts exactly that ply's SAN. One grammar, two questions; a second tokenizer in the view layer is how the highlight and the validator would drift.

**Validation stays once per change, not thrice.** The status line, the Save gate and the highlight all want the same replay for the same characters; a `CollectionFoldCache` keyed on the plain string (D78′'s box at editor scale) makes the three readers one computation — strictly cheaper than the pre-D79′ once-per-render.

**Costs, named:** typing at the edge of a red run inherits its colour for the one frame before the restyle repaints — invisible in practice, and the common case (fixing the token) clears the red entirely. Colour is the *pointer*, never the whole signal: the words stay in the status line, so the surface reads without colour vision. The status line's "Move N" ply-vs-full-move label is untouched by this decision and still mislabels — recorded, offered, declined so far.

Rejected: **an overlay highlight behind a plain `String` editor** (glyph-metric guesswork over a scrolling `NSTextView`, fragile at exactly the long games that need it); **highlighting via the score sheet's row** (points at a row, not a token, and dies the moment the reader reflows the text); **a `TextKit` representable** (AppKit surface for something the shipping SwiftUI binding now does).

### D80′ — companion scenes take the associated window-manager role; the AppKit configurator is deleted

By defect report, 10 Aug 2026: with the main window full screen, the evaluation graph and the data window opened as their **own** full-screen Spaces instead of appearing over the board — the exact behaviour `fullScreenAuxiliary()` existed to prevent, failing on its first real exercise.

**The defect was timing, not the transform.** `FullScreenAuxiliary.auxiliary(_:)` was correct — mutating, both flags, idempotent, pinned four ways — and it ran in `viewDidMoveToWindow`, which fires when the *content* attaches. The Space assignment is decided when the window is placed, and the behaviour read at that moment was the default. A window already given its own Space is not re-homed by a later write, so the mechanism was structurally unable to affect the one moment it was built for. The configurator's own doc anticipated SwiftUI *resetting* the value and reserved `updateNSView` as the remedy; the measurement arrived, and the reserved remedy is wrong the same way — a re-assert is still after placement.

**The premise was false too, which is why this is a replacement rather than a repair.** The file's header said SwiftUI "cannot reach the flag". It can, one level up: `.windowManagerRole(.associated)` is a **scene** modifier — macOS 15+, macOS-only, shipping API well inside the 26.2 target, not the 2027 beta line — so the framework itself configures the window as a companion *before* placing it. That ordering is the entire fix. All five companion scenes carry it; the main group keeps its primary role by carrying nothing.

**What went with the door**, per the deletion rule: `FullScreenAuxiliary.swift` whole — the enum, the view extension, the app's one `NSViewRepresentable` — and its four-test suite. The suite pinned the pure transform faithfully while the mechanism around it could never work: a green suite over an unreachable moment, the D44′ species wearing AppKit clothes. The declaration-scan expected set shrinks by `makeNSView` / `updateNSView` (corrected at the sweep command), and a representable witness reappearing there now means someone reached for AppKit again.

**Witness:** scene modifiers are framework wiring with no unit seam, so the manual check *is* the feature — main window full screen, open the graph and the data window; both must appear over the board rather than switching Spaces, and Get Info, the queue and View Options must do the same.

Rejected: **growing `updateNSView` a body** (the reserved remedy — still after placement, so it ships the same bug with more code); **re-asserting from an earlier AppKit hook** (a race against the framework's own configuration, where a scene modifier is a declaration to it); **keeping the transform test-only beside the modifier** (a door with no surface — D52′'s words — and the transform's whole content is two flags the role now owns).

### D81′ — board cues are one sound per move, classified from typed values, gated four ways

By request, 12 Aug 2026: a sound when a move is played or replayed, and separate sounds for check
and checkmate. Four bundled samples, one classifier, four toggles — and one rule that is the whole
of the design: **a move makes exactly one sound, the most specific one that fits.**

**Precedence rather than layering, and the alternative was real.** A capture that gives check could
plausibly play both samples, and two clips fired at one instant is mush — no listener separates
them, and the compound tells you less than either alone. So `check` outranks `capture`, `checkmate`
outranks both, and the losing cue is simply not heard. The consequence, stated rather than
discovered: **turning Move off does not silence captures**, and a reader who expects the toggles to
be additive layers will read that as a defect. It is in the Settings footer for that reason, which
is the one thing in that section not deducible from the labels.

**Classified from `Move` + `GameState`, never from SAN.** The tempting shortcut is free: `san(for:)`
already appends `+` and `#`, and the stored movetext already carries them, so a cue could be a
string suffix at both call sites with no chess computed at all. Declined on the project's own
grounds — D18′ records that this app has exactly two SAN strippers and that they are *meant* to
differ, and a third string reading with its own opinion about `#` would land straight on the open
item where `hasSuffix("#")` and `contains("#")` already disagree about `Qd2#!`. Typed values cannot
be fooled by an annotation. The price is one extra `legalMoves()` per move **in check positions
only** — `isInCheck` is asked first and is a single attack scan, which is `GameState+SAN`'s own
optimisation rather than a new one, and `isCheckmate` would pay the scan twice. It joins the
known-costs census; at one move per several seconds of human play it is not a candidate for M7.

**Stalemate has no cue and falls through to `move`.** The position is drawn and the move was quiet,
and there is no sample for "the game just ended in a way nobody chose". Worth naming because "no
legal replies" looks like the end of a game, so a future reader will be tempted to route it to the
mate sound — `stalemateFallsThroughToMove` is the test that should fail when they try.

**The step/jump split is structural, not a parameter.** `Game.onStep` is fired by `advance()` and
`retreat()` and by nothing else; `jump(to:)`, `toStart()` and `toEnd()` are silent. Expressing it
as *which methods call the hook* rather than as a flag callers pass means a caller cannot get it
wrong, because a caller is never asked — `CollapsibleSection`'s one-argument-used-twice argument
(D45′) in its cheapest form. The rule it encodes is one keypress, one sound: End over a 90-ply game
crosses 90 plies and is one position change, and 90 clicks for it is the machine-gun this exists to
avoid. Retreating sounds too, and with the *landing* position's cue: the cue describes where you
are, not which way you came, so stepping back onto a check is a check.

**Two hooks, one for each surface, both nil-silent.** Live rides `DGTLiveSession.onMoveCommitted`,
fired in the `.move` settle arm **after** `commit` returns true — the F5 guard's argument applied to
audio, since a cue for a commit that did not happen is a lie you hear before you see. It is the
eighth settable hook and is wired once in `App.init()` beside the other seven; nil in headless tests
means silent by construction, which is the whole reason that invariant exists. Review rides
`Game.onStep`, wired by `BoardDestination` at construction rather than inside `Game.init`, because
the player is an environment value and a model-layer type reaching for one is how a `Game` stops
being constructible from a preview.

**`BoardSounds` owns the four preferences; D13′'s beep deliberately does not change.** That closure
re-reads `UserDefaults` and states its own `?? true`, which is the twin `StorageKeys` documents. The
new gates take D25′'s owned-value shape instead — one type, four defaults stated once in `init`,
Settings binding to the properties — so playback and the form cannot disagree about them. The two
also differ *audibly*, which is why they are separate sections rather than one: the illegal-move cue
is `NSSound.beep()` at the user's **alert** volume because it is an alert about the board
contradicting the game, and these are samples at app volume because a move landing is feedback.
Merging the sections was considered and left alone as a mechanical change riding a feature change.

**Silent under the test host, and unlike D63′ there is no escape hatch.** One `@Test` walking a game
would fire a cue per ply, which is that decision's console-noise finding with a worse failure mode.
Logging needs `DGT_LOG=1` because a suppressed *diagnostic* can hide a defect; a suppressed *click*
cannot, so the seam exists for the suite (`audible:`) rather than for a scheme. Both `isAudible(in:)`
and the four-way gate are pure functions taking their inputs, for D44′'s reason and no other: the
shipped constants are fixed in any process a test runs in, so without the seams a suite could only
ever confirm the room it was standing in. The gate is where that pays — four cues over four flags is
crossable twelve ways, and a `check` reading the capture toggle compiles, renders a correct-looking
Settings pane, and is caught by ear or not at all.

**The samples are synthesised, and that is a compromise recorded as one.** The intent was lichess's
set (`lichess-org/files`, CC0 1.0, confirmed at source). It could not be fetched into this tree by
the hand that wrote the rest — the fetch reaches the file and returns `[binary data]` — so the four
were generated instead: one wooden knock model driving all four, with check and checkmate adding a
chime *over* the knock rather than replacing it, so the set reads as one instrument. 16-bit 44.1 kHz
mono, 80 KB total, and reproducible: `Tools/make-cues.swift` regenerates them from a fixed seed,
runnable as `swift Tools/make-cues.swift` with Foundation and nothing else.

**The generator is Swift, by request, and the version history is the useful part.** It was first
written in Python — the fastest way to get four usable samples — and rewritten on the grounds that
a Swift repo with one Python file in it has a Python toolchain dependency nobody declared. The
rewrite forced one real change rather than a transliteration: numpy's PRNG cannot be reproduced in
Foundation, so the noise transient moved to an explicit 64-bit LCG with uniform noise, an algorithm
both languages express identically, and **the committed samples were re-derived from that algorithm
before the port** so the script and the files it claims to produce are the same recipe. What is
*not* claimed is byte-identity across the two implementations: `sin` and `exp` are platform libm,
so a sample could differ by one 16-bit step in principle. Run it once and diff if that ever matters.

No package, and declining one is the decision: AVFoundation writes a WAV, a synthesis package
(AudioKit and its relatives) writes it more comfortably, and the project has **zero** third-party
dependencies. Adding the first one to generate four sixty-millisecond clicks would be the largest
dependency decision in the repo taken for its smallest asset — a canonical RIFF header is fifteen
lines, and they are in the file.

The script lives at the repo root rather than beside the samples because `DGTStudioPro/` is a
**synchronized folder group**, where target membership IS folder contents — anything dropped in
there ships inside the app bundle. That is the same mechanism that bundles the ECO tables with no
project-file edit, working against us for once, and it applies to a `.swift` exactly as it would
have to a `.py`. `BoardCue.resourceName` is the only thing that names the samples, so replacing them
with lichess's own is four files renamed into `Features/Board/Sounds/` and **no code change** — the
swap is deliberately that cheap, and the generated set should be treated as a placeholder that works
rather than as a decision about taste.

**Playing a sound at all needed an entitlement, and the app died finding out.** First launch after
this shipped: the game opened, an arrow key was pressed, and the process was **killed** —
`PRECONDITION FAILURE: Process is sandboxed but
'com.apple.security.exception.mach-lookup.global-name' doesn't contain 'com.apple.audioanalyticsd'`.
Not a warning, not a silent cue, not a degraded feature: CoreAudio takes the process down the first
time a sandboxed app initialises playback without a mach-lookup exception for the analytics daemon.
`DGTStudioPro.entitlements` carries it now, and it is the second grant in that file beside
`com.apple.security.device.serial`.

**What makes it worth a paragraph rather than a line is which instinct was wrong.** The reflex on
seeing a CoreAudio crash was to retreat from `AVAudioPlayer` to `NSSound`, on the honest evidence
that D13′'s `NSSound.beep()` has been playing inside this sandbox for weeks. That would have
changed nothing: on modern macOS `-[NSSound play]` calls `-[AVAudioPlayer play]` calls
`AudioQueueStart`, one stack, which Apple's own DTS thread on the macOS 26 `caulk` SIGILL shows
frame by frame. `beep()` is not a counter-example either — it is the system alert path and
initialises no playback graph in-process, which is precisely why D13′ never needed this entitlement
and why its success was misleading evidence about a different API. **There is no lighter framework
to retreat to; every route to a sample ends in the same AudioQueue.**

Recorded as a decision because the alternative was real and worse: the sandbox could have been
turned off (`ENABLE_APP_SANDBOX`, already on the table for Syzygy's folder access) to make a click
work. Widening a temporary-exception array by one service is the proportionate answer, and the
standing input settles the usual objection — exception entitlements are an App Store review flag,
and there is no App Store here.

**Bundle presence is a manual check**, and this is the one place the suite is honestly blind: the
filenames are pinned on literals (`AppLog`'s category reason — nothing in the app would notice a
drift, because the symptom is silence, which is also what an off toggle looks like). A missing
resource logs once to `sound` and caches the failure, so a broken bundle does not log per ply — the
`.DS_Store` lesson, applied before it could bite.

Rejected: **layering the cues** (a capture-check plays both, and it is mush); **classifying off SAN
suffixes** (free, and it inherits an open item about `#` that the typed form cannot have);
**`NSSound.beep()` for everything** (zero assets, zero licensing, and every move would sound like a
notification at alert volume — the wrong organ for feedback); **one toggle for all four** (fewer
keys, and it makes "quiet moves, loud mates" unrepresentable, which is the arrangement most likely
to be wanted after a week); **firing the cue from `LiveGame.commit`** (closer to the move, and it
puts audio in the append-only model and re-wires per game, where the session hook is wired once);
**a flag on `jump(to:)` for whether it announces** (one method instead of two paths, and it makes
the machine-gun a caller's mistake to make).

### D82′ — the cue set is a user choice; D81′'s samples become one material among three

By request, 12 Aug 2026, once D81′ was green and audible. `BoardSoundSet` — **felt**, **wood**,
**marble** — is picked in Settings and holds all four cues; wood is what shipped and stays the
default. This is **D62′'s shape exactly**, one domain over: that decision turned D11′'s fixed
ladder into an elected default without overturning its argument, and this turns D81′'s fixed
samples into an elected default without touching its classifier, its precedence, or its gates.

**A set, not twelve loose files, and the difference is an invariant rather than tidiness.** One
choice instead of four means a felt move cannot end up beside a marble capture — internal
consistency is structural, not a thing the reader has to maintain. It also keeps the Settings
section at five controls instead of thirteen.

**The gesture is constant across sets; only the material varies.** Check is one blip, checkmate is
a falling fifth, in all three. Felt takes the same interval an *octave down* rather than a
different interval, so muting the set never changes what a cue **means** — a reader who switches
material should not have to relearn which sound is a mate. That constraint is why felt is not
simply "wood, quieter".

**One tuning finding, recorded because the first attempt shipped backwards in reasoning.** Marble
was given a *longer* decay than wood, on the intuition that stone rings — and measured **duller**
than wood (spectral centroid 819 Hz against 2236 Hz). A long ring at a low fundamental dominates
the spectrum and drags the centroid below the contact transient, so "rings longer" and "sounds
brighter" pull in opposite directions. The fix was the opposite of the instinct: harder material
means **higher and shorter**, not longer. Marble is now 460 Hz over 45 ms against wood's 190 Hz
over 55 ms. Worth keeping because the correction was only available by *measuring* — by ear at one
sitting the first version sounded plausibly like stone, and the description in the Settings footer
would have been quietly false.

**Picking auditions, and it deliberately ignores the Move toggle.** `soundSet`'s `didSet` persists,
drops the loaded samples and plays the new set's move cue. A picker over sounds you cannot hear
while picking is a list of adjectives; and a reader who has switched Move *off* would otherwise
audition in silence and reasonably conclude the picker was broken — so the audition is gated on
audibility (a fact about the process) and not on preference (a statement about taste). `.move` is
the cue it plays, because a set should be chosen on the sound you hear a hundred times an evening
rather than on its most dramatic one. `init` does not fire `didSet`, which is what keeps every
launch from clicking at you.

**An unknown stored value falls back to `.wood` rather than failing**, and that is what makes
retiring a set safe: dropping one would otherwise leave anyone who had chosen it unable to launch,
with the failure arriving on their machine rather than in the suite. Pinned by
`unknownSoundSetFallsBack`.

**Naming moved from `BoardCue` to `BoardSoundSet`.** `resourceName(for:)` lives on the set because
the set is the axis that *grows* — a cue is one of four fixed questions — and a convention belongs
with the thing that changes. The suite now pins the whole **set × cue product** rather than four
names: a collision *across* sets, `wood-check` reachable as marble's, is the failure no per-set
check could see, and the symptom would be one cue playing another's sound with every string still
spelled correctly.

Rejected: **round-robin takes within each cue** (3 subtly different move clicks in rotation, which
is the real game-audio answer to a held arrow key — invisible in Settings, so it answers a
different request than the one made; still available later, and it multiplies the sample count by
three); **a fourth "digital" set** (offered and declined — the three chosen are all physical
models, and a synthetic blip is the one that stops sounding like a board); **per-cue set choice**
(maximum control, and it makes an inconsistent set representable for no use anyone has); **a
segmented picker** (D48′'s reason: the view-mode control is segmented, and two segmented controls
read as one broken one); **a separate audition button** (hears all four cues, and adds a control to
a section that is otherwise a picker and four toggles, to solve a problem selection already solves).

#### Settings grows to five tabs — no D-number, and the omission is the decision

By request, 12 Aug 2026, immediately after D82′. General had accumulated six sections — connection,
an alert, the board cues, engine options, tablebases, sleep gates — which is a drawer rather than a
category. It is now **General, Board, Sounds, Engine, Data**: sounds and the illegal-move alert to
Sounds, engine options and Syzygy to Engine.

**No number because it reverses nothing, mints no vocabulary and changes no behaviour.** Not one
control, default, storage key or accessibility identifier moved — only which tab draws it. That is
this file's threshold, the same one the score sheet declined a number under, and holding to it here
matters more than usual: a reorganisation is exactly the change that *looks* significant while
being inert, and giving it a number would put a decision anchor where there is no decision to cite.

Two choices inside it are worth a sentence each, so they read as decisions rather than accidents.
**Energy stays in General** rather than following the engine, because only half of it is
engine-shaped — one gate is analysis, one is live play, under a single footer that deliberately
covers both causes at once (D66′), and splitting it to satisfy a tab would mean splitting that
footer. And **"Live Play" became "Alerts"**, the one non-mechanical edit in the split: that header
described *when* a sound happens, which was a useful axis beside connection settings and is the
wrong one beside a section describing *what* a sound is. The new name also puts D81′'s distinction
on screen — an alert about the board contradicting the game, at system alert volume, against
feedback that a move landed, at app volume.

The consequence to hold onto, and it is the reason the split was kept mechanical: **anything that
behaves differently after this is a defect, not a design choice.** The manual check says so too.


### D83′ — the collection surfaces share their machinery, not just their grammar

18 Aug 2026, from a DRY audit of the whole tree. Two new types — `IconGridView` and
`FilmstripGalleryView` — now own what `LibraryIconsView`/`PlayersIconsView` and
`LibraryGalleryView`/`PlayersGalleryView` had been spelling twice. The card stays the caller's;
everything around it is shared.

**The number is minted for the reversal, not the extraction.** `PlayersDestination` carried a
written argument that its `applyInspectorPolicy(for:)` twin was deliberate — "sharing would mean a
parameter whose only job is to say who's calling" — and that argument is *correct about a shared
function*, which is why this pass did not write one. The **policy** moved onto
`CollectionViewMode.inspectorPresentationOnEntry`, a `Bool?` where nil is a third answer ("no
opinion, leave it") rather than a default; each destination still writes its own flag in one line,
and nothing is passed. A recorded decision reasoned its way to the wrong shape and the entry that
overturns it should say which half of it survived.

**What the fork actually cost, since that is the case for the change.** `IconGridSelection` has
owned the pure half of the icons grids since Players became the second host, and it was the right
half to extract — index math and rect normalization are where a wrong answer is invisible. But the
stateful half stayed in two files: the drag gesture, the frame observation and its sweep gate, the
band overlay, the focus chrome, the anchor. Normalised for type names, 109 lines were identical.
The tell was in the comments — "the fifth cycling correction, **shared with the Library grid**" is
not a note about sharing, it is a note that a fix had to be applied twice and was. The sixth
correction now has one home, and `IconGridSelection.subjects` (Finder's "act on the selection, not
the card" rule, which the 17 Aug pass had to fix in the grid by hand) became a pure function with
its own tests instead of a private method on a `View`.

**What deliberately did not converge.** The two filmstrips still differ — 180 pt vs 170, stack-default
spacing vs 12, and a 160 pt card pin on the Players side only — and `FilmstripMetrics` holds those as
two named presets rather than one set of numbers. Only the Library's height has a stated reason
("the strip sizes itself to the card, never the reverse"); the rest is unexplained divergence, which
is exactly what must not be silently resolved by a refactor. Unifying them is now a one-line edit by
someone looking at both on screen, which is the only way that question can honestly be answered.

Also folded in the same pass, each small enough to need no number of its own: the two destinations'
byte-identical `backfillPlayerLinks()` onto `PGNStore.healPlayers(in:logger:)` (the logger *is*
passed, and that is not "who's calling" — a category is a contract with the console, and folding both
callers onto `.pgnstore` would silently empty two `log stream` predicates); five copies of the same
Library preview fixture onto `LibraryPreviewFixtures`, which is a separate type from
`PreviewFixtures` so the latter stays Foundation-only and keeps being a witness that the pure folds
work; a second `"yyyy.MM.dd"` `DateFormatter` in the columns fixture, deleted rather than relocated
— it was built without the UTC pin `PGNParser`'s doc calls load-bearing, so it was a second spelling
that already disagreed; `Square.pawnAttackOrigins(of:)`, which `Position.isSquareAttacked` and
`SpecialCheckmate.Context.pawnAttacks` each held inline, the second with a comment pointing at the
first for the convention; and `checkingBishopExists`, which was `bishopAttacks(king)` written out
again beside it.

**One finding recorded and not acted on.** `LibraryIconsView.onOpen` and `LibraryGalleryView.onOpen`
are unreached — the card has one Open door and both gestures route to `onOpenInPlace` — while
`LibraryDestination` still supplies them and still calls the first "the menu's new-tab door" in a
comment. That is a behaviour question (should a grid card's menu offer a new tab?), not a
de-duplication, so the properties stay and now say so at their declarations. Deleting a
destination-supplied door inside a refactor is how a refactor stops being trustworthy.

Rejected: **leaving the grids forked and extracting only the gesture** (about 60% of the duplication,
and it leaves two `body`s that must keep agreeing — the arrangement that produced the doubled
corrections); **generic over the selection type** (both destinations bind a `Set` and ⌘A writes one;
the generality has no second shape to serve); **a `static let` coordinate-space name on the shared
grid** (a generic type cannot have stored static properties — it is a parameter, and the two names
stay distinct so a space never resolves across a destination switch); **unifying the filmstrip
metrics now** (above); **`PGN` fixtures on `PreviewFixtures`** (costs it `import SwiftData` and mixes
model fixtures into the file whose Foundation-only character is the point); **logging both player
backfills under `.pgnstore`** (above); and **collapsing `applyInspectorPolicy` into a shared function
taking the destination** (the objection the old doc raised, and it stands).
