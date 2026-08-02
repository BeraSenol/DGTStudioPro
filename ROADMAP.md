# DGT Studio Pro — Roadmap

*Created 29 July 2026, against clean `ab33bdf`. Milestone slices with gates:
each milestone is a small coherent unit with a written definition of done; no
dates, sequence only. Updates to this file arrive as a complete `.md`, same as
the instructions. When a milestone lands, it moves to the Landed section at the
bottom with its gate evidence — the roadmap is also the record of what shipped.*

*Revised 2 August 2026 (second): **M9 added by request and moved to Landed in
the same pass** — Players and Rankings merged into one destination (D48′): the
ladder becomes Players' default sort with a persisted name toggle, rank and
rating render in every mode, one profile grid states each fact once, and the
Rankings folder's six files retire along with three open items. The
schedulable half is empty again; **M7's two gated items remain**.*

*Revised 2 August 2026: **M6 moved to Landed** — the animation mechanism
decided and built as **D47′**, `SquareView.pieceID` retired with its story
resolved, and the milestone's own goal sentence corrected by its own
constraint line: the mirror glides only what is *proven* (see the entry's
gate evidence for the reasoning, which is the milestone's real finding).
Base `7bf733f` — the four commits of the same day's audit/review pass — and
the tree was **clean** on arrival at M6 itself, the audits having been
committed first. **What is left is M7's two gated items** (Instruments,
which needs Bera and a board; the Xcode 27 GM re-read, ~September). The
roadmap's schedulable half is now empty.*

*Revised 29 July 2026 (evening): **M8 added** (two inspector-chrome features
requested by Bera); **M1 moved to Landed** with its gate evidence.*

*Revised 30 July 2026: **M2, M3, M4 and M5 moved to Landed**, each with gate
evidence, after a working day that ran M2 → M3 → M4 → a post-M4 conformance
audit → M5. The base is `f98cd6a` (M2, committed green); everything after it is
`415ef51` (M3), `06d15c9` (M4), `2187a37` (audit), `79e537f` (a mechanical
resource move), `6a41bc9` and `0a21fc9` (M5's two batches). **No milestone
input remains outstanding** — M4's ECO table source, the last one only Bera
could supply, was picked and bundled. What remains scheduled is **M6, M7 and
M8**, reorderable on appetite.*

*Revised 30 July 2026 (later): the **M5 epilogue** moved to Landed — the
Players editing UITest M5 recorded as its honest gap, plus **D40′**, the
orphan sweep the test's own preparation turned up. Base `3f785a3`. M6, M7 and
M8 remain, unchanged and still reorderable.*

*Revised 1 August 2026: **M8 moved to Landed — both items, in one pass**, the
first milestone to be delivered whole in a single session. Two decisions,
**D45′** (collapsible sections) and **D46′** (the magnifier window), plus a
prerequisite neither item declared: **eight of the app's fifteen inspector
section headers went through `InspectorSectionHeader` and seven did not**, so
"every `InspectorSectionHeader` grows a chevron" would have reached barely half
the app. Base `f64b8d4`, and the tree was **not** clean — D44′ was sitting in it
uncommitted, the sixth such find in seven passes. Seven commits, 211 → 217
sources, ⌘U green at both review points. **What is left is M6, and M7's two
gated items** (Instruments, which needs Bera and a board; the Xcode 27 GM
re-read, ~September).*

*Revised 31 July 2026 (third): **M7's `RosterSummary` experiment run and
closed** (D44′) — the item D43′ explicitly left open, and the last of this
milestone's non-gated work. The `@MainActor` on the live-projection init was
unnecessary and its stated reason was false: a global actor isolates a type's
members, not the types nested inside it. Deleted, and pinned from a
nonisolated suite so restoring it is a compile error. Base `f64b8d4`, and the
tree was **clean** on arrival — the first pass in four that did not open by
finding its predecessor uncommitted. **What is left is M6, M8, and M7's two
gated items** (Instruments, which needs Bera and a board; the Xcode 27 GM
re-read, ~September). Every roadmap item that can be closed from a keyboard
alone is now closed.*

*Revised 31 July 2026 (second): **two more M7 items closed — one as a
correction, one by landing it** (D43′). The warning triage had no population:
a cold build of all three targets emits **zero** compiler diagnostics, and the
"295" this file scheduled work against is unattributable. The item's real
content was the bullet below it — the 230 diagnostics the project had never
asked for. Measured, fixed in three annotations, and the project now builds in
**Swift language mode 6**. Base `c93f54f`. **M6, M8, and M7's remaining two**
(Instruments; the Xcode 27 GM re-read) are what is left — and only Instruments
is actionable before September.*

*Revised 31 July 2026: **M7's swift-format item closed by declining it**
(D42′) — the first roadmap item retired as a decision rather than delivered
as work, because the entry rested on a `.swift-format` that was never
committed. `.DS_Store` untracked in the same pass, so `git status` — the
sweep's mandated first command — stops reading permanent noise. Base
`abf9e0c`. **M6, M8 and M7's remaining three items** are what is left; M7's
three each need a build or a board.*

*Revised 30 July 2026 (last): the **between-milestone sweep** moved to Landed
— the first standalone run of M5's own agreement, which found the epilogue
uncommitted, minted **D41′**, folded the columns grids onto their shared
metrics, and closed the inspector-header AX question with a passing test.
Base `3f785a3`. **M6, M7 and M8 remain** — still reorderable on appetite, and
now the only things left on this roadmap.*

---

## M7 — Measure, format, decide

**Goal: the standing debts that need numbers or a toolchain moment, done
deliberately instead of "while I'm here".**

- **Instruments, first ever run**: leaks + main-thread hangs across a full
  live game, a depth-heavy analysis, a large import, and a Players/Rankings
  browse. The known-costs list in the instructions gets numbers; only then
  do any of the perft/ownership forward notes become eligible. **M4 added two
  entries to that list** (the ECO table's ~3,800-row parse, now warmed
  off-actor but never measured, and `ECOClassifier.opening(for:)`'s quadratic
  prefix re-join) and **M5 added one** (`retag`'s per-game rehash across a
  large linked set). The post-M4 audit *removed* one by predicating
  `backfillClassifications`, which is the shape of win to look for first.
- ~~**Warning triage**: count (last known 295), bucket, burn, waive.~~ —
  **closed 31 July as a correction (D43′)**. There is no 295. A cold build
  of all three targets under the project's own settings emits **zero**
  compiler diagnostics; the only three `warning:` strings in 2001 lines are
  one identical `appintentsmetadataprocessor` notice per target, which is
  not the compiler. The number's provenance cannot be reconstructed, so it
  is recorded as unattributed rather than superseded. **Second false-premise
  bullet in two consecutive passes**, after swift-format below — and this
  one was worse, because a stale *count* stays plausible forever where a
  missing *file* is one command from being caught. What the item was really
  worth turned out to be the bullet underneath it.
- ~~**swift-format, one-time run**~~ — **closed 31 July by declining it
  (D42′)**, and closed as a *decision* rather than a task, because that is
  what it turned out to be: `.swift-format` was never committed, so this
  bullet and the instructions' open item both scheduled a run of a config
  that did not exist. The reason for declining is 314 hand-aligned lines
  across 37 files (215 app, 99 test) in five classes, which swift-format
  cannot preserve — column padding is the pretty-printer's business, not a
  maskable rule, and the one directive that suppresses pretty-printing
  attaches to the enclosing declaration, so protecting six aligned enum
  cases also stops formatting the type's methods. `lint --strict`, the half
  worth having, would report those 314 lines forever. See D42′ for the
  accepted counterargument and the sunset condition. **This bullet's own
  parenthetical was the tell**: "legal since M1's gate passed" is a claim
  about permission, which nobody doubted, standing in for the claim that
  mattered.
- ~~**Language-mode 6 evaluation**~~ — **landed 31 July (D43′)**, and it
  absorbed the triage bullet above, which is where the real population was.
  `SWIFT_VERSION = 6.0` on all three targets.

  **Gate evidence.** Three cold builds, each against a scratch derived-data
  path so every source recompiles: **0** warnings as configured, **230**
  (+165 notes) under `SWIFT_STRICT_CONCURRENCY=complete`, **1 error** under
  `SWIFT_VERSION=6` — which stopped the build at 144 of 239 phases and was
  the whole of the gap between "written as if mode 6" and mode 6. After the
  fixes: mode 6 builds clean, 239 compile phases, exit 0, ⌘U green.

  **Three annotations did it.** `@MainActor` on the UITest class took 226 —
  one file, one cause, eight message shapes refracting the single fact that
  the suite was nonisolated while every `XCUIElement` member it touches is
  main-actor. `@MainActor` on `UITestSeed.scratchDefaults` took the error,
  with `nonisolated(unsafe)` *rejected* rather than reached for: one keyword,
  equally effective, and it would have been the first such opt-out in the app
  target. And `setUpWithError`/`tearDownWithError` → the `async` spellings,
  forced by a language rule worth keeping — a synchronous override cannot add
  isolation its superclass lacks, an async one can.

  **The negative result carries as much weight as the positive.** All 79
  unit-test sources produced **zero** diagnostics under complete concurrency
  before anything was touched. The suite-isolation agreement isn't just
  written down, it's compiler-verified — which is why the app target had four
  warnings rather than two hundred.

  **Waived:** two, both `Binding(present:)`, written at the declaration with
  a sunset condition — `Binding` isn't `Sendable` while its own initializer
  demands `@Sendable` closures, and the 2027 SDK's `.alert(item:)` retires all
  seven call sites and the helper with them.

  *The `RosterSummary` `@MainActor`-init experiment stayed open out of this
  bullet and is now closed — see D44′ below.*

  *The method note worth reusing: the endpoint was chosen by the compiler,
  not in advance. "Fix, re-probe, land wherever it comes back clean" priced
  a migration nobody had measured, and `xcodebuild SWIFT_VERSION=6` as a
  per-run override made the branch this bullet asked for unnecessary.*
- ~~**The `RosterSummary` `@MainActor`-init experiment**~~ — **landed 31 July
  (D44′)**, the rider D43′ left attached to the mode-6 flip.

  **Gate evidence.** The attribute is gone; `RosterSummary.init(_:result:)` is
  nonisolated; `theLiveProjectionIsReachableOffTheMainActor` builds a
  `LiveGame.Roster` inside the nonisolated `RosterSummaryTests` and projects
  it, so the deletion cannot be undone without a compile error. Expected
  green — ⌘U is Bera's.

  **The answer was not "it turned out to be removable".** The reason written
  at the declaration was wrong: `@MainActor` was there "because `Roster` is
  nested in a `@MainActor` class and inherits that isolation", and nested
  types do not inherit global-actor isolation (SE-0449 shows this shape in
  its own text). So the item was never the coin-flip it was filed as.

  **Why a month of green builds missed it, which is the part worth keeping.**
  Every other site constructing a `LiveGame.Roster` is `@MainActor` already,
  correctly, for `LiveGame`'s sake — so no context existed from which the
  claim could fail. D43′'s lesson was "a language claim in a comment is a
  hypothesis until something compiles it"; D44′ sharpens it, because this one
  *was* compiled, constantly. **Something has to compile it from the side
  where it would break.** That is now a working agreement in its own right,
  and it retro-fits three earlier findings: the `.disabled(…)` guard that
  could never be true, the two guards agreeing on an impossible value, and
  the measurement taken from a build that compiled nothing.

- **Xcode 27 GM re-read** (when it ships, ~September): re-read D27′, promote
  or strike each forward note on evidence, run the toolchain-move manual
  checks (Liquid Glass screenshot pass, full UITest suite).

### Instruments run sheet

*Written 31 July with D44′, so the one remaining actionable item needs no
planning on the day. Four scenarios, each naming the known-costs entries it
is the only chance to see.*

**Two rules for the whole pass, both learned the hard way here.**

*Every scenario records a corroborating count* — plies played, games
imported, info lines parsed, players folded — beside its numbers. D43′'s
agreement in its profiling form: an idle app profiles beautifully, and a
profile with no work in it is indistinguishable from a profile with no
problem in it. If the count is absent the measurement did not happen.

*Every super-linear cost is measured at two sizes, and the ratio is the
finding.* Most of the list below is quadratic or fetch-all — `opening(for:)`
re-joins prefixes, `backfillPlayerLinks` scans everything, `Glicko1.histories`
builds every player's array to answer about one. A single point at today's
Library cannot tell "fine" from "fine at this size", and this app's whole
performance envelope is an assumption about size. Import a duplicate batch to
double the Library, re-run, compare. **A 2× input that costs 4× is the result
worth having**, and it is invisible to any single run.

| # | Scenario | Instruments | Known costs it exercises | Record |
|---|---|---|---|---|
| 1 | **A full live game**, real board, to a natural finish | Time Profiler + Allocations; Leaks at teardown | `parseSAN` generating all legal moves per ply; `Position`'s `[Piece]` heap-allocating per `applying`; the draft sidecar's atomic write per committed ply; the New Game sheet's `games.map(\.gameRecord)` fold per seat edit | Plies played; main-thread time per settle; allocations per ply; whether any settle crosses the hang threshold |
| 2 | **A depth-heavy analysis** on one long game | Allocations + Time Profiler; Leaks after Stop All | `UCIProtocol.parse`'s ~3 arrays per info line — by frequency the hottest allocation in the app; engine teardown (the strand-no-waiter contract) | Info lines parsed; allocation rate; Stockfish resident memory against configured Hash; zero leaked engine processes after Stop All |
| 3 | **A large import**, then the first Library appearance | Time Profiler; SwiftUI (view body counts) | The ECO table's ~3,800-row parse, warmed off-actor but never measured; `ECOClassifier.opening(for:)`'s quadratic prefix re-join, bounded at 36 plies; `backfillPlayerLinks`'s fetch-all-and-scan; MD5 per game; `parseSAN` × plies × games | Games imported; wall-clock import; whether the ECO parse ever lands on the main actor; time to first Library paint; **then double the batch and re-run** |
| 4 | **A Players → Rankings browse**, then a rename | Time Profiler; SwiftUI | `Glicko1.histories` building every player's full sample array per question; both destinations folding once per body; `backfillPlayerLinks` again at its three `onAppear`s; `retag`'s per-game re-resolve + MD5, O(linked games), **inside a modal save** | Players in the fold; body evaluations per navigation; rename wall-clock against the linked-game count — this is the one that blocks a sheet, so it is the one a user feels |

**What the pass is allowed to change: nothing.** It produces numbers, and the
numbers go into the instructions' known-costs list — each entry either gets a
figure or is struck as negligible. Fixes are a separate decision with a
separate D-number, because a performance change made in the same pass as its
measurement has no before-and-after. The `backfillClassifications` predicate
is the model: a win found by looking, taken deliberately, recorded on its own.

**Do not add signposts first.** The temptation is to instrument before
measuring; the app already has `os.Logger` categories that give coarse
intervals for free, and adding `os_signpost` calls is production code riding
a measurement pass. Profile raw, and only reach for signposts if a specific
profile is genuinely unreadable — then it is a small named change with a
reason, not scaffolding left behind.

**Eligibility this unlocks.** D27′ gates the perft/ownership forward notes on
this pass explicitly: no `~Copyable` or specialization work on the move
generator until Instruments has run. Note the standing veto that survives the
measurement — generated move order is what the perft counts were taken
against, so perft is both the witness and the thing that can refuse the
change.

**Gate.** Measurements written into the instructions *(outstanding — this is
Instruments' half; the concurrency measurements are recorded)*; ~~warning
count and buckets recorded~~ *(done, and the answer was zero — D43′)*;
~~format landed alone~~ *(struck — D42′ declined the formatter, so there is
no format commit to land; the item is closed, not waived)*; ~~a mode-6
decision recorded with its evidence~~ *(done — D43′, landed rather than
merely decided)*; ~~the `RosterSummary` experiment re-run in the same pass~~
*(done one pass later — D44′, and it closed with a finding rather than a
shrug)*; D27′ re-read logged when GM actually arrives.

**Status: four of six items closed** — swift-format declined (D42′), warning
triage corrected and language-mode 6 landed (D43′, which absorbed the
triage), the `RosterSummary` experiment run (D44′, promoted out of D43′'s
rider to a bullet of its own since it closed with a finding). **Both
survivors are gated on something other than appetite:**

- **Instruments** needs Bera's hands, a board and a real game. It is the item
  this milestone was actually named for, and after three passes of closing
  bullets that dissolved on contact, it is also the only one left that was
  never in doubt. A run sheet is below.
- **The Xcode 27 GM re-read** is calendar-gated, ~September.

**What the four closures have in common, since it is now a pattern and not a
coincidence.** Three of the five original bullets rested on a claim nobody
had checked — a config file that never existed, a warning count nobody could
source, and a comment describing a language rule that isn't one — and the
fourth turned out to be one static property away from done. All four had been
sitting here reading as substantial scheduled work. None cost more than a
command to settle. The M7 lesson is not about formatters or concurrency:
**an unmeasured item accrues imagined weight**, and the longer it sits the
heavier it reads, because nothing about it ever fails.

**The corollary now that only Instruments is left.** Everything M7 has closed
so far, it closed by *checking a claim*. Instruments is the opposite shape —
there is no claim to falsify, only numbers that do not exist yet, and the
known-costs list is honestly labelled as unmeasured rather than quietly
wrong. That is why it survived three passes of demolition, and it is worth
noticing that the one item nobody could dissolve is the one that was written
down as an admission of ignorance rather than as an assertion.

---

## Horizon — known, wanted, unscheduled

File-menu Export via `.focusedSceneValue` (the pattern has three worked
examples now: `activeGame`, M1's `tagEditorDraft`, and `SmartTagCommands`) —
unblocked on appetite since M2 made export truthful; **Library sectioning by
opening**, which M4 promoted from speculation to a named candidate by giving
every game an ECO identity (the 2027 SDK's native `sectionBy` makes it cheaper
later, which is a reason to wait); Library sectioning by event / player /
month; the galleries' empty-selection parity decision; a click-to-move /
position-setup surface (would finally consume `BoardView.selectedSquare`); an
opening-tree explorer over the Library (natural now that M4 landed); the
custom Xcode agent skill encoding the working agreements (gated on Xcode 27
GM).

---

## Landed

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