# Waste audit — 9 August 2026

> **Applied the same day** (the ranked-fixes tier, recorded D74′–D78′ in
> DECISIONS.md, tests riding each change, diagrams updated):
> **A1+A3 → D74′** (book-skip + per-ply depth, incremental re-analysis, the
> plan pure and suited), **B1 → D75′** (the converged stamp), **B5 → D76′**
> (scoped collection at the editing doors), **C3 → D77′** (the swing column),
> **B2+B3 → D78′** (narrowing + sort memoized, key-completeness suite).
> Still open by choice: **A2** (keep-warm — decide with usage data), **A4**
> (IOKit notifications — parked), **A5** (import cancellation — open item),
> **C1/C2/C4/C5** (product surfaces, each needing its own design pass),
> **C6/M7** (the Instruments run).

Read off the five activity diagrams, verified against the sources at `5f82de7`
plus the comment-only working tree. Scope: where the app spends time, CPU or
opportunity it does not have to. Every item cites the diagram node that shows it.

Two standing caveats govern everything below. **Personal scale caps most of
this** — one person, one Mac, libraries in the hundreds — so "waste" here means
waste at that scale, not at an imagined one. And **M7's Instruments pass has
still never run**, so every CPU item is an argument, not a number; the census
keeps growing while the measurement that would rank it stays untaken. That gap
is itself the first finding.

Items are tagged: **[recorded]** — already an accepted cost in DECISIONS.md or
the known-costs census, listed so the ranking is complete; **[new]** — surfaced
by this pass.

---

## A. Time — waits a person actually feels

**A1. Every ply of every game is searched at full depth, book moves included.**
[new — the largest avoidable wall-clock cost in the app]
`02 AN0–AN2`: the driver walks `pgn.moves` from ply 0 at the configured depth
(verified — `GameAnalysisDriver` line 158, no skip). A depth-18 search of ply 3
of a Ruy Lopez is spending seconds evaluating theory, per game, across a batch.
The irony: `02 IMP7` shows the app *already computes* the book prefix —
`ECOClassifier` longest-prefix-matches the opening at classification time — and
then throws the match length away (only the name is stored; no `ecoDepth`
column exists, verified). Storing the matched ply count would let the driver
start at book exit, or shallow-pass the prefix. On a 40-ply game with 12 book
plies that is ~30% of the batch, for free, with honest nil/em-dash coverage on
the skipped plies (`D73′`'s window already renders exactly that). Cost: one
stored `Int?`, one driver guard.

**A2. Every batch pays a cold engine handshake.** [recorded — decision 4]
`02 SLEEP` note: the engine is released at drain so nothing idles in Activity
Monitor; the next batch pays launch + UCI handshake + hash allocation (the
zeroing of a 512 MB table is the slow half — the test suite budgets 60 s for it
under load). The trade was priced for *batches*; the pattern it taxes hardest is
the other one — analyzing single games one at a time, where every game is its
own batch of one and pays its own handshake. If that pattern is common, a
keep-warm linger (release after N idle seconds instead of at drain) buys most of
the win without a resident subprocess. Contingent on usage; measure first.

**A3. Re-analysis always starts from zero.** [new opportunity]
`02 AN2`: re-analyzing resets `evaluations` to all-nil and re-searches every
ply — even at the same depth, even when only the tail was unsearched (a skipped
batch, a mid-game cancel). Blocked structurally: `Evaluation` stores
`centipawns(Int)` / `mate(Int)` and **no depth** (verified), so "already scored
at ≥ target depth" is unknowable. One `Int?` of depth per ply unlocks
incremental deepen, honest "analyzed at depth N" coverage, and turns A1's skip
into a refinement rather than a hole. Same schema touch as A1 — the two land
together or not at all.

**A4. Replug waits on a 3-second poll.** [recorded — v1 simplification]
`01 LOSS`: the reconnect loop sleeps `reconnectRetryInterval = 3 s` per lap and
re-enumerates IOKit each lap for the whole outage. IOKit arrival notifications
(wake on the device appearing, zero polling) are parked in the roadmap. Cost
today: up to 3 s of avoidable dead time per replug, plus one enumeration per
lap. Small, and the recorded parking is fine — listed because it is the only
place in the live loop where the app waits on a timer it could replace with an
event.

**A5. A wrong import cannot be stopped.** [recorded open item]
`02 IMPORT`: batches are uncancellable — ⎋ keeps the sheet up and the footer
disables until done, deliberately, but a mis-dropped folder of hundreds of files
runs to completion. The open item ("implement cancellation or relabel") has been
carried unscheduled since before M5.

---

## B. Resources — work that runs more often than its inputs change

**B1. Two full-table scans on every collection appearance, forever.**
[recorded shape; the ranking is new — this is the most-run redundant work in
the app]
`02 WARM` / `03 P1`: `backfillPlayerLinks` and `backfillPlayerTagNames` run on
**every** Library and Players appearance (both destinations, verified — four
call sites), and both are fetch-all-and-scan by necessity (a nil link on a `"?"`
row is *correct*, so "needs healing" isn't a predicate). The healing they exist
for converged months ago; the converged case still materializes every game and
every player per visit. `backfillClassifications` got the fix (predicated,
converged case fetches zero — `02 WARM` says so); the other two cannot be
predicated but *can* be gated: a one-time "converged" stamp after a clean pass
(zero heals), cleared by nothing — imports link at the door, so no door can
re-create the work the backfills exist for except a future player deletion,
which could clear the stamp itself. One defaults bool ends the app's largest
recurring scan.

**B2. The Library sorts every render, and the ECO comparator allocates per
comparison.** [recorded, censused at the column]
`02 N4/FG`: `filteredGames` ends in an unconditional `sorted(using:)` per body
pass; sorted by ECO, the comparator goes through `opening`, which rehydrates an
`ECOOpening` per comparison per render. D70′ memoized the *fold* and stopped
per-ply re-renders, so the remaining triggers are selection, keystrokes and
queue-counter ticks — but each of those now pays an O(n log n) with allocation
inside the comparator. The fix shape already exists in the codebase: the same
`CollectionFoldCache` keyed on (narrowed ids, sortOrder) would make the sort
once-per-change too. Post-Instruments.

**B3. Smart-tag filtering is a per-game rule fold per render.** [recorded]
`02 N1`: TagRule matching is an in-memory fold (load-bearing — a stored Codable
rule array cannot be a `#Predicate`), so an active tag re-evaluates every game's
rules on every render pass of the destination. Same memoization shape as B2 if
Instruments ever names it.

**B4. Mirror identity runs move generation at event rate, not settle rate.**
[recorded as a unit cost; the *rate multiplier* is the new observation]
`01 MIRROR` + `SP2`: during a move gesture every field update publishes, every
publish re-renders the mirror, and the resolver's proven-identity arm runs
`DGTReconstructor.reconstruct` — a diff plus one `legalMoves()` pass — per
render while the board diverges. The session then runs the *same*
reconstruction again at settle. Bounded (2–4 updates per move, ~30-move
generation each) and invisible at play cadence; named because it is the one
place move generation runs per event rather than per settle, and any future
fast-replay surface would multiply it.

**B5. A Get Info field commit fans out to a global orphan scan.** [recorded
mechanism; scoping is a new micro-opportunity]
`04 GDV4` → `03 COLLECT`: each Return on a Details field is `applyEdit` —
re-resolve both seats, MD5 the whole game — plus `collectOrphanedPlayers`,
which fetches **every** player and faults relationships to find the one row the
re-spelling may have stranded. The edit *knows* which players it displaced; a
scoped check of those two rows would do the same job at O(2). D60′ chose the
global spelling for one-implementation simplicity — defensible, and the scoped
version keeps that if it lives inside the same door.

**B6. Small, deliberate, fine.** [recorded — listed to close the census]
Draft JSON write per ply (`01 SD` — Decision #2, the crash-safety contract);
ECO table re-parse per launch on first Library visit (warmed off-actor,
unmeasured); PGN re-serialization per render while the inspector's PGN section
is expanded (collapse-gated) and in the columns detail (selected game only);
two 64-square recovery diffs per render (`01 RV3`); the D49′ extra dump (it
*saves* a false recovery, the opposite of waste).

---

## C. Opportunities — machinery already built and sitting idle

**C1. The field-desync replay is suite-only.** `DGTSessionRecording.
reconstructions(from:quiescence:)` deterministically replays a recorded board
stream through the real reconstructor — the exact tool for the 20-July class of
field bug — and its only consumer is the test target. Its own doc names the
in-app "replay this log" view as the consumer that would move it off the
test-only list. The debugging loop it would replace is currently: export from
the Diagnostics menu, read a text timeline by hand.

**C2. Click-to-move is one value away.** `BoardView.selectedSquare`, the
`.selected` highlight and its tint are threaded and permanently defaulted
(`04`'s pre-wiring notes; drawn as unreachable in the SquareView preview). A
position-setup or click-to-move surface turns all three on by passing one
value. No action until such a surface is *decided* — but it should be decided
knowing the machinery is paid for.

**C3. Blunder detection is a pure fold over data the app already stores.**
Per-ply `whiteWinProbability` exists for every analyzed game (`04 DATA`,
`GRAPH`); the delta between consecutive plies is the standard blunder signal,
and `AnalysisDataRow` is already the row shape a "largest swings" section
would want. Zero engine cost, zero schema cost — the one analysis feature the
stored data supports that no surface asks of it.

**C4. Head-to-head is a subtitle and nothing else.** `PlayerStats.headToHead`
computes an oriented W–D–L for any pair (`03 SUB`) and renders only as the
two-selection toolbar line. The same fold could give the player profile or Get
Info a rivalry row against the most-played opponent at no model cost.

**C5. The queue evaporates on quit.** `02 AN3`: waiting ids live only in
memory. Evaluations already survive (D71′ saves at exits, and sudden
termination is disabled while the inhibitor holds), so the loss is just the
line itself — re-queueing by hand after a restart. Persisting the waiting ids
is small; only worth it if overnight batches ever get interrupted in practice.

**C6. The meta-opportunity: run M7.** Items B1–B4 are one Instruments session
away from being either a fix with a number or a documented "leave it" with a
number. The census has ~15 entries and has only ever grown; the audit that
would close half of them is the one pass that keeps not happening.

---

## D. Looks like waste, is not — do not "fix"

- **Engine released at drain** — priced trade (nothing idles in Activity
  Monitor); A2 argues for a linger, not for keeping it resident.
- **The tautological star guard** at both archive doors — structural
  enforcement of Decision #3, drawn as a note in `01`, not a branch.
- **Two computations of RecoveryGuidance** (board overlays + sidebar
  checklist) — two consumers by decision, one spelling.
- **`gamesInDisplayOrder` re-derived per action** — correctness: an action
  fires long after the fold that painted the screen (`02 EX0`).
- **The all-nil evaluations reset before a pass** — preserves the
  empty-or-parallel invariant and the graph's animation baseline.
- **⌘A's painted-list rule and the Open threshold** — the threshold is the
  cheapest tab-explosion insurance the app has (`02 OP0`).
- **Perft deep's 468M nodes** — `.slow`-tagged, outside the default plan.
- **Per-field commit's repeated MD5s** (`04 GDV`) — the alternative
  (Save/Revert forms) was rejected for recorded UX reasons; B5's scoped
  collection is the only cheap trim.

---

## Ranked, by expected payoff per unit of work

1. **A1 + A3 together** — store the book-exit ply and per-ply depth; skip the
   prefix, deepen incrementally. Minutes off every real batch; the only item
   here that changes felt wall-clock by an integer factor.
2. **B1** — a converged stamp on the two link backfills. Ends the app's
   most-frequently-run redundant scan for one defaults bool.
3. **A2** — decide the keep-warm question with one week of honest usage data:
   if most analyses are batches of one, linger; if not, close it as priced.
4. **B2** (with **B3** riding along) — memoize the sorted output the way D70′
   memoized the fold. Wait for Instruments to confirm it matters.
5. **C3** — the swings surface: the highest product value per line of code in
   this list, because every input already exists.
6. **C6 / M7** — the measurement that converts the rest of this file from
   argument to arithmetic.
