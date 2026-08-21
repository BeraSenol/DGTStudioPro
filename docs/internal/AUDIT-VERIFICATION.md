# Audit verification — 21 August 2026

An adversarial re-check of the four 21 Aug audits (UI performance, naming, orthogonality, test
coverage). The brief was **disprove**, not confirm: every claim was re-derived from source rather
than re-read, and the dependency graph and the view/logic line split were recomputed with
independent scripts rather than trusted.

**Result: the four documents are mostly sound, and two of their headline findings do not survive.**
Perf finding #2 ("the live mirror runs chess twice per render") is false — the two call sites are
mutually exclusive by their own guards, and in the steady state neither fires. Orthogonality §1/§6
("four mechanical moves take 27 cycles to 9") is false — `TabState` is not a leaf, `Destination` is
not a file, and the moves relabel cycles rather than dissolving them.

---

## 0. Method problem that affects all four documents

**The audits describe at least two different snapshots of the tree, and two of them mix snapshots
internally.**

The working tree is dirty: 16 modified files, `App/SessionSidebarPanel.swift` deleted,
`App/SessionWindow.swift` untracked (the D84′ work). HEAD is `c8eea2d`.

| Document | Snapshot its line numbers match |
|---|---|
| UI performance | **Mixed** — `LibraryDestination` cites match HEAD; `BoardDestination` cites match the working tree |
| Naming | Working tree (cites `SessionWindow.swift:68`/`:89`, which exist only there) |
| Orthogonality | **Mixed** — `LibraryDestination` 858 loc and `PlayersDestination` 462 are HEAD; `BoardDestination` 671, `DGTStudioProApp` 331, `ContentView` 275, `SettingsView` 456 are working-tree only |
| Test coverage | HEAD (test plan, tags, and structure are unchanged in the working tree) |

Verified offsets:

```
                        HEAD    working tree    audit says
LibraryDestination.swift  858        889           858  (orthogonality)
BoardDestination.swift    668        671           671  (orthogonality)
DGTStudioProApp.swift     305        331           331  (orthogonality)
PlayersDestination.swift  462        471           462  (orthogonality)
```

The most likely story is that the tree was being edited while the scans ran. The practical
consequence: **line numbers in all four documents should be treated as approximate**, and the perf
audit's `BoardDestination` findings describe code that already changed (the session panel is
`SessionWindow` now, not the `.overlay` the file's own comments describe).

**Header counts also don't reproduce.** "164 Swift files, 28,402 LOC" appears in three documents.
Actual: HEAD 28,353, working tree 28,442 — neither is 28,402. File split is 164 app / 108 test, not
the naming scan's "163 app, 109 test" (its total of 272 is right). `AccessibilityID` holds **145**
literal values, not the naming scan's 146 — the orthogonality audit's 145 is the correct one, so
the two documents disagree with each other.

---

## 1. Findings that are wrong

### 1.1 Perf #2 — "The live mirror runs chess twice per render" — **false**

The headline, the tier-1 table entry, and the cost arithmetic all rest on `legalMoves()` running
twice per `mirrorBoard` render, from `DGTReconstructor.reconstruct` and `MoveHints.destinations`.
**It cannot run twice. The two sites are mutually exclusive.**

`DGTReconstructor.reconstruct` returns before generating moves:

```swift
if before == physical { return .noChange }          // settled board: no generation
let diff = DGTBoardDiff(from: before, to: physical)
if diff.placed.isEmpty { return .inProgress }       // pieces lifted, none placed: no generation
…
let legal = lastLegal.legalMoves()                  // only reached when placed is NON-empty
```

`MoveHints.destinations` returns before generating moves *unless* `placed` is empty:

```swift
guard diff.placed.isEmpty,
      diff.vacated.count == 1,
      let origin = diff.vacated.keys.first
else { return [] }
return Set(game.legalMoves().filter { $0.from == origin }.map(\.to))
```

Both diff the same pair of positions (`session.liveGame?.currentState.position` vs
`connection.physicalBoard`, passed identically at the two call sites), so `diff.placed.isEmpty` has
one value per render. The reconstructor generates only when it is **false**; MoveHints generates
only when it is **true**.

Per-render generation count, by board state:

| Board state | reconstruct | MoveHints | total |
|---|---|---|---|
| Settled, matches the game (the resting state) | 0 (`.noChange`) | 0 | **0** |
| One piece lifted, none placed | 0 (`.inProgress`) | 1 | **1** |
| Two-plus pieces lifted | 0 (`.inProgress`) | 0 | **0** |
| A piece placed (the settle that commits a move) | 1 | 0 | **1** |

The comment at the hoist site already says this — *"Hoisted above move generation — this settle
fires most often and needs no legal-move walk"* — so the discipline the audit recommends adding
("compute `legalMoves()` once per settle and hand the result down") is the discipline that is
already there, one level lower than the audit looked.

The finding's cost model — "~35 allocations + 35 ray scans per call, ×2 calls, per render… runs on
every observable change during live play" — is therefore wrong in both the multiplier (×2 → ×1) and
the base rate (every render → only renders where the physical board disagrees with the game by
exactly the right shape).

**What is actually redundant, and the audit missed it:** `DGTBoardDiff(from:to:)` *is* built twice
per render over identical inputs — once inside `reconstruct`, once inside `MoveHints.destinations`
— and each build allocates two `Dictionary`s over a 64-square loop. That is the real "two call
sites need the same answer" shape here, and it is much cheaper than the one the audit describes.

### 1.2 Perf #2's second half — "two `RecoveryGuidance` folds per live-board render" — **overstated by roughly the whole of it**

`RecoveryGuidance.current` short-circuits before any diff:

```swift
guard session.needsRecovery, let game = session.liveGame else { return nil }
```

During normal play `needsRecovery` is false, so both reads cost a Bool check. The double fold
happens **only while the board is desynced** — an exceptional state, not "per live-board render" as
the tier-1 table says.

The audit's cost ladder also lists `:583 64-square loop` as a cost paid alongside the second
`recoveryGuidance` read. It never is: `liftedGhostPieces` guards `recoveryGuidance == nil`, so when
guidance is non-nil the function returns `[:]` at the guard and the loop does not run; when guidance
is nil, the guidance fold is the cheap one. The two costs are mutually exclusive.

The hoist is still worth doing — it is free and correct — but it is a tidiness fix, not the
frequency fix the document frames it as.

### 1.3 Orthogonality §1 and §6 — "27 cycles → 9 in four mechanical moves" — **false**

Two load-bearing premises fail.

**`TabState` is not a leaf.** §1 states that all five misfiled types "are constants and a logging
façade — pure leaves with no dependencies of their own." `App/TabState.swift` in full:

```swift
var boardPGN: PGN?                          // → PGN module
var boardGame: Game?                        // → Game module
var boardLoadError: String?
var boardPerspective: PieceColor = .white   // → Chess module
var boardInspectorPresented: Bool = true
var manualNewGameRequested: Bool = false
var libraryInspectorPresented: Bool = true
var playersInspectorPresented: Bool = true
```

Three cross-module dependencies, one of them a SwiftData `@Model`. Moving it into a `Core/` layer
"below everything" would put the persistence model *underneath* the persistence layer — a worse
violation than the one being fixed, and it carries the `App ↔ PGN`, `App ↔ Game` and `App ↔ Chess`
cycles into `Core` rather than dissolving them.

**`Destination` is not a file.** §1 says "move those five files." `Destination` is declared inside
`App/ContentView.swift` — as the same document's §17 correctly notes. Four of the five are files;
one is a nested declaration in the composition root's main view. The move as written cannot be
executed for it.

**The simulation.** I rebuilt the dependency graph independently (comments stripped, string literals
stripped, `#Preview` blocks stripped, references resolved only against unambiguously-owned top-level
declarations) and replayed the four moves, granting the audit its best case — `Destination`
extracted into its own dependency-free file, every move clean:

```
baseline                                              25 mutual pairs
1. AccessibilityID/AppLog/StorageKeys/TabState/
   Destination → Core/                                22   (audit claims 16)
2. + Player/PlayerName/Glicko1/PlayerStats/
     RankedPlayer → Domain/                           25   (audit claims 13)
3. + BoardCue/SessionPhase → Game/                    24   (audit claims 10)
4. + EvaluationBarReading, AnalyzingGear              23   (audit claims 9/8)
5. + GameResult, Evaluation (§4)                      21
```

Move 2 makes it **worse**, not better: `Domain/` immediately cycles with `PGN`, `Shared`,
`Features/Players` and `Features/GetInfo`, because `Player` is a `@Model` in a bidirectional
relationship with `PGN` and the fold machinery in `Shared/` reads `Glicko1` and `RankedPlayer` while
those types read back. The audit's §2 asserts three cycles dissolved; the graph says the seam is not
where the folder boundary would be drawn.

My baseline of 25 vs the audit's 27 is within methodology noise (nested-type name collisions like
`State`, `Status`, `Key`, `Value` produce two or three phantom pairs if not filtered — the audit
does not describe its filter). **The baseline number is credible; the *after* numbers are not.**

The real conclusion the same evidence supports: the cycles are not caused by file placement. They
are caused by `TabState` holding models, by `Player` being a `@Model` co-owned with `PGN`, and by
`Shared/Collection/` hard-coding both concrete collections — all three of which the audit identifies
correctly elsewhere (§2, §5) and then prices as free file moves.

### 1.4 Perf #1 — the fix arithmetic is wrong, and three sub-claims don't hold

The finding itself is real: `BoardView` does declare five `.blendMode(.overlay)` image layers, and
none of it is cached. But:

- **"`.drawingGroup()` on `squareGrid`'s grain overlay alone flattens four of the five passes"** —
  it cannot. Four of the five live in `boardFrame(size:frameThickness:)`, a sibling subtree in the
  root `ZStack`. A `drawingGroup` on `squareGrid`'s overlay reaches none of them.
- **`.drawingGroup()` changes the rendering here, it doesn't preserve it.** `.blendMode(.overlay)`
  blends against what is *beneath* it. Rasterising the overlay into its own offscreen group isolates
  it from the squares and piece layer below, so the grain would composite against transparency
  instead of against the board. The suggested fix is not behaviour-preserving; the `Equatable`
  subview keyed on `(size, style)` — the audit's own alternative — is.
- **"four `size × size` ZStacks — the GPU pays for the full rect"** — the *ZStack* is `size × size`,
  but the blended image inside it is framed `size × frameThickness` (`frameThickness = totalSide/10`),
  i.e. already about a tenth of the area the finding charges it with.
- **All five layers are conditional on `style != .leather`.** In the leather style there are zero
  grain composites. The finding presents the cost as unconditional.
- **"384×384 @3x … stretched across a board that can be 900 pt wide"** — the asset dimensions are
  right (`WoodGrainFine@3x.png`, 384×384, 357,478 bytes), but no Mac display has a 3× backing scale.
  This is a macOS 26.2 target; the resource that actually loads is the 256×256 @2x.

### 1.5 Perf tier 3 — "Six material surfaces" — miscounted and mis-argued

The bullet says six, lists five, and misses one. Actual material sites at HEAD:

```
SessionSidebarPanel.swift:64    .regularMaterial     (deleted in the working tree)
SessionSidebarPanel.swift:126   .regularMaterial     (deleted in the working tree)
AnalysisQueueStatusWindowView.swift:276  .bar        ← not listed at all
RecoveryGuidanceView.swift:51   .regularMaterial     ✓
MoveHistoryView.swift:47        .thinMaterial        ✓
LiveGameHUDView.swift:110       .regularMaterial     (audit says :113)
FilmstripGalleryView.swift:139  .thinMaterial        ✓
```

And the argument attached to it — *"`MoveHistoryView`'s and `FilmstripGalleryView`'s sit behind
fully opaque content, so they're paying for a blur nobody can see"* — is false at both sites. The
move rows carry `.padding(.vertical, 4)` inside a `LazyVStack(spacing: 0)` whose rows are inset
rounded rects; the filmstrip carries `.padding(.horizontal, 16)`, `.padding(.vertical, 16)` and
inter-card spacing. The material is visible in the gutters at both.

### 1.6 Naming #3 — "three renderings" is two, and the tally is inverted

`RecordChart.swift:190` is not a rating placeholder:

```swift
/// Rounded to whole percent, matching the stats grid's Win Rate.
private func share(_ count: Int) -> String {
    guard decided > 0 else { return "—" }
    …
}
```

It is the em-dash for *a percentage share when no game has been decided* — different property,
different type, different guard. The scan half-admits this ("its own no-data case") while still
counting it in the finding's headline and severity.

The scan also omits a fourth site that *is* a rating: `PlayersListView.swift:88` uses
`RosterSummary.displayUnknown`. With it, the real split is **2 sites on `displayUnknown`
(`PlayerCardView:88`, `PlayersListView:88`) against 1 on `"Unrated"` (`PlayersInspectorView:79`)** —
which makes `"Unrated"` the outlier rather than one half of a symmetric disagreement, and points at
a different canon than the finding implies.

### 1.7 Naming #8 — "three spellings" is one deviation from an externally-mandated name

`Syzygy50MoveRule` is Stockfish's own UCI option name:

```swift
// Engine/EngineConfiguration.swift:117
lines.append("setoption name Syzygy50MoveRule value \(syzygy50MoveRule)")
```

So `StorageKeys.syzygy50MoveRule` and `EngineConfiguration.syzygy50MoveRule` are not drift — they
are the correct decision to mirror the protocol's spelling. The genuine finding is one identifier:
`AccessibilityID.settingsSyzygy50MoveToggle = "settings.syzygy.fiftyMoveToggle"`, where the constant
and its own value disagree. The toggle's prose (*"Respect the 50-move rule"*) is user copy in a
different register and is not a third spelling of an identifier.

### 1.8 Coverage #6 — the list of nine is incomplete, and the omissions matter more than the entries

By the audit's own criterion ("no test names it"), scanning all 164 app files against the whole test
target finds these **non-view** files unreferenced and absent from the list:

| File | Why it matters |
|---|---|
| `Engine/GameAnalysisDriver.swift` | 168 exe lines; the analysis pipeline the audit praises in §"what's already right" |
| `PGN/PGNExporter.swift` | sits in the module the audit rates 0% view / high coverage |
| `Engine/EngineProgress.swift` | |
| `Engine/SyzygyLocation.swift` | the two-key writer `SyzygySettingsSection` defers to |

Eight of the nine listed entries verified; `Shared/BindingPresent.swift` declares no top-level type,
so it falls outside a type-name scan either way. The audit's own §8 caveat (transitive coverage is
not observable this way) applies to the four additions as much as to the nine — but the list as
published understates its own finding.

---

## 2. Findings that survived unchanged

Re-derived from source and correct as written:

- **Perf #3 — `FilmstripGalleryView` is not lazy.** Line 128 is a plain `HStack`, backing both
  galleries, against `IconGridView`'s correct `LazyVGrid`. Exact.
- **Perf #4 — the fetch in a view body.** `prospectiveGameNumber` builds a `PGNStore` and runs a
  `FetchDescriptor` per render, read at the `recordingNumber:` argument. `.inspector`'s content
  builder is evaluated whether or not the inspector is open, so it runs with the panel closed too —
  the finding is if anything understated.
- **Perf #6 — the redundant re-sort.** `narrowed.sorted` holds exactly
  `result.map { $0.game }.sorted(using: sortOrder.wrappedValue)`, memoised, and `filteredGames`
  exposes it. `let games = filteredGames` is byte-identical. Real one-line win.
- **Perf #7, #8, #9, #10** — all confirmed at (or within three lines of) their cites.
- **Orthogonality §3 — session state nested in a view.** `Game/SessionPhase.swift` opens
  `extension LiveGameHUDView.Phase`. The best finding in any of the four documents: domain priority
  logic that cannot be compiled without SwiftUI in scope.
- **Orthogonality §4 — `GameResult` misfiled.** Declared `PGN/PGN.swift:4`, used on five lines of
  `Chess/MovetextEdit.swift`. Confirmed.
- **Orthogonality §7 — the "already orthogonal" list.** `@AppStorage`: exactly **26** sites, **zero**
  with a string literal. `Chess/`: 17 files, exactly one reference to `AppLog` (`ECOTable.swift`).
  Fan-in table correct — my counts are each +1 because I included the declaring file.
- **Coverage #1 — coverage is off.** No `codeCoverage` key in the test plan, the schemes, or the
  pbxproj. The target identifier in the audit's suggested JSON (`C5D920C02F732FE8003D0A74`) matches
  `targetForVariableExpansion` exactly.
- **Coverage #2 — the shape argument reproduces.** My independent classification: 54% of executable
  lines inside view types (audit: 56%), `Features/` 87%, `Chess`/`PGN`/`Game` 0%, `DGT` 15%,
  `Shared` 50%. Totals 15,272 vs their 15,307. The ceiling arithmetic lands at ~41% rather than 40%.
  Directionally identical, and the strongest single argument in the set.
- **Coverage #4 — `.slow` skipped, `PerftDeepTests` is the whole population.** Confirmed:
  `"skippedTags": {"tags": [".slow"]}`, one `@Suite(… .tags(.slow))` in the tree.
- **Coverage #4's supporting claim** — `EvaluationGraphView.monotoneSlopes` is referenced twice in
  the tree, both inside its own file. Untested, as stated.
- **Naming #7 — `customizationID` vs sort raw value.** `mate`/`checkmateType` and `player`/`name`
  are the only two disagreements; all 17 other columns agree on both sides. Exact, and the highest-
  value finding in that document.
- **Naming #11 — `StorageKeys`.** 45 keys, exactly 5 where name ≠ value: the three documented
  `legacyCollection*` and the two undocumented column-layout keys. Exact.
- **Naming #14 — mixed dashes.** Lines 46, 49 en dash; 60 ASCII. (There is a fourth at `:63`, also
  ASCII, consistent with `:60`.)
- **Naming "checked and clean"** — spot-verified and holding: `AppLog` declares exactly 17
  categories with no drift; the only `...` in the tree is the PGN parser's move-number comment.

---

## 3. Smaller corrections

- **Perf #9** misses a fourth site of its own class: `Features/Board/AnalysisDataWindow.swift:115`
  reads `pgn.evaluations` and builds rows from it in a view body.
- **Perf #6's supporting claim** that `PGN.opening` is expensive overstates it. It reads three
  stored SwiftData attributes and builds a struct — it does not run `ECOClassifier`. The audit is
  repeating the codebase's own "rehydrates per comparison" comment rather than pricing it.
- **Perf #8's code block is not verbatim** — it omits the `guard selectedKeys.count == 1` line that
  opens the property. (The prose acknowledges the gate; the quoted block does not.)
- **Naming #4** counts 16 lowercase-`library` strings; at least one (`PGNStore.swift:222`) is a
  `Logger.error` message, not user copy, and two more ("library numbers", "library index") are
  adjectival rather than the destination's proper noun. `SessionSidebarPanel.swift:170` is deleted
  in the working tree.
- **Naming #5** says `"Edit Details"` appears at 7 sites; 6 are control labels and the 7th is
  `#Preview("Edit Details")` at `NewLiveGameSheet.swift:470`.
- **Naming #12** undercounts itself: `ImportStatusView.swift:178` uses `doc.on.doc` for
  `.duplicate` — a *third* meaning for the stacked-documents glyph, which strengthens the finding.
- **Naming #13** cites `LiveGameHUDView:185` (actual `:182`) and two `SessionWindow.swift` lines
  that exist only in the uncommitted working tree.
- **Naming #23** — 719 plain `// MARK:` against 20 dashed, not 718/20.
- **Coverage §3** — `Engine` measures 23% view in my run against the audit's 32%, and `App` 52%
  against 67%. Neither changes the conclusion; both suggest their view/non-view classifier is more
  inclusive than mine.

---

## 4. What I could not check

- **Nothing was run.** No build, no test run, no Instruments trace, no `xccov`. The perf audit's
  own caveat stands and now covers this document too: findings #1 and #2 there were ranked by
  reasoning about SwiftUI internals, and #2 is the one that reasoning got wrong.
- **`.blendMode` cost** is an assertion about SwiftUI's renderer that no static read can settle. My
  correction to finding #1 is about *how many* layers, *when*, and *whether the proposed fix works*
  — not about whether blend modes are expensive.
- **Transitive test coverage.** Section 1.8 uses the audits' own "is the type named in a test"
  proxy. Several of the files it adds are certainly reached indirectly.
- **The working tree, mostly.** I verified against HEAD (`c8eea2d`) where the audits' line numbers
  pointed there, and spot-checked the working tree where they pointed here. A clean re-run of all
  four against one committed snapshot would be worth more than any single correction above.

---

## 5. Recommended reading order after this

1. **Drop perf finding #2** from the tier-1 table. If a redundancy fix is wanted in `mirrorBoard`,
   the target is the duplicate `DGTBoardDiff`, not `legalMoves()`.
2. **Rewrite orthogonality §6.** The table's *after* column is not reproducible. The three real
   structural findings in that document (§2 `Player` as a co-owned `@Model`, §3 `Phase` nested in a
   view, §5 `Shared/Collection` as a switchboard) survive on their own merits and don't need a
   cycle-count headline.
3. **Keep the ordering of the perf audit's "suggested order" 1–4**, all of which verified. Move
   `.drawingGroup()` off the list; replace it with the `Equatable` subview keyed on `(size, style)`,
   which is behaviour-preserving where `drawingGroup` is not.
4. **Take the coverage baseline first**, exactly as that document says. It is the only one of the
   four whose central claim is both reproducible and unblocked by anything.

---

---

## 6. What was then fixed (21 Aug 2026)

Applied after this verification, scoped to findings that survived it. **Nothing here has been
compiled or tested** — there is no Swift toolchain where the edits were made. Treat the whole set
as a reviewed patch awaiting its first build.

### Test plan

- `codeCoverage: true` with `codeCoverageTargets` scoped to the app target only, so the test
  target's own lines cannot inflate the number. The baseline in §"Phase 0" of the coverage audit is
  now takeable.

### Performance

| Finding | Change |
|---|---|
| #3 filmstrip | `HStack` → `LazyHStack` in `FilmstripGalleryView`; both galleries |
| #6 double sort | `LibraryDestination.coreContent` reads `filteredGames` instead of re-sorting |
| #4 fetch in a body | `prospectiveGameNumber` is `@State`, refreshed on appear and on `session.archivedPGN`'s identity |
| #2 (the surviving half) | `liftedGhostPieces` takes the hoisted `guidance` rather than re-reading it |
| #1 board chrome | `BoardFrame` and `BoardGrainOverlay` extracted as `Equatable` views — **not** `.drawingGroup()`, which would isolate the overlay blend and change the wood's appearance |
| #7 matchup | `opponents` memoized in a `CollectionFoldCache` box; `mostRecentOpponentKey` is a function so `body` cannot reach for it |
| #8 selected games | Memoized under a new `SelectionKey` and threaded to both consumers — it was walked and sorted **twice** per render, not once |
| #9 blob reads | One `PGN.winProbabilityCurve`, replacing the same expression at three sites |
| #10 lazy stack | `moveRows` uses `LazyVStack` only in the self-scrolling form, `VStack` in the `List`-hosted one |
| tier 3 | `last(where:)` over `compactMap { $0 }.last`; `.task(id: game?.contentHash)` over `id: game?.moves`; `LibraryColumnsView` memoizes `pgnText` |

### Naming and labels

`Win %` app-wide · `Mates` / `Special Mates` · `"Unrated"` at all three rating sites · `Library`
capitalised in 15 user-facing strings (the log line in `PGNStore` left alone) · sheet titled
`Edit Details` to match its seven controls · Get Info window titled `Get Info` · the queue window
titled `Analysis Queue`.

### Registries, symbols, typography

`customizationID` renamed to `checkmateType` and `name` **(this resets saved column layouts once,
by decision)** · `AccessibilityID`'s doc corrected to describe both spelling schemes rather than
claiming one · `settings.syzygy.50MoveToggle` so the constant matches its value · import / export /
backfill share one shape · `StorageKeys`' two `name ≠ value` exceptions documented · the orphaned
Syzygy comment returned to its keys · one `document.*` family for the game glyph, with the fill
carrying the selected/copy distinction · warning triangles filled at the two sites that broke the
terminal-vs-resting rule, and the rule written down · ASCII hyphens in result tokens · `New Game…`
· two Title Case tooltips made sentence case · 21 dashed `// MARK:`s normalised · British
*analysed* → *analyzed* (five sites, four of them in tests the scan missed) · `Destination.title` →
`displayName`, and `Collection.displayName` derived rather than switched · 15 test suites
Title-Cased and three unnamed ones given display names · `EditLiveGameDetailsSheet` moved to its
own file beside `EditGameInfoSheet`.

### Deliberately not done

- **Perf #5** (the memo key's O(n) build and compare). Scale-dependent by the audit's own account
  and correct at 111 games; the proposed cheap proxy trades exactness for a saving nothing has
  measured yet.
- **The duplicate `DGTBoardDiff`** in `mirrorBoard`. Real, but fixing it means threading a diff
  through `DGTReconstructor.reconstruct` — the most heavily fixture-pinned function in the tree —
  to save two dictionary builds. Not worth an unverifiable edit.
- **Selection `first(where:)` → `Dictionary`** at three sites. Threading a map through three view
  boundaries to save ~111 pointer compares is a worse trade than the O(n).
- **`AnalysisQueueStatusWindowView` → `AnalysisQueueWindow`.** Cosmetic, and the rename touches
  `sceneID` call sites across scenes. Worth doing with a compiler in the loop.
- **The remaining file/type name mismatches** (`Square.swift`/`Squares`, `LibraryChrome.swift`,
  `DGTProtocolTests.swift`, the `DGTSessionRecorderTests`/`DGTSessionRecordingTests` pair). Judgement
  calls, and one is entangled with the deferred `Board` namespace rename.
- **Everything from the orthogonality audit's §6 plan.** §1.3 above is why.

### First build will likely surface

Nothing was compiled. The changes most likely to need a touch-up, in order: `BoardFrame` /
`BoardGrainOverlay` (new `Equatable` view conformances and an implicit-`@ViewBuilder` body with a
bare `if`), the two new memo-key types (`OpponentsKey`, `SelectionKey`) and their `CollectionFoldCache`
instantiations, and `coreContent`'s widened signature in `PlayersDestination`. Brace, paren and
bracket balance was checked mechanically across all 66 touched files, and no test references any
renamed symbol, label or identifier — but that is not a compiler.

---

*Static verification of a static audit, then a patch applied on its findings. No build or test
was run.*
