# DGT Studio Pro — Roadmap

*Created 29 July 2026 against clean `ab33bdf`. **Rewritten whole on 23 August
2026 against clean `28b45eb` as the final roadmap**: the ladder below is the
finish line, written so that when M23 closes, the scheduled section of this file
is empty and stays empty. Milestone slices with gates: each is a small coherent
unit with a written definition of done; no dates, sequence only — the one
calendar gate is M23, which waits for Xcode 27 GM and is deliberately last.
Updates to this file arrive as a complete `.md`. When a milestone lands, it
moves to the Landed section at the bottom with its gate evidence — the roadmap
is also the record of what shipped.*

*Next free milestone number: **M24.** The next free D-number lives in
`DECISIONS.md`, which owns it — this file repeats no count. Milestone numbers
live in one namespace with the legacy tags (M7.2, M-prs.1, the M11 decoupling
review, which was never a roadmap milestone): the next free number is `max`
over the sources and every document, never over this file alone.*

*The 23 August rewrite closed **M7, M12, M13 and M14** into Landed, each with
its gate evidence, and re-homed their survivors in the ladder: Instruments and
its run sheet → M17, the FocusedValue two-run check → M16, the
`LiveGameRosterForm` extraction → M16, the Xcode 27 GM re-read → M23. Revision
narrative is in `git log`, as before.*

**Currently scheduled: M15 → M23 in sequence, M20 excepted** — the clock was
withdrawn to Horizon on 26 August 2026, by request: it is post-GM work, and
its number stays vacated rather than reused. M15 blocks everything —
nothing on this tree is trustworthy until the 21 August patch has its first
build. The sequence is the argument: verify before measuring, measure before
fixing, fix before extending, extend before the board sitting that witnesses
it all, and consolidate before the toolchain move that closes the book.

---

## The finish line

*What "finished" means here, stated once so every gate below is a step toward
something checkable rather than toward a feeling. "No bugs" is not a checkable
claim; this ladder's version is: every claim checked, every cost measured,
every affordance reachable, every check run. The project is done when every
line of this table is true at the same time, on the same tree:*

| Condition | Witness |
|---|---|
| Cold build, zero diagnostics, language mode 6, all targets | scratch derived-data build log |
| ⌘U green at the expected denominator, counted | Bera's run, suites reported |
| Logic-core coverage ≥ 90%; whole-target number recorded, not chased | the app-target-scoped coverage plan (M15 baseline, M18 target) |
| Known-costs census: every entry priced or struck | the Instruments pass (M17) |
| Owed manual checks: zero — run, or struck with a written reason | PROJECT-INSTRUCTIONS § Manual checks |
| Open items: zero unscheduled; Horizon is by choice, each entry deliberate | PROJECT-INSTRUCTIONS § Known open items |
| Waiver register empty — both `Binding(present:)` sunsets executed | M23 |
| One full board sitting clean, on the finished feature set | M21's recorded sitting |
| Both documents pass their own greps: counter-grep, D-citations, counts vs commands | M22 |

---

## M15 — The first build

**Goal: the 21 August patch stops being "a reviewed patch awaiting its first
build".**

The tree carries four commits of work no compiler has seen (`1018add` the
coverage key, `ef082dd` the perf fixes, `2c1030c` the label pass, `9bffce8`
the convention pass) — 66 files edited with no Swift toolchain present.
Brace balance was checked mechanically, and AUDIT-VERIFICATION.md §6 says the
rest out loud: *"Nothing here has been compiled or tested."* It also names the
likely break points in order: `BoardFrame` / `BoardGrainOverlay` (new
`Equatable` conformances, an implicit-`@ViewBuilder` body with a bare `if`),
the two new memo-key types (`OpponentsKey`, `SelectionKey`) and their
`CollectionFoldCache` instantiations, and `coreContent`'s widened signature in
`PlayersDestination`.

- **Cold build against a scratch derived-data path, both targets.** Fix
  what surfaces; each fix stays inside the finding it repairs, and anything
  larger than a touch-up gets its own commit with its own reason.
- **⌘U, counted.** The 8 August run was 1108 tests / 101 suites; the tree
  since adds four suites and D80′ deleted one, so ~104 is the expected
  denominator. A run reporting far fewer skipped something — that is the
  failure a bare "green" cannot show.
- **The `customizationID` renames reset saved column layouts once, by
  decision** — confirm the columns come back and the two renamed ones
  (`checkmateType`, `name`) re-persist after a quit.
- **Phase 0 of the coverage plan, same sitting.** The test plan now carries
  `codeCoverage` scoped to the app target, so the baseline is takeable for the
  first time in the project's life. Take it with and without `.slow`, note
  whether Stockfish was present, and write the number into the instructions
  with its command.

**Gate.** ⌘U green with the denominator reported; the coverage baseline
recorded; tree committed clean. Nothing else on this ladder lands until this
does — every later milestone builds on 66 files that are currently a claim.

**Status, 24 Aug 2026 — the build happened and the claim held.** The
combined set (the 21 August patch *plus* the 23 August sitting, ~85 touched
files) compiled with **one** error: `CollectionViewOptions.inset`, an
isolated `static let` read from the newly `nonisolated` fit math — fixed the
same hour, lesson recorded in Build-diagnostic lessons. None of
AUDIT-VERIFICATION §6's predicted break points (`BoardFrame` /
`BoardGrainOverlay`, the memo-key types, `coreContent`) actually broke. **⌘U
green, reported by Bera.** The commit landed the same night as **`4d3761e`**,
both new files tracked. Still owed before this milestone moves to Landed:
the suite count off the report (~105 expected — a far-lower number means
something was skipped), the coverage baseline off the same report (with and
without `.slow`; note whether Stockfish was present), and the column-layout
reset check.

---

## M16 — Every question with a cheap answer

**Goal: the open-items list stops carrying entries that one launch, one read,
or one small build would settle.** M7's lesson stands guard over this
milestone: an unmeasured item accrues imagined weight, and the longer it sits
the heavier it reads.

*The experiments — write the answer down whichever way it comes out:*

- **FocusedValue, the two-run check** (M12's survivor). Launch into
  **Library** — the warning should be gone, because the destinations'
  publish-and-self-read cycle was fixed in `863a623`. Launch into **Board** —
  if it returns, the second cause is real: `BoardDestination` mints
  `$getInfoRequested` fresh on every body pass and `Binding` is not
  `Equatable`. **If it returns, fix it here** rather than filing it: the shape
  is a stable trigger publish, and since the arrangement is D53′'s
  trigger-binding pattern in its third use, the fix is a decision about a
  pattern and takes a D-number at recording.
- **The geometry warning's confirmation launch** — icons view, console open,
  expected silent; then one rubber-band sweep confirming selection still
  tracks the band (the gate's first 4 pt select nothing — Finder's own feel).
- **Does the gear loop?** One minute of a live batch, or the *Every State,
  Both Titles* preview. The fallback is named at `AnalyzingGear`.
- **The chevron's 12 pt gap** — the *Collapsible, No Actions* row in the
  *Actions — Every Arity* preview. The one D45′ claim written from reasoning
  rather than read off a compiler.
- **⌘⌫ / ⌘E / ⌘R with no menu open.** If delete-by-keyboard is dead, **build
  the menu-bar `Commands` scene this time** — skipping it was decided with
  that remedy on the table, and a keyboard-reachable delete is part of the
  finished feel this ladder exists for.
- **Syzygy through the sandbox** — the three-readings check at
  Settings ▸ Engine ▸ Check. If the child process loads nothing, the fork is
  `ENABLE_APP_SANDBOX` off (no App Store here) versus copying the tables into
  the container — an architecture decision waiting on one button press, and it
  takes a D-number whichever way it goes.
- **Export filename numbering vs. DGT's own convention** — read a folder the
  DGT software wrote, compare, confirm or correct `PGNSerializer.fileName`,
  and strike the open item either way.
- **The 20 July log-format leftovers** — one live session with `DGT_LOG=1`,
  read against what the format strings promise.

*The small builds:*

- **Import cancellation — implement or relabel, decided rather than
  deferred.** The sheet already survives ⎋; the honest minimum is a cancel
  that stops between files and reports what landed. If the decision is
  "relabel", the label stops promising what the code does not do, and the
  item closes as a decision.
- **`LiveGameRosterForm` out of `NewLiveGameSheet.swift`** (M13's survivor,
  still at line 32 of its host). Three consumers now — `NewLiveGameSheet`,
  `EditLiveGameDetailsSheet`, `EditGameInfoSheet` — and it owns the D61′ seat
  refusal. A shared type carrying a refusal lives in its own file.
- **The stale-check purge.** The D82′ set-picker manual checks outlived the
  feature: sound packs were deleted on 17 August (`141b9fa` — one voice, nine
  cues over seven samples) and the owed list still schedules auditioning a
  picker that no longer exists. Strike them with the dated note the
  instructions' style requires, and re-read the surviving D81′ cue checks
  against the one-voice reality while there.

*The boardless owed checks, run as a batch and recorded:* the 7 August
performance-pass list, the 8 August sitting list, the 9–10 August list, D81′'s
cue checks (the app-must-not-quit one first), the Settings five-tab check,
sleep inhibition flipped mid-batch under `pmset -g assertions`, the ten
checkmate motifs visually, and the boardless standing list. None needs the
board; most need ten minutes and a written result.

**Gate.** The instructions' § Known open items holds nothing answerable from a
keyboard; § Owed holds only board-required lines; every experiment's answer
written where the question stood. ⌘U green on whatever code moved, counted.

**Status, 26 Aug 2026 — the three small builds are code, awaiting their ⌘U.**
The stale-check purge ran: the D82′ re-read held for the cue checks and caught
two more survivors (the five-tab check's set picker, README's Sounds caption)
— fixed, with the screenshot re-capture owed. `LiveGameRosterForm` and the
three placeholder helpers moved to their own file, proven a pure relocation by
the comment-stripped projection (byte-identical code, the M13 method); the
"stay where they are" note at `EditLiveGameDetailsSheet` reversed by name.
Import cancellation implemented as decided: an `isCancelled` flag the loop
reads between files, a live Cancel that disables once the request is in
flight, "Import Stopped" plus an "N not imported" summary part, ⎋ untouched;
`ImportProgressTests` pins the partition, the counts and the cancel
arithmetic; two registry entries (`library.import.cancel`, `.done`). **⌘U
green on the slice, reported by Bera, 26 August** — counts not reported, so
M15's denominator ask stands. The experiments and the boardless batch remain
Bera's; the checklist is in the instructions' § Owed.

---

## M17 — Instruments

**Goal: the known-costs census stops being a list of admissions and becomes a
list of numbers.** M7's surviving item, unchanged in intent — the one bullet
three passes of demolition could not dissolve, because it was written as an
admission of ignorance rather than as an assertion. It is also this ladder's
only remaining unmeasured-performance debt: the 21 August perf fixes landed
upstream (M15 built them), so the pass doubles as the check that the memos
hold — **a key that misses every render profiles exactly like no key.**

### Instruments run sheet

*Written 31 July with D44′; re-read 6 August against the census (it needed it:
a deleted destination named, the whole search-and-filter path missing — now
scenario 5); rows corrected 10 August after D75′/D76′/D78′ retired or gated
costs the rows still name. The standing instruction survives the rewrite:
**re-read this sheet against the census on the morning of the run**, because a
run sheet is a claim about what the run will cover.*

**Template names verified against the picker, 6 Aug 2026 (Xcode 26.x).** There
is **no "Core Data" template** — the SwiftData one is **Data Persistence** —
and the os_log instrument is the **Logging** template. Three easily missed:
**File Activity** for the draft sidecar's per-ply atomic write; **Swift
Concurrency** for the engine-teardown contract; **App Launch** for whether the
ECO table's ~3,800-row parse lands on the main actor. **CPU Profiler** sits
beside **Time Profiler** in the picker — this sheet names Time Profiler
because its call-tree behaviour is understood here; CPU Profiler is an
experiment, not a sight-unseen substitution.

**Setup, and it invalidates everything if wrong.** Profile (⌘I) builds
**Release**; confirm the scheme's Profile action actually says so. Debug Swift
is unoptimized, and its numbers are both wrong and plausible.

**Two toggles do most of the work in Time Profiler:** *Hide System Libraries*
and *Invert Call Tree*. **The census is mostly "runs N times per render", not
"this is slow"** — so **SwiftUI**'s View Body lane is the primary instrument
for scenarios 3–5 and Time Profiler is secondary. **No signposts needed**: add
**Logging** to the document and the existing `AppLog` categories appear on the
same timeline.

**Two rules for the whole pass, both learned the hard way here.**

*Every scenario records a corroborating count* — plies played, games imported,
info lines parsed, players folded — beside its numbers. An idle app profiles
beautifully; if the count is absent, the measurement did not happen.

*Every super-linear cost is measured at two sizes, and the ratio is the
finding.* Import a duplicate batch to double the Library, re-run, compare.
**A 2× input that costs 4× is the result worth having**, and it is invisible
to any single run.

| # | Scenario | Instruments | Known costs it exercises | Record |
|---|---|---|---|---|
| 1 | **A full live game**, real board, to a natural finish | **Time Profiler** + **Allocations**; **Leaks** at teardown; **File Activity** for the sidecar | `parseSAN` generating all legal moves per ply; `Position`'s `[Piece]` heap-allocating per `applying`; pawn movegen's per-call capture-offset array (the one census entry gated on perft rather than appetite); the draft sidecar's atomic write per committed ply; the New Game sheet's `games.map(\.gameRecord)` fold per seat edit | Plies played; main-thread time per settle; allocations per ply; whether any settle crosses the hang threshold |
| 2 | **A depth-heavy analysis** on one long game | **Allocations** + **Time Profiler**; **Leaks** after Stop All; **Swift Concurrency** for the teardown contract | `UCIProtocol.parse`'s ~3 arrays per info line — by frequency the hottest allocation in the app; engine teardown (the strand-no-waiter contract) | Info lines parsed; allocation rate; Stockfish resident memory against configured Hash; zero leaked engine processes after Stop All |
| 3 | **A large import**, then the first Library appearance, then select a game and expand its PGN section | **App Launch** for the ECO parse; **Time Profiler**; **SwiftUI**; **Data Persistence** | The ECO table's ~3,800-row parse, warmed off-actor but never measured; `ECOClassifier.opening(for:)`'s quadratic prefix re-join, bounded at 36 plies; MD5 per game; `parseSAN` × plies × games; the inspector's PGN section re-serializing while expanded (collapse-gated since D45′; the columns detail's copy ungated) | Games imported; wall-clock import; whether the ECO parse ever lands on the main actor; time to first Library paint; body evaluations with the PGN section open vs collapsed; **then double the batch and re-run** |
| 4 | **A Players browse**, then a rename | **Time Profiler**; **SwiftUI**; **Data Persistence** | The fold behind its memo key (confirm the memo holds); `retag`'s per-game re-resolve + MD5, O(linked games), **inside a modal save**; the D76′-scoped collection at the editing doors | Players in the fold; body evaluations per navigation; rename wall-clock against the linked-game count — the one a user feels, because it blocks a sheet |
| 5 | **Type in the Library search field**, with a tag filter active and a non-default column sort | **SwiftUI** first, **Time Profiler** second | `CollectionSearch`, `LibraryFilter.matches`, the glyph scan and the ECO comparator — all behind memo keys since 7–9 Aug, so "per keystroke" means *per input change*; the run confirms the memos under load | Keystrokes; body evaluations per keystroke; time per keystroke at 1× and 2× Library. **Sort by ECO and by `#` and compare** — one comparator rehydrating, one comparing `Int?` |

**What the pass is allowed to change: nothing.** It produces numbers, and the
numbers go into the census — each entry either gets a figure or is struck as
negligible. Fixes are a separate decision with a separate D-number, because a
performance change made in the same pass as its measurement has no
before-and-after. The `backfillClassifications` predicate is the model.

**Do not add signposts first.** The `os.Logger` categories give coarse
intervals for free; `os_signpost` is production code riding a measurement
pass. Profile raw; reach for signposts only if a specific profile is genuinely
unreadable, as a small named change.

**Eligibility this unlocks.** D27′ gates the perft/ownership forward notes on
this pass explicitly. The standing veto survives the measurement: no
`~Copyable` or specialization work on the move generator regardless of the
numbers — generated move order is what the perft counts were taken against, so
perft is both the witness and the thing that can refuse the change.

**Gate.** Every census entry carries a figure or a strike, written into the
instructions; the two-sizes rule applied to every super-linear entry with the
ratio recorded; each scenario's corroborating count present. Anything the pass
flags becomes its own scheduled fix with its own evidence — inserted as
M-numbered work before M18 if structural, folded into M18 if it is an
extraction the coverage phase would touch anyway.

---

## M18 — Coverage and structure

**Goal: the logic that can be pinned is pinned, and the structural findings
that survived adversarial re-check are fixed or carry a written disposition.**

*Coverage — phases 1–3 of TEST-COVERAGE-AUDIT.md's plan, in order:*

- **Phase 1, the free points.** The unreferenced non-view files — the audit's
  nine plus the verification's four (`GameAnalysisDriver`, `PGNExporter`,
  `EngineProgress`, `SyzygyLocation`) — and the refusal paths:
  `#expect(throws:)` appears 69 times against 130 `throw`/`throws` sites, so
  the refusal seam is the densest. Ordinary work in the suite's own style.
- **Phase 2, extract logic out of views** — the `EvaluationGraphReading`
  precedent exactly, one `Sendable` value type beside each host:
  `AnalysisQueueReading` (seven pure formatters, the best ratio in the
  codebase); `BoardGeometry` (`layout(for:)`, `gridBorderInset`, and the
  perspective XOR — `^ 56` / `^ 7` is a correctness claim currently checked by
  nothing but the eye); `monotoneSlopes` beside `EvaluationGraphGeometry`
  with a property test over random evaluation sequences (a stronger witness
  than the 17 Aug visual comparison it rests on); the fold and selection
  algebra out of both destinations to sit beside `CollectionFold`
  (`narrowed`, `searchFields(of:)`, `gamesInDisplayOrder`, `selectAll` — the
  ordering contracts the architecture doc says every fold must have, currently
  unpinnable inside a `View`); `NewLiveGameSheet.normalized` and
  `GetInfoWindow.title` / `resolve`. Contract changes take D-numbers; pure
  relocations do not.
- **Phase 3, the decision, recorded rather than drifted into:** the standing
  gate becomes **≥ 90% on the logic core**, with the whole-target number
  recorded but not chased. No UI suite reinstated, no third-party snapshot
  testing — both rejections re-affirmed on their existing arguments (the
  flaky-launch saga; first-party-throughout), not re-argued.

*Structure — the survivors of AUDIT-VERIFICATION.md (the 27→9 cycle plan is
debunked and stays dead; these stand on their own merits):*

- **`SessionPhase` out of `LiveGameHUDView.Phase`** — domain priority logic
  that cannot compile without SwiftUI in scope. The best finding in the four
  audits.
- **`GameResult` re-filed** out of `PGN/PGN.swift` — five of its use sites are
  `Chess/MovetextEdit.swift`; file it by meaning.
- **`Player` as a co-owned `@Model`, and `Shared/Collection` as a
  switchboard** — *decided*, not necessarily moved. The verification showed
  the cycles are not caused by file placement, so what remains is whether
  either arrangement has a cost a reader feels. Write the disposition either
  way; a considered "stays" closes the item as firmly as a move.
- **The deferred renames, with a compiler in the loop** (each was declined
  precisely because no compiler was present):
  `AnalysisQueueStatusWindowView` → `AnalysisQueueWindow` (touches `sceneID`
  call sites); the file/type mismatches (`Square.swift`, `LibraryChrome.swift`,
  `DGTProtocolTests.swift`, the recorder/recording test pair); the §5 Board
  namespace recipe **executed or struck for good** — it has been deferred
  since July and a final roadmap does not carry a permanent deferral; the
  FEN / GameState collapse.

**Gate.** Logic-core coverage ≥ 90%, measured with the command recorded; ⌘U
green, counted; every structure item fixed or carrying a disposition at the
site; no rename landing without a clean build in the same sitting.

**Status, 26 Aug 2026 — Phase 1's free points are suites; the refusal seams
remain.** Six new suites: `LibraryMessagesTests` (the deletion clause's four
arms against a real store, the backfill grammar's every branch with both
truncation boundaries), `BoardStyleTests` (persisted raw spellings, plus the
one-lowercase-word rule `displayName`'s doc stated and nothing enforced),
`SquareHighlightTests` (six distinct single bits), `BindingPresentTests`
(the dismissal contract, including true-is-not-a-command),
`GetInfoRequestTests` (Codable routing round-trips, `.game` through a real
inserted id), `SyzygyLocationTests` (the census summary shapes, the
nil-clear taking both keys, access refusing garbage). Dispositions instead
of decoration: `EngineProgress` joined the waiver table (pure payload, a
suite could only re-assert the compiler); `BoardStyle` and `SquareHighlight`
left the presentation-types waiver row in the same change; `TabState`,
`Inspector+Toolbar`, `InspectorColumn` and `DGTDeviceDiscovery` stand on
their existing waivers.

**The refusal seams, same day (second half).** Surveyed rather than assumed,
and the audit's 21 Aug list was partly stale: retag's three rejection arms,
the archive's `.ongoingGame`, the parser's tag/brace/paren refusals, and the
session's recovery escalation and draft cadence all had pins the audit
predated. Three genuinely missing pins added to their existing suites:
`PGNParser.Error.multipleGames` (the one parser refusal with no test),
`PGNStore.Error.fileReadFailed` naming its URL at the door, and the
correction-hint lifecycle in `DGTLiveSessionTests` — the EP nudge raised
with its exact message, committing nothing, not a desync; then the fix
committing `exd6` and clearing it. What Phase 1 leaves for Phase 2's shape:
the `DGTConnection` reconnect-policy extraction (a structural move, not a
free point) and `StockfishEngine`'s teardown contract (engine-gated).
Expected ⌘U denominator: +6 suites over M15's count (≈112), the three new
pins riding existing suites.

**Phase 2, first two extractions (26 Aug 2026, same day).**
`AnalysisQueueReading` takes the queue window's prose pure — header, timing
line, speed tiers, ply label, outcome symbol and detail — generic over the
id so its suite runs on `Int` with no store; `outcomeTint` stays in the view
(`Color` is presentation) and the move label stays
`GameAnalysisDriver.moveLabel` (the driver is `@MainActor` and already the
one spelling). `BoardGeometry` takes the board's arithmetic — `Layout`, the
grid-border inset with its rosewood-fifteenth warning, and **the perspective
mask, which was spelled four times across two files** (the grid's XOR, the
piece layer's inverse, both coordinate strips' ternaries): the strips now
derive from the one mapping and the layer reads the involution back, so the
four-spellings hazard is unrepresentable, and `BoardGeometryTests` pins the
orientation corners, the 128-cell involution, layout conservation per style,
and the fifteenth. Two new suites (≈114 expected); rendering unchanged by
construction — the checkpoint's eyes-on-board confirms.

**Phase 2, second slice (26 Aug 2026, same day).** `monotoneSlopes` moved to
`EvaluationGraphGeometry` and the no-overshoot claim stopped resting on the
17 Aug visual comparison: `EvaluationGraphSlopesTests` evaluates the cubic
Hermite the view's Bézier *is* (the conversion is exact, which is what makes
a test-side evaluator an oracle rather than a copy) against seeded random
sequences at seven lengths — the curve never leaves any ply interval — plus
the two Fritsch-Carlson clauses pinned singly and the NaN guard. The M16
roster trio (`formValue` / `tagValue` / `normalized`) gained the pins it
never had, the round trip and the touches-exactly-four-fields contract
included. **`GetInfoWindow.title` / `resolve` close as a disposition, not an
extraction**: `resolve` and `seedGameDrafts` are store transport under the
tombstone invariant's existing pins, and `title` is a four-line model read
whose one derivation (`PlayerName.displayForm`) is pinned at its owner — a
considered stays. Remaining in Phase 2: the destination fold and selection
algebra, the one extraction that touches behaviourally live ordering
contracts. Two new suites again (≈116 expected).

**Phase 2 closes (26 Aug 2026, same day).** `CollectionSelection` extracts
the two selection contracts both destinations ran inline — display-order
subsequence (what queues and numbers exports) and ⌘A's every-visible-row —
generic over `Identifiable`, pinned on plain values including the
select-all-then-read-back identity. Two dispositions with findings, not
shrugs: **`searchFields(of:)` stays view-side because retyping it onto
`GameRecord` would change behaviour** — `record.white` is nil for an
unlinked seat while `PGN.whiteDisplayName` always renders the stored tag,
so the move would silently drop unlinked players' names from search (found
by checking the projection before trusting the relocation); and **the
narrowing pipeline stays the memo's body** per D78′ — its key completeness
is `DestinationDisplayKeyTests`' to hold, its pieces are individually
pinned (`SearchMatch`, `LibrarySearchToken`, `LibraryFilter` → `TagRule`),
and extracting it would retype the Table's `KeyPathComparator<PGN>` sort
off the model for no pinnable gain. With `GetInfoWindow`'s disposition
above, every Phase 2 line item is now extracted-and-pinned or
dispositioned-with-reason. One new suite (≈117 expected).

**Structure, first slice (26 Aug 2026, same day): the best finding lands.**
`SessionPhase` is its own type in `Game/SessionPhase.swift` — the register
and one doc comment had called it that for days while the code spelled it
`LiveGameHUDView.Phase`; the code now agrees with what the documents knew.
The derivation's connection gate takes `isReconnecting` / `isConnected` as
named scalars, which is what retires the register's regret: the whole
ladder runs off a headless session, and `SessionPhaseTests` pins every arm
— reconnecting outranking a live game (and the gate itself), disconnected
as no-phase, idle, setup, playing with its live payload, the EP correction
outranking playing, recovery off an inexplicable board, the finished
banner, and a failed archive outranking it. The `SessionPhase` waiver row
is struck. `GameResult` re-filed to `Chess/GameResult.swift` by meaning
(five use sites in `MovetextEdit`; the chess core decides results before
the store sees one), its hash-input warning written at the new home. The
deferred renames travel alone, next slice — mechanical changes do. One new
suite (≈118 expected).

---

## M19 — Discard, and the review layer

**Goal: the Board gets its missing exit, and the archive starts talking about
quality — both engine-free, off data the app already stores.**

- **The Discard button, Board toolbar.** Two meanings, one button,
  mode-decided:
  - *Reviewing an archived game:* clear the board back to the empty state —
    `clearBoard(error: nil)` already exists in `BoardDestination` and is the
    whole of the mechanism. The Library row is untouched: discard-from-board
    is not delete-from-Library, and the control's help text says so.
  - *Live recording:* confirmation first — this is the double-check the
    feature was asked for — then the existing `session.discardGame()` path.
    The inspector's Discard stays; **both doors share one confirmation**, one
    predicate, one spelling of the copy, because two doors with two dialogs is
    the twin-read-site shape in dialog clothes.
  - The disabled state (board already empty) must be producible both ways —
    D40′'s check at minting. Registry entries for the button and the dialog.
- **The review layer.** Per-ply evaluations, win %, and the swing column
  (D77′) already exist; the layer derives and stores nothing new unless a
  backfill decision says otherwise:
  - **Move classifications** off win%-swing — the D77′ column's own currency.
    Thresholds as data, exhaustive switch, vocabulary chosen once
    (inaccuracy / mistake / blunder). **No "best move" tier**: the stored
    data cannot honestly say it without multipv, and a tier the data cannot
    produce is a lie with a green build.
  - **Per-game accuracy** — a pure fold over the swings, formula recorded at
    the declaration with its rejected alternatives (chess.com's CAPS is
    proprietary; a monotone map from mean win%-loss is honest and stated as
    ours). Both players, per game.
  - **Surfaces:** classification badges in the move list; an accuracy summary
    in the Library inspector's Evaluation section; accuracy in the Players
    stats grid and gallery (the eight-fact grid grows deliberately, not by
    accident); "jump to biggest swing" beside the existing game navigation.
  - All of it memo-keyed like every other fold, and the census gains entries
    only if M17's method says they would be visible.
- **The feature intake rule, since more features will follow:** a new feature
  enters this ladder as its own numbered milestone inserted **before M22** —
  consolidation and the GM close stay last, whatever arrives.

**Gate.** ⌘U green with the new folds pinned (threshold algebra, the accuracy
fold, classification-vocabulary raw values if they ride a blob, the discard
confirmation's producibility); the boardless manual checks for both features
written into the instructions and run; D-numbers minted at recording for the
classification vocabulary and the discard contract.

---

## M20 — *withdrawn to Horizon, 26 August 2026*

The clock left the ladder by request: inbound DGT 3000 support is post-GM
work. The entry moved whole into Horizon below — research notes, phases and
the mode-migration risk intact, so none of it is re-derived — and the number
stays vacated; the namespace never renumbers. M21 loses only its clock
lines, and the finish line never depended on this milestone.

---

## M21 — The board sitting

**Goal: every check that needs hardware runs in one recorded sitting, on the
finished feature set.** Scheduled after M19 so nothing added later
invalidates the sitting — this is the witness pass, and a witness pass over a
tree that then changes is a profile of a different app.

The needs-the-board list verbatim (auto-connect both ways, the remembered-board
no-op, mid-game cable pull, discard mid-outage, record → pull → stop-and-export
coherence, illegal-move sound both ways, idle-sleep both ways across a long
think, a recording surviving an idle window, one desync worked through from the
session checklist, Round prefill, `[Board]` serial matching and surviving a
draft resume). D47′'s animation checks (a slid pawn glides; lift-think-place
fades honestly; fast O-O animates; the connect dump **fades** — thirty-two
flying pieces means the anonymous-key rule broke; recovery overlays and ghosts
never animate). D81′'s live-cadence cue check (~300 ms settle — the delay is
the feature; a cue for an uncommitted move is the F5 shape). M19's discard
button exercised live: the confirmation appears, a confirmed discard stands
the loop down, a cancelled one changes nothing. *(The clock checks that
stood here left with M20 on 26 Aug 2026 — they run under the Horizon
entry's own gate when it does, not in this sitting.)*

**Gate.** Every line run with its result written into the instructions'
manual-checks section; anything red becomes a scheduled fix **before M22** —
the sitting is the witness, not the fix.

---

## M22 — Consolidation

**Goal: the documents describe the finished app, and every count in them
re-derives from a command.**

- `PROJECT-INSTRUCTIONS.md` rewritten to final form: Where-things-stand
  current and audit-verified, the owed lists empty, open items zero-or-Horizon,
  the waiver register carrying only the two `.alert(item:)` sunsets M23 will
  retire, the manual-checks section reduced to the standing lists a finished
  app still re-runs after a toolchain move.
- This roadmap's ladder all in Landed with evidence; Horizon relabeled
  **post-final intake** with its rule.
- **The four audit documents retired** the way the review documents were on
  7 August: their methods are already lifted into working agreements or
  consumed by M15–M18, their findings resolved or dispositioned; delete them,
  sweep for dangling citations (the one dangling `AUDIT-2026-08-01` citation
  is the precedent for why the sweep is a grep, not a memory). If any finding
  is still open at that moment, it moves to a document that is not history.
- **The full grep battery, run and clean:** the milestone counter-grep across
  all three documents; every cited D-number resolving to an anchor; prohibited
  tokens; the `.disabled(…)` census with every enabling value producible; the
  comment-stripped declaration scan at its expected set; counts against
  commands.

**Gate.** Every grep clean; a cold build and a counted ⌘U on the exact tree
the documents describe; the finish-line table checked line by line, every line
true except M23's own.

---

## M23 — Xcode 27 GM *(calendar-gated, deliberately last)*

**Goal: the project closes on the toolchain it will live on.**

- **D27′ re-read**: every forward note promoted or struck on evidence, none
  carried forward — a closed project has no forward notes.
- **The waiver register empties.** The 2027 SDK's `.alert(item:)` retires
  `Binding(present:)`, its helper, and both waived warnings across the eleven
  call sites the migration touches. The sunset condition written at the
  declaration in July executes here.
- **Liquid Glass screenshot pass** over the board chrome and all four view
  modes × three destinations; the full window-chrome re-check (D80′'s
  companions over full screen, restoration, the queue window's singleton
  behaviour).
- **`sectionBy` noted against the Horizon sectioning entry** — adoption is
  post-final intake, not this milestone.
- **Last: the finish-line table, all lines, one sitting.** When every line is
  true, this file's scheduled section is empty, and the project is finished —
  not abandoned, finished: maintenance and intake continue under the Horizon
  rule, but nothing is owed.

**Gate.** Mode-6 clean cold build on GM; ⌘U green at the final denominator;
the waiver register empty; the finish line signed with its evidence.

---

## Horizon — post-final intake

*The rule: before M22, a new feature enters as a numbered milestone inserted
ahead of consolidation (M22 and M23 stay last, whatever arrives). After M23,
features enter as M24+ maintenance milestones with the same gate discipline —
the ladder closes; the method doesn't.*

- **File ▸ Export** via `.focusedSceneValue` — three worked examples in the
  tree; read M16's FocusedValue answer first, since this would be that
  pattern's fourth use.
- **Library sectioning by opening / event / player / month** — cheaper after
  M23 on the 2027 SDK's native `sectionBy`, which is the reason it waits.
- **A click-to-move / position-setup surface** — the one entry with code
  already waiting: it consumes `BoardView.selectedSquare`,
  `SquareHighlight.selected` and `SquareView`'s tint arm. **The pre-wiring
  stays because this entry does** (M12.3's disposition); if this entry is ever
  struck, the wiring goes with it in the same commit.
- **A deferring editor / inline annotations** (NAGs, comments) — consumes
  `OpenGamesRegistry.markDirty` and turns on `LibraryDestination.delete`'s
  discard-confirmation arm with no wiring. Same contract as above: entry and
  wiring live and die together.
- **An opening-tree explorer** over the Library — natural since M4 gave every
  game an ECO identity; pairs with per-opening performance stats off the same
  fold.
- **Print / PDF score sheet** — `MovetextScoreSheet` already renders the
  layout; print is the natural finisher for an over-the-board app.
- **The clock, inbound** *(withdrawn from the ladder as M20, 26 Aug 2026 —
  post-GM by request; the research stands here so it is never re-derived)*.
  The DGT 3000 as part of the daily driver: live times on the board surface,
  `%clk` in the archive. **The mode is the risk, not the message** — the
  board pushes clock messages only in UPDATE / UPDATE_NICE, and this app
  deliberately runs UPDATE_BOARD (`DGTCommand.sendUpdateBoard = 0x44`), so
  clock support is a mode migration for the whole session pipeline; the
  framer, decoder and reconstructor are all fixture-pinned against the
  quieter wire. On hand: `DGT_SEND_CLK` (`0x41`) for a one-shot read; the
  clock message carries both times BCD-style plus a status byte (running
  side, flag fallen, low battery, clock present); the two filters every
  serious implementation applies — **reject minutes/seconds ≥ 60** (garbage
  during connection and button presses) and **reject a time that increases
  for the running side** (corrupt packet; picochess filters exactly this
  way). Command bytes verified against `dgtbrd.h` before relying on them;
  picochess is the comparison implementation when a message does not decode.
  Three phases when it runs: **(A)** a protocol note before any code —
  capture real traffic with the session recorder, write `docs/DGT-CLOCK.md`,
  and answer the load-bearing question of what UPDATE mode does to
  field-update traffic during live play; **(B)** decode and model — a typed
  clock message, a `ClockState` applying both filters at the boundary,
  fixtures from captured traffic, the migration behind a clock-present check
  so **a clockless board keeps today's wire byte-for-byte** with the
  reconstructor suite as the untouched regression net; **(C)** surfaces —
  HUD times, `[%clk H:MM:SS]` per ply at commit under D24′'s export
  contract, flag-fall displayed never adjudicated, and no low-time cue
  without its own decision. Gate when it runs: ⌘U green on the fixtures and
  the clockless-wire regression, the protocol note in `docs/`, one real game
  recorded with times and exported with `%clk`, plus its own board sitting
  for the desk half. **If the mode migration destabilizes move settling in
  any way the reconstructor fixtures cannot see, the work stops and records
  why: the move pipeline outranks the clock.**
- **Outbound clock control** (set time, display text, beep) — a separate,
  firmware-version-sensitive command family; only after the inbound entry
  above has survived a month of daily use.
- **The custom Xcode agent skill** encoding the working agreements — after GM.

---
## Landed

### The 23 August sitting — one menu rule, the grid stops re-proposing per frame, and the card sheet becomes a choice *(recorded 23 August 2026)*

Two reports and one feature request, the same day as the rewrite below,
nineteen source files, numberless throughout (defect fixes, a
standardization, and an additive preference; no recorded contract reversed —
`PlayerActionsMenu`'s single-subject rule is *strengthened*, not repealed).

**The feature: what the Library card writes on its sheet is now the View
Options "Icon" picker's choice** — index (the pre-picker rendering,
byte-identical at the default), result, date, or round.
`LibraryCardInscription` owns the vocabulary and a pure `content(...)`
derivation (pinned in its own nonisolated suite), persisted on
`CollectionViewOptions.libraryCardInscription` under a new `StorageKeys`
entry with the retired-raw-value fallback the view modes follow. The picker
renders only where its effect is visible — Library subject, icons and gallery
modes (`hasCards`), never on the table modes or Players — and both card
hosts pass the choice through, the gallery gaining the options environment
read (both its previews now inject it, per the new-environment-object rule).
Two display decisions argued at their declarations: the date is a two-tier
calendar form (month abbreviated above, day large below, sized as fractions
of `glyphWidth` so the slider scales the writing with the sheet), and **a
draw inscribes "½-½", not the stored "1/2-1/2"** — the `Glicko1`
provisional-marker precedent for a narrow surface, with a pin asserting the
compact form differs from the raw spelling precisely so it cannot quietly
become it. Absent values write `RosterSummary.displayUnknown`, stated once
in the derivation rather than per surface. Registry: one entry
(`viewOptions.icon.inscription`), taking the count to 146.

**Second report first, because its finding is the sharper one:** *"opening or
closing the inspector makes the UI refresh very laggy, especially in list or
icons view."* The icons half was ours. `IconGridView` wrapped the entire grid
in a `GeometryReader` whose only jobs were deriving the column count and
handing the arrow keys a width — and a `GeometryReader`'s content closure
re-evaluates whenever its size changes, which during the inspector slide is
**every animation frame**: every card's view struct rebuilt, every per-card
`onGeometryChange` re-registered, the whole subtree diffed, at animation rate
over the most view-dense surface in the app. The 8 August pass had gated the
per-card frame *transforms* and left the container-level reader standing —
same disease, one level up. The fix is the same shape as that pass's, promoted:
**quantize the observation to the value the body actually needs.** The reader
is gone; `.onGeometryChange(for: Int.self)` maps width → fitted column count
through the pure static (`CollectionViewOptions.columnCount`, now
`nonisolated` so the `@Sendable` transform can reach it), and the action —
and therefore the body — runs only when the count actually crosses a
boundary: a handful of times per slide instead of every frame, and zero times
for any resize that never changes the count. `LazyVGrid`'s flexible items
track the continuous width in the layout pass, which needs no body
involvement; the arrow keys read the same settled count the layout used. No
cycle by construction — the count cannot feed back into the width the
transform reads. Both grids inherit the fix through the shared type. The
width-taking `columns(containerWidth:for:)` and instance
`columnCount(containerWidth:for:)` are deleted with their one caller;
`columns(count:for:)` replaces them. **List-mode resize cost is
framework-dominated** (an AppKit-backed `Table` re-laying ten columns of
hosted cells per frame) and is left for M17's SwiftUI-lane measurement — with
the note that the binary the report came from predates the entire unbuilt 21
August perf set, so the felt lag includes costs already fixed on paper.

**First report:** *"select all in icon view — the context menu doesn't show
the batch options the list shows."* True, and it undercounted; the sweep it
triggered found **four** related defects, two of them behaving wrong rather
than merely reading wrong.

**The shape underneath all four: the label and the action answered different
questions.** `LibraryGameCardView` rendered `GameActionsMenu(games: [game])`,
so however many cards were selected the menu read singular — "Export PGN" over
a fifty-game selection, Get Info always present, "Open in New Tab" routing to
open-in-place — while the closures underneath acted on the whole set. The
Library **gallery** had the inverse and worse half: its verbs were still
`(PGN) -> Void`, the pre-17-Aug "select all, delete all, it deletes one"
hazard surviving in the mode nobody re-checked after the icons fix. The
**columns** menu showed correct counted plurals and fanned them into singular
doors — "Delete 5 Games" assigned `pendingDeletion` five times and deleted
the last one; "Export 5 PGNs" would have run five save panels. And **Players**
list/columns read `keys.first` of the selection `Set`, so a multi-selection's
menu offered Get Info for whichever member the set ordered first.

**The fix is the columns row's own rule, promoted:** *a per-row menu would
shadow the selection* — so no card owns a context menu any more. Both cards
shed their menus and menu-only closures; every host attaches the shared menu
(`GameActionsMenu` / `PlayerActionsMenu`) with subjects resolved through one
rule — `IconGridSelection.subjects` for the grids and galleries,
`.contextMenu(forSelectionType:)` for the tables. The gallery verbs went
set-taking; columns adopted the list's `IDs` doors verbatim (its detail pane's
Analyze button rides the same door with a one-game set); the Library
destination's gallery and columns call sites now feed the same
`request…(ids:)` doors as icons and list. `PlayerActionsMenu` takes `keys:`
with the single-subject guard **inside the menu**, so a fifth host cannot
re-open the question: a multi-selection renders no player items — the same
honest answer in all four modes — and the guard's comment names where a batch
verb would land if one ever exists.

**Also resolved by the move:** the 18 Aug "currently unreached `onOpen`"
notes on both Library grid hosts — the menu's Open item now reaches the
destination's new-tab set door with the whole selection, as its label always
claimed; both notes rewritten at their sites.

**Gate evidence: built and green the next day.** The sitting joined the
21 August patch in M15's first build (24 Aug), which surfaced exactly one
compile error across the combined set — the `inset` isolation read, this
sitting's own, fixed and recorded — and **⌘U came back green, reported by
Bera, 24 August**, `LibraryCardInscriptionTests` and the options round-trip
included. Counts not reported; M15's status block carries what the green
still owes. (The pre-build text here read "none of it compiled" with brace
balance as the only witness — kept in spirit: the one error was precisely
where mechanical checking cannot reach.) `LibraryCardInscriptionTests` pins the raw values, the compact
result, the stacked date under a fixed locale, and the placeholder rule;
`CollectionViewOptionsTests` gains the inscription round-trip with the
unknown-spelling fallback, and its construction-writes-nothing pin covers
the new key. The manual checks land in the instructions' owed list (M16's
batch): counted plurals over a ⌘A selection in icons and gallery, a
five-game columns delete removing five, the players multi-selection yielding
no menu items in every mode, Get Info appearing only for a single subject;
the inspector toggle re-run in icons and list view, where icons should now
track the slide smoothly and any remaining list hitch is M17's to measure;
and the inscription picker — choice applying live in icons *and* gallery,
surviving a relaunch, absent from the panel in list, columns and Players.

### The 23 August rewrite — M7, M12, M13 and M14 close into the final ladder *(recorded 23 August 2026)*

A documents-only sitting against clean `28b45eb`: this file rewritten whole as
the final roadmap, the four standing milestones closed here with their
evidence, and their survivors re-homed (Instruments and its run sheet → M17,
the FocusedValue two-run check and the `LiveGameRosterForm` extraction → M16,
the GM re-read → M23). Full narratives are in `git log`; what follows is the
record that was ever read twice, per the 7 August trimming precedent.

**M7 — Measure, format, decide.** Four of six bullets closed by *checking a
claim*, none costing more than a command: **D42′** declined swift-format
outright (`.swift-format` never existed; 314 hand-aligned lines across 37
files that `lint --strict` would report forever); **D43′** corrected the
phantom warning count (there was no 295 — a cold build emits zero compiler
diagnostics; provenance unreconstructable, recorded as unattributed) and
landed **language mode 6 on all three targets**, gate evidence: three cold
scratch builds — 0 warnings as configured, 230 (+165 notes) under
`SWIFT_STRICT_CONCURRENCY=complete`, 1 error under `SWIFT_VERSION=6` — fixed
by three annotations (`@MainActor` on the UITest class took 226 diagnostics;
`@MainActor` on `UITestSeed.scratchDefaults` took the error with
`nonisolated(unsafe)` rejected; the `setUp`/`tearDown` async spellings), all
79 unit-test sources clean under complete concurrency **before anything was
touched**, two waivers (`Binding(present:)`) with a written sunset; **D44′**
closed the `RosterSummary` experiment — the attribute's stated reason was a
language rule that does not exist (nested types do not inherit global-actor
isolation, SE-0449), and the working agreement it minted survives: *something
has to compile a claim from the side where it would break.* The milestone's
transferable lesson is restated at M16, where it now stands guard: **an
unmeasured item accrues imagined weight.** Survivors at closure: Instruments
(→ M17, never in doubt, honestly labelled ignorance), the GM re-read (→ M23,
calendar-gated).

**M12 — Close what is known.** Every keyboard-closable bullet closed on
6 August, ⌘U green reported by Bera: the `endedInMate` "divergence" **did not
exist** — no door can store a trailing annotation, and the test disproving the
bullet was already green a hundred lines from four artefacts asserting the
opposite (the *checked-and-contradicted* species; the defence is a comment
citing the test that holds its claim, now written at both homes, with
`annotationsDoNotSurviveImport` green on its first run by design); **D61′'s
scope gap** closed at the shared form — `Player.seatsNameOnePlayer(_:_:)` as
the one predicate, `GetInfoWindow.seatsCollide` deleted, both sheets disabling
their primary button while Get Info keeps revert-and-alert (two shapes, one
commit-model argument), six pins where D61′ had shipped with none,
`formSeatConflict(_:)` registered; **the three unconsumed symbols** kept by
decision with dispositions at their declarations — the finding being that two
of them carry *unreachable branches in their consumers*, which no name scan
can see (M10's reachability lesson one level deeper; the `SquareView` preview
wrinkle labelled at both ends); **the library-index backfill** built —
hash-matched (D58′'s filename trap recorded), never overwriting an existing
ordinal, always alerting including on matched-none, ten pins. **The
FocusedValue warning** got its real narrowing here: reasoned to
`BoardDestination`'s fresh non-`Equatable` `Binding`, corroborated by a 12 Aug
launch log, then **discriminated by Bera's 18 Aug repro** (it fires launching
into Library icon view, where `BoardDestination` is never constructed) — which
convicted a second, Library-side cause: both collection destinations read back
the focused key they publish, body depending on its own output, fixed in
`863a623` as pure readers of `controlActiveState`. The Board half remains
suspect and untested; the two-run experiment is M16's first bullet.

**M13 — Feature-first, and the filesystem says so.** The move landed
`ff1220c` — 92 renames, 0 insertions, 0 deletions, the path sweep its own
commit — and the path debt was almost nothing: **zero source comments cite a
moved folder** (the codebase names types, not paths); one document claim
corrected. The filing-quirk list undercounted — the check that found all five
misfiled suites: *for each test file, does its subject live in the mirrored
folder?* The `GetInfoWindow` split stopped at 1,234 lines **by decision**: the
remaining six extensions need eighteen `private` members widened to
`internal`, all of it `@State`, and D57′'s per-field commit argument outranks
file size — reopen only if someone gets lost in it, not because 1,234 is a
large number. Three merges landed (`LastMove`→`Move`, `FEN+Parsing`→`FEN`,
`GameState+Replay`→`GameState`) with the comment-stripped-diff method
recorded; the evaluation-readings merge **declined** because the D46′ pin is a
test asserting one type against the other, and a boundary it no longer crosses
is a weaker test. The layout is D64′'s and is now simply the tree. Survivor at
closure: the `LiveGameRosterForm` extraction (→ M16) — still at
`NewLiveGameSheet.swift:32`, three consumers now.

**M14 — Reading cost.** `DECISIONS.md` took all 55 anchors verbatim and
append-only — moved, then **diffed against `HEAD` to prove moved rather than
rewritten** — taking the instructions 335 KB → 173 KB with nothing lost; the
next-free-number line moved with them so it has exactly one owner. The
doc-comment rule was adopted as **standing guidance for new comments, not a
retroactive pass** — the two-file calibration tranche (31→11, 37→18 lines)
plus the arithmetic (38% comment ratio; ~2,400 lines to cut, nearly all
reasoning that lives nowhere else) settled it, with the three exemption
classes argued: language-rule comments stay complete (D43′/D44′ each cost a
month), rejected-local-implementation comments stay, and a disposition record
is not a restatement. The review/audit documents were kept-and-labelled, then
**deleted by request on 7 August** once every method they demonstrated had
been lifted into the working agreements as a runnable command; the one
dangling citation (`PlayersInspectorView` → `AUDIT-2026-08-01 § Zero`) was
found by grep and inlined at the site — a citation into a file that no longer
exists is worth less than nothing. *(The 9 August comment pass, `bc92c65`,
later applied the calibrated rule tree-wide — ~19,000 comment lines to ~7,000
— recorded in its own sitting entry below.)*

**Between-milestone sweep, 6 August** *(previously recorded outside Landed;
moved here with the rewrite, its date kept)*: `git status` clean,
counter-grep clean across three documents, prohibited tokens clean, every
cited D-number resolving; the `.disabled(…)` census at 22 code sites, every
enabling value producible both ways. The finding: **two dead view members in
`LibraryInspectorView`, ~80 lines, orphaned by M10 and surviving three
sweeps** — because the declaration scans counted a name mentioned in a
*comment* as a reference, and the comment most likely to name a symbol is the
one explaining its removal. Stripping comments before building the frequency
table is the whole fix; the corrected scan returns two explained orphans over
1,841 names, and the method now lives in the working agreements as a command.
The process note that outlived the sweep: three clean-for-the-wrong-reason
checks in two days — a passing check is never interrogated; run it while
asking what it would have to see to fail.


### The 12 August sitting — the board makes a sound *(recorded 12 August 2026)*

Committed above `424b4e1`, by request across one conversation. **D81′ — board
cues**: four samples, one classifier, one sound per move on a total precedence
(checkmate over check over capture over move), so a capture that gives check is
heard as a check rather than as both. Classified from `Move` + `GameState` and
never from SAN suffixes, which would have been free and would have inherited the
standing `hasSuffix("#")` / `contains("#")` disagreement. Live rides a new
`onMoveCommitted` hook — the eighth wired once in `App.init()`, nil-silent like
the rest; review rides `Game.onStep`, fired by `advance()` and `retreat()` and by
nothing else, so steps sound and jumps do not without any caller being asked.

**D82′ — cue sets**: felt, wood, marble, picked in Settings, each holding all
four cues so an inconsistent set is unrepresentable. Picking auditions, past the
Move toggle deliberately, because you are choosing a set rather than a cue. One
tuning finding worth keeping: marble was first given a *longer* decay to sound
like ringing stone and measured **duller** than wood — a long low ring dominates
the spectrum and drags the centroid under the contact transient. Harder material
is higher and *shorter*. Only measuring caught it; by ear the first version was
plausible, and the Settings footer would have been quietly false.

**The crash between them is the sitting's real finding.** The first sample ever
played killed the app: CoreAudio raises a hard `PRECONDITION FAILURE` when a
sandboxed process initialises playback without a mach-lookup exception for
`com.apple.audioanalyticsd`. Not a throw, not a nil, not a degraded feature. The
reflex — retreat from `AVAudioPlayer` to `NSSound`, on the evidence that D13′'s
`beep()` has worked inside this sandbox for weeks — would have changed nothing:
`-[NSSound play]` calls `-[AVAudioPlayer play]` calls `AudioQueueStart`. `beep()`
is the system alert path and builds no playback graph in-process, which is why it
never needed the entitlement and why its success was misleading evidence about a
different API. Both halves are now build-diagnostic lessons.

Two riders. **Settings grew to five tabs** — General, Board, Sounds, Engine, Data
— deliberately as pure relocation, no control or key or identifier changed, and
deliberately without a D-number. And a **test hole closed by being asked a
question**: "are the choices persistent?" led to a round-trip fixture that stored
`false` under all four cue keys and asserted all four read `false`, which passes
unchanged if two properties read each other's key. A fixture where every expected
value is the same cannot catch a crossed mapping; the agreement now says so.

**Gate evidence: ⌘U reported green by Bera, 12 August**, on D81′ and D82′ — the
tab split came after and adds no test. Owed and named in PROJECT-INSTRUCTIONS:
one run of `Tools/make-cues.swift`, which was ported from a working Python
implementation by a hand with no Swift toolchain, so "it compiles" is a claim;
and the audible checks, which are the only witness that the twelve samples are in
the bundle, since a missing file and a disabled toggle sound identical.

### The 9–10 August close — game 98, the red ply, and the companion windows *(recorded 10 August 2026)*

Committed as `1ad5975`, `42820be` and `407c846`, with the recording itself in
`424b4e1` — *this entry read "Uncommitted at this recording, above `2db96e8`"
until 12 August, which is the same decay the instructions' tree line suffers and
is corrected here for the same reason.* **Game 98's Move Text error
adjudicated real, not a false positive**: the file writes `Qf4+` at ply 98
where the position holds a white pawn on f4 (standing since `30. gxf4`), so
the unique legal queen move to f4 is the *capture* and strict x-iff-capture
SAN refuses — the DGT exporter dropped the `x`. Import never replays (the
parser checks shape only, which is why the game sat quiet until Get Info's
validator read it — diagram 02 now carries the import-never-replays note),
and the definitive replay ran outside the app against the uploaded file:
plies 1–97 clean, and with the one token fixed the rest replays to
`52… Qf2#`. The remedy is a one-token edit in the Move Text tab, with the
recorded cost that the hash moves and the on-disk file stops deduping against
its own row.

**D79′** followed by request: the editor's binding is `AttributedString` (the
macOS 26 `TextEditor` overload — shipping, not the 2027 beta line) and the
offending ply renders red on open and after every change. The range comes from
`MovetextEdit.characterRange(ofPly:in:)` — the tokenizer's own walk, so the
highlight and the validator cannot drift — and one validation per change
feeds the status line, the Save gate and the paint through the fold cache.

**D80′** closed the sittings, by defect report: with the main window full
screen, the evaluation graph and the data window opened as their **own**
full-screen Spaces. The AppKit configurator wrote `collectionBehavior` in
`viewDidMoveToWindow` — after the window's Space was already decided — so it
was structurally unable to affect first placement, its own reserved
`updateNSView` remedy included; and its "SwiftUI cannot reach the flag"
premise was false one level up. All five companion scenes now carry
`.windowManagerRole(.associated)` (scene-level, applied before placement);
`FullScreenAuxiliary` and its four-test suite are deleted, and the
declaration-scan expected set shrinks by its two representable witnesses.

**Gate evidence: ⌘U reported green by Bera, 10 August, on the whole of it.**
The full-screen behaviour itself is manual-check territory and owed — the
9–10 Aug list in PROJECT-INSTRUCTIONS.md carries it.

### The 9 August sitting — comments cut to the why, the waste audit applied, the diagrams re-authored *(recorded 10 August 2026)*

Three commits, one day, all by request. **`bc92c65`**: the comment pass —
~19,000 comment lines to ~7,000, essays replaced by one-liners citing their
D-anchor, verified by a byte-identical code projection across all 249 files
before anything else moved. The three exemption classes (language rules,
rejected local implementations, disposition records) survive whole and are
now written into Working agreements as the new-comment guidance.

**`4d81150`**: the five ranked fixes out of **`WASTE-AUDIT-2026-08-09.md`**
(repo root — the diagram-driven waste analysis, its "Applied the same day"
header mapping each fix to its number), minted D74′–D78′ *with* the work:
incremental analysis with the book skip and per-ply depths (D74′), the
converged backfill stamp (D75′), collection scoped to the displaced rows
(D76′), the swing column (D77′), and narrowing/sort joining the fold memo
(D78′). ⌘U came back red twice on the way, both times usefully: two swing
literals had been written against a base-10 sigmoid the code never had —
`whiteWinProbability` is **base-e** at k=400, and the `Evaluation` doc now
says so at the declaration — and two `isDeleted` assertions learned that
SwiftData answers *false* once the containing save expunges the row, so both
suites assert deletion by fetch instead.

**`2db96e8`**: the five activity diagrams re-authored whole at `5f82de7` plus
the working tree — D61′–D78′ drawn or triaged, the checker green at
parse 5/5 / render 5/5 / structural 0 / placement 0, every citation resolving
against `DECISIONS.md`, and `Diagrams/DIAGRAMS.md` carrying provenance,
denominator and the exclusions table.

### The 8 August sitting — release audit, per-game saves, badges everywhere, one counter, a wider gallery *(recorded 8 August 2026)*

The pre-release pass, by request: a full file-per-file audit of the tree
(**`RELEASE-AUDIT-2026-08-08.md`**, repo root — first-export checklist at its
head), plus four asked-for changes. Two took numbers, two did not, and the
split is the D-threshold working: the numbered pair each reverse a recorded
position.

- **D71′ — analysis saves at exits, never per ply.** The answer to "still
  stuttery during a batch" after D70′: the memo made the folds indifferent to
  the per-ply save while every `@Query` fan-out, sort and table diff underneath
  it still ran once per ply. Reverses the driver's recorded crash-durability
  contract, whose benefit was found empty (the next pass resets partials
  anyway); every exit persists before its message claims anything was kept. A
  rider at the engine: the Stockfish subprocess launches at `.utility` QoS, so
  a raised Threads setting stops fighting the render loop.
- **D72′ — analysis state legible in every view mode.** Green-check / red-x /
  spinning-gear at each card's bottom-trailing (icons, gallery strip) and each
  columns row's trailing edge; the list column joins the same input. One
  projection (`analyzedIDs` off the memoized records) feeds every badge, which
  also retired the list column's per-row blob decode — the one D70′ left
  standing. Reverses the columns row's recorded uniform-icon argument.
- **One batch counter, numberless.** The toolbar said "0/110" while the window
  said "Analyzing 1 of 110" — `completedCount` against `completedCount + 1`,
  two spellings on screen at once. `AnalysisQueue.batchPosition` is the one
  spelling; both surfaces read it; three pins.
- **The gallery preview grew, numberless.** `PlayerStatsGrid` five facts →
  eight (Uncertainty, First/Last Played — the zero-cost inspector rows), which
  widened the columns detail too, one grid being the point; and the selected
  player's rating trend renders under the grid through `RatingTrendChart`,
  extracted from `PlayerRatingGraph` so the inspector and the gallery draw one
  line (`EvaluationGraphContent`'s split, applied to the rating).

**The sitting's second half**, from the follow-up requests:

- **D73′ — the analysis as data.** A table window (ply, move, evaluation,
  white win %) behind a new button beside the magnifier in the Library
  inspector's Evaluation header; the queue window's Depth fact now shows the
  configured target and holds still; and Get Info's File tab lost its
  Analysis section, whose four summaries the table supersedes — coverage now
  reads per ply, as em-dash rows. One entry because they are one movement:
  the window is where the removed section's answers went.
- **D72′ postscript — plain marks on the badges.** The card corners and
  columns rows dropped the gear-badged glyphs for a bare green
  `checkmark.circle.fill` / red `xmark.circle.fill`, the gear appearing only
  while the engine has that game — reversing the entry's own first rejection,
  by request, with the two vocabularies pinned to share exactly the running
  gear. The action surfaces (Analyze column, chips, menus, queue toolbar)
  keep the gear family.
- **Screenshots named, README illustrated, numberless.** The fourteen
  `Screenshots/` captures renamed from timestamps to what they show
  (`library-gallery-game-preview.png`, `analysis-queue-window.png`, …) and
  embedded in README.md under a Screenshots section — Board, Library's four
  modes and filter, the two analysis windows, Get Info's tabs, Players' four
  modes.
- **The launch geometry warning, resolved structurally.** Both suspect
  geometry actions dealt with in one pass: `IconGridWidthBox` deleted (the
  arrow keys read the `GeometryReader`'s width as a parameter — the mirror
  never needed to exist) and the per-card frame transforms gated on an
  active rubber band, so idle grids observe nothing and there is no value
  stream to cycle at launch. Fifth correction on that warning, first to
  remove observation rather than tune quantization; confirmation launch on
  the owed list, alongside re-observing whether the `FocusedValue` warning
  was its shadow.

**Manual checks owed** are on PROJECT-INSTRUCTIONS' list: the badge sweep
across all four modes during a live batch, the counter agreeing at both
surfaces, per-game save timing (other windows update at game end now), `pmset`
untouched by the QoS change, the gallery's chart height leaving the strip
pinned, the data window's em-dash rows on a skipped game, and the Depth fact
sitting still through a full batch. ⌘U owed on the tree; expected green, never
claimed.

### The 7 August evening — collection folds memoized, documents trimmed *(recorded 7 August 2026)*

Two requests, one of them a performance pass and one a documentation pass. **No
D-number**, and the omission is a decision: nothing here reverses a recorded rule
or mints vocabulary. The one behaviour change is named below and at its site.

**The finding, which was not the one on the census.** Both collection
destinations folded the whole Library in `body`, which is correct and cheap when
`body` runs on data changes. It does not. Three triggers ran it far more often,
and none of them was on the known-costs list:

- **A rubber-band drag** wrote the selection on every drag callback, and the
  selection is `@State` on the destination — so `Glicko1.histories`,
  `PlayerStats.index` and two array sorts ran at pointer rate over a library that
  had not changed.
- **A search keystroke**, because both destinations narrow *downstream* of the
  fold.
- **A batch analysis**, and this was the sharpest: `GameAnalysisDriver` saves once
  per ply, a save invalidates every `@Query`, so an 80-ply game re-folded the
  whole Library eighty times if Players happened to be open. The app was already
  busy at exactly that moment.

**What made it expensive rather than merely repeated** is that `PGN.gameRecord`
decodes two Codable blobs off the model — `moves` and `evaluations` — so the fold
was *n* × two blob decodes, not *n* × a struct copy. `AnalysisGlyph.isAnalyzed`
in the Library's subtitle was a third, unconditional, on every render.

**The mechanism:** `CollectionFoldKey`, an exact fingerprint built from two
stored scalars per game, and `CollectionFoldCache`, a one-entry memo in the
`IconGridFrameStore` box idiom so it can be written from inside `body`. Players
keys on content alone. **The Library composes an analysis signal from the
queue's own counters** — `runningID`, `completedCount`, `hasFailures` — because
its backlog count and `TagRule.analyzed` genuinely track analysis, and those
counters move once per *game* where the save moves once per *ply*. That ratio is
the whole win.

**Two fields in the key, and the second is the one a future reader will think is
redundant.** `contentHash` folds everything either fold reads *except*
classification, which D24′ and D34′ keep outside the hash on purpose — so a
motif backfill would change the Special Mates column while every hash stayed
byte-identical. `aChangedCheckmateMovesTheKey` is the pin.

**Exact, not hashed.** A `Hasher` fingerprint is allocation-free and one `Int` to
compare, and it was rejected: a 64-bit digest is one collision away from a
silently stale ladder, and the failure renders perfectly and looks like data.

**The behaviour change, priced rather than discovered.** The Library's backlog
count used to drop the instant a game's first ply was scored (`hasScoredPly` is
true after one). It now drops when that game leaves the queue. That reads better
— a game halfway through a pass is not analyzed — but it is a change, and it is
documented at `LibraryDestination.FoldKey` as well as here.

**Accepted regression, on one path.** An unfiltered Library used to decode only
`evaluations`; it now builds a full `GameRecord`, which decodes `moves` too.
Twice the work on a miss, in exchange for misses becoming rare, and one
projection with two consumers rather than two walks that could disagree about
"analyzed?".

Also: both rubber-band gestures now guard on an unchanged selection, and
`LibraryFilter.matches` takes the record rather than projecting one per call.

**Nine tests**, split by isolation — `CollectionFoldKeyTests` nonisolated over
the value algebra, `CollectionFoldCacheTests` `@MainActor` for the models it
builds, with a note at the suite that the annotation is about the `@Model`s and
**not** a claim about the cache's isolation (D44′'s lesson).

**The documentation pass, same sitting.** The three review documents deleted
(see M14's struck bullet), the revision narrative cut from this file and the
instructions, every struck open item dropped, and the manual checks reorganised
from twenty-four dated per-decision lists into *owed* / *board-required* /
*standing boardless*. `PROJECT-INSTRUCTIONS.md` went 650 → ~430 lines and lost
roughly half its words.

**Three stale counts corrected in the process, all three found by measuring
rather than by reading:** sources 239 → **247** on disk (148 app, 99 test),
tracked 239; the accessibility registry 146 → **153**. The instructions had
carried the pre-View-Options figures.

**Gate.** ⌘U owed — not run, and not claimed. The counter-grep is clean across
the three surviving documents. No toolchain was available to compile in, so the
performance pass is **unbuilt**; if anything fails it will be the labelled-tuple
arithmetic in `narrowedPairs`, where key paths do not reach tuple elements and
`map` over a zipped sequence takes one argument. Both are avoided deliberately
and both are noted at the site.

### The 7 August day — ten checkmate types, and sleep through a batch *(recorded 7 August 2026)*

Two requests, both widenings of something that already existed, **no new source
files** — 238 tracked and 238 on disk, unchanged. Base `601ae50`, clean.
⌘U reported green by Bera, which here also discharges the compile gate.

**D65′ — the checkmate vocabulary grows to ten.** `anastasia`, `arabian`,
`opera`, `boden`, `epaulette`, `gueridon`, `dovetail`, `hook` join `smothered`
and `backRank`. No schema change and no new type: every consumer already drove
off `allCases`, `displayName` and the raw value, so the smart-tag picker, the
Library's Checkmate Type column, Get Info and the tag rule widened for free.
D19′'s deferral — "enumerating the long tail *before a surface shows them*" —
expired on its own terms rather than being overturned, the three surfaces
having arrived on 5 August. Precedence is narrowest-first and stated as data.

*Gate evidence.* One reference fixture per motif, all ten reachable
(`everyCaseIsProducible` — the D40′ producible-value rule pointed at an enum);
the three overlapping pairs pinned individually, including
`aCornerHookIsCalledArabian`, which records a genuine tie-break rather than a
specificity call and is the test to change if that call ever changes; raw
values pinned on literals, since they ride `PGN.specialCheckmate` and every
saved rule blob; `theBasicQueenMateIsNotSpecial` pinning the *exclusion* of the
endgame workhorses so it reads as deliberate.

*The finding, and it is not a feature.* The Boden recogniser was **wrong on
first writing and only a distribution caught it** — it fired on 2.2% of a
1,500-mate sample against 0.3% for every sibling, because a middlegame position
with two bishops usually has a queen doing the work. Eight predicates, all
equally plausible on the page. Separately, a hand-written near-miss fixture
turned out not to be mate at all, which would have **passed** — `classify`
guards on `isCheckmate` and returns nil honestly. Every FEN in the suite is now
verified against an independent generator before landing.

**D66′ — batch analysis inhibits idle sleep, on its own gate.**
`StorageKeys.preventSleepDuringAnalysis`, absent reads true, its own Energy
row. Two preferences rather than one widened one: play is minutes and needs the
serial link, a batch is hours and needs the engine. Only writable because the
queue went app-global on 6 August (controller decision 2) — the per-tab
controller had no door for "is any tab analyzing", which that decision names as
its own proximate cause.

*Gate evidence.* The predicate **left the waiver register**: one gate over two
causes had nothing to extract, two gates over two causes can be crossed
(`allowsAnalysis && playing` compiles and reads fine), so it is now the pure
`activityReason(playing:analyzing:allowsPlay:allowsAnalysis:)` with
`gatesDoNotCross` running each cause against only the other gate. Both
defaults, both keys' independence, and the both-causes-named case are pinned.
The token stays waived; `pmset -g assertions` is its witness and D66′ carries
the run sheet.

*Owed, and outside ⌘U by decision:* the `pmset` sequence — in particular
flipping the analysis toggle **mid-batch**, which an implementation that only
releases at drain would pass every automated test while failing.

**D67′ and D68′ — one spelling of "is there analysis to show".** From a bug
report, not a plan: two analysed games drew "no data points, a flat line".
`GameAnalysisDriver` resets `evaluations` to full-length nils *before* it
walks, so a pass that scores nothing leaves a non-empty array holding no
analysis — which `!evaluations.isEmpty` admits and `?? 0.5` then draws as a
curve lying on the graph's own midline. `PGN.hasScoredPly` is the predicate
now; the bar, the graph window, the glyph and (D68′) `GameRecord.hasAnalysis`
all ask it. **D68′ changes what saved smart tags match**, on D30′'s precedent.

*Gate evidence.* `PGNScoredPlyTests`, whose middle case is the whole suite —
empty-versus-scored is a distinction *both* spellings get right, so a test
covering only those two would have passed against the defect. `GameRecordTests`
turns red by design: it pinned the repealed rule, and its assertion message was
the repealed belief written out as prose.

*Two findings, one of them a retraction.* The comment that let this survive
did not merely assert a guarantee — it **named the divergence and ruled it
intentional**, which pre-answers the question a reader arrives with. And a
second such comment was reported and the report was wrong: the search chips
were on the correct predicate all along, because `admit` takes a bare `Bool`
and the call site is invisible from the function. Both are recorded at D67′.

*Not fixed by any of it:* the two games. Their evaluations were destroyed by
the reset before the walk, and only re-analysing restores them. The cause —
Syzygy, or `staleBestMovesOwed` — is still unidentified and needs the engine
log during a re-run.

### M10 — Get Info, and three affordances removed *(shipped 4 August 2026 in `7390227`; **recorded 4 August 2026, evening**)*

**This milestone was never on this roadmap.** It shipped whole — seven
commits' worth of surface across eight app sources — and `grep -c "M10"` over
this file and the instructions returned zero against thirteen references in
the code. It is entered here retroactively, from the sites, because a
milestone the roadmap never knew about is the one thing neither document's
checks can catch: absence never fails a grep that reads what is written. The
lesson and the standing counter-grep are in the instructions' working
agreements as the fifth species of unchecked claim.

**Shipped.** The Get Info system — `GetInfoRequest` (a three-case enum: an
archived game, the live recording, a player by key), `GetInfoMenuItem`,
`GetInfoWindow`, a third `WindowGroup`, a registry group, and ⌘I on six
context menus. Three removals: the Players rename pencil, the Library
inspector's `PGN.name` editor (`nameEditor` / `beginEdit` / `commitEdit`), and
the Board's Edit Moves pencil. Plus a session-recorder growth bound (M10.2,
suited) and, in the two commits before it, the `GameActionsMenu` /
`PlayerActionsMenu` extractions.

**What the recording pass had to decide, because the milestone left two
surfaces wired to nothing.** Both were found by the 4 Aug review, both were
documented at their sites as needing a decision rather than a comment, and
neither was visible to a symbol-level dead-code scan — every name on both
chains was referenced, and both chains ended at a closure no control invoked.

- **Player rename had no door.** The pencil went with this milestone, Get
  Info was read-only, and D52′ had removed merge that same evening — so
  `PGNStore.retag` wrote nothing anywhere in the app while `RenamePlayerSheet`,
  `RenameRequest`, `beginRename` and the refusal alert all sat intact behind
  `PlayersInspectorView.onRename`, a property whose own comment called itself
  "a deadline, not a description". Resolved as **D53′**: Get Info's player form
  became editable and the whole rename path moved into it; the sheet is
  deleted.
- **Movetext editing had no door.** `BoardDestination` still wired the
  `.movetext` editor case and `applyEditedMovetext`; nothing set it. Resolved
  as **D54′**: read-only on the Board in both branches, and the editor is the
  Library inspector's PGN header. D18′'s validator, store door and five
  identifiers are untouched.

Also applied from the review: `getInfoBoardMenuItem` had been minted against a
doc sentence rather than a built control — the Board had no Get Info door at
all — so the Game menu item was **built**, which forced the trigger-binding
shape (`Commands` has no `openWindow`, `SmartTagCommands`' arrangement, third
use) and made `.live` reachable for the first time, which in turn exposed a
staleness the unavailable state's doc had claimed to handle. `board.editMoves`
removed with its affordance, successor `library.editMoves`. The two menu
extractions' "once" made true across all six hosts. Previews for
`GetInfoWindow`, `GameActionsMenu`, `PlayerActionsMenu` and `AnalysisLabel`; a
waiver row for `SessionPhase`.

**A fifth undeclared decision surfaced when the tests were finally run.**
`RosterSummary` collapsed the four display placeholders into one em dash —
recorded now as **D55′** — overturning D22′'s two-placeholder rule and
leaving four pins asserting the old contract.

**Gate evidence: ⌘U run by Bera on the recording pass's tree — RED, 4 of 940
failing, all `RosterSummaryTests`, all pre-existing at `7390227`.** So the
milestone shipped red as well as unrecorded, and neither fact was visible
until someone ran the suite: the failures are in a file this pass never
touched, and the milestone's own commit is what changed it. The tests were
stale rather than wrong — the production behaviour is D55′ and is correct —
and they now pin the shipped rule plus the two claims the collapse introduced
and nothing checked. ⌘U owed again on the fix, expected green, never claimed;
that phrase is worth exactly what it was worth the first time.

The milestone shipped without a check list, which is a consequence of shipping
without a roadmap entry. The recording pass wrote that list after the fact,
against what the code does rather than what it was meant to do; it is in the
instructions under *M10's own*, and its first item is the `openWindow` routing
check, because five existing call sites depend on the answer.

### The 4 August late sitting — ⌘A, shortcuts, and the file ordinal *(recorded 5 August 2026)*

Entered late, and the reason is the one this roadmap has now recorded twice:
**D58′ appeared nowhere in this file until the 5 August sweep looked for it**,
and an unrecorded decision cannot go stale, contradict anything or fail a
grep. The counter-grep on the sweep list catches milestone numbers; it does
not catch D-numbers, and this is the case that says it should.

Shipped: ⌘A selecting every visible row in all four view modes on both
collection destinations, through the system's Edit ▸ Select All rather than a
shortcut of our own — "visible" meaning after smart tags, query and chips,
which is `filteredGames`' existing contract rather than a new one; a keyboard
shortcut on every context-menu item across both destinations; **D56′** — Open
takes the selected set rather than one game, which is what makes display order
tab order; **D57′** — Get Info split into Details and File tabs, with Details
becoming where an archived game's roster is edited; and **D58′** — a game
carries the ordinal its file already had on disk, so the Library's `#` column
reads the filing number rather than an invented one.

**Gate evidence: ⌘U reported green by Bera**, discharging the M10 recording's
owed run at the same time.

### The 5 August day — tables, Get Info, orphans, the ladder, and the logs *(recorded 5 August 2026)*

A day of requests rather than a milestone, recorded the same day, against
`97d1243` "Keyboard Shortcuts" and `75a02d3` "Secondary Personal ID, Detailed
Info Window" plus a working tree of 54 changed paths. Eight decisions, two
deliberately numberless.

Shipped, in the order asked for: **column-header sorting** on both collection
destinations (once ascending, twice descending), which deleted D48′'s sort
picker — the sort lives on the destination rather than the table, because
`gamesInDisplayOrder` feeds D24′'s export filename numbering, the analysis
queue's order and D56′'s tab order, and a table-local sort would have let
export silently number by one order while the reader looked at another; the
Library opening on `#` descending; **D57′**–**D59′** — Get Info grew to three
tabs and became the only place a game is edited, taking the movetext editor
off the Library inspector's pencil one day after D54′ put it there, the
one-day reversal recorded rather than smoothed; the known-player seat menu
everywhere a seat is edited; **D60′** — orphaned players are always collected,
on the stated premise that the PGN files are the source of truth; the Move
Text tab's numbered two-column **score sheet** (numberless, resting entirely
on `MovetextEdit.tokenize` treating numbers and padding as decoration — tab
separation was tried and reverted the same hour); **D61′** — one player cannot
hold both seats; **D62′** — the ladder's ordering is a user choice (wins /
win rate / rating) with D11′ demoted from the only answer to the default, and
the rating graph gaining a hollow point at step 0 for the 1500 everyone starts
from; a **Checkmate Type** column on the Library and a **Special Mates** count
on Players; the *mate pattern* vocabulary renamed to **Checkmate Type** with
the motif names title-cased; and **D63′** — logging given one owner, one
policy and one grammar, silent under the test host and re-armed by `DGT_LOG=1`.

**An auto-fit column feature was built and withdrawn the same day** — an
`NSTableView` delegate proxy measuring the widest cell on a double-click in
the header divider. SwiftUI has no native equivalent and
`TableColumnCustomization` does not persist width at all, which is the finding
that outlived the feature: both list views' docs had claimed it did, wrong
since the day they were written and checkable in twenty seconds.

**Gate evidence: ⌘U reported green by Bera twice during the day, then red
once.** The red was `displaySummaryRoundsAndMarksProvisional` — `Glicko1`'s
provisional marker had changed from "(provisional)" to `*` for the new Rating
column's 120 pt cell, and neither the doc comment above it nor its pin moved
with it. Fixed. **⌘U is owed on the full tree including D63′ and is not
claimed here**, which is the formula this project records as a hypothesis
rather than a result — the same day it came back red is the day to stop
writing "expected green" as though it settled anything.

### The 2–4 August burst — search, selection, chrome, the cascade, and the suite's exit *(recorded 4 August 2026)*

Four commits outside milestone discipline (`d7398ca` "flat columns view",
`772ecb3` "Features removed", `b972b5a` "Checkpoint before deleting the UI
test target", `b2f3c32` "UI Improvements"), landed fast and recorded late —
the messages describe almost none of the contents, so this entry is the
readable record the log doesn't give. Shipped: live search with token chips
on both collection destinations (`SearchMatch` on the D30′ fold;
`LibrarySearchToken` / `PlayersSearchToken` after a one-day scope-bar detour,
both retirements documented in `CollectionSearch.swift`); Finder-flat
columns; icon-grid rubber-band and arrow-key selection (`IconGridSelection`,
plus `IconGridFrameStore` after two observed-state designs oscillated
layout); toolbar subtitles (`DestinationSubtitle`, with
`SessionPhase.current` extracted so the sidebar and the toolbar cannot rank
session states differently); the analysis-state glyph (`AnalysisGlyph`,
unifying two latent spellings of "analyzed?"); the glide-speed preference;
**D50′** — game deletions collect the players they strand; and **D51′** —
the UI test target deleted (884 lines, `UITestSeed`, and the seeded
container branch with it; § Zero closed unresolved).

**Gate evidence: none claimed.** The burst carried no ⌘U report of its own.
The 4 Aug recording pass that paid this entry's debt also applied the
same-day review to the tree: the icons grids' ↓-on-last-row slide fixed and
pinned; the merge refusal alert titled for its own operation
(`RetagRefusal.Operation`); `SearchMatch.Query` folding the query once per
pass; `LibraryDestination`'s filter folded once per render; the twin
`DGTStudioProUnitTests.xctestplan` deleted with the Tests scheme repointed;
and the dead-suite comment sweep. ⌘U owed on the combined tree, expected
green — **reported green by Bera the same day**, which discharges the
burst's and the review's gates together.

### M9 — One Players destination *(landed 2 August 2026)*

**Requested by Bera, delivered as D48′.** Players absorbs Rankings:
`RankedPlayer` is every mode view's row currency in both orderings, the D11′
ladder is the default sort with a persisted toggle to name order
(`PlayersSortOrder`, one new `StorageKeys` entry), rank badges and ratings
render everywhere, and columns mode's grouping follows the ordering — letters
under name sort, win bands under rank sort, one view where two files
disagreed. The merged inspector states each fact once (Rank, Games, Record,
Win Rate, Rating, Uncertainty, Rated Games, Mates, First/Last Played), then
the rating trend and recent games; `.rankingProfile` retires from
`InspectorSection`, `.ratingTrend` survives its move. Product decisions —
rank-default ordering, ladder chrome everywhere, the full-merge grid — were
Bera's, asked and answered before the build.

**Closed with it:** the RankingsInspectorView Wins-twice item and both
P-vs-R parity residues (stat grids, gallery spacing) — each by deleting the
duplication rather than reconciling it. The galleries' empty-selection
divergence narrows to Library-vs-Players and stays open.

**Gate evidence.** Six files deleted, no stray references (repo-wide grep
finds "Rankings" only in comments); the `rankings.*` registry group removed
with the removal recorded at its anchor, `rankingRow` re-homed on the merged
table's rank cell beside `playerRow`'s name cell — two currencies, two
elements; the ladder-order UITest retargeted to Players with its assertions
unchanged (the seeded expectations pin the same comparator through the new
surface); the M5 editing flows untouched. ⌘U green — reported by Bera,
2 August, unit plan, the retargeted ladder pin included; the Players editing
tests' standing § Zero failures remain that investigation's, not this
milestone's.

---

### M6 — Live-mirror piece animation *(landed 2 August 2026)*

**Delivered as D47′.** One identity-keyed piece layer above the square grid
(`BoardPieceLayer` + `PieceGlyph`), fed by a pure resolver
(`PieceIdentity` / `ResolvedPiece`) whose keys carry the whole animation
contract: a persisting key glides, a churned key fades. Identity is proven
or absent, never guessed — per-square parity against the live game's last
committed position, plus the *same* `DGTReconstructor.reconstruct` the
session settles with, run presentation-side, so a slid or quickly played
move glides under its real `PieceID` before the commit and re-keys nothing
at it. `SquareView.pieceID` retired (the open item closes): a square that
knows its piece's identity still can't glide anything — gliding is a
relationship between two squares, and only a layer sees both.

**The milestone's real finding: its goal sentence and its constraint line
disagreed, and the constraint won.** "Pieces glide on the mirror" as written
would need either a piece rendered where the physical board has none
(violating "the mirror renders the physical board, always") or an identity
guessed before anything proved it (violating "never speculation") — a
lift-then-place move renders as two truthful states with the piece honestly
in a hand between them, and there is no jump to glide. What the mirror does
instead: proven moves glide, everything else fades honestly, and a fade *is*
the correct rendering of a piece leaving for a hand. The gate's "e4, O-O,
exd5, promotion all animate correctly on the mirror" is met in that reading
— correctly ≠ always-glides — and all four shapes glide unconditionally on
the review board, where parity is total. Fifth species averted rather than
collected: the quantified sentence got checked against its set before the
set was assumed.

**Gate evidence.** Mechanism decided and recorded (`matchedGeometryEffect`
rejected in D47′ with reasons); ghosts and recovery overlays untouched by
construction (they never left the square layer, which doesn't animate); the
four shapes watchable in the *Four Shapes — Interactive* preview stepping a
scripted line through `LibraryGamePreviewState.compute`; `PieceIdentityTests`
(12, nonisolated) pin the occupancy-verbatim property across every fixture,
the mis-key guard, the origin-identity glide, promotion's pawn-ID reuse,
both castle placements, the correctable en-passant, and commit-stability of
the proven key. ⌘U green — reported by Bera, 2 August, unit plan, the twelve
new pins included. The board-side half of the gate (real settle cadence, no
hitching, dump fades in) is on the M6 manual list and stays open until the
board is on the desk.

---

### M8 — Inspector chrome, second pass *(landed 1 August 2026)*

Both items, one pass, against `f64b8d4` — seven commits, ⌘U green at both
review points. Decisions **D45′** and **D46′**. Six files added
(`InspectorSectionCollapse`, `CollapsibleSection`, `EvaluationGraphReading`,
`EvaluationGraphWindow`, and two suites), 211 → 217 sources.

**The milestone had a prerequisite it did not know about, and finding it is the
entry's real content.** Item 2 read "every `InspectorSectionHeader` grows a
show/hide chevron", which is a complete-sounding instruction over an incomplete
set: **eight of the app's fifteen inspector section headers used that type and
seven did not.** Built as written, 8 of 15 sections would have become
collapsible with no rule a reader could perceive — Board's Game and Opening
folding while its Evaluation and Moves could not — which is exactly the
divergence D26′ exists to prevent, minted by the milestone whose stated
constraint was not breaking D26′. Item 1 shared the blocker: the Evaluation
header it wanted to hang a magnifier on was a raw `Text` in both inspectors.

The sentence was **true**, which is what makes this a new species of the
project's favourite failure. D42′ found a claim about a file that did not
exist, D43′ a number nobody could source, D44′ a rule the language does not
have — all false. This one quantified correctly over a smaller set than its
reader assumed, and nothing about a true statement ever fails. The check was
one grep.

**Gate evidence.**

- **Every section header goes through the shared type** (`0d0dcc3`), all
  fifteen, plus the two previews that simulate an inspector. Board's Moves
  header was the sharpest case: a hand-rolled `HStack` reimplementing
  `InspectorSectionHeader` and disagreeing with it on three counts, sitting in
  the same file whose roster header used the type.
- **The trailing inset has one owner.** `InspectorEditButtonView`'s
  `.padding(.trailing, 10)` was doing two jobs — insetting the header's
  trailing control and widening the pencil's hit target — which coincide only
  while the pencil is last. M5's Players header put a menu after it, so the
  edge inset transferred to a control carrying none: **three distances from one
  edge**, 10 pt at the four lone pencils, 8 pt at the PGN glyph pair, 0 pt at
  the actions menu. Now `InspectorSectionHeader.actionsInset`, applied to the
  whole row so a host cannot get it wrong. The post-M4 audit had fixed the
  *stacking* form of this defect and left the number where it was.
- **Collapse is one argument, not two** (`a1289c2`, `4daaefe`).
  `CollapsibleSection` takes one `InspectorSection` and drives both the chevron
  and the body gate, making "header toggles X, body checks Y" unrepresentable
  — M5's two-guards agreement in structural form. Ten tests on the store: the
  empty default, that construction writes nothing, the round trip through a
  *reload* rather than through memory, and both halves of the retired-section
  rule.
- **The magnifier opens in its own window** (`1931583`) with hover read-outs,
  and `EvaluationGraphRequest` keeps `openWindow(value:)` unambiguous — that
  call routes by value *type*, the main group already claims
  `PersistentIdentifier`, and three call sites depend on it. Thirteen tests on
  the two pure mappings, including the ply↔x round trip across a whole 63-ply
  curve and the evaluation label asserted against `EvaluationBarReading` rather
  than a literal.
- **Four stale claims corrected in code this touched**, all found by reading
  rather than by any check: the Library disclosure's doc said the chevron led
  the copy button and the `HStack` had it trailing; the paragraph above it
  justified a choice on "every other section has no disclosure chrome", true
  when written and false the moment this milestone landed; the "Raw PGN"
  preview said the section starts collapsed, reversed on 30 July; and the
  roster pencil's call site still named `InspectorEditButtonView` as the
  inset's owner.
- **Two build lessons, both pre-recorded** (`81a29ec`, `caae1d7`): generic
  types have no stored static properties, which `SevenTagRosterSection` records
  at `noGamePlaceholder` in a file this milestone had open; and
  `AccessibilityID.swift` compiles into the UI test target, so every function
  there takes a `String` — a constraint obeyed by every entry and stated by
  none, which reads as taste until you break it.
- **Verified clean:** standing prohibitions zero, beta surface (D27′) zero, no
  raw identifier strings, 144 registry entries all referenced, mode 6 still at
  two waived warnings with six new files added under complete concurrency.

**The agreement this earned.** *A sentence that says "every" is a claim about a
set, and the set has a size.* When a plan quantifies over a category, count the
category before believing the plan's scope — especially when the plan's author
could see the category and chose not to enumerate it.

**Not done, deliberately, and on the manual-check list instead:** the chevron's
12 pt gap to the actions slot rests on a bare `EmptyView` not being laid out.
It compiles either way, so ⌘U cannot answer it; the *Actions — Every Arity*
preview's collapsible-with-no-actions row is where it becomes visible.

---

### Between-milestone sweep *(landed 30 July 2026)*

The first standalone run of M5's own new agreement — a grep-level conformance
pass belongs *between* milestones, not only inside them. Three commits on
`3f785a3`, ⌘U green before the pass began (all four Players-editing UITests
included). One decision minted: **D41′**.

**Its headline finding was not a grep result.** The M5 epilogue — six source
files, both rewritten documents — was sitting **unstaged**, while both of those
documents stated the tree was committed and named a base the epilogue was not
part of. A ⌘U-green delivery existed only in the working tree. `git status`
found it as the sweep's first command, and it is now `d33abd3`. The standing
"a discarded working tree is a discarded delivery" agreement gains its sharpest
instance and a new corollary: the sentence claiming the tree is clean is the
one most likely to be stale, because it is written at commit time and never
re-read.

**Findings, in full.**

- **D41′ — `Player.createdAt` deleted** (`43311f9`). A stored `@Model` column
  assigned in `init` and read by nothing in 211 sources. Deleted rather than
  surfaced because it is redundant with a *better* sibling: it records when the
  row was minted, i.e. import time, while `PlayerStats.firstPlayed` answers the
  question it appears to answer — "since when have I played this person?" —
  from game dates. On a back-filled archive the two disagree and `createdAt` is
  the wrong one. Lightweight migration, no plan needed.
- **The columns detail grids fold into `CollectionGridMetrics`** (`40e201d`,
  travelling alone as a mechanical change). `PlayersColumnsView` and
  `RankingsColumnsView` restated `spacing: 16` and `.padding(16)` while
  `LibraryColumnsView`'s equivalent card grid already read the constants — one
  sibling reading and two agreeing by coincidence, which is the twin-read-site
  shape, not merely a literal. Rendered output unchanged. Card *sizing* stays
  local by decision.
- **The AX question is answered.** `test_players_profileHeaderControls_areHittable`
  **passed**: an inspector section header's borderless controls are AX-visible
  on macOS, where M1 proved a *sidebar* header's + button is not. The finding
  does not transfer, no menu-bar remedy is needed, and the three UITests queued
  behind the answer are unnecessary. Closes an open item with evidence rather
  than a decision.

**Verified clean, recorded because a negative result is what makes the
positives credible.** Standing prohibitions all zero (`DispatchQueue`,
`Combine`, `NotificationCenter`, `Thread.sleep`, `@unchecked Sendable`,
`nonisolated(unsafe)`, TODO/FIXME/HACK). D27′'s beta surface still entirely
empty — the only `ContentBuilder` hits are `ToolbarContentBuilder`; build
settings unchanged. All 144 `AccessibilityID` entries referenced, no raw
identifier strings, no residue from D40′'s removal of
`players.inspector.deleteItem`. All 495 private declarations referenced.
D40′'s new dead-guard grep re-run across all fifteen `.disabled(…)` sites:
every enabling value is producible, so D40′'s was the only one. The post-M4
audit's two fixes verified still single-stated (`EvaluationBarView.width`, the
shared pencil's 10 pt inset). Previews conform to the waiver register:
`BoardDestination` is the only View file without one and is waived;
`AnalysisQueueStatusView`'s apparent `#Preview` is its own doc comment
explaining why it has none.

**Gate.** Tree committed and clean — the three commits above on `3f785a3`,
plus this document and the instructions as the fourth; every finding either
fixed or recorded with a D-number; the mechanical change travels alone; both
documents reconciled with what the code and the test run actually say.

*(⌘U after this pass is expected green — nothing here changes behaviour. The
`createdAt` deletion touches a schema attribute nothing reads, and the grid
fold substitutes constants of identical value.)*

---

### M5 epilogue — the orphan sweep *(landed 30 July 2026)*

The witness gap M5 recorded as "the honest gap" — the Players editing flow is
boardless, therefore UITestable, and simply wasn't tested — closed against
`3f785a3` in two reviewed batches, ⌘U green after each. One decision minted:
**D40′**. No files added; the source count stays 211.

**Writing the test found a defect first, which is the entry's real content.**
Before a line of UITest existed, reading the surfaces end to end showed that
**Delete Player could never be enabled**. `GameRecord.Side` is built from the
*resolved* `whitePlayer` / `blackPlayer` links, so `PlayerStats.index(of:)`
only ever emits players holding at least one game; the list renders that index,
so selection can only be a key the index emitted; and `canDelete` read
`recentGames.isEmpty`, filtered on the same links. "Is in the list" and "is
deletable" were exact complements — no player satisfied both, ever. M5's own
manual-check step ("delete that player's only game, revisit Players, confirm
the item is now enabled") was impossible: deleting the last game removes the
player from the list rather than enabling anything.

D9′ had the intent right — "a manual door for them, not a collector" — the
door was just hung on a surface where orphans are structurally invisible. D40′
moves it to the Players toolbar and makes the confirmation dialog the one place
an orphan is ever rendered.

**Gate evidence.**

- **The unreachable affordance is gone, not documented:** `onDelete` and
  `canDelete` leave `PlayersInspectorView`; `players.inspector.deleteItem`
  leaves the registry — a breaking accessibility-contract change, recorded at
  the symbol with why it gets no successor there.
- **One spelling of the rule:** `PGNStore.isOrphaned` replaces three
  independent ones — the old delete guard, `merge`'s post-retag assertion, and
  the inspector's `canDelete`. The second predated this session and was the
  twin-read-site pattern in behavioural clothes.
- **Store door:** `deleteOrphanedPlayers(_:)` takes the confirmed snapshot,
  re-checks each row, and sweeps in one transaction. `PGNStoreRetagTests` grows
  17 → 18: a linked player is never *listed* (absence, not refusal), the orphan
  is listed and swept, and a row that gains a link between listing and
  confirming is skipped — the merge-survivor `isDeleted` lesson applied to a
  snapshot held across a dialog.
- **A reactivity bug caught inside the same change:** the destination first
  read orphans through a store fetch in `body`, which re-renders on `PGN`
  changes only — so the sweep, which deletes `Player` rows and nothing else,
  would have left the toolbar naming rows it had just removed. It is a second
  `@Query` filtered through `PGNStore.isOrphaned`: the store owns the rule, the
  query owns the rows. The fetch-based door was deleted rather than left with
  no app caller.
- **The flow is witnessed:** four UITests —
  `test_players_profileHeaderControls_areHittable` (its own test because both
  controls are borderless inside a `List` section header, the exact shape M1
  proved AX-invisible for the sidebar's + button),
  `test_players_renameRewritesTheListedName` (whose load-bearing assertion is
  that the field opens holding **tag** form, the trap D37′ names),
  `test_players_mergeFoldsTheLoserAway`, and
  `test_players_maintenanceSweep_reachesOrphansTheListCannotShow`, which drives
  the complement end to end: delete the game two players share, watch both rows
  leave the list, reach them through the toolbar.

**The agreement this earned.** *A disabled affordance whose guard can never be
true is a lie with a green build.* It costs nothing at runtime, breaks no test,
and reads as a considered edge case — the same signature as the audit's
comments that *assert* a guarantee. The grep is cheap: for each `disabled(...)`
over a derived condition, ask what supplies the condition and whether that
supply can produce the enabling value at all.

---

### M5 — Player rename and merge *(landed 30 July 2026)*

Executed in two reviewed batches from a Cowork session against `2187a37`,
⌘U green after each. Three decisions minted at recording time — **D37′**,
**D38′**, **D39′** — each chosen by Bera from concrete options before any
diff. Three files added (`PGNStoreRetagTests`, `RenamePlayerSheet`,
`MergePlayerSheet`), so the source count moves 209 → 211.

**The decision-first half, and what the code changed about it.** The roadmap
proposed rewriting the games' seat tags and flagged the registry-alias
alternative; reading the code first turned up a third fact that made the
choice structural rather than aesthetic. `applyEdit` re-resolves **both seats
from the tag strings, unconditionally**, so a merge that only moves
relationships is undone by the first metadata edit on any merged game — the
tag resolves to the deleted player and mints it back. Rename and merge are
therefore one operation underneath, and D38′ records them on one door.

The roadmap's delete proposal did not survive at all. "Merge-into-nobody
(nullify + delete)" is futile: `.nullify` leaves the seat tags intact and the
Library's next `backfillPlayerLinks()` resolves them and recreates the row.
Delete is now **orphan-only**, refusing linked players and returning `false`
so the surface can say rename-or-merge instead of appearing to work.

*(Superseded in its surface by D40′ — see the M5 epilogue above. Orphan-only
was right; the per-player menu item it was attached to could never enable,
because a player with no games appears in no view mode. The refusing singular
door is now a sweep over the rows the list cannot show.)*

**Gate evidence.**

- **Rename and merge round-trip with links intact and dedupe unbroken:**
  `PGNStoreRetagTests`, 17 tests. `renameRewritesStoredTags` and
  `renameChangesTheHash` pin D37′ and its accepted price;
  `renamedGameExportRoundTrips` pins the gate sentence by asserting the import
  door refuses the re-imported export **and that the refusal names the same
  row** — a bare `#expect(throws:)` would pass on a refusal naming some other
  game.
- **Merge survives the app's own doors:** `mergeSurvivesApplyEdit` is D38′'s
  reason for existing, made a test.
- **The resolver never grows a second creation door:**
  `retagCreatesTargetThroughTheResolver` — a retag to a brand-new name creates
  exactly one player for it, through `resolvePlayers`.
- **D39′ refuses whole:** `collidingRenameIsRefusedWhole` asserts both games'
  hashes are untouched after a refusal; `refusalNamesTheCollidingGames` pins
  the payload; `batchInternalCollisionIsCaught` covers the source a
  Library-only probe misses — two of the player's own games colliding with
  each other, which is the double-imported game that motivates merging;
  `foldEquivalentRenameIsAllowed` pins the case that must *not* refuse.
- **The self-play shape:** `selfPlayRewritesBothSeats`. Found while building —
  a per-seat `Rewrite` computes two prospective hashes for a row the player
  holds on both sides, and neither is the hash the row reaches.
- **Surfaces:** five previews across the two sheets, including both branches
  no fixture reaches by accident (a no-comma tag, where the derived display
  line legitimately reads the same as the field; and the one-player Library,
  where the merge picker is absent rather than disabled). Ten identifiers
  registered.

**Three build lessons, all pre-recorded, all re-learned anyway.**
`Swift.Error` refines `Sendable` and a live `@Model` never is, so
`HashCollision` carries identifiers and names — `Error.duplicate`'s precedent
from three hundred lines up the same file. Key paths do not reach tuple
elements. And `Player.normalizedKey(for:)` takes a **display** form: handing
it a comma tag yields a key no row carries, so every lookup written that way
returns nil and passes an "it's gone" assertion for the wrong reason — the
suite routes through one `key(forTag:)` helper instead.

---

### Post-M4 conformance audit *(landed 30 July 2026)*

Not a milestone; recorded because it closed violations of rules this project
already had, and because the shape of what it found is worth repeating before
M6. A repo-wide sweep after M4 came back clean on every mechanical axis — no
`TODO`/`FIXME`, no `DispatchQueue`/`Combine`/`NotificationCenter`, no
`@unchecked Sendable`, no deprecated SwiftUI, no beta API (D27′ re-verified
across the whole 6.4 / 2027 surface), all 116 identifiers referenced, every
view-bearing file previewed except the waived `BoardDestination`.

What it did find was four real items, each a rule already written down:

- **Two twin read sites.** `EvaluationBarView` framed itself at 20 pt while
  `BoardDestination` carried `evaluationBarWidth = 16` for the surrounding
  geometry — the inner fixed frame won, so the bar drew 20 centred in 16, with
  2 pt of bleed each side and a gap that was really 8. And the shared inspector
  pencil grew a 10 pt inset that stacked with the Library's own 8, putting one
  of five pencils at 18 — exactly the drift D26′ exists to prevent. Both
  collapsed to one statement, owned by the type that draws the thing.
- **One second reader.** The Library's ECO column read `ecoCode` directly
  rather than through `PGN.opening`, the accessor where the both-or-neither
  invariant is checked — which would have made it the one surface printing a
  code the rest of the app calls unclassified.
- **One fetch-all worth predicating.** `backfillClassifications` filtered
  `ecoCode == nil` in memory after fetching every game with its full `moves`
  array, on every Library appearance. Unlike the player backfills — where
  "needs linking" genuinely isn't a predicate over the link alone — this is
  one stored column, so `#Predicate` moves it to SQLite and the converged case
  fetches nothing.

**The lesson worth carrying:** three of the four were introduced *by* the two
milestones that had just landed green, and none was visible from inside the
change that caused them. A sweep between milestones is cheap; the pencil one
in particular is invisible unless two inspectors are open side by side.

---

### M4 — Classification: ECO openings + special mates *(landed 30 July 2026)*

Four reviewed batches, ⌘U green after each, on top of M3's working tree.
Decisions **D34′**, **D35′**, **D36′**. Four files added plus five bundled
`.tsv` resources and three new suites (four suites — `ECOTableTests` shares
`ECOClassifierTests`' file), 201 → 208 sources.

**Gate evidence.**

- **A known Ruy Lopez yields its ECO code:** `ruyLopezClassifies`, against the
  real shipped asset behind a vacuity guard that fails loudly if the resources
  fall out of the bundle. `everyVolumeLoads` covers one row per volume, because
  a single probe cannot tell a full table from one where only `eco-c.tsv` made
  it in.
- **Smothered and back-rank fixtures classify:** `GameClassificationTests`,
  including the two halves failing independently — a game the replayer chokes
  on still gets its opening name.
- **A movetext edit re-derives both fields:** `movetextEditReclassifies`. This
  is where the milestone corrected its own decision — D19′ promised the fields
  would *clear*; once D34′ made classification engine-free, clearing was the
  wrong verb, and a re-seated Ruy Lopez is a Ruy Lopez before the transaction
  closes.
- **TagRule filtering works end to end:** six new pins, including the
  absent-motif guard that inherits D30′ and the two Codable pins protecting
  every already-saved tag from the eighth slot.
- **Hash exclusion:** `classificationDoesNotChangeTheHash` — a re-classified
  game must never fork from its own twin.

**The two findings that generalize.** A synchronous parse of a bundled asset
belongs off the main actor, and **XCUITest finds it before Instruments does**:
the symptom was two unrelated suites failing to resolve elements, and the cause
was ~3,800 rows of string work inside an `onAppear`. And: do not infer a data
row any more than an API name — two fixtures built on the assumption that
`1. a4` was unnamed had to be rewritten when it turned out to be the Ware
Opening.

---

### M3 — The evaluation bar *(landed 30 July 2026)*

Decision **D33′**: leading edge, bottom tracks the near player, always-visible
numeric label in a fixed slot beneath the bar.

**Gate evidence.** `EvaluationBarReading` is the pure mapping with a
nonisolated suite, and its fraction is `whiteWinProbability` **verbatim** — so
"the bar agrees with the graph" is structural rather than tested by
coincidence, and mates clamp identically by construction. A nil per-ply
evaluation folds to `Evaluation.drawn`, which finally has the consumer it was
named for. Presence is the wiring's one-line guard on `evaluations.isEmpty`,
the `hasAnalysis` projection's exact truth, so bar presence and the "Analyzed"
tag rule cannot disagree. Five previews. *(The bar's width was found
disagreeing with its caller's geometry constant by the post-M4 audit above;
fixed there.)*

---

### M2 — PGN truth *(landed 30 July 2026, commit `f98cd6a`)*

All six items, decisions **D28′**–**D32′**.

**Gate evidence.** A picker-seeded archived game exports `[White "Senol, Bera"]`
with a real `[Board "…"]` — D28′ threading the identity captured at game start,
outside the content hash so a boarded game still dedupes against its
board-less pre-M2 twin, and D29′ closing the D16′ picker defect by *remembering*
tag form rather than deriving it (D23′: the inverse is undecidable). The splice
defect is closed structurally: `MovetextEdit.tokenize` drops a result token only
when it **closes** the text and throws `.splicedGames` otherwise, so two
concatenated games can no longer validate as one. D30′ decided TagRule's string
semantics in both halves, and flipped M1's documentation test into the
decision's pin. D31′ and D32′ recorded integer-rounds-only and silent batch
overwrite as contracts rather than accidents.

---

### M1 — Trustworthy green *(landed 29 July 2026)*

Executed in one Cowork session against clean `ab33bdf`, in reviewed batches
applied directly to the working tree, with Bera running ⌘U between every
batch. All nineteen items plus the hygiene riders landed; the baseline run
also surfaced and closed seven UITest failures that predated the item list.

**Gate evidence.**

- **Green and meaningful:** full runs green across the final batches
  (Bera's reports); PerftDeep verified *skipped* by test-report observation
  — item 12's dot-spelling suspicion resolved by evidence: the plan's
  `".slow"` spelling matches, so it was kept, and the new unit-only
  `DGTStudioProUnitTests.xctestplan` (which replaced the unit scheme's
  skip-less autocreated plan) spells it identically.
- **No vacuous waits, structurally:** `poll` deleted from
  `DGTLiveSessionTests` — its silent return on timeout was the vacuity —
  and all seven timer-driven waits now `await settled(_:)` (the armed
  quiescence task) with explicit expectations; the archive suite's two
  fixed-sleep negatives got the same treatment; `DGTConnectionTests.poll`
  verified as already asserting on timeout. The vacuity guard is
  `settled`'s `#require(quiescenceTask)`, which fails loudly when no
  settle was armed.
- **Export witnessed:** `PGNSerializerTests` round-trips the three DGT
  reference files byte-for-byte through the production `pgn.pgnText` path.
  The files' real bytes are bundled as test resources (LF-only, single
  trailing newline, byte-verified before landing — they had been sitting
  in the project docs all along). Filename, fallback, sanitization, and
  the constant nine-tag unknown shape are pinned beside the round trip.
- **Pins or written reasons, per item:** new pins for items 1 (drain-race
  suite), 6 (newline-keyword UCI case — the one input that distinguishes
  the two nil exits), 8 (`replacementAnalysisSurvivesStaleBestMove`,
  deterministic via serial UCI), 15–18 (FEN signs + Unicode digit,
  rights-without-rook ×3, hostile evals at both the value and import
  layers, TagRule quantifier + the deliberate documentation test), 19 (the
  two field-desync fixtures with PNG board attachments on failure —
  `BoardAttachmentSupport`, the codebase's first use of 6.3 attachments).
  Written reasons where a pin can't reach: 9a is structural (the reset now
  sits behind the throw), 13 is a release-only breadcrumb, 3/4/5/7 and the
  riders are doc- and canvas-witnessed.
- **Item 11:** `DGTStudioProUITestsLaunchTests` deleted (a screenshot test
  with no audience, launching unseeded against the real store).

**Landed beyond the item list** (the baseline run's harvest): hermetic
UITest defaults — `UITestSeed.scratchDefaults` + `.defaultAppStorage`,
after the ambient-UserDefaults leak explained five row-test failures and
an argument-domain pin was tried and rejected for masking writes; the
inspector-toggle tests taught the open-by-default reality; the Diagnostics
ellipsis and view-mode repairs; and **File ▸ New Smart Tag…**
(`SmartTagCommands`, the `activeGame` focused-value pattern's second use)
after two runs proved the sidebar header's + button is AX-invisible on
macOS — the + stays as pointer furniture on the manual checklist.

**Two register claims predating the item list** were queued as the M1
epilogue; both are closed — the Board load-error UITest witness landed
30 July, and `RankingsGalleryView`'s preview with it.

**Consequence recorded at the time:** the one-time swift-format run became
legal. *Superseded 31 July — D42′ declined the formatter outright, so the
permission M1 unlocked was never used. Left here as provenance: this is
where the run was first called "scheduled", which is the sentence the false
open item grew out of.*