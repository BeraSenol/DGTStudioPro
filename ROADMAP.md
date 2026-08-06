# DGT Studio Pro — Roadmap

*Created 29 July 2026, against clean `ab33bdf`. Milestone slices with gates:
each milestone is a small coherent unit with a written definition of done; no
dates, sequence only. Updates to this file arrive as a complete `.md`, same as
the instructions. When a milestone lands, it moves to the Landed section at the
bottom with its gate evidence — the roadmap is also the record of what shipped.*

*Revised 4 August 2026 (evening): **M10 entered retroactively and moved
straight to Landed** — it had shipped in `7390227` with zero references in
either document, which is the first time in this roadmap's life that a whole
milestone existed only in code. Two decisions minted at recording time, to
close the two surfaces it left wired to nothing: **D53′** (Get Info is one
window over three subjects and the app's rename door) and **D54′** (movetext
is read-only everywhere but the Library), and **D55′** (one display glyph for
every unknown, minted after ⌘U came back red on four pins asserting the
contract it replaced). The standing
counter-grep that would have caught this — milestone numbers in the code
against milestone numbers in these two documents — is now on the sweep list.*

*Revised 5 August 2026: **the 5 August day entered as a Landed entry**, the
2–4 August burst's precedent for work that ships outside milestone discipline.
Eight decisions across the day — **D56′** through **D63′** — none of them a
milestone, and the roadmap's schedulable half is unchanged: M7's two gated
items remain (Instruments-with-board; the ~September GM re-read). Next free:
**D64′**. That number was **D56′** in this file until now, eight behind the
instructions, which is the same drift the instructions' own header produced on
the same day and the reason both counts now point at one owner: the
instructions' header is the source, this line repeats it.*

*Revised 6 August 2026: **three refinement milestones added — M12, M13, M14**
— the first entries on this roadmap that schedule no feature. M7's Instruments
item is absorbed into M12 rather than left standing beside it, because the run
was always a gate on something and now it is a gate on something scheduled;
M7's remaining bullet is the ~September GM re-read, which is the only thing on
this roadmap that waits on a date. Base: `ef92d96` plus a working tree dirty
with 36 modified sources — named rather than discovered, and **⌘U is owed on
it before M12 starts**, since the last reported run predates the four
doc-compression commits. The ordering is the argument and it is written into
M12: stability, then structure, then reading. **No D-numbers are penciled** —
three M12 bullets will each take one at recording time. Next free: **D64′**.

**M11 is skipped, and the reason is a finding rather than a preference.**
These three were drafted as M11–M13 and renumbered, because `M11` is already
taken: it is the pre-roadmap **decoupling review**, live in ten source
comments across `SettingsView`, `StorageKeys`, `BoardDestination`,
`StockfishEngine`, `PGNStore` and `PGNStoreTests`, in the same provenance
class as M7.2 and M-prs.1. Roadmap milestones stopped at M10, so the next
free *roadmap* number and the next free *tag* number had quietly diverged by
one — and nothing would have failed if the collision had shipped. The
counter-grep would have come back clean, because it asks whether a tag in the
sources appears in these documents and both meanings share a string. A reader
grepping `M11` would have got two unrelated things and no way to tell them
apart. **Caught by running the check rather than by trusting it**, which is
the only method with a record here. The transferable rule: milestone numbers
live in one namespace with the legacy tags, not two, so the next free number
is `max` over the sources and both documents — never over the roadmap alone.*

*Next free milestone number: **M15**.

*Revised 6 August 2026 (later): **⌘U reported green by Bera**, discharging the
gate on the em-dash pass (`09df7ed`), the roadmap itself (`389b7a5`), and
M12.1 (`f6c4b6c`) and M12.2 (`a09a3fe`) — four commits, one run. Worth one
line because two of them predicted their own results and both predictions were
the weak kind: M12.1's `annotationsDoNotSurviveImport` was expected green on
its first run, which is normally a sign a pin is decorative and here was
correct because the thing it pins was already true and merely unstated; and
M12.2 changed behaviour on three surfaces with six new pins behind it. **M12.3
is not in that run** — it landed after, and is doc-and-comment work with no
behaviour change, so its own gate is the cheap one.*
The three measurements this revision rests on, with their methods, so the next
pass re-runs rather than inherits: 140 app sources and 91 test sources
(`find … -name '*.swift'`) — **92 test sources from M12.5 that afternoon,
which is this line demonstrating its own point within the day**; 30,332 app
lines of which 11,587 are comments
(`grep -rh '^\s*///'` and its `//` sibling); `PROJECT-INSTRUCTIONS.md` at
335 KB (`wc -c`).*

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

## M12 — Close what is known

**Goal: every item on the instructions' open-items list is closed, decided,
or measured — while the code is still where every anchor says it is.**

*Sequencing note, because this milestone's position is the argument rather
than its contents. M12 runs before M13's file moves for one reason: a bug fix
and a path rewrite are both cheap alone and expensive together. A fix landing
into a tree mid-reorganization cannot be reviewed against the anchor that
describes it, and the anchor cannot be corrected until the file stops moving.
Stability first also means the reorganization lands on a tree with nothing
outstanding, which is the only state in which "⌘U green plus a cold build" is
a sufficient gate for a change that touches a hundred paths.*

**No D-numbers are penciled here.** Three of the bullets below reverse or
narrow a recorded contract and will each take a number at recording time, in
the instructions, in sequence. Next free is **D64′**, which is a fact about
today rather than an allocation.

- ~~**The `endedInMate` divergence, decided.**~~ — **closed 6 August 2026 as
  a correction, not a fix. There was no divergence.** This bullet was written
  as the milestone's headline item and was wrong within the hour, which is
  worth leaving visible rather than deleting.

  It read: `PGN+GameRecord` builds the record with `hasSuffix("#")` while
  `GameClassification` gates on `contains("#")`, so a game ending `Qd2#!` is a
  special mate that is not a mate, on screen since the Special Mates column
  landed. **No such game can be stored.** `PGNParser.flushToken` runs every
  emitted token through `stripAnnotations`, which strips trailing `!`/`?` —
  and it is the only `moves.append` in the parser. The other two writers store
  canonical `san(for:)` output, which appends `#` or `+` and nothing else. So
  `#` is always last, and the two spellings agree on every value either will
  ever be handed.

  **The finding is not the false comment. It is that the test disproving it
  was already green.** `suffixAnnotationsStripButCheckAndMateSurvive` has been
  parsing `1. e4! f5?? 2. Qh5+ g6!? *` to `["e4", "f5", "Qh5+", "g6"]` since it
  was written. Simultaneously: `GameClassification`'s doc asserted annotations
  survive import, the instructions carried an open item resting on that
  assertion, `PlayerStats`' doc repeated it, and `PlayerStatsTests`
  reproduced the impossible record under a name calling it a bug. Four
  artefacts agreeing with each other and one passing test contradicting all
  four. Nothing failed, because **the check and the claim never met** — the
  sibling test used `+`, so no grep, no build and no run would ever put them
  on the same screen.

  That is a species this roadmap had not named. The working agreements cover
  claims that are false, stale, invented, true-but-narrower, and absent; this
  one is **already checked and already contradicted**, sitting a hundred lines
  from its own refutation. The defence is not another grep. It is that a
  comment asserting a fact about *another file's behaviour* should name the
  test that holds it — a citation the reader can follow in one jump, which is
  what the corrected comments now carry.

  **Landed:** the false claim corrected at `GameClassification` and
  `PlayerStats` (two homes, one pass); `annotationsDoNotSurviveImport` added
  to the parser suite as the `#` case, citing the sibling and stating the
  consequence; and the anomaly test rewritten as
  `matesAndSpecialMatesAreCountedFromDifferentFields`, which is what it
  actually witnesses — the old name described a bug that did not exist over a
  record no door produces. **No behaviour changed and no D-number is owed**:
  nothing was reversed, nothing minted, and `contains` keeps its spelling on a
  narrower argument now written at the site (a pure function tolerating input
  it does not own).

  *Method note, because it is the transferable part: this was found by asking
  what would have to be true for the bug to occur, and then checking whether
  any door could produce it — rather than by reading the two spellings and
  believing the comment between them.*

- ~~**D61′'s scope gap, closed at the shared form.**~~ — **landed 6 August
  2026.** The guard lived in `GetInfoWindow` alone while `NewLiveGameSheet` and
  `EditGameInfoSheet` refused nothing, so the three surfaces *deliberately
  unified* for the seat menu one request earlier were deliberately different
  for the guard one request later.

  **Landed:** `Player.seatsNameOnePlayer(_:_:)` beside `identity(forTag:)` as
  the one predicate, `LiveGame.Roster.seatsNameOnePlayer` forwarding for the
  shape the forms hold, and `GetInfoWindow.seatsCollide` **deleted** — a rule
  living inside one of its consumers is what let the gap open, so extracting it
  is the fix rather than a tidy-up. The form renders an inline warning; both
  hosts disable their primary button; Get Info keeps its revert-and-alert.

  **Same predicate, two shapes, and the reason is the commit model.** Get Info
  commits per field on Return or focus loss, so by the time it can object the
  value is already going to the store and reverting is the only honest
  response. The sheets stage behind one button, so nothing is committed and
  there is nothing to revert — reverting a field the reader is still typing
  into would be the rudest reading of the same rule. D57′'s pattern, across
  three surfaces instead of one window.

  **Gating the archive sheet is safe and the opposite would have been a trap**,
  which is the thing this bullet did not know when it was written:
  `EditGameInfoSheet` appears *after* the game is archived, so a disabled Save
  strands nothing — Done dismisses unconditionally and the game is already in
  the Library. Blocking it before checking that would have made a played game
  unsaveable on a typo.

  **The find underneath: D61′ shipped with no test of its own.**
  `PlayerIdentityTests` pinned the guard's *input* and nothing pinned the
  predicate, so the case that matters — two spellings of one player colliding —
  was unasserted, and a raw `!=` would have passed the entire suite. Six pins
  now, including both unknown-seat exemptions and the accessor asserted against
  the predicate rather than a literal.

  The import asymmetry is untouched, as required: `selfPlayRewritesBothSeats`
  and `headToHeadIgnoresSelfPlay` both stand, and `importPGN` still admits a
  file recording one person on both sides. **What closed is one door minting
  them, not the concept.**

  Registry: one entry, `formSeatConflict(_:)` — the first minted since
  `players.rankingPicker`, and named because on these two sheets the refusal is
  a line of text and a greyed button rather than an alert.

- ~~**The three unconsumed symbols, each decided rather than swept.**~~ —
  **landed 6 August 2026. All three kept, all three now written down.**
  `markDirty` joins the test-only-by-decision list, where it already belonged
  in fact: `OpenGamesRegistryTests` covers it end to end. `isOpen` and
  `selectedSquare` keep their places with the disposition argued at the
  declaration rather than only in the register.

  **The framing was wrong, and that is the finding.** This bullet called them
  "three unconsumed symbols", which is what a declaration-name scan reports.
  Two of them are deeper: they carry **unreachable branches in their
  consumers**, which no name scan can see. Nothing calls `markDirty`, so
  `LibraryDestination.delete`'s discard-confirmation arm can never execute —
  and `markClean` *is* called twice, on a set that can only ever be empty.
  `BoardView.selectedSquare` takes its default at every call site, so
  `BoardView.squareHighlight`'s `.selected` insert is dead **and** so is
  `SquareView`'s tint arm: two dead branches behind one unset property.

  That is the M10 reachability lesson one level further in. M10 recorded that
  a token cross-reference proves a name is *used*, never that a user can reach
  it; M12.3 adds that it says nothing about whether a consumer's **branch** can
  execute. A branch whose condition can never be true is the D40′ shape
  wherever it appears, and D40′'s own prescription is a comment at the branch —
  which all three now carry.

  **The preview wrinkle, kept and labelled.** `SquareView`'s preview passes
  `.selected` directly, so the tint renders on canvas while the app cannot
  produce it. D51′ records that a preview witnessing an arrangement the app
  does not have reads as evidence the arrangement is checked — same hazard,
  opposite cause: D51′'s had been *retired*, this one has never been
  *reached*. Kept so a future click-to-move surface starts from a style
  someone has looked at, and now saying so in both places.

  `isOpen` stays the odd one and its paragraph says why: `markDirty` and
  `selectedSquare` are pre-wiring with a named future consumer and a dead
  branch resting on them, while `isOpen` is a plain accessor with nothing
  resting on it at all. Nothing is dead because of it; it is simply not asked.
  Still not D41′'s disposition — `createdAt` had a better sibling, and this has
  none, since `DGTConnection.status` answers a different question one layer up
  and the two can disagree during a teardown.

- **The launch-time `FocusedValue` warning, discriminated.**
  `FocusedValue update tried to update multiple times per frame` fires at
  every launch and is narrowed to two candidates: `\.boardGetInfoRequest`
  carrying a `Binding<Bool>` that is a fresh non-`Equatable` instance on every
  body pass (so SwiftUI cannot dedupe it) while `.onAppear` mutates
  `tabState.boardGame` and forces a second pass inside the launch frame; or
  two restored board windows both writing `\.activeGame` in one frame, which
  D51′'s restoration saga makes more than hypothetical.

  ~~**One step separates them: quit with a single board window open,
  relaunch.**~~ **Narrowed by reading, 6 Aug 2026, and the step it proposed is
  now the wrong one.** The first candidate is *sufficient on its own and needs
  only one window*, which the bullet assumed was what the test would rule out.
  The chain is all in `BoardDestination`'s modifier stack and none of it
  depends on a second window: `.onAppear { loadIfNeeded() }` (line 207) fires
  during the first render and mutates `tabState.boardGame`, which invalidates
  the body and re-evaluates it **inside the same frame**; both passes publish
  `\.activeGame` (190) and `\.boardGetInfoRequest` (195); and line 197 mints
  `$getInfoRequested` fresh on each pass, which SwiftUI cannot dedupe because
  `Binding` is not `Equatable`. Two publishes, one frame, one window.

  So a relaunch with a single window is now *expected* to warn, and seeing it
  warn proves nothing. **What is still unsettled is which key**, and that is a
  fact about SwiftUI's dedupe behaviour rather than about this code:
  `\.activeGame` publishes a `Game`, a reference type, so if SwiftUI compares
  by identity the second pass dedupes and only the `Binding` warns. The
  informative step is therefore to read the **log line itself** and see whether
  it names a key — not to count windows.

  Deliberately **not fixed on this reasoning.** The obvious remedy is moving
  `loadIfNeeded()` off `.onAppear`, which changes when the Board loads for a
  warning the instructions already class as redundant-work rather than
  incorrect — and the arrangement it implicates is D53′'s trigger-binding
  pattern in its third use, so it is a decision about a pattern rather than a
  tidy-up. Guessing at a fix for something nobody has observed is how the 295
  got into the open items list.

- ~~**The library-index backfill, built.**~~ — **landed 6 August 2026.**
  `PGNStore.backfillLibraryIndices(from:)` matches PGN files in a chosen folder
  to Library rows **by content hash** and stamps each match with the ordinal
  its filename carries. `hasUnnumberedGames()` is the affordance's own
  question, and the Library toolbar's third transfer item exists **only while
  it answers true** — the `queueStatusLabel` shape in the same toolbar, and the
  honest one for a job that retires itself: run it once and the button is gone,
  rather than sitting greyed out forever (D40′).

  Matching by hash rather than filename is the load-bearing choice and the one
  most likely to be "simplified" later, so it has its own pin: D58′ records
  that the working folder spells filenames with full display names while
  `PGNSerializer.fileName` writes given names only, so a name-based match would
  miss exactly the files this exists to read. Two more guards pinned because
  their failure would be silent and total: an existing ordinal is **never**
  overwritten (a scan that renumbers from a stale folder is worse than one that
  does nothing), and a filename with digits but no period is a year in a title
  rather than an ordinal. Ten pins, including `hasUnnumberedGames` producible
  both ways — the D40′ check run at minting.

  Reported rather than logged: the alert always fires, including on "matched
  none of them", because a scan that finishes silently is indistinguishable
  from one that never ran, and the commonest real failure is pointing at the
  wrong folder. Unmatched files are phrased as a finding rather than a fault —
  a file the Library does not hold is a game not yet imported.

  **Two stale claims fell out on the way**, both in `LibraryDestination` and
  neither related to the feature. The transfer group's doc described "a single
  `ToolbarItem`" with "the explicit `Divider`" over code holding **two**
  `ToolbarItem`s and no `Divider` at all. And `Binding(present:)`'s doc — the
  one that argues counts belong in commands rather than prose — carried "it is
  currently eight" beside that argument; it was **nine** when written and is
  eleven now. Corrected, and the second is recorded at the site as the fourth
  time that particular number has been wrong.

  *Superseded bullet text follows, kept because it is the specification the
  door was built to and the rejections still hold.* D58′ shipped with a stated gap:
  every game imported before it gets `nil`, the app never stored the URL it
  imported through, and re-importing is refused as a duplicate — so the
  existing archive **cannot be backfilled by any door that exists**. The `#`
  column and the File tab read em dashes for the whole pre-D58′ library, which
  is most of it.

  The remedy is the one the anchor names: **a folder scan matching files to
  rows by content hash**. Point at the PGN folder, hash each file through the
  pipeline that already computes the import hash, match, stamp
  `PGNSerializer.libraryIndex(fromFileName:)`'s answer onto the row. It reuses
  the import machinery whole, needs no schema change, and is re-runnable as
  the folder grows. Two properties to get right at the declaration: it must
  stamp **only** where the row's index is currently nil (a scan that
  overwrites is a scan that can renumber the archive from a stale folder), and
  a file matching no row is a *finding worth logging*, not an error — it means
  the folder holds a game the Library does not.

  Rejected, and worth recording because the obvious one is wrong: **storing
  the source URL at import** is the right permanent fix and does nothing about
  the games already imported, which is the entire problem — it only pays off
  bolted to the scan, and the scan alone is sufficient. **Hand-editing the
  index on the File tab** was rejected on D57′'s own split: File is defined as
  what the app derived or stamped, and putting an editable field there costs
  the rule that makes the two tabs legible.

- **Instruments, the run that gates the census.** M7's surviving item,
  unchanged and now load-bearing for this roadmap rather than only for itself.
  The four scenarios are already written down in the run sheet above; what M12
  adds is the consequence: **every entry in the known-costs census gets a
  number or gets struck**, and nothing on that list becomes eligible for
  optimization until it has one.

  The list has said that since it was written and has never been able to
  enforce it, because there was no moment at which the enforcement was due.
  This is that moment. Three entries are the ones to watch — `Glicko1.histories`
  folding every player's full sample array per render on the merged Players
  body, `LibraryFilter.matches` building a `GameRecord` per game per body pass
  on the most invalidation-prone surface in the app, and the ECO comparator
  rehydrating an `ECOOpening` per comparison per render since the column sort
  landed — but the run is what decides whether any of them is real.

**Gate.** ⌘U green, reported by Bera, on the whole of it. **This gate said
something different when it was written**, and the change is instructive: it
named `aSpecialMateCanOutnumberMatesWhileTheSpellingsDisagree` as a pin that
*must go red*, on the reasoning that a milestone repealing a rule should break
the test holding it. That reasoning is sound and the premise was wrong — there
was no rule to repeal, so the honest expectation is now the ordinary one, plus
one new test that must be **green on its first run**:
`annotationsDoNotSurviveImport`. A new pin passing immediately is usually a
weak signal, and here it is the correct one, because the thing it pins was
already true and merely unstated.

Plus the manual checks each fix implies: the seat guard exercised from all three
surfaces rather than from Get Info alone; the relaunch step for the
`FocusedValue` question, with the answer written down whichever way it comes
out; and the folder scan run against the real archive with the `#` column
read afterwards, since a backfill that stamps nothing and a backfill that
stamps everything look identical from the console.

---

## M13 — Feature-first, and the filesystem says so

**Goal: a file's folder states what it is for. Surfaces are grouped by the
thing they serve; the substrate is grouped by what it knows.**

***The move landed 6 August 2026 (`ff1220c`) — 92 renames, 0 insertions, 0
deletions, followed by the path sweep as its own commit. What remains of this
milestone is code: the `GetInfoWindow` split and the three merges, both of
which want a compiler and are deliberately not riding a mechanical commit.***

***The path debt turned out to be almost nothing, and that is the finding.***
*The sweep expected a hundred false claims and found **one** — D45′'s
invariant saying the collapse store is read "in exactly two files, both in
`Inspector/`". **Zero source comments cite a moved folder at all.** The
codebase names types, not paths, so the reorganization could not invalidate
it; the two documents cite paths in fourteen places and eleven of those are
folders that did not move. M14's "stop citing paths in docs" option was
written as a proposal and turns out to describe what the code already does —
the remaining exposure is the documents, and it is small enough to fix by
hand rather than by policy.*

*One item closed as collateral: the filing-quirk entry naming
`StockfishEngine` and three misfiled suites. It undercounted, because it was
a list of things someone had noticed rather than the output of a check —
`DGTBoardDiffTests` had sat two folders from its subject the whole time. The
check that would have found all five: for each test file, does its subject
live in the mirrored folder?*

*What this milestone is not: a purity axis. `Core/`, `Model/`, `Feature/`
was the alternative and it was declined — it would make D10′ visible in the
filesystem, and it would also scatter every feature across three folders so
that working on Players means three directories open. Feature-first is the
choice that optimizes for the person doing the work rather than for the
diagram. The purity invariant survives where it always lived: it names
**types**, not folders, which D34′ already had to say out loud when
`ECOClassifier` and `ECOTable` were filed together.*

**The layout, measured at writing (140 app sources, 91 test sources).**

```
DGTStudioPro/
  App/            the shell alone — DGTStudioProApp, ContentView, SettingsView,
                  SessionSidebarPanel, StorageKeys, AppLog, TestHost,
                  AccessibilityID, PreviewFixtures, SleepInhibitor, TabState
  Features/
    Board/        the board and everything played or reviewed on it: destination,
                  BoardView, SquareView, piece layer, PieceIdentity, the two
                  evaluation surfaces and their readings, MoveHistoryView, the
                  board and live inspectors, the live sheets, HUD, recovery,
                  GameNavigationCommands
    Library/      unchanged — destination, four modes, inspector, filter, import,
                  actions menu, preview
    Players/      unchanged — destination, four modes, inspector, stats, Glicko,
                  ranking, rating graph, name, pairing
    SmartTags/    unchanged
    GetInfo/      the split window (below) plus MovetextEditorView, which D59′
                  made a tab rather than a sheet
  Shared/
    Inspector/    the chrome six areas consume: section header, collapse store,
                  CollapsibleSection, edit button, empty state, +Toolbar — and
                  SevenTagRosterSection + OpeningSection, which are views that
                  have been misfiled in PGN/ since they were written
    Collection/   CollectionViewMode, CollectionSearch, IconGridSelection,
                  DestinationSubtitle — reusable machinery currently in App/,
                  serving Library and Players
  Chess/          the pure rules core
  DGT/            transport, protocol, framer, decoder, reconstructor, session
  Engine/         Stockfish, UCI, the queue and its controller — gains
                  StockfishEngine.swift, whose filing in PGN/ is a recorded quirk
  Game/           model only — LiveGame, its draft sidecar and store, Game,
                  GameHeadline, SessionPhase, OpenGamesRegistry
  PGN/            model and format only — PGN and its two extensions, PGNStore,
                  GameRecord, Parser, Serializer, Exporter, RosterSummary
```

**Where feature-first strains, named rather than smoothed.** `Recovery/`'s
two files went to `Features/Board/`, and `SessionSidebarPanel` — which stayed in
`App/`, because D15′ makes the sidebar the master of session info — reads
`RecoveryGuidance` across that boundary. That is a real cross-feature
reference and there is no filing that removes it: the guidance is computed in
two places by decision (the board for its overlays, the panel for its
checklist), so whichever folder it sits in, one consumer is elsewhere. It is
recorded here so the next reader knows it was seen rather than missed.

- **`GetInfoWindow` splits by tab — half done 6 Aug 2026, and the other half
  needs a decision this bullet did not know it was asking for.**

  **Landed, free:** `GetInfoRequest.swift` and `GetInfoMenuItem.swift` are out.
  Both are independent types that touch nothing private on the window, so
  extraction cost **zero** access changes. 1,362 → 1,234 lines.

  **Blocked, and the blocker is a recorded decision.** The remaining six files
  are all *extensions on `GetInfoWindow`*, and Swift's `private` is
  file-scoped: an extension in another file cannot see it. The window declares
  **18** private members in its body — two statics, two `@Environment`s, a
  `@Query`, a `@FocusState`, and eleven `@State`s including all eight drafts —
  and the tab renderers use them throughout. So the split costs eighteen
  widenings to `internal`, which makes every piece of this window's `@State`
  writable from anywhere in the module. This bullet anticipated "a visibility
  widening… argued once at the type"; it did not anticipate that the number is
  eighteen and that all of it is `@State`.

  **The obvious escape is closed by D57′.** The idiomatic SwiftUI answer is to
  extract each tab as its own `View` taking explicit inputs — which preserves
  encapsulation and is why the language makes this awkward. It needs the eight
  drafts bundled into one type to keep the interface sane, and **D57′
  explicitly rejected a draft struct**: "the field is the unit of work —
  `commitField(_:on:)` writes exactly the property its case names, so a stray
  edit cannot ride along with another row's Return. A struct would make 'which
  changed?' a diff, the shape D18′ rejected at `applyEdit`." That argument is
  about correctness, not tidiness, and it outranks file size.

  So the three real options were: **widen the eighteen** and accept a window
  with no private state; **keep the file at 1,234** and treat the two free
  extractions as the whole of it; or **revisit D57′'s draft-struct rejection**,
  which is a decision about commit granularity wearing a refactor's clothes.

  **Decided 6 August 2026: stop at 1,234.** The file is large and coherent —
  one window, one subject resolution, three forms, and every draft private to
  the type that commits it. Neither of the other two buys anything the reader
  can feel: widening eighteen `@State`s trades a real guarantee for a smaller
  file, and reopening D57′ would let a formatting preference reach into a
  correctness argument. **Recorded as a decision rather than left as an open
  item**, because "this file is too big" is exactly the kind of unexamined
  discomfort that sits on a list accruing imagined weight — M7's own lesson.
  If it is ever reopened, the reason should be that someone got lost in it,
  not that 1,234 is a large number.

  *Original specification follows, unchanged, for whichever option is taken.*
  1,362 lines holding one enum, two views
  and four extensions becomes eight files, and the seams are the decisions:
  `GetInfoRequest` (the routing type, carrying the `openWindow`-by-type trap
  D46′ minted and D53′ made a pattern), `GetInfoMenuItem`, `GetInfoWindow`
  (shell, `Subject`, `resolve`, title, content dispatch, unavailable),
  `GetInfoDetailsTab` (D57′ and D61′ — the nine tags, per-field commit, the
  seat rows, the result check, `FieldRefusal`), `GetInfoMoveTextTab` (D59′),
  `GetInfoFileTab` (D57′ and D58′, with its formatters), `GetInfoLiveForm`,
  and `GetInfoPlayerForm` with the rename extension (D53′).

  By tab rather than by subject because the game form is most of the file and
  its three tabs are three different stories with three different commit
  models — per-field on Return or focus loss for Details, accept-whole for
  Move Text, read-only for File. A by-subject split would leave one file still
  carrying nearly a thousand lines.

  **The one thing to check while splitting:** `private` members become
  invisible across files. Everything the tabs share — the drafts, `commitField`,
  `seatValue`, `optionalValue`, `seatsCollide` — has to move to a level all
  the extensions can see, and the honest spelling is `internal` on the type
  rather than `fileprivate` scattered. That is a visibility widening and it
  should be argued once at the type, not eight times.

- ~~**Three merges, and only three.**~~ — **landed 6 August 2026.** 140 app
  sources to 137. `LastMove` into `Move`, `FEN+Parsing` into `FEN`,
  `GameState+Replay` into `GameState`.

  **Method, because it is the transferable part of a merge with no compiler
  to hand.** The two small ones were retyped and then **diffed against their
  originals with comments stripped** — both came back identical, which is the
  only reason retyping was acceptable at all. The 209-line one was
  *concatenated* rather than retyped, because a transcription check that
  passes is evidence about that transcription and nothing about the next one.
  Then three structural checks: every moved declaration present exactly once,
  braces balanced per file, and no symbol referenced from a file that no
  longer exists. That is what can be verified by reading; the compiler is
  still owed.

  *One check misfired and is worth recording, since it is the fourth time this
  shape has appeared in two days: a grep for duplicate top-level declarations
  flagged `extension FEN {` and `extension GameState {`, which are multiple
  extensions of one type — legal, normal, and invisible to a line-oriented
  check. A first run that needs interpreting is a check nobody runs twice.*

  Original reasoning, unchanged: `LastMove.swift` is four lines and folds
  into `Move.swift` — it is a `Move` plus context and there is no reading
  under which it earns a file. `FEN+Parsing` folds into `FEN.swift`, which
  puts the boundary-hardening rules beside the type they harden. And
  `GameState.swift` (51 lines) takes `GameState+Replay` (51), leaving
  `+MoveGeneration` (354) and `+SAN` (324) standing alone — which is the split
  that was always earning its keep, now visible as such rather than as one of
  four siblings.

  **Deliberately not merged:** the two evaluation readings. It was the
  tempting fourth — both pure, both small, and D46′ pins the graph's label to
  the bar's verbatim — and it is declined because that pin is a test asserting
  one type against the other, and a test asserting a type against itself
  across a file boundary it no longer has is a weaker test. The separation is
  what makes the agreement checkable.

- **One extraction, found while checking M12's seat-guard bullet.**
  `LiveGameRosterForm` is declared at line 38 of `NewLiveGameSheet.swift` and
  used by *both* that sheet and `EditGameInfoSheet` — a shared component living
  inside one of its two consumers, which is the arrangement that makes the
  second consumer invisible to anyone reading the first. It gets its own file.

  This matters beyond tidiness because it is where M12's D61′ fix lands: the
  self-play guard moves into this form, so the file it lives in is about to
  become the single home of a rule covering two surfaces. A shared type inside
  a sibling's file is survivable while it only draws controls; it is not once
  it owns a refusal. Note also that `GetInfoWindow` reproduces this form's
  `playerMenu` shape **deliberately rather than sharing it** — D59′ argues that
  one at the site, on two different commit contracts — so the extraction covers
  two consumers, not three, and the third stays separate on purpose.

- ~~**The test target mirrors, and three recorded misfilings go.**~~ —
  **landed with the move.** `PairingRoundTests` out of `Chess/`,
  `MovetextEditTests` out of `Players/`, `PieceTrackerTests` out of `DGT/` —
  and a **fourth** the recorded list had never noticed, `DGTBoardDiffTests`,
  which had sat in `Board/` while `DGTBoardDiff` lives in `DGT/`.
  `DGTBoardSimulator` followed it to the folder holding its one consumer, and
  `MovetextScoreSheetTests` went to `Features/GetInfo/` with the view it
  renders. Suites track their subjects, so a suite is findable from the thing
  it pins.

**How it lands: two commits, one sitting.** The first moves files and changes
no code — mechanical changes travel alone, and this is the largest mechanical
change in the project's life. The second re-points every path citation in
both documents, driven by a grep for the old folder names rather than by
reading, because "any sentence in these documents that contains a path is a
checkable claim about the filesystem" is this project's own rule and a
hundred-file move is the event that falsifies the most of them at once.

**Gate.** ⌘U green — and a **cold build against a scratch derived-data path**,
which is the gate ⌘U alone cannot be, because under synchronized folder
groups *target membership is folder contents*. A file moved out of a target's
folder leaves that target silently. The specific thing to verify by hand is
the bundled resources: the five ECO TSVs and the three reference PGNs land
flat at the Resources root whatever source folder they came from, so they
*should* be unaffected — and "should" is what the 30 July resource death was
made of. Confirm `ECOTable` reports its row count once at load and
`PGNSerializerTests` finds its bundle, rather than assuming the flat-root rule
held. Then: `grep -rn` for each retired folder name across both documents,
expecting empty.

---

## M14 — Reading cost

**Goal: the project's memory stops charging full price on every read.**

`PROJECT-INSTRUCTIONS.md` is 335 KB — roughly 84,000 tokens, re-read at the
start of every sitting. The app target is 30,332 lines of which **11,587 are
comments** (7,964 doc, 3,623 ordinary): 38%. Neither number is a defect on its
own. Together they mean the same reasoning is being paid for twice, in two
places, at every read — which is the actual finding, and it is what makes this
milestone a consolidation rather than a deletion.

- ~~**`DECISIONS.md` takes the anchors, verbatim and append-only.**~~ —
  **landed 6 August 2026.** 55 anchors, 913 lines, moved and then **diffed
  against `HEAD` to prove they were moved rather than rewritten** — identical.
  `PROJECT-INSTRUCTIONS.md` goes **335 KB → 173 KB**, a 48% cut with no
  information lost, and keeps all twelve of its sections.

  What stayed, because it is read constantly and this document has to stand
  alone: locked decisions **#1** (the physical board is truth, the live game is
  append-only) and **#3** (`*` never finishes and never archives), restated
  rather than cited. What moved with the anchors: the **next-free-number**
  line, so it has exactly one owner — the rule the other document's header had
  to learn twice.

  Both new checks were run and both are clean: every D-number cited in a source
  resolves to an anchor that exists, and the milestone counter-grep now reads
  three documents. The second matters more than it looks — a third file is a
  third place work can fail to be recorded in, and absence is the one species
  no check that reads what *was* written can catch.

  Original specification: D9′ through
  D63′ move unchanged. `PROJECT-INSTRUCTIONS.md` keeps what the app is, where
  things stand, the architecture invariants, the working agreements, the
  waiver register, the toolchain notes, the open items, and the manual checks
  — and cites D-numbers without restating their arguments.

  **Verbatim, and by the whole set rather than by judgement, for one reason
  each.** Verbatim because a decision rewritten in the act of being moved is a
  decision silently re-decided, and this document has caught itself doing
  smaller versions of that repeatedly. The whole set rather than only the
  superseded ones because "which anchors are still cited daily" is a judgement
  that needs re-making every sitting, and a rule that needs re-judging is the
  thing this project replaces with mechanism wherever it can.

  **The property to preserve, stated because it is what could go wrong:** the
  fifth species of unchecked claim is *absence* — a milestone that was never
  written down cannot be caught by any check that reads what was written. A
  split creates a second place work can fail to be recorded in. So the
  counter-grep gains a second target: milestone numbers in the sources against
  **both** documents, and the next-free-D-number line keeps exactly one owner,
  which after this split is `DECISIONS.md`'s tail rather than the
  instructions' header.

- **Doc comments defer to the anchor.** The rule the last four commits have
  been applying, stated so it governs the next reader too: a site comment
  carries the *local* why — the decision made here, the alternative rejected
  here, the trap avoided here — and cites the D-number rather than restating
  its argument. The reasoning lives once, in the archive, where it is
  maintained.

  This is the second half of the split's payoff and the reason M14 is one
  milestone rather than two: moving the anchors out of the instructions and
  leaving the code restating them would relocate the duplication rather than
  remove it.

  **Two exemptions, argued rather than assumed.** A comment that states a rule
  about *the language* stays where it is and stays complete — D43′ and D44′
  both cost this project a month of green builds because a language claim read
  as expertise, and a citation is not a claim a compiler can check. And a
  comment recording a **rejected** local implementation stays: the anchor
  records why the decision went the way it did, not why this function does not
  use `hasSuffix` here.

- **The five review and audit documents get a disposition.**
  `AUDIT-2026-08-01.md`, `CODE-REVIEW-2026-08-01.md` and
  `CODE-REVIEW-2026-08-04.md` are 76 KB of findings that have all been applied
  and are all recorded in the instructions. They are history, not memory. The
  decision is whether they are archived, folded into `DECISIONS.md`'s
  provenance notes, or kept — and it is a decision rather than a sweep,
  because their value is that they show the *process* that found things, which
  is the one thing the instructions' summaries cannot preserve.

**Gate.** ⌘U green (nothing here touches behaviour, which is exactly why the
run matters — a doc-comment pass that changes code is a doc-comment pass that
went wrong). The counter-grep clean against both documents:
`comm -23` of `grep -rhoE "\bM[0-9]+" --include='*.swift'` over the sources
against the same grep over `PROJECT-INSTRUCTIONS.md`, `ROADMAP.md` and
`DECISIONS.md`. Every D-number cited in a source resolving to an anchor that
exists — which is a new grep and is the split's own falsifiable check, since
a citation into a document that lost the entry is precisely the failure this
milestone could introduce. And the ratio re-measured rather than assumed:
`grep -rh '^\s*///'` and its sibling, against the same denominator, so the
next revision inherits a number with a method attached rather than a number.

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