# DGT Studio Pro — Roadmap

*Created 29 July 2026, against clean `ab33bdf`. Milestone slices with gates:
each milestone is a small coherent unit with a written definition of done; no
dates, sequence only. Updates to this file arrive as a complete `.md`, same as
the instructions. When a milestone lands, it moves to the Landed section at the
bottom with its gate evidence — the roadmap is also the record of what shipped.*

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

---

## M6 — Live-mirror piece animation

**Goal: the `PieceTracker` payoff — pieces glide on the mirror, keyed on the
stable `PieceID` that has been threaded, unread, into `SquareView` since the
tracker landed.**

Decision inside: mechanism — `matchedGeometryEffect` across squares vs an
animated overlay layer above the grid (the board renders squares, not
pieces-with-positions today, and the overlay approach avoids restructuring
the 64-square grid). Constraints from the invariants: the mirror renders the
*physical* board — animation is presentation between settles, never
speculation; ghosts and recovery attention/target overlays must not animate;
castling animates two pieces, en-passant animates a capture from the odd
square, promotion morphs identity-preserving (the tracker already reuses the
pawn's ID — by design, this is where that pays off).

Work: the mechanism decision + implementation; `SquareView.pieceID` finally
read (or retired in favour of the overlay's own keying — either way the
"intended consumer" comment resolves); previews for the four move shapes;
manual checks on the real board at real settle cadence.

**Gate.** e4, O-O, exd5 (en passant), and a promotion all animate correctly
on the mirror; recovery and ghost overlays are visually unaffected; no
hitching at settle cadence (eyeball now, Instruments in M7); the `pieceID`
story is resolved in code and doc.

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
- **Warning triage**: count (last known 295), bucket, burn what's cheap,
  waive what's deliberate — each waiver written. (`@diagnose` is the 6.4
  tool for the residue; the triage itself doesn't wait for it.)
- **swift-format, one-time run** (legal since M1's gate passed):
  pre-mark the aligned tables with `// swift-format-ignore`, run repo-wide
  as a mechanical-only commit, adopt `swift format lint --strict` as a
  habit.
- **Language-mode 6 evaluation** (D27′'s recorded fact): flip
  `SWIFT_VERSION` to 6 on a branch, collect the diagnostics, and decide —
  the codebase is written mode-6-shaped, so the gap is likely small, but it
  is a decision with a diff, not an assumption. Re-run the `RosterSummary`
  `@MainActor`-init deletion experiment in the same pass.
- **Xcode 27 GM re-read** (when it ships, ~September): re-read D27′, promote
  or strike each forward note on evidence, run the toolchain-move manual
  checks (Liquid Glass screenshot pass, full UITest suite).

**Gate.** Measurements written into the instructions; warning count and
buckets recorded; format landed alone; a mode-6 decision recorded with its
evidence; D27′ re-read logged when GM actually arrives.

---

## M8 — Inspector chrome, second pass

*(Added 29 July 2026 at Bera's request, mid-M1. Two quality-of-life
features on the D26′ chrome family. No dependency on the rest — ride on
appetite any time.)*

**Goal: the inspectors' sections earn richer furniture — a zoomable
evaluation graph and collapsible sections everywhere — without breaking the
D26′ contract that any divergence between inspectors is a compile-visible
choice.**

1. **Evaluation-graph magnifier.** A magnifying-glass button in the
   evaluation graph's section header — the `InspectorEditButtonView` slot
   pattern (one `LocalizedStringKey` label feeding `.help` and
   `.accessibilityLabel`, identifier required, registered in
   `AccessibilityID`) — opening an enlarged reading of the analysis graph.
   Decisions inside: what it opens (popover anchored to the header vs a
   sheet — a popover keeps the inspector context visible and matches
   "glance bigger, dismiss fast"); whether the enlarged graph gains hover
   read-outs (ply + eval under the cursor) that the small one can't afford;
   and whether the Board-review and Library inspectors share one enlarged
   view — they should: one view, two presenters, the D18′ Edit Info
   precedent. *(Recorded from Bera's 29 July ask; if the intent was zoom
   controls on the graph itself rather than a header-launched enlarged
   view, edit this entry before building.)*
2. **Collapsible sections across all inspectors.** Every
   `InspectorSectionHeader` grows a show/hide chevron — generalizing the
   Library inspector's bespoke PGN-section disclosure, whose own doc
   reserved the glyph "to keep consistent if a second collapsible section
   ever wants the same control". That section migrates to the shared
   mechanism in the same pass: one collapse control in the app, not two.
   Decisions inside: where collapsed state lives (per-tab `TabState`, the
   inspector-visibility precedent, vs persisted `@AppStorage` per section —
   persistence matches the view-mode keys but mints a lot of `StorageKeys`;
   decide and record); whether D26′'s "empty state renders outside the
   `List`" contract needs a collapsed-state sibling rule; and the animation
   (the PGN section's `.snappy(duration: 0.2)` is the precedent).

**Constraints from standing contracts:** sections default **open** — the
UITest suite pins inspector-profile presence immediately after selection,
so a collapsed-by-default section is a UITest change in the same commit
(the accessibility-contract rule). *The M1-era "one deliberate exception"
clause is gone: the PGN section's collapsed default was reversed on 30 July,
so every section in the app now defaults open and the shared mechanism
inherits that uniformly.* New header buttons take required identifiers
through `AccessibilityID` — the D26′ no-default lesson. The header's actions
slot now has a two-control precedent in **two** places (the Library's PGN
header, and M5's rename-pencil-plus-menu), so a third control is a layout
question already answered.

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

**Consequence now in force:** the one-time swift-format run is legal
(still scheduled M7).
