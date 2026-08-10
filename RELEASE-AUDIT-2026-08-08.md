# DGT Studio Pro — Release Audit, 8 August 2026

**Occasion:** the first official build/export is next. This is the asked-for
file-per-file, folder-per-folder pass over the whole tree — flimsy hacks,
stability, clarity, sanity — plus the four requested changes, which shipped in
the same sitting (D71′, D72′, the shared batch counter, the gallery growth;
ROADMAP's 8 August entry is the delivery record, this document is the survey).

**Method.** `git status` first (clean at `e61ceb9`, 247 tracked sources = 247
on disk). Every app source read or head-read; the 99-file test target surveyed
by suite (1,114 `@Test`s). Smell greps over the whole tree: `try!`, ` as! `,
`fatalError`, force-unwrap suspects, TODO/FIXME/HACK, fire-and-forget `Task`,
`runModal`. The standing greps from PROJECT-INSTRUCTIONS re-run at the end of
the sitting.

**Verdict, up front.** This is not a codebase that hides hacks; it is a
codebase that files them. The grep for TODO/FIXME/HACK returns zero because
every deferred cost is instead a *sentence* — on the known-costs census, in a
waiver table, or at the site with a D-number. The audit therefore found very
few surprises and a handful of real items, all listed below; the largest
(the per-ply save) was the cause of the stutter you asked about and is fixed
in this sitting. Nothing found blocks a first export.

---

## The findings that matter, ranked

1. **Per-ply `modelContext.save()` in the analysis walk** — the stutter.
   D70′ memoized the folds but every save still invalidated every `@Query` in
   every open window, re-ran the Library's fetch + sort + table diff, once per
   ply at engine speed. **Fixed: D71′** (saves at exits only), with the engine
   subprocess additionally dropped to `.utility` QoS so a raised Threads
   setting stops competing with the render loop. These two together are the
   sitting's answer to "is there a bottleneck"; if hitching survives them, the
   next suspect (recorded, unfixed) is the queue window's per-scored-line
   `search` publish while that window is open — the remedy would be a
   time-based throttle on `GameAnalysisDriver.search`, and the manual check
   names it.
2. **Two spellings of the batch numerator** — toolbar "0/110" vs window
   "Analyzing 1 of 110". **Fixed:** `AnalysisQueue.batchPosition`, one
   arithmetic, both surfaces, three pins.
3. **The list column's per-row blob decode** — `AnalysisGlyph.state(of:
   [game], …)` per Analysis-column cell decoded `evaluations` per row per
   render; the one per-row decode D70′'s pass left standing. **Fixed** as part
   of D72′: all four modes now read `analyzedIDs`, built once per render off
   the memoized records.
4. **`LibraryGalleryView`'s filmstrip height comment lied** — said 260, code
   says 180. The 4 Aug story ("the strip grew to 260 to fit the card") was
   true of the 80 pt-glyph card; the View Options pass shrank the strip's card
   to the 60 pt default and the number moved back without its comment.
   **Fixed** (comment now carries the rule: strip fits card, never the
   reverse). Worth a glance in the running app that nothing clips — the check
   is on the 8 Aug manual list.
5. **Three doors still produce a nil `libraryIndex`** — paste-import, an
   unnumbered filename, and `PGNStore.archive` into an empty Library (its
   `flatMap` hands the first game no ordinal). Named at
   `LibraryGameCardView.displayIndex` as "meant to be unreachable"; the em
   dash renders correctly meanwhile. *Open, small, pre-export nice-to-have:*
   the archive-door arm is a one-line `?? 0`-shaped fix that deserves its own
   decision (what is the first game's number — 1?), so it was not slipped into
   this sitting.
6. **⌘⌫ / ⌘E / ⌘R liveness is still unmeasured** — the row menus' shortcuts
   are known only to *render* since the toolbar buttons went. The owed manual
   check stands; if they are dead, the remedy on record is a menu-bar
   `Commands` scene. This is the top pre-export functional unknown because
   delete-by-keyboard may currently not exist in the app.
7. **The Syzygy child-process sandbox question** — genuinely open and
   architectural: Apple documents child processes as inheriting only *static*
   sandbox rights, so the engine may see nothing at a PowerBox-granted path.
   The Settings Check button was built to answer exactly this; run it before
   the export and record which of its three readings you get. If it is the
   documented failure, the recorded options are disabling `ENABLE_APP_SANDBOX`
   (no App Store here) or copying tables into the container.
8. **Two launch warnings** (geometry cycling / focused-value) — narrowed 8 Aug
   to the two icons-grid geometry actions, with a decisive two-build
   experiment written down. Redundant work, not a correctness bug; fine to
   ship with, worth the two builds when convenient.

## First-export checklist

Nothing here is App Store machinery — one person, one Mac — but a first
archive is still a different beast from ⌘R:

- **Build the Release configuration once before trusting it.** The standing
  Debug/Release gap is recorded in the build-diagnostic lessons: every "zero
  diagnostics" claim to date is a Debug claim, and `#Preview` bodies compile
  in Release. Profile (⌘I) is the cheapest Release build.
- **The bundled Stockfish must be in the archived product** — it reaches the
  bundle by folder membership, and `defaultBinaryURL` failing is a per-item
  batch failure by design (controller decision 3). Launch the exported app and
  run one analysis.
- **Hardened runtime / signing:** the serial entitlement
  (`com.apple.security.device.serial`) is the operative grant; confirm the
  exported, signed app still connects to the board — an ad-hoc-signed debug
  build proving it means little for a Developer-ID export.
- **Syzygy check** (item 7 above) from the exported app, not the Xcode run —
  the sandbox inheritance question is about exactly this configuration.
- **⌘U green on the final tree** (owed for this sitting's changes — expected,
  never claimed), plus the 8 Aug manual list in PROJECT-INSTRUCTIONS.
- **Window restoration sanity:** quit with board + Library + queue window
  open, relaunch the exported app once. The queue window is
  `.defaultLaunchBehavior(.suppressed)` and must stay closed; the graph
  window floats; Get Info must not have become a restored orphan.
- Draft safety net: with a live game mid-flight, force-quit the exported app
  and relaunch — the Resume/Delete offer is the crash-safety feature a first
  real-use build most wants proven.

---

# Folder by folder, file by file

Vocabulary: **Clean** — nothing to say beyond what the file already says about
itself; **Note** — worth knowing, no action; **Finding** — acted on this
sitting or queued above.

## App/ (12)

- **DGTStudioProApp.swift** — Clean, and load-bearing: all wiring in `init()`
  exactly once, every scene's window-level/launch-behavior choice argued. The
  one `fatalError` in the tree lives here (ModelContainer creation) and is
  right: an app whose store cannot open has nothing to degrade to, and an
  alert-then-quit would be ceremony around the same outcome.
- **ContentView.swift** — Clean. Sidebar, tags CRUD through a value draft,
  stale-selection degradation to the full Library. The pointer-only `+`
  affordance is documented with its AX evidence and its menu-bar fallback.
- **StorageKeys.swift** — Clean; the namespace's own note that two dead keys
  are tolerated and a third needs a sweep is the right tripwire. Nothing new
  minted this sitting.
- **AppLog.swift / TestHost.swift** — Clean; policy has a pure twin, grammar
  written at the only shared point. The suppression's escape hatch is named in
  three places.
- **AccessibilityID.swift** — Clean by its own rules (153 entries, grep-owned
  count). No identifiers minted or retired this sitting: the badge is status,
  not a control.
- **SessionSidebarPanel.swift** — Clean; D15′'s surface, hudPhase ordering
  documented. (Head-read this sitting; unchanged since last full read.)
- **SettingsView.swift** — Note: the file carries several `?? true` twin-read
  defaults documented as twins in StorageKeys; the single-read-site shape
  (`SleepInhibitor`) is recorded there as where the others should eventually
  go. Not release-relevant.
- **SleepInhibitor.swift** — Clean; D66′'s two-gate predicate extracted pure,
  token handover constructs-before-releasing, preview suite uses a wiped
  scratch suite (the one non-preview force-unwrap in App/, of a suite name
  that cannot fail).
- **TabState.swift / PreviewFixtures.swift / FullScreenAuxiliary.swift** —
  Clean. FullScreenAuxiliary is the kind of five-line fix that usually ships
  as an unexplained modifier; here it carries its whole why. One small audit
  find: its `makeNSView`/`updateNSView` witnesses joined the dead-name scan's
  false positives on 7 Aug and the grep's expected-output note still said
  two names — updated this sitting (a check's false positives are part of
  the check). *(Postscript 10 Aug, D80′: "Clean" was the wrong verdict. The
  why was sound and the moment was not — the configurator wrote the behaviour
  after the window's Space was decided, so it never worked, and the audit read
  the well-argued comment as evidence the mechanism had been exercised. The
  scene-level role replaced it whole; the file and its suite are deleted.)*

## Engine/ (12)

- **GameAnalysisDriver.swift** — **Finding (fixed, D71′):** the per-ply save,
  item 1 above. The header had been corrected once already (per-emission →
  per-ply, 6 Aug); this is the same correction one level up, and the header
  now records the trajectory. Every exit persists before its message claims
  anything was kept; the done path refuses to land `.done` on a failed save
  (the E1 shape, kept at one strike).
- **StockfishEngine.swift** — **Finding (fixed):** subprocess QoS unset —
  inherited foreground priority, so a raised Threads setting fought the UI.
  Now `.utility`, with `.background` declined at the site (throttled
  overnight batches). Otherwise Clean and notably hardened: ordered stdout
  pipeline, split-codepoint-safe buffering, three-way handshake failure,
  stale-bestmove budget, teardown that strands no waiter.
- **AnalysisQueue.swift** — Clean; **grew `batchPosition`** this sitting (item
  2), the one spelling of the numerator, with the drained/active split
  documented and pinned.
- **AnalysisQueueController.swift** — Clean; the app-global reversal is one of
  the best-documented ownership changes in the tree. `runningID` vs
  `currentProgress` observation split is exactly why the badges could ship
  without per-ply re-renders.
- **AnalysisQueueStatusWindowView.swift** — Clean; now reads `batchPosition`.
  Note: while this window is open, the search panel re-renders per scored
  info line (~20–25/ply). Bounded and deliberate (`search`'s doc); it is the
  named next suspect if stutter survives D71′, and only with this window
  open.
- **BatchProgressEstimate.swift** — Clean; measurement vs projection spelled
  differently on purpose.
- **EngineConfiguration.swift / EngineProgress.swift / UCIProtocol.swift /
  Evaluation.swift** — Clean. UCI parse allocations are census'd; the
  `[%eval]` parser rejects `inf`/`nan` at the boundary (a real crash fixed at
  the right layer). `deliberatelyIgnoredKeywords` is the D63′ noise fix.
- **SyzygyLocation.swift / SyzygySettingsSection.swift** — Clean code, open
  *question* (item 7): the two-number diagnostic exists precisely because the
  sandbox answer is unmeasured. Run the Check button from the exported build.

## Features/Library/ (13)

- **LibraryDestination.swift** — At 1,605 lines the tree's largest file, and
  cohesive despite it — but it has now blown the type-checker budget twice
  (alerts split, `coreContent` split) and carries the destination, its
  toolbar, import, backfills, deletion flows and export routing. **Note for
  after the release:** an extraction pass (import pipeline and backfills are
  the natural seams) before it bites a third time. This sitting: grew
  `analyzedIDs` (one projection for every badge), the toolbar counter moved
  to `batchPosition`, the FoldKey doc re-tensed for D71′.
- **AnalysisGlyph.swift** — **Grown (D72′):** the projection overload,
  `AnalysisGlyphIcon` (extracted so the badge and the label share one palette
  arrangement), `AnalysisStatusBadge` (material chip, argued for dark mode),
  `statusLabel` vocabulary pinned to the chip's phrase. The suite grew with
  it, including the two-overloads-agree pin driven through `\.gameRecord`.
- **LibraryListView.swift** — **Finding (fixed, item 3):** the Analysis
  column's per-row decode; now projection-fed. Otherwise Clean — the column
  customization persistence-contract notes and the ten-column result-builder
  ceiling warning are exactly the traps a future editor needs.
- **LibraryColumnsView.swift** — **Changed (D72′):** trailing glyph per row,
  reversing the recorded uniform-icon argument (the reversal is argued at the
  site and in the anchor); detail button joins the projection. Note: the
  160-stated-twice pane/column floor is documented as deliberately not the
  twin-read-site pattern — correct, and a good example of why the doc
  standard pays.
- **LibraryIconsView.swift / LibraryGalleryView.swift /
  LibraryGameCardView.swift** — **Changed (D72′):** badge threading; the
  gallery's stale 260-comment fixed (item 4). The icons grid's box-not-State
  geometry story (four corrections, each a real layer) is the tree's best
  worked example of taming `onGeometryChange`.
- **GameActionsMenu.swift** — Clean; carries the honest "renders vs fires"
  note for its shortcuts (item 6).
- **LibraryFilter.swift / LibraryGamePreviewState.swift /
  LibraryGamePreviewView.swift / ImportStatusView.swift** — Clean. Import is
  main-actor with per-file yields, uncancellable by known open item —
  acceptable at personal scale; ⎋ is blocked mid-run for the right reason.
- **LibraryInspectorView.swift** — Clean; PGN section re-serialization is
  collapse-gated and census'd.

## Features/Players/ (15)

- **PlayersDestination.swift** — Clean; the memoized three-fold with
  content-only key is D70′'s worked example. This sitting threads `history`
  to the gallery. Note (census-shaped, not new): `selectedGames` filters and
  sorts per render while a single selection exists; per-game-save cadence
  now bounds how often that happens during batches.
- **PlayerCardView.swift** — **Grown:** `PlayerStatsGrid` five → eight facts
  (Uncertainty / First / Last), both hosts widened by construction; the
  em-dash-not-hidden-row choice argued at the site. `RankMedal`'s two
  fallbacks-differ-on-purpose doc remains a model of recording a would-be
  "bug" before it is reported.
- **PlayersGalleryView.swift** — **Grown:** the trend chart under the grid,
  selection's history threaded in, gated on non-empty with the reason the
  gallery's absence needs no sentence where the inspector's does.
- **PlayerRatingGraph.swift** — **Split:** `RatingTrendChart` extracted
  (presentation-agnostic content, the `EvaluationGraphContent` precedent) so
  inspector and gallery draw one line.
- **PlayersIconsView.swift / PlayersListView.swift /
  PlayersColumnsView.swift / PlayersInspectorView.swift /
  PlayerActionsMenu.swift** — Clean; the § Zero unresolved-identifier note
  survives at its site with its ruled-out causes inlined.
- **Glicko1.swift / PlayerStats.swift / PlayerRanking.swift / Player.swift /
  PlayerName.swift / PairingRound.swift** — Clean pure cores, suited to the
  edge. The `endedInMate` `hasSuffix`-vs-`contains` divergence remains the
  one *deliberately* open correctness wart, pinned by the test that should
  fail when it closes (`aSpecialMateCanOutnumberMates…`).

## Features/Board/ (21)

- **BoardDestination.swift** — Clean at head-read; the blessed id→model
  tombstone pattern, offer bindings' fork-not-suggestion contract, and the
  focused-value publishing are all as recorded. The launch-warning open item
  points here only through the *collection* grids now (refuted candidates
  struck 8 Aug).
- **BoardView.swift / SquareView.swift / BoardPieceLayer.swift /
  PieceIdentity.swift** — Clean; D47′'s occupancy-verbatim property is
  suite-pinned. `SquareView.selectedSquare` pre-wiring is a named dormant
  branch with a preview that renders it — the recorded "reads as live" trap,
  fine as filed.
- **EvaluationBar\*/EvaluationGraph\* (5 files)** — Clean; one projection
  (D33′) across bar, graph, window and queue panel is why the fourth consumer
  (the search panel) cost one line.
- **NewLiveGameSheet.swift / EditGameInfoSheet.swift** — Clean; the
  `"?"`↔`""` boundary conversions are documented at the type; the
  known-players menu fills-not-commits contract is stated on both sheets.
- **LiveGameHUDView.swift / LiveGameInspectorView.swift /
  BoardInspectorView.swift / MoveHistoryView.swift / RecoveryGuidance\* /
  GameNavigationCommands.swift / SquareHighlight.swift / BoardStyle.swift** —
  Clean; the HUD's five-exhaustive-switches duplication is a recorded
  keep-apart.

## DGT/ (17)

Clean throughout at this audit's depth, and the folder most worth *not*
touching before a first export: transport is waived where it is hardware,
pure where it is decidable (policy, diff, reconstructor, framer, decoder all
suited), and the failure paths (resync one-shot D49′, reconnect loop,
recorder ring) are the app's most battle-tested code. Two notes: 
**DGTSerialPort.isOpen** stays the app's one consumerless symbol, kept by
recorded disposition (M12.3); **DGTSessionLog/Recording** `runModal` export
panels are the AppKit-modal family, waived with their kin.

## Chess/ (17)

Clean — the purity invariant holds (one Foundation import in the SAN layer),
movegen is perft-pinned with deep tests, and the two Codable-on-model parsers
sit on the right sides of the trust boundary (`[%eval]` hostile, ECO table
trusted). Notes: **Move.swift**'s masked force-unwraps are safe against every
value the packer can produce and would trap on a corrupted raw value — an
acceptable internal invariant, but the one place in the core where a comment
saying exactly that would close the audit question a reader will ask;
**SpecialCheckmate.swift** (533 lines) carries D65′'s precedence array and the
Boden distribution story — the file to re-read before ever touching a
recogniser. The FEN/GameState collapse stays the known rename-scale item.

## PGN/ (9)

- **PGNStore.swift** — Clean at 1,119 lines: every door single, every save
  owned, orphan collection at the four sites with the prospective-cascade
  exception documented. The archive door's nil-ordinal arm is item 5.
- **PGNParser.swift / PGNSerializer.swift / PGN+Export.swift /
  PGNExporter.swift** — Clean; byte-pinned round trip committed. Export
  filename numbering vs DGT's own convention stays unconfirmed (open item).
- **PGN.swift / PGN+GameRecord.swift / GameRecord.swift /
  RosterSummary.swift** — Clean; `hasScoredPly`'s D67′ story is written on
  the property, and the projection seam is why D72′'s badges could be fed
  without new model reads.

## Game/ (8), Features/GetInfo/ (4), Features/SmartTags/ (4)

- **Game/** — Clean; draft sidecar atomic+versioned, `LiveGame` append-only,
  `OpenGamesRegistry.markDirty` dormant-by-design with its named future
  consumer.
- **GetInfoWindow.swift** — Clean but **the second-largest view file (1,243)**
  carrying three subjects × three tabs; same post-release note as
  LibraryDestination — a split by subject is the natural seam when it next
  grows. The rest of the folder (request enum, menu item, movetext editor)
  is tight and its traps (openWindow routing, score-sheet tokenizing) are
  anchored.
- **SmartTags/** — Clean; the defaulting decoder (D36′) plus the
  checkmateType raw-value freeze are the persistence contracts that make the
  folder safe to extend.

## Shared/ (15)

- **Collection/** — Clean; `CollectionFoldKey`'s mirror rule with its
  three-missing-fields confession is the best cache documentation in the
  tree; the trigger list re-tensed this sitting for D71′. `CollectionSort`'s
  failable round trip (unknown column leaves the sort alone) is the quiet
  kind of correctness that survives future columns.
- **Inspector/** — Clean; `CollapsibleSection`'s one-argument-twice design,
  the `EmptyView`-gap open item still awaiting its canvas glance.
- **ViewOptions/CollectionViewOptionsWindow.swift** — Clean; the
  panel-as-pure-reader arrangement (the latch lives in the destinations)
  records why the obvious `@FocusedValue`-in-panel version cannot work.

## DGTStudioProTests/ (99 files, 1,114 tests)

Surveyed by suite rather than line-read. Shape: every pure core suited
nonisolated, store logic through in-memory containers, byte-pinned resources
committed (`PGN/PGNs/`, ECO volumes app-side), image attachments on the two
field-desync fixtures, and the change-detector pins (`Field` raw values, sort
raw values, registry precedents) that make renames loud. This sitting adds:
three `batchPosition` pins (AnalysisQueueTests), the projection-overload
agreement + running-beats-flag + status-label pins (AnalysisGlyphStateTests).
No suite was weakened; nothing waived gained code without either a pin or a
named manual check.

---

## What was deliberately not done

- No extraction of the two giant view files before a release — churn risk
  exceeds reward this week; both are noted above as the first post-release
  clarity items.
- No fix for the archive-door nil ordinal (item 5) — one line of code, but
  the *number* it should assign is a decision (D-worthy) about a second
  identity, not a patch.
- No throttle on the queue window's per-line search panel — it is the named
  next suspect only if D71′ leaves hitching behind, and adding it now would
  blur the measurement the manual check is about to take.
- Nothing touched in Chess/ or DGT/ — perft is witness and veto, the board
  code is field-proven, and a release week is the wrong week to disturb
  either.
