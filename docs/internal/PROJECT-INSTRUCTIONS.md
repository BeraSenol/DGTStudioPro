# DGT Studio Pro — Project Instructions

**Revision 7 August 2026 (late) — simplification pass, by request.** The
revision-by-revision narrative that opened this file is gone; so are the struck
open items, the applied-audit documents, and the per-decision manual-check lists
for features long since verified. What survives is what a reader needs *now*:
the invariants, the agreements, the live open items, and the checks still owed.

*Everything cut is in git. This document is memory, not history — history is
`git log`, and a document that carries both stops being read for either.*

**Two recorded positions were reversed by request in this pass**, named rather
than quietly dropped, because reversing a decision silently is the failure this
project spends most of its discipline on:

- The three review documents (`AUDIT-2026-08-01.md`, `CODE-REVIEW-2026-08-01.md`,
  `CODE-REVIEW-2026-08-04.md`) were **kept and labelled** by a 6 August decision
  recorded in ROADMAP.md's M14. They are **deleted**. The argument for keeping
  them — that they show the *method*, which summaries cannot preserve — was
  sound and is answered by the methods themselves having since been lifted into
  Working agreements as runnable commands, which is the durable half. One source
  comment cited `AUDIT-2026-08-01.md § Zero`; it was re-pointed at
  `PlayersInspectorView`'s own site note in the same pass.
- The header of this file used to carry each sitting's narrative on the argument
  that a correction left visible teaches more than a correction applied. It did,
  and the lessons it taught are now agreements. What remained was a ledger of
  count corrections about counts nobody reads.

## What the app is

A macOS SwiftUI daily-driver for a DGT USB chessboard: play over the board while
the app records SAN live, finished games archive automatically into a
SwiftData-backed PGN Library, and everything is reviewable and analyzable there
(bundled Stockfish). One unified `WindowGroup` parameterised by
`PersistentIdentifier` gives native window-tabs.

Three destinations: **Board**, **Library**, **Players** (Rankings merged in at
D48′). The two collection destinations share four `CollectionViewMode`s (icons /
list / columns / gallery) under one `@AppStorage` key — the last mode used
anywhere is the mode everywhere. Columns is Finder-style list-plus-detail. The
sidebar carries user-editable, rule-based smart tags (Apple Music
smart-playlist shape) that filter the Library. Connection and session status have
a single surface, `SessionWindow`, opened from View ▸ Show Session — it hung in
the sidebar until 16 Aug 2026 and moved twice more before landing as a scene
(D84′). The stage above the board stays clear.

**This app is for one person, one Mac, one board.** No release, no App Store, no
other users. That is a standing input to every trade-off here: the App Store
submission floor is irrelevant, personal-scale libraries are the performance
envelope, and "would confuse a user" carries no weight — "would annoy Bera in
six months" is the test.

## Where things stand

Tree: **`7e0b3e6`** — the 26 August M16 slice (the stale-check purge, the
`LiveGameRosterForm` extraction, import cancellation, the M20 withdrawal to
Horizon; ⌘U green reported) — plus the same day's M18 Phase 1 working set:
six new test suites and their register/roadmap bookkeeping, nothing else
dirty. **The six test files must be staged with their commit**, the standing
hazard. Beneath `7e0b3e6`,
24–25 August: seven comment-trim / review-fix commits ending in the M17
inspector measurement (`c1e57fb`, with `M17-HITCH-CAPTURE.md` and the
census's first real numbers), the audit-fix sitting (`eb0906d`), the
roadmap-finalizing documents commit (`e9ca488`), and the 23–24 August source
sitting (`4d3761e` — context-menu standardization, the icons-grid
quantization, the card inscription picker; the ROADMAP's Landed entry
carries the accounts). Committed beneath those, all on 21 August: the
coverage key (`1018add`), the perf fixes (`ef082dd`), the label pass
(`2c1030c`), the convention pass (`9bffce8`), and the audit verification
(`28b45eb`).

**The first build happened on 24 August, and the headline risk is retired.**
The four 21 August commits (66 files edited with no toolchain, "a reviewed
patch awaiting its first build") and the whole 23 August sitting compiled and
ran together: **one** compile error surfaced across the combined set —
`CollectionViewOptions.inset`, isolated static read from a nonisolated
context, fixed the same hour and recorded as a build-diagnostic lesson — and
none of AUDIT-VERIFICATION §6's predicted break points broke. ⌘U green,
reported by Bera, 24 August. What remains of **M15's gate**: the suite count
read off the report (the denominator, ~105 expected), the coverage baseline
read off the same report (the plan has carried `codeCoverage` scoped to the
app target since `1018add` — the number already exists in the Report
navigator), the column-layout reset confirmation (the two `customizationID`
renames), and the commit.

**Committed atop it, 24 August (late): the audit-fix sitting.** A
whole-project scan against current Apple documentation found five things, and
the commit is the five fixes: the game form's `.tabItem`s — the one deprecated
API in the tree — became the `Tab(_:systemImage:)` its two siblings already
used, both site comments corrected (the old one defended `.tabItem` against
the wrong alternative); `com.apple.security.files.bookmarks.app-scope` joined
the entitlements, argued at the key, at `SyzygyLocation.store`, and in the
Syzygy owed check, with the plist now naming the build-settings half of the
grant story (`ENABLE_USER_SELECTED_FILES = readwrite`); the gear's repeat
question closed on the API side at `AnalyzingGear` and in its owed check;
"all three targets" became "both" in this file's two present-tense homes and
the roadmap's M15 bullet (DECISIONS keeps three as provenance); and four
scene modifiers came back from column 0. No source added or removed — the
count block re-ran unchanged. The `Tab` migration is the sitting's one
code-shape change and awaits its ⌘U.

**This line has now decayed five recorded times, and the fifth is the worst.**
The four earlier instances were the same failure — written at the moment of
committing, never re-read, surviving as a confident description of a tree that no
longer exists. This one sat at `34c7043` for six days across four commits while
describing dirty audit files that had long since gone, and it was not caught by
reading, because it reads perfectly. It was caught by a scan that compared every
number in this file against the tree. The remedy the file prescribes — write it
*before* the commit, in a form true when read — is used above, and the standing
answer is now the audit, not the intention: **run the count block below whenever
this section is touched.** (A sixth instance followed anyway, mildest so far:
seven comment-pass commits landed 24–25 Aug atop the paragraph's described
tree while it stood; caught the next day by this section being touched again,
which is the rule above doing its job rather than a new failure mode.)

| | |
|---|---|
| Sources on disk | **283** — 167 app, 116 unit-test, 0 UITest |
| Tracked (`git ls-files '*.swift'`) | **283** once the M18 Phase 1 suites are staged (277 at `7e0b3e6`) |
| Accessibility registry | **148** constants + **23** functions |

*Re-measured 26 Aug 2026, at `7e0b3e6` plus the M18 Phase 1 working set.*
The M16 slice committed as `7e0b3e6` (roster-form file, import-progress
suite, two registry entries); the Phase 1 slice adds six test files — all
new suites, no app sources — and they must be staged with their commit, the
standing hazard. The registry line had corrected 142 → 145 → 146 across the
prior week — the 18 August figure was wrong when written (AUDIT-VERIFICATION
§0 counted 145 literal values at `c8eea2d`, the same snapshot), which is
this table's own lesson re-taught: the number lives in the grep, not here.

All three counts are dated snapshots. The registry count lives in its grep (D42′)
and the source counts in `find` / `git ls-files`, because a number in prose decays
and a number in a command cannot — which is exactly what the paragraph above is
about.

Not counted, because they are not sources: **seven** `.wav` samples under
`Features/Board/Sounds/`, **136 KB** — nine cues over seven samples, one voice.
This read "twelve samples, 268 KB, three sets × four cues" until 18 Aug 2026, six
days after D82′ was reversed and the packs deleted.

**Language mode 6 on both targets (D43′, which landed it on three — D51′ took
the UITest target).** Two warnings in the whole
project, both `Binding(present:)`, both waived below with a sunset condition.
No `DispatchQueue`, `Combine`, `NotificationCenter`, `Thread.sleep`,
unchecked-`Sendable` or the unsafe-`nonisolated` opt-out anywhere in the app
target. No TODO/FIXME/HACK markers, no commented-out code, no `#if DEBUG`
regions.

**⌘U:** green as reported by Bera on **24 August 2026**, on the working tree
carrying the 21 August patch and the whole 23 August sitting — the first run
since 12 August and the first ever over the patch. Counts not reported that
run. The last counted run (8 August, against `275f037`) was **1108 tests,
101 suites**; the tree since adds four suites (the analysis plan, the heal
gate, scoped collection, the display keys), D80′ deleted one with its type,
and the 23 August sitting adds `LibraryCardInscriptionTests` — so a run
reporting around **105 suites** is the expected denominator. Never claimed —
⌘U runs locally and Bera reports.

*The count is a dated snapshot and will decay; it is here because the
denominator is the useful half — a run that reports far fewer suites than this
is a run that skipped something, which is the failure a bare "green" cannot
show.*

**Untracked files a tracked file references will not build.** **None are in
that state at this recording** — the D73′ pair that stood here was committed
with its sitting, and every 9–10 August file landed tracked or sits as a
modification. The hazard has been the single most-repeated finding in this
document's life: `git status` has caught it every time and the prose has never
once prevented it. (An earlier version of this paragraph named
five such files, and before that miscounted them as two — the fourth species,
inside the sentence warning about it. The check, not the count:)

```bash
for f in $(git status --short | awk '$1=="??" && $2 ~ /\.swift$/ {print $2}'); do
  for t in $(grep -oE '(struct|enum|class|protocol|func) [A-Za-z_][A-Za-z0-9_]*' "$f" | awk '{print $2}' | sort -u); do
    git ls-files '*.swift' | xargs grep -ln "\b$t\b" 2>/dev/null | grep -q . && { echo "$f"; break 2; }
  done
done | sort -u
```

*Read the output as "these will not build until staged", not as a file count:
one untracked file can be referenced from a dozen tracked ones, which is why
naming the files beats naming a number.*

### Built and in use

The daily loop end to end — import / dedupe / four modes / analysis → mirror →
reconstruction → live surface → crash-safe drafts → archive-first with
confirmation → recovery guidance. Connection QoL (auto-connect policy, silent
launch connect, mid-game reconnect). Diagnostics and Game menus. Batch analysis
on a pure queue with an app-global controller and its own window. Players and
SmartTags on pure folds. Movetext editing by full replay, splice-refusing, from
Get Info's Move Text tab (D59′). PGN export byte-pinned to the DGT reference
shape (D24′). Shared inspector chrome with collapsible sections (D26′, D45′).
Idle-sleep inhibition behind two Energy preferences — play and batch analysis,
separately gated (D14′, D25′, D66′). Board coordinates, illegal-move sound,
`[Board]` tag on live archives (D28′), seat pickers inserting tag form (D29′),
the evaluation bar on the review board's leading edge (D33′), the evaluation
graph in its own window (D46′), piece animation under proven identity (D47′),
engine-free ECO and checkmate-type classification filterable as tag rules
(D34′–D36′, ten motifs since D65′), live search with token chips, rubber-band and
arrow-key grid selection, ⌘A across all four modes, keyboard shortcuts on every
row menu, Open-takes-a-set with a count threshold (D56′), Get Info as three tabs
over three subjects and the app's one rename door (D53′, D57′, D59′), the file
ordinal as a second weaker identity (D58′), automatic orphan collection (D60′),
one logging door and policy (D63′), the View Options panel (⌘J) driving icon
size, grid spacing and sort for both collection destinations, the analysis
badge in all four Library view modes off one projection (D72′), exit-cadence
analysis saves with the engine at utility QoS (D71′), one batch counter on
both progress surfaces, the Players gallery preview at eight facts plus the
rating trend, and the Analysis Data window — per-ply move / evaluation /
win % behind the button beside the magnifier, superseding Get Info's removed
Analysis section, with the queue window's Depth fact pinned to the configured
target (D73′). Analysis is incremental since D74′ — the opening book is never
searched, every evaluation carries its depth, an already-satisfied game never
starts the engine, and raising the target deepens only what needs it. The
player backfills retire behind a converged stamp (D75′), orphan collection at
the editing doors scopes to the rows the edit displaced (D76′), the Analysis
Data window carries the per-ply swing (D77′), narrowing and sort join the
collection fold memo (D78′), the movetext editor paints the offending ply red
in the field (D79′), and every companion window joins a full-screen space
rather than claiming its own (D80′).

## Decisions

**The D-anchors live in `DECISIONS.md`** — D9′ onward, moved verbatim and
append-only at M14. That file owns them *and* owns the next-free number; this
one cites numbers without restating arguments.

**What did not move, because it is read daily and this document has to stand
alone.** Locked product decisions #1–#8 were recorded in the retired roadmap
document §2 and remain in force. Two are restated rather than cited:

- **#1** — the physical board is truth and the live game is append-only. No
  takebacks, ever; Discard lives in the inspector.
- **#3** — `*` is never a finished result and never archives. The *import* door
  admits it deliberately; the archive door refuses it.

Old milestone and finding tags (M7.2, M-prs.1, F1–F9…) survive in code comments
as provenance only — they identify where a decision came from and schedule
nothing. **They do not all survive in `DECISIONS.md`**, which this sentence
claimed until 24 Aug 2026: of the F family only F5 is reconstructable there, and
seven others are defined in no document at all. The grep in Working agreements
names them (hyphenated, for the reason given there) and is what makes the list
visible instead of assumed. **M11** is one of them (the pre-roadmap decoupling
review), which is why the refinement milestones start at M12.

## Architecture invariants

- **The compiler enforces mode 6 (D43′).** Every isolation and `Sendable` claim
  below is checked rather than asserted. Reaching for unchecked-`Sendable` or
  the unsafe-`nonisolated` opt-out is now the visible act of opting *out* of
  enforcement.
- **Chess-core purity.** `Position`, `GameState`, `Move`, `FEN`, `Square`,
  `CastlingRights` are pure `Sendable` value types — logger-free, I/O-free,
  actor-free (sole Foundation import: `CharacterSet` trimming in the SAN layer).
  The invariant names **types, not folders**, which is why `ECOClassifier` and
  `ECOTable` share a directory. Board geometry offsets live on `Square`, one
  copy.
- **Move generation defends against hand-edited state.** Castling is generated
  only when the rook actually sits on its home square. Same hardening in FEN
  parsing.
- **`LiveGame` is an I/O-free `@Observable @MainActor final class`**, append-only
  — no takebacks, no `rollback()`, ever (Decision #1).
- **One Mode, honestly scoped.** `DGTLiveSession`'s single private `Mode` derives
  `liveGame`, `awaitingPhysicalSetup`, `needsRecovery`. Three published members
  are deliberately not Mode-derived but Mode-guarded.
- **Settable hooks are wired exactly once in `App.init()`** — `sessionLog`,
  `draftStore`, `onGameFinished`, `onBoardChanged`, `onDesync`, `boardIdentity`,
  `requestBoardResync` (D49′), `shouldAutoReconnect`, `onMoveCommitted` (D81′).
  **Nil hooks mean unit tests run headless by construction.** `recordError` is
  the one door for must-reach-somewhere errors.
- **A move makes exactly one sound (D81′).** `BoardCue.cue(for:landing:)` is the
  single classifier and its precedence is total — checkmate over check over
  promote over capture over castle over move — so no surface layers two samples or
  spells the ordering a second time. A promoting capture is a promotion first:
  captures are common where promotions are not. `BoardCue` carries a `family`
  split because `gameStart` and `gameEnd` made "what a landed move sounds like"
  stop being true of the whole enum, and `cue(for:landing:)` never returning an
  event is tested rather than assumed. Classified from `Move` + `GameState`,
  never from SAN: a third
  string reading of `#` would land on the open item where the app's two existing
  spellings already disagree. Live rides the session hook above; review rides
  `Game.onStep`, which `advance()` and `retreat()` call and `jump(to:)`,
  `toStart()` and `toEnd()` deliberately do not — the step/jump split is which
  methods fire the hook, so no caller can get it wrong.
- **`BoardSounds` is the only thing that plays a sample**, owns the **nine** gates
  as observable properties (D25′, not `@AppStorage` twins), and is silent under
  the test host. Nine cues over seven samples: `resources` is a list, so
  `checkmate` layers the move and the game ending — a mate is both — and
  `promote` borrows the move sample. D13′'s illegal-move `NSSound.beep()` became a
  sample with the rest; it is no longer an `NSSound` call. **Playing anything at
  all needs the `audioanalyticsd` mach-lookup exception** — without it a sandboxed
  process is killed on first playback, not warned (D81′).
- **There is one voice, and the only choice is which cues are on.** D82′ made the
  cue set a user choice — felt, wood, marble — and was **reversed 17 Aug 2026 by
  request**: `BoardSoundSet`, the twelve pack samples and `Tools/make-cues.swift`
  are all deleted. Its invariant survives the reversal in a stronger form: one set
  meant a felt move beside a marble capture was unrepresentable, and no sets means
  there is nothing to make representable. The licensing finding recorded at the
  reversal is the part worth not rediscovering — the `lichess-org` sounds anybody
  means are listed non-free in that project's own COPYING.md, and the four broken
  out as free carry AGPLv3+ into a shipping app.
- **Auto-connect decisions are pure; transport is not.**
- **Idle-sleep inhibition is App-owned and preference-gated**, two causes with
  two gates (D66′). Display sleep is intentionally left alone, structurally, via
  `.userInitiated`. `observe()` is re-entry-guarded.
- **The mirror renders the physical board. Always.** Only overlays come from the
  game. Since D47′ this is a *tested property*: `PieceIdentity`'s output
  occupancy is the rendered position verbatim — the resolver decides keys, never
  presence.
- **A piece glides only under a proven identity (D47′).** Parity vouches for the
  settled; the reconstructor's own verification vouches for the in-flight move;
  everything else is anonymous and can only fade. No surface may pair a vacate
  with a place by inference — that inference has one home, `DGTReconstructor`,
  and one standard, full-position verification.
- **One surface owns session info; the stage above the board stays clear (D15′).**
  That surface is `SessionWindow`, a scene since D84′ — the sidebar, the Board
  inspector and a board overlay were all homes it outgrew, and the stage-clear
  half is the reason the overlay did not last. Recovery marks on squares are the
  one thing drawn over the board, and they are the mirror's, not messaging. The
  per-tab load error is an `.alert` on `BoardDestination`, deliberately not here:
  it is a fact about one tab, and this surface is app-global.
- **id→model resolution guards tombstones, and a snapshot held across a dialog is
  the same hazard without the cast.** Every site pairs the cast with an
  `isDeleted` check.
- **`DGTBoardDiff.vacated` and `.placed` are disjoint**, decided by
  end-occupancy. Reconstruction returns `.inProgress` before generating moves.
- **One draft, one JSON sidecar.** Atomic writes, `schemaVersion`-guarded,
  flattened fields. Additive **optional** fields are non-breaking (D28′) — a
  limit D36′ makes structural for the other Codable-on-a-model type.
- **Archive-first, exactly once, never lost.**
- **One content hash, one recipe, two spellings.** MD5 over
  `normalize(event) | normalize(site) | hashDateString(date) | round |
  normalize(white) | normalize(black) | result.rawValue | moves joined by spaces`.
  The model-typed `contentHash(for:)` forwards to a field-taking twin (D39′).
  Changing its order, separator, normalization or digest un-dedupes the archive
  against itself. Any in-place edit calls `refreshHash(of:)`; a retag rehashes
  inside the same transaction. `timeControl`, `board`, `libraryIndex` and all four
  classification columns are deliberately outside it; `PGN.name` too.
- **Player links are store-owned (D9′).** `resolvePlayer(named:)` is the single
  creation door; both doors link on insert; `backfillPlayerLinks()` heals
  pre-schema rows — behind a converged stamp since D75′, which Erase Library
  clears. `applyEdit` re-resolves unconditionally; `applyMovetextEdit`
  deliberately does not.
- **Stored seat tags change through one door (D37′).** `PGNStore.retag(_:to:)`,
  with a pre-flight that refuses before writing (D39′) and a rehash riding the
  rewrite.
- **"Orphaned" has one spelling (D40′)**, `PGNStore.isOrphaned(_:)` — and since
  D60′ orphans are collected automatically by every door that can strand one.
  The editing doors ask it only of the rows the edit displaced (D76′); the
  backfill arm stays global, because a backlog healer's candidates *are*
  everyone.
- **An orphaned player is unreachable through selection, by construction.** The
  collection destinations render folds over `GameRecord`s, whose sides come from
  resolved links. Anything gated on the *selected* player having no games is dead
  code with a green build.
- **Classification is store-owned and derived (D34′).** `PGNStore.classify` is the
  single write site for all four columns; the fields are absent from `PGN.init`.
- **Player names render through `PlayerName.displayForm(of:)`, once (D23′).** Tag
  form is stored, display form is shown, there is no inverse.
- **Movetext edits validate by replay, accepted whole or rejected whole (D18′).**
- **PGN export is byte-pinned to the reference files (D24′).** Classification is
  not exported.
- **Pure cores are `GameRecord`-typed (D10′)**, with two recorded shape
  exceptions: `SpecialCheckmate` and the M4 classifiers.
- **SmartTag matching is model-stored, value-decided** — an in-memory fold, never
  a `#Predicate`, because a stored-Codable rule array cannot be queried in the
  store. `SmartTag.self` in the container is load-bearing: no relationships, so
  schema inference from `PGN` never pulls it in.
- **A collapsible section is one argument, not two (D45′).** `CollapsibleSection`
  is the only door; it takes one `InspectorSection` and uses it for both the
  chevron and the body gate, so "the header toggles X while the body checks Y" is
  unrepresentable. The store is read in exactly two files.
- **Section identity is what a section shows, not where (D45′).** One case per
  *kind* of content, shared across hosts. Two sections that merely share a title
  are not the same section.
- **The accessibility registry speaks only in `String`.** Minted while
  `AccessibilityID.swift` compiled into the UI test target too; kept after D51′
  deleted that target, because re-typing sixteen signatures buys type safety
  nothing checks. Identifiers are a registry, **no longer a tested contract** — a
  raw string in a view is still a defect, and a rename or removal is still
  recorded at the symbol, but the discipline is carried by the sweep's grep
  alone. No table column is pinned visible, so **no cell is a guaranteed
  address**.
- **Collection-destination parity.** Both destinations share `CollectionViewOptions`
  for icon size, spacing and sort. Known residue, unscheduled: none currently.
- **Destructive actions confirm, whichever route reaches them.**
- **Logging has one door and one policy (D63′).** `AppLog.logger(_:)` is the only
  `Logger` factory and returns `Logger?`, so suppression short-circuits before
  interpolation. Silent under the test host, re-armed by `DGT_LOG=1`.
  `TestHost.isActive` is the single spelling of "am I under XCTest?".
- **`StorageKeys` is the single home for `@AppStorage` keys.**
- **Engine options are sent in the UCI window;** inbound option advertisements are
  deliberately ignored. Teardown must complete even when the surrounding work is
  cancelled, and must strand no waiter.
- **`[%eval …]` parsing rejects what it cannot represent.** The bundled ECO table
  is *trusted* content by contrast — its parser skips malformed rows and logs.
- **`DGTSessionLog` discipline.** `record` buffers and Console-mirrors; `capture`
  buffers only; `recordDesync` for irreconcilable boards. Ring-bounded.
- **Test hosts stay hermetic**, by the XCTest env-var guard in `App.init` — a real
  board must not feed the suite hardware events mid-run.
- **Collection folds are memoized on content, never on evaluations
  (7 Aug 2026).** `CollectionFoldKey` is built from stored scalars only. The
  Library composes an analysis signal from the *queue's counters*, because it
  genuinely tracks analysis state; Players does not, because nothing it folds
  reads `evaluations`. That asymmetry kept the per-ply save from re-folding
  the Library while per-ply saves existed; since D71′ the driver saves per
  exit, and the key remains what makes the folds indifferent to save cadence
  at all.
- **An analysis pass touches the store once per exit (D71′)** — done,
  cancelled, or failed — never per ply, and every exit persists *before* its
  message claims anything was kept. Per-ply state for the queue window lives
  on the driver (`search`, `status`), never on the model.
- **"Analyzed?" reaches rendering leaves as a projection, never a model read
  (D72′).** `LibraryDestination` builds `analyzedIDs` off the memoized records
  once per render; every badge and the list's Analysis column read membership
  plus the ambient `analysisRunningGameID`. A leaf asking a `PGN` directly is
  the per-row blob decode D70′ exists to prevent.
- **Narrowing and sort live inside the fold memo (D78′)**, one cache per
  destination keyed on every input the stage reads — and a memo key's only
  defence is field-list completeness, which is a suite
  (`DestinationDisplayKeyTests`: every input moved singly must move the key).
  The action-time contract survives: `gamesInDisplayOrder` re-reads the cache,
  which recomputes iff an input moved.
- **Analysis is planned before the engine starts (D74′).** `AnalysisPlan` reads
  stored evaluations, per-ply depths and the classified book prefix; only the
  searchable set runs, a satisfied plan never spawns the process, and storage
  resets only when the plan says so. The book is never searched — an opening
  table's verdict outranks a depth-18 pass over its own rows.
- **Companion scenes carry the associated window-manager role (D80′)** — scene
  level, so the role precedes placement; a companion joins a full-screen space
  and never claims one. The main group carries nothing and keeps the primary
  role. A window-behaviour write that happens after placement is dead code
  with a green build, which is what the deleted AppKit configurator was.

## Working agreements

**Process**

- **Code is truth.** Docs follow code; when they disagree, fix the doc. Look
  first at any comment that *asserts* a guarantee — it reads as settled and is
  exactly as checkable as anything else.
- **A correction has two homes.** Fix the comment that originated the claim in
  the same pass. A comment describing a deletion lands in the same commit as the
  deletion.
- **Sweep between milestones, not only within them.** Run `git status` first,
  before any grep. The first standalone sweep's headline finding was not a
  finding but a commit: a green delivery sitting unstaged while both documents
  described it as landed.
- **A discarded working tree is a discarded delivery.** Any sentence in these
  documents containing a path, a count or a claim of cleanliness is a checkable
  claim about the filesystem. Written down, this rule has prevented the failure
  zero times in nine passes; `git status` has caught it every time. Treat it as a
  reminder to type the command, not a substitute for typing it.
- **Never pencil a D-number for future work.** Numbers are assigned at recording
  time, in `DECISIONS.md`, in sequence.
- **Code edits arrive as SEARCH & REPLACE.** Never prose naming call sites; never
  a whole-file replacement unless asked or labelled. Mechanical changes travel
  alone.
- **Re-sync project knowledge after each integration.** The tracked file is the
  owner; the sync is a projection that decays silently. Read the repo's copy,
  then re-sync — never the reverse. Sync artifact: `+` in filenames arrives as
  `_`; contents are unaffected, so anchors stay exact.

**Claims and checks** — six species of unchecked claim, each found the hard way:

1. *False* — the sentence is wrong. Cheap to catch, rarely caught.
2. *Stale* — true when written, decayed when something adjacent changed.
3. *Invented* — a count or a path with no reconstructible provenance. A number
   decays worse than a path, because a path is either there or not while a stale
   count stays plausible forever.
4. *True but narrower than read* — a sentence saying "every" quantifies
   correctly over a smaller set than its reader assumes, and a true statement
   never fails. Count the category before believing the plan's scope.
5. *Absent* — a milestone written down nowhere cannot be caught by any check that
   reads what was written. Absence never fails.
6. *Refuted by a green test nobody connected to it* — four artefacts agreeing
   with each other and one passing test contradicting all four, with nothing to
   make them meet.

- **A claim is only checked by a test that could have failed.** The question that
  catches all of these: *what would it take for this to fail, and does that
  situation exist anywhere in the tree?* If nothing does, the check is decorative.

  **A fixture where every input agrees is one of these in disguise** (12 Aug 2026,
  found by being asked whether the cue toggles persist — they did). D81′'s
  round-trip test stored `false` under all four keys and asserted all four
  properties read `false`, which passes unchanged if two properties read each
  other's key: with identical inputs a crossed wiring produces an identical
  answer. The fix is to vary *one* input and assert the others are unmoved, which
  is now `eachCueReadsItsOwnKey` and its write-side mirror. The tell is a test
  whose expected values are all the same — an N-way mapping needs N distinct
  expectations, or it is checking that the code does *something*, not that it does
  the right thing.
- **Compiling is not the test; being compiled from the side where the claim would
  break is.** A comment stating a rule about *the language* is a hypothesis until
  something exercises it from that side.
- **A measurement must carry proof that it measured.** Report a corroborating
  count from the same log — `SwiftCompile` phases, sources compiled, the
  `** BUILD SUCCEEDED **` line. A build that did nothing produces a beautifully
  clean log.
- **A method that lives in the author's head is not part of the check.** Anything
  published here as a command gets run verbatim by someone who was not there.
- **A check's false positives are part of the check.** A first run that is mostly
  noise is a check nobody runs twice — and the fastest way to add the noise is to
  document a rule inside the thing the rule scans. Never write a prohibited token
  verbatim; spell around it ("the unsafe-`nonisolated` opt-out"). Before trusting
  a grep, ask what it does when its subject spans a newline.
- **A token cross-reference proves a name is used, never that a user can reach
  it** — and a declaration scan says nothing about whether a consumer's *branch*
  can execute. Reachability is a separate pass: for each closure a view exposes,
  find the control that invokes it; for each `.sheet`/`.alert`, find what sets its
  state.
- **A disabled affordance whose guard can never be true is a lie with a green
  build.** For every `.disabled(…)` over a derived condition, ask whether the
  supply can produce the enabling value at all.
- **A guard that exists in two places must be computed from one source** — not
  "make them read the same data" but *one predicate, called twice*. Two guards
  agreeing is not evidence either is right; only that they will be wrong together.
- **A manual-check list is a claim, and claims get checked.** Written checks are
  "code is truth" material — arguably more so, because nothing compiles them.
- **"Expected green, never claimed" is a hypothesis; the run is the check.** A red
  suite can be inherited: answer "did I break this?" with `git status` on the
  failing file and `git log` on its last commit, not by re-reading the diff.

**Standing greps** — run at each sweep, all expected clean:

```sh
git status                                     # first, always

# Provenance tags in code but in no document (species 5). Rewritten 24 Aug 2026, twice broken:
# `*.md` is a shell glob reaching only the repo root, so from the day the documents moved into
# docs/internal this read exactly one file (README.md) and reported all twelve milestones as
# undefined — noise, which is why nobody ran it twice. And M-only could not see the D and F
# families, where the real gap was. `--include` walks the tree; primed tags cancel because they
# match identically on both sides, so no lookahead is needed (BSD grep has no -P).
comm -23 <(grep -rhoE "\b[MDF][0-9]+" --include='*.swift' DGTStudioPro DGTStudioProTests | sort -u) \
         <(grep -rhoE "\b[MDF][0-9]+" --include='*.md' . | sort -u)
# **Every tag below is written with a hyphen — D-2, not the literal.** The rule against writing
# a prohibited token inside the thing that scans for it applies here exactly: spelled straight,
# these lines would put the tags in a document, the grep would find them there, and the check
# would pass by describing its own failure.
#
# Expected: two ECO volume codes from ECOClassifierTests (D-00 and D-06, not tags), plus the
# standing gap. The B family is deliberately absent — B-00/B-01/B-10/B-20/B-7 are ECO codes and
# B-9600 is a baud rate, six false positives burying the one real B-tag.
#
# **Standing gap, 24 Aug 2026:** D-2, D-6, D-7, F-2, F-3, F-4, F-7 — cited in code, defined in
# no document. A retired layer scheme (D-1 decode, D-2 transport, D-6 recovery, D-7 archive)
# and four findings. Every citing sentence reads correctly with its tag deleted, which is what
# makes them survivable; shrinking this list means writing them up or dropping them.

# Declared names referenced nowhere. Comments stripped BEFORE the frequency
# table — the comment most likely to name a symbol is the one explaining its
# removal, which kept ~80 dead lines alive through three sweeps.
find DGTStudioPro DGTStudioProTests -name '*.swift' -exec cat {} + \
  | sed 's|//.*||' | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*' | sort | uniq -c > freq
find DGTStudioPro -name '*.swift' -exec sh -c 'sed "s|//.*||" "$1"' _ {} \; \
  | grep -oE '(func|var|let|struct|enum|final class|class|actor)[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' \
  | awk '{print $NF}' | sort -u > decls
awk 'NR==FNR { f[$2]=$1; next } { if (f[$1]==1) print $1 }' freq decls
# Expected: DGTStudioProApp (@main), isOpen (kept by decision, M12.3).
# makeNSView / updateNSView left the set with FullScreenAuxiliary (D80′ — the
# scene-level windowManagerRole replaced the app's one NSViewRepresentable),
# so a representable witness reappearing here means someone reached for
# AppKit again and the reason belongs in a D-entry.

grep -rn '\.disabled(' --include='*.swift' DGTStudioPro   # every guard producible both ways
grep -c  'static let\|static func' DGTStudioPro/App/AccessibilityID.swift

# Conditional-compilation regions. Comment lines excluded, because the only two
# matches in the tree are `PreviewFixtures`' doc *stating this rule* — the
# self-inflicted false positive this file warns about, planted by the warning.
# Caught on this grep's first run, which is the argument for running a check
# once before publishing its expected output.
grep -rn '#if DEBUG' --include='*.swift' DGTStudioPro | grep -v ':[0-9]*:///\?\s*'
```

**Code and tests**

- **Doc comments carry the why.** A site comment cites the anchor rather than
  restating it — `DECISIONS.md` holds the argument, the comment holds the *local*
  trap and a D-number. **Three exemptions:** a rule about *the language* stays
  complete; a **rejected local implementation** stays; a **disposition record**
  (why a symbol with no consumer is kept) stays, because no anchor holds it.
  Guidance for new comments, deliberately not run retroactively — the app target
  is ~38% comments and cutting to 30% would trade a definite loss of reasoning
  for an indefinite gain.
- **Tests land in the same change as the behaviour they cover.** Outcomes are
  expected, never asserted.
- **Actor isolation in tests: `@MainActor` suites for `@MainActor` types,
  nonisolated for pure value types.** Where nonisolation is load-bearing, say so
  at the suite.
- **A test referencing API that doesn't exist is not a landed test.** Nor is a
  fix without its pinning test, nor a test whose resources aren't committed. When
  a suite wants API that doesn't exist, decide rather than default.
- **A test that pins a factory is a change-detector** — editing the factory means
  editing the test in the same change.
- **A view without a preview needs a written waiver; a preview must instantiate
  its own type.** Previews should cover the branches no fixture reaches by
  accident. **A preview witnessing an arrangement the app has retired is worse
  than no preview** — it reads as evidence the arrangement is still checked.
- **Waivers are written, not implied** — and a type that gains a suite comes off
  the register in the same change.
- **The compiler outranks any platform reference, including the forward notes
  below.** Do not infer an API name from its neighbours, a data row, or a
  function's contract from its name.
- **Not every duplicate should be collapsed.** Worked examples stand: the HUD's
  five switches, `BoardStyle`'s exhaustive switches, the memberwise-init
  taxonomy, `OpeningSection`'s em dash beside `SevenTagRosterSection`'s.
- **A constraint obeyed by every instance and stated by none reads as taste** — and
  gets broken by someone improving it. One sentence at the first instance.
- **Manual checks stand in for what XCUITest cannot reach**, and a synchronous
  parse of a bundled asset belongs off the main actor.

## Build-diagnostic lessons

- **The sandbox is part of the API surface, and it fails as a kill rather than as
  an error** (D81′). The first sample this app ever played terminated the process:
  `PRECONDITION FAILURE: Process is sandboxed but
  '…mach-lookup.global-name' doesn't contain 'com.apple.audioanalyticsd'`. No
  `throws`, no `nil`, no degraded feature — an entitlement a compiler cannot check
  and a suite cannot reach, discovered by launching. Anything touching a *daemon*
  (audio, media, speech, location) is entitlement-shaped, and the check is a run,
  not a build.
- **`NSSound` is `AVAudioPlayer` underneath, so it is not the lighter retreat it
  looks like.** `-[NSSound play]` → `-[AVAudioPlayer play]` → `AudioQueueStart` →
  CoreAudio, one stack. `NSSound.beep()` is the exception that misleads: it is the
  system alert path and initialises no playback graph in-process, which is why
  D13′ has beeped inside this sandbox for weeks while D81′'s first click died. A
  working `beep()` is **not** evidence that playback works.
- **`#Preview` compiles in Release**; it is stripped at link time, not excluded at
  compile time. A preview referencing an `#if DEBUG` symbol is a Release-only
  compile error, and ⌘U and ⌘R both build Debug. **No symbol a `#Preview` touches
  may be `#if DEBUG`.**
- **The Debug/Release split is a coverage gap in every measurement here.**
  `build-for-testing` builds Debug, so "zero diagnostics" was never a claim about
  Release. **Profile (⌘I) is the cheapest Release build available.**
- **A global actor isolates a type's members, not the types nested inside it.**
  `@MainActor class Outer { struct Inner {} }` leaves `Inner` nonisolated. The
  trap is that the members rule is true and adjacent.
- **A `static let` on a globally-isolated type is isolated like any other
  member — an immutable `Sendable` value earns no exemption.** A `nonisolated
  static func` reading a plain `static let CGFloat` on its own `@MainActor`
  class is a compile error, however raceless the constant is; the fix is
  `nonisolated` on the constant, stated rather than assumed. Found by the
  23 Aug sitting's first build (`CollectionViewOptions.inset`), against a
  confident assumption that immutability implied reachability.
- **A synchronous override cannot add isolation its superclass lacks; an async
  override can** — there is a suspension point to hop on. Hence
  `setUp() async throws` rather than an annotation on `setUpWithError`.
- **A type with its own `init` gets no memberwise one**, so a defaulted stored
  property is invisible to callers — and the error names the *caller*. If a
  property default "isn't working", look for a hand-written initializer first.
  Grep `init(` in that **type's** body, not the file's.
- **Generic types cannot have stored static properties.** `static var x: T { … }`
  compiles where `static let` does not.
- **A signature is a contract with every target that compiles the file.** API
  surface is limited to what the *narrowest* target can see.
- **`Swift.Error` refines `Sendable`**, so an error payload can never carry a
  `@Model`. Read the names where the models are in hand.
- **Foundation members do not arrive through a transitive import**, and this
  codebase enables `MemberImportVisibility`. `firstRange(of:)` and `drop(while:)`
  are stdlib; `range(of:)`, `trimmingCharacters(in:)`, `padding(toLength:)` are
  Foundation. Reads perfectly, fails at compile.
- ~~**Key paths do not reach tuple elements**~~ — **struck 24 Aug 2026, refuted by
  a green build.** Two app-target sites compile a key path into an `enumerated()`
  pair: `AnalysisQueueStatusWindowView`'s `id: \.element` and `ImportStatusView`'s
  `id: \.element.id`. Whatever the original diagnostic was, it was not this. The
  other half of the sentence stands: `map` over a zipped sequence takes the pair
  as **one** argument — the two-parameter spelling is the tuple splat removed in
  Swift 3.
- **Never assign to a property from inside its own `didSet` on an `@Observable`
  type.** The macro rewrites stored properties into computed ones, so the
  self-assignment goes through the setter, the observer re-enters, and it
  recurses to the stack guard page — surfacing as `EXC_BAD_ACCESS (code=2)`,
  which reads like a memory bug and is control flow.
- **Inserting before a declaration means walking back over its attributes first.**
  A declaration is its attributes *plus* its doc comment *plus* its signature.
  The compiler catches a stacked `@Test`; nothing catches a re-homed `///` block.
- **With synchronized folder groups, target membership IS folder contents.**
  Deleting a file from the project without deleting it from disk removes nothing.
- **Swift 6 capture discipline in `@Sendable` closures.** A weak capture is a
  mutable box; capture `@MainActor` classes strongly and verify no cycle.
- A mass identical test failure is one death, fanned out — clean build, ⌘R the
  host, target membership, then the crash report, in that order. A suite full of
  "no member Y" is one missing production half. "Cannot find X in scope" after a
  diff usually means the wrong file. Result builders top out at ten statements.
  Typed throws propagate to every helper on the path. `os.Logger` interpolation
  has no `Substring` overload. A new environment object breaks every preview that
  doesn't inject it — inject scratch `UserDefaults`, never `.standard`.

**Cold-build invocation**, for any future measurement:

```sh
xcodebuild -scheme DGTStudioPro -testPlan DGTStudioPro \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath <scratch> build-for-testing
```

Delete the scratch path first. `build-for-testing` with the full plan is what
compiles both targets; a plain ⌘B covers only the app target. Settings can
be overridden per-run without touching the project file.

**Runtime verification:** `pmset -g assertions` shows the held activity by its
reason string; `log stream --predicate 'category == "uci"'` shows the setoption
order; `"eco"` shows the table's row count at load; `"players"` shows retag and
collection lines; Stockfish resident memory should track configured Hash.

## Toolchain forward notes (Xcode 27 / Swift 6.4 / 2027 SDKs — all beta)

Governed by D27′: none of this is adopted, none of it is scheduled. Snapshot at
Xcode 27 beta 4; the compiler outranks this list whenever they disagree. Re-read
at GM, not automatically reversed.

**Strong — these restate arguments this project already makes**

- `withContinuousObservation(options:)` replaces the self-rescheduling loop
  (D14′, D25′) with a token whose lifetime owns the subscription — verbatim the
  RAII argument D14′ makes for `ActivityToken`. Two cautions: the gate and the
  predicate must stay in one closure, and Apple's sample spells the handler
  `[weak self]`, against this project's strong-capture lesson.
- `withTaskCancellationShield { }` guards engine teardown.
- `.alert(item:)` / `.confirmationDialog(item:)` remove the Bool-plus-optional
  pairing class and retire every `Binding(present:)` call site with the helper —
  **and the waiver below with it.** Count lives in
  `grep -rn 'Binding(present:' DGTStudioPro/`, not in a sentence.
- `@diagnose` for scoping a single deprecation to one declaration with a
  mandatory reason. Its headline use — staging a language-mode migration — is
  spent; D43′ made that migration in one pass.

**Real, but wait for a measurement or a surface**

- Ownership and specialization for the perft hot path. `~Copyable` collides with
  chess-core purity, and generated move order is what the perft counts were taken
  against — perft is both witness and veto. The Instruments pass (M17 since
  the 23 August rewrite) gates it.
- `ModelResultsObserver` / `HistoryObserver` — candidates are
  `backfillPlayerLinks()` and `backfillPlayerTagNames()`.
- `@Attribute(.codable)` names D12′'s arrangement rather than changing it, and
  would have to preserve D36′'s defaulting decoder rather than replace it.
- Toolbar composition; `@Query(sort:, sectionBy:)` native sectioning.

**Small, cheap, no downside beyond being beta**

`CommandMenu` icons via `.labelStyle(.titleAndIcon)`; `@Environment(\.appearsActive)`;
memberwise-init broadening (check, don't assume); `Dictionary.mapKeyedValues` /
`MutableRef`; `weak let`; two-way XCTest ↔ Swift Testing interop; Liquid Glass
arrives with no diff; Xcode 27 agent skills, for which these agreements are the
natural content.

**Considered and not applicable — recorded so it is not re-derived**

`WritableDocument` / `ReadableDocument`; `@available(anyAppleOS 27, *)`; the `@c`
attribute; `AsyncImage` caching; drag-to-reorder; cross-platform `FilePath`;
module selectors; `ProgressManager` / `Subprogress`; `ContentBuilder`.

## Assumed-never (do not design for these)

Chess960; two same-colour kings; mid-game board flips; occupied-only boards;
Bluetooth boards; live engine eval during play; takebacks of committed legal
moves.

Player rename/merge/delete left this list — built (D37′–D40′), with merge
subsequently un-built by D52′ as *surface*, not as concept. Automatic orphan
collection also left it, in two steps (D50′ then D60′), and took the whole idea
with it: "nothing collects unasked" is no longer true of this app. **DGT clock
support / move timestamps left it 26 Aug 2026** — the 23 August rewrite had
already scheduled it as M20 without correcting this list (the stale species,
caught three days later), and the same week it was withdrawn to the roadmap's
Horizon as post-GM work: planned-later now, never never. A document-based
architecture stays not-applicable rather than assumed-never.

## Waiver register

A waiver is a decision, not an omission. Views are out of scope by design and are
not listed individually; a view with **no preview** needs its own entry.

| View | Reason no preview | Witness |
|---|---|---|
| `BoardDestination` | needs session, connection, log, queue registry and a container — a canvas would be a second app | live-play manual checks |
| `DGTConnectionView` (dialog body) | `status` is `private(set)`, so a canvas can pass no state. The shipped not-found preview is honest **only with the board unplugged** — it takes a live `DGTConnection`, and `onAppear` runs a real IOKit walk and will open the port (24 Aug 2026; the old reason named `DeviceRow` and a load-error arm, neither of which exists) | connect-flow manual checks |
| `Inspector+Toolbar` | toolbar content with no standalone visual | the destinations that apply them |
| `DGTConnectionToolbarContent` | the `ToolbarContent` wrapper has no standalone visual — but `ConnectButton`, the plain `View` it wraps, has five (24 Aug 2026: splitting the button out retired this row's original reason, and nothing replaced the coverage) | connect-flow manual checks |
| `AnalysisQueueStatusWindowView` | `queue` is `private(set)` by design; the states worth seeing need an engine subprocess and a container | ships the idle-branch preview; the rest is the batch checklist |

| Type | Reason | Witness |
|---|---|---|
| `TabState` | plain state holder | `BoardDestination`, its one driver |
| Serial transport (`DGTSerialPort`, `DGTSerialDevice`, `DGTDeviceDiscovery`) | hardware I/O; decisions extracted pure into `DGTAutoConnectPolicy` | manual hardware checks |
| `DGTConnection` (port/timer half) | status machine suited; serial half is transport | manual hardware checks |
| `GameAnalysisDriver`, `AnalysisQueueController` | engine + SwiftData transport; branching extracted pure into `AnalysisQueue` | `AnalysisQueueTests`, `AnalysisQueueControllerTests` |
| `CollectionViewMode`, `TagColor` | presentation value types, exhaustive switches. `BoardStyle` and `SquareHighlight` left this row 26 Aug 2026 (M18 Phase 1) — each gained a suite pinning what the compiler cannot see (persisted raw spellings and the one-lowercase-word rule; six distinct single bits); their color and style switches stay compiler-witnessed | compiler exhaustiveness + previews |
| `EngineProgress` | pure payload — four stored properties, a synthesized memberwise init, no branches; a suite could only re-assert the compiler (M18 Phase 1 disposition, 26 Aug 2026) | constructed by `StockfishEngine` (its gated suite), rendered by the queue window's formatters |
| `StorageKeys` | constants namespace | compile-checked usage |
| `DGTSessionLog.exportViaSavePanel()`, `DGTSessionRecording.exportViaSavePanel()` | AppKit modal panels | export flow, run in anger 18 July |
| `PGNExporter` | AppKit panels + file writes; every byte from the pure serializer | `PGNSerializerTests` + export/re-import check |
| `LibraryFilter` | model-bearing composition; logic delegates to `TagRule.evaluate` | tag-filter manual checks |
| Illegal-move audio transport | thin system-alert playback; the decision is the `enterRecovery` edge | `onDesync` spy test + audibility check |
| `BoardSounds` — **the playback only** | `AVAudioPlayer` over a bundled file, which is transport. Every decision came out pure and is pinned rather than waived: `BoardCue.cue` classifies, `isEnabled(_:moves:captures:checks:checkmates:)` gates, `isAudible(in:)` decides. What is left is loading a URL and restarting a clip (D81′) | `BoardCueTests`, `BoardSoundPreferenceTests`, plus the audible checklist above — which is also the only witness that the four samples are **in the bundle**, since a missing file and an off toggle sound identical |
| `SleepInhibitor` — **the token only** | a `ProcessInfo` activity handle, which is transport. The *decision* came out as the pure `activityReason(…)` and is pinned rather than waived | `SleepInhibitorPreferenceTests`; `pmset -g assertions` |
| `SessionPhase` | reads two `@MainActor` app-global observables whose flags are computed, not settable — a suite would have to fabricate a connection to assert an ordering | its two consumers, which must agree, plus the sidebar checklist. **The ordering is the content**, and nothing automated checks it |

**Test-only by decision, not gaps:** `FEN.legalMoves()`; `CastlingRights`' no-arg
init; `Square.dgtField`; `DGTBoardDiff.changedSquares`; `Evaluation`'s eval-tag
emitting half; `DGTSessionLog.clear()`; `FEN.startingString`;
`DGTSessionRecording.decoded(from:)`, `.reconstructions(from:quiescence:)`,
`.settledBoards(quiescence:)` and `Step` (added 24 Aug 2026 — the whole Replay
Analysis extension is test-only, and listing two of its four members read as if
the others had consumers); `DGTReconstructor.move(from:to:promotion:in:)` (same
sitting — `reconstruct` matches against its own `legal` array and never calls
it, so both callers are suites);
`AnalysisQueueController.shutdown()` (teardown, not a feature — one line from an
app-termination hook); `Evaluation.init?(parsingEvalTag:)`, `.evalTagContent`
and `.evalTag` (added 24 Aug 2026 — the importer strips the wrapper itself and
calls `init?(parsingEvalTagContent:)`, and export writes no evaluations, so the
full-tag pair exists as its own round-trip witness; the register previously named
only "the eval-tag emitting half", which left the parsing half unwritten);
`AnalysisQueue.failures` (same sitting — five sites ask `hasFailures`, which
exists precisely because the array form built the whole list to test emptiness); `OpenGamesRegistry.markDirty` (dormant with a *named*
future consumer and a live read side); `CollectionFoldCache.isCached` (the
property worth pinning is *that a hit is a hit*, and a cache whose only door
computes on demand cannot be asked that question without also answering it —
argued at the declaration, listed here 8 Aug 2026 because a waiver argued in one
place and absent from the register is a waiver that is implied rather than
written).

**Compiler warnings — one entry.**

| Site | Diagnostic | Reason | Expires |
|---|---|---|---|
| `Binding.init(present:)`, ×2 | capture of non-`Sendable` `Binding<T?>` in a `@Sendable` closure | `Binding` is not `Sendable` while its own initializer demands `@Sendable` closures. `T: Sendable` would fix it and lock out the `@Model` call sites; the alternatives are opt-outs this codebase has none of. Stays a *warning* under mode 6 — the compiler treating it as framework friction. | By deletion: the 2027 SDK's item-based alert APIs retire every call site and the helper. |

The waiver is written at the declaration as well, per the two-homes rule. **A
second entry on this table is a signal** — the app target went from 230
diagnostics to two in three annotations, so a new warning is far more likely to
be a real finding than an unavoidable one.

## Known open items — unscheduled

Everything scheduled lives in ROADMAP.md — and since the 23 August rewrite,
**almost everything that stood here is scheduled**: the two launch-warning
confirmations, the FocusedValue two-run check, the chevron's `EmptyView` gap,
import cancellation, the export-numbering and log-format verifications, and
the `LiveGameRosterForm` extraction are all **M16**; the FEN/GameState
collapse and the deferred renames are **M18**. Closed items are not kept here;
they are in `git log`.

- **`DGTSerialPort.isOpen` is kept with no consumer**, decided M12.3, disposition
  written at the declaration. Not D41′'s shape — `createdAt` was deleted because
  a sibling answered its question better, and nothing else in the app can say
  whether the descriptor is live. A plain accessor with nothing resting on it.
- **`BoardView.selectedSquare` and `OpenGamesRegistry.markDirty` are pre-wiring
  with dead branches in their consumers**, all named at their sites (M12.3).
  `selectedSquare` takes its default everywhere, so `squareHighlight`'s
  `.selected` insert and `SquareView`'s tint arm are unreachable — while a
  **preview passes `.selected` directly**, so the style renders on canvas and
  reads as live. A click-to-move or setup surface consumes all three by passing
  one value. Since the roadmap rewrite this carries an explicit contract: the
  wiring stays **because** the Horizon entries that consume it stay; if either
  entry is struck, its wiring goes in the same commit. The transferable part:
  a name scan reports a symbol as *referenced* and says nothing about whether
  its consumer's branch can execute.
- **Known costs, deferred until measured** (M17 measures — the census stays
  here because this document owns it; none scale-critical at personal size). `parseSAN` generates all legal moves per ply; the ECO table's
  ~3,800-row parse is warmed off-actor but never measured; `ECOClassifier`'s
  quadratic prefix re-join, bounded at 36 plies; pawn movegen builds its
  two-element capture-offset array per pawn per call in `legalMoves()` — the one
  non-static offset table, mechanical to fix but it touches `Chess/` and so
  inherits the deep-perft gate; `retag`'s per-game re-resolve and rehash, O(linked
  games) with an MD5 each, inside a modal save; `backfillPlayerLinks` is
  fetch-all-and-scan by necessity (relationships cannot go in a `#Predicate`),
  and `collectOrphanedPlayers`' global arm with it — though the editing doors
  scope to the displaced rows since D76′, and the converged stamp (D75′) stops
  the backfills re-running at all; `UCIProtocol.parse` allocates ~3 arrays per
  info line; `Position`'s `[Piece]` storage heap-allocates per `applying`; the
  New Game sheet folds `games.map(\.gameRecord)` per seat edit; the Library
  inspector's PGN section re-serializes per body pass while expanded
  (collapse-gated) — the columns detail was listed here as a second, *ungated*
  site and is not: it reads through `pgnTextCache`, keyed on `contentHash`. The
  entry had the two the wrong way round until 25 Aug 2026.

  *Corrected 7 Aug 2026:* the destination folds are **no longer** on this list.
  `Glicko1.histories` and `PlayerStats.index` per render, `LibraryFilter`'s
  `GameRecord` per game per render, and `AnalysisGlyph.isAnalyzed`'s per-row array
  scan were all memoized behind `CollectionFoldKey`. The remaining per-render cost
  in both destinations is the key build — two stored scalars per game, no blob
  decode.

  *Corrected 9 Aug 2026:* the Library's per-render sort followed — narrowing
  and sort sit inside the memo (D78′), so the ECO comparator's `ECOOpening`
  rehydration runs per recompute rather than per render, and the tag-rule walk
  with it.

  *Measured 25 Aug 2026 (M17's first real measurement, Release build):* **none of
  the above is what hitches.** Toggling the Library inspector in icons mode spends
  **~170 ms of SwiftUI update time per toggle**, and the PGN section is not in it —
  `LibraryInspectorView`'s body totalled **0.2 ms across 79 s** and `PGNSerializer`
  appeared **zero times in 2.25 M update rows**. The cost is the inspector column's
  *width animation*: `LazySubviewPlacements<LazyVGridLayout>` at 1.65 ms a pass
  (535 ms total), ~285,000 `LayoutChildGeometries` calls, and interpolated display
  lists for every card's text. Body invalidation was already handled by
  `IconGridView`'s column-count quantization (23 Aug) and that fix is working —
  `IconGridView.body` ran 118 times, card bodies ~220 per toggle rather than the
  ~1,200 an animation-rate rebuild would give. `InspectorToggleContent` now writes
  the flag inside a `Transaction(animation: nil)`; re-measure before believing it.
  **Two findings that stand on their own:** `LibraryDestination.body` costs **5.4 ms
  per evaluation** (43 evaluations, 232 ms) — 65% of a 120 Hz frame for one body —
  and the app issues ~90,000 SwiftUI updates in a second containing a toggle against
  2–7 ms in an idle one. Protocol and full numbers: `M17-HITCH-CAPTURE.md`.

  *Added 12 Aug 2026 (D81′):* `BoardCue.cue` pays a `legalMoves()` **in check
  positions only** — `isInCheck` is asked first and is a single attack scan, so
  the generation runs solely where `checkmate` is answerable. Once per committed
  move, or once per arrow keypress; deliberately not on the jump paths, which is
  the point of the step/jump split rather than a side effect of it. Named here
  because it is the one cost this feature adds, not because it is a candidate —
  at human move cadence it is orders below `parseSAN` above it.

## Manual checks

### Owed — not yet run, or run with an unresolved result

*Since the 23 August rewrite these are batched: everything boardless below
runs as **M16**'s recorded checklist pass; everything board-required runs in
**M21**'s single sitting, after the feature milestones, so nothing added later
invalidates the witness.*

- **The context-menu standardization (23 Aug 2026), all four modes × both
  collections.** Library: ⌘A in icons and in gallery, right-click a selected
  card — the menu must read counted plurals ("Open N in New Tabs", "Analyze",
  "Export N PGNs", "Delete N Games") with **no Get Info item**; right-click an
  *unselected* card — singular menu with Get Info, acting on that card alone;
  the menu's Open item opens the selection in **new tabs** (it opened one game
  in place until this pass). Columns: select five, "Delete 5 Games" must
  delete five after one confirmation — the fan-out bug deleted the last one —
  and "Export 5 PGNs" must run one panel. Players: multi-selection right-click
  shows **no menu items in any mode** (single-subject guard — it named an
  arbitrary member in list and columns before); single selection shows
  Get Info + Show in Library everywhere.
- **The inspector toggle, re-felt (23 Aug 2026).** In icons view (both
  destinations), toggle the inspector repeatedly on a full Library: the grid
  must track the slide smoothly, reflowing only at column boundaries — the
  per-frame whole-grid rebuild went with `IconGridView`'s `GeometryReader`.
  Confirm arrow-key ↑/↓ still step by the *visible* column count after a
  resize (the keys read the same settled count the layout used), and confirm
  the launch console stays free of the geometry-cycling line — the sixth
  arrangement that could have minted it, avoided by construction. Then toggle
  in **list** view: any remaining hitch there is `Table` live-resize,
  framework-side — record how bad it is; M17's SwiftUI lane adjudicates
  whether anything app-side is left in it.
- **The card inscription picker (23 Aug 2026).** ⌘J over the Library in icons
  mode: the Icon section's "Shows" picker offers Index / Result / Date /
  Round. Pick each and confirm the sheets rewrite immediately — the date as
  month-over-day, a drawn game as "½-½", never "1/2-1/2" — and that the
  gallery's filmstrip cards follow the same choice. An undated or unrounded
  game shows the dash, not an empty sheet. Quit and relaunch: the choice
  holds. Switch to list or columns, reopen ⌘J: no Icon section (the picker
  renders only where cards do); Players likewise. At the default (Index),
  compare a card against memory of the old rendering — it must be identical,
  because the default is the pre-picker pair verbatim.

- **Import cancellation (26 Aug 2026, M16).** Import a dozen files and press
  Cancel mid-run: the button disables at once (the request is in flight), the
  current file completes, the loop stops between files, the header reads
  "Import Stopped", and the summary carries "N not imported" beside what
  landed. ⎋ mid-run must still do nothing — the standing check holds; Cancel
  is the button alone, deliberately. A full drain must show no "not imported"
  part at all (zero is unrendered by arithmetic). Relaunch: everything the
  batch reached before the cancel is in the Library; nothing after it is.

- **D81′'s cues, and the first item is the one that already failed once.** Open
  any game and press → once. **The app must not quit.** As first shipped it did:
  CoreAudio killed the sandboxed process on the first playback for want of a
  mach-lookup exception, which is now in `DGTStudioPro.entitlements`. If it dies
  again, read the last line before the exit — the precondition names the service
  it wants, and the remedy is that array growing by one string. Nothing about
  this is checkable without launching.
- **Then: is there a sound?** A wooden knock on →. If it is *silent* rather than
  fatal, the samples are not in the bundle — `log stream --predicate 'category ==
  "sound"'` names the missing file, and the suite deliberately does not test
  bundle presence, because a missing resource and a disabled toggle sound
  identical.
- **The precedence rule, by ear.** Step to a capture (knock plus grit), then to
  a checking move (knock plus a bright blip), then onto a mate (knock plus a
  falling two-note figure). Then find a capture that *gives* check and confirm
  you hear the check, **not** the capture — one sound, never two. That is the
  rule the Settings footer states and the thing most likely to read as a bug.
- **Steps sound, jumps do not.** Hold → through a dozen plies: one knock per
  ply, no pile-up, no lag. Then press End on a long game: the position jumps and
  **nothing sounds**. Home likewise. Clicking a ply in the move list likewise.
  A burst of clicks on End means `jump(to:)` acquired the hook.
- **Retreat sounds with the landing position's cue.** Step ← off a checking move
  onto a quiet one: you hear the quiet one. The cue describes where you are, not
  which way you came.
- **Each toggle governs its own cue.** Settings ▸ Sounds ▸ Board Sounds: turn
  **Move** off alone and step through a game — quiet moves go silent while
  captures, checks and mates still sound. That is the crossable wiring the pure
  gate is tested against, checked here against the actual samples. Then quit and
  relaunch: the toggles persist.
- **Settings has five tabs** (12 Aug 2026) — General, Board, Sounds, Engine,
  Data. Open each and confirm the tab bar is not crowded at the 500 pt frame, and
  that every control is present exactly once: connection and the two sleep gates
  under General; the four cue toggles and the illegal-move alert under Sounds
  (the set picker this line named until 26 Aug 2026 left with the packs on
  17 Aug — the one-voice reversal reached the Sounds tab, not the tab split);
  depth/hash/threads and Syzygy under Engine. The split moved no
  control, default, key or identifier — **anything that behaves differently after
  it is a defect, not a design choice.**
- (**The two D82′ set-picker checks stood here until 23 Aug 2026** — audition
  on pick, set surviving a relaunch — six days after the feature they check
  was deleted: sound packs went to one voice on 17 August (`141b9fa`, nine
  cues over seven samples), and the checks outlived the picker the same way
  the make-cues generator entry below outlived its generator. Struck rather
  than run. The surviving D81′ cue checks above still apply to the one voice;
  M16's re-read ran 26 Aug 2026 and they hold as written — the precedence,
  step/jump, retreat and per-toggle checks describe cues, not sets. The
  re-read caught two more survivors instead: the five-tab check still seated
  a set picker under Sounds, and README's Sounds caption still said "sound
  set" over a screenshot of the deleted picker — text fixed, the re-capture
  owed with the boardless batch.)
- **Live play, with the board.** Play a move over the DGT and confirm the cue
  fires when the app *registers* it — roughly 300 ms after the piece lands, on
  the settle, not on the touch. That delay is the feature rather than lag: it is
  the app telling you it read the move. A cue that fires for a move the mirror
  did not commit is the F5 shape and should be reported.
- **⌘U stays silent.** The player is off under the test host, so a full run must
  make no sound at all. A suite that clicks its way through `GameTests` means
  `TestHost` stopped being consulted.
- (**"The generator runs"** stood here until 18 Aug 2026 — a standing check on
  `swift Tools/make-cues.swift`, owed since 12 Aug and never once performed. It is
  moot: the generator was deleted with the cue sets on 17 Aug, having never been
  executed. It is worth recording *why* it was deleted rather than finally run,
  because the check itself named the reason without drawing the conclusion — a
  generator ported by a hand with no Swift toolchain, whose output nothing loads,
  is a trap for the next reader, and six days of an unperformed check is the
  evidence that nobody was going to be that reader.)

- **Syzygy: does the sandbox let the child process read the folder?** Press
  Settings ▸ Engine ▸ Endgame Tablebases ▸ **Check** (the Engine *tab* since
  12 Aug 2026; this line read the same when Engine was a section under General,
  which is a coincidence worth naming so nobody reads it as already updated).
  Three readings, and they
  mean different things: *"290 WDL · 290 DTZ — engine says: Found 290…"* is
  working, nothing further owed. *"The app sees 290 WDL · 290 DTZ, but the engine
  loaded nothing"* is **the expected failure** — Apple documents child processes
  as inheriting only the *static* rights in the entitlements file, and a folder
  chosen in an open panel is granted after launch; the options then are turning
  `ENABLE_APP_SANDBOX` off (no App Store requirement here) or copying the tables
  into the app's own container. *"The app sees no .rtbw or .rtbz files here"* is
  the wrong folder — or, since 24 Aug 2026, no longer plausibly the app-side
  bookmark: `com.apple.security.files.bookmarks.app-scope` is in the
  entitlements file now, the key Apple's reference requires for the app-scoped
  bookmark `SyzygyLocation` stores (current macOS was observed granting without
  it; the line ends the disagreement with the docs rather than betting on it).
  **This is a genuine open question about the architecture, not a formality.**
- **⌘⌫, ⌘E and ⌘R with no menu open.** Select two games in list mode and press
  ⌘⌫. If nothing happens, **delete-by-keyboard no longer exists in this app** —
  the toolbar button carried the only known-live copy and was removed by request;
  the row menu's copy is known only to *render*. Whatever the answer, write it
  down; if they are dead, the remedy is a menu-bar `Commands` scene, and skipping
  it was decided with that on the table.
- **Does the gear loop?** The API half settled 24 Aug 2026: `.rotate` is an
  indefinite effect and `.repeat(.continuous)` is documented as repeating until
  disabled, so a still gear is no longer an API question. What the watch still
  owes is view identity — a state bug once pulled the glyph out from under the
  effect. Watch the queue item for a full minute of batch; a still gear after
  one turn means identity churn, per the note at `AnalyzingGear`. The
  **Every State, Both Titles** preview is the cheaper place.
- **Sleep inhibition, flipped mid-batch.** `pmset -g assertions` is the only
  witness the token has. The item worth running is toggling the *analysis*
  preference **during** a queue — an implementation that only releases when the
  queue drains passes every automated test in the suite.
- **Ten checkmate motifs, visually.** The smart-tag picker at ten items, the
  accented names (Anastasia's, Guéridon, Épaulette) in a 140 pt frame, and the
  Checkmate Type column after the backfill reclassifies an existing archive.
- **The 7 Aug performance pass** — see its own list below.
- **The 8 Aug sitting** — see its own list below.
- **The 9–10 Aug sittings** — see their own list below.

### The performance pass (7 Aug 2026, boardless except the last)

The memo is invisible when it works, so every check here is "confirm nothing
changed except the speed".

- **Rubber-band a large Library and a large Players list.** Both should stay
  smooth where they previously stuttered. Then confirm the *selection* is
  identical to before — the guard skips writes, it must not skip changes.
- **Type in both search fields.** Results narrow per keystroke exactly as before.
- **Switch the ranking method** (Wins / Win % / Rating) on Players: the badges
  renumber instantly, because the method is deliberately outside the memo key.
- **Import a game, rename a player, edit a result, delete a game.** Each must
  update both destinations immediately — these move the content hash, which is
  what the key reads.
- **Run a classification backfill** and confirm the Special Mates column moves.
  Classification is *outside* the content hash, which is why the key carries a
  second field; if that column freezes, the field was dropped.
- **The backlog count's new timing, which is the one behaviour change.** Start a
  batch and watch the Library subtitle. The unanalyzed count now drops when a
  game **finishes**, not at its first scored ply. That is deliberate; a game
  halfway through a pass is not an analyzed game.
- **With the engine: analyze an 80+ ply game with Players open in another tab.**
  This is the case the pass was written for — the per-ply save used to re-fold
  the whole Library eighty times. Scrub, switch modes and type while it runs.

### The 8 August sitting (boardless, engine for most)

- **The badges, all four modes (D72′, plain marks per the postscript).**
  Icons: every card wears a chip at the sheet's bottom-trailing — a plain
  green `checkmark.circle.fill` analyzed, a plain red `xmark.circle.fill`
  not, **no gear on the verdicts**; the bare gear appears only while the
  engine has that game. Gallery: same chip on the filmstrip cards. Columns:
  the same bare marks at each row's trailing edge. List: the Analysis column
  keeps the gear family — it is an action surface. Check one *dark-mode* pass
  over the cards specifically — the chip exists because the running gear
  inherits `.foreground` over an explicitly white sheet, and dark mode is
  where that fails without it.
- **The gear, live.** Start a batch and watch the running game's card or row:
  gear while the engine has it, verdict the moment it drains — and the badge
  must flip *at game end*, not at first ply. Whether the gear *loops* is the
  standing `AnalyzingGear` question; the badges add surfaces, not a second
  motion.
- **One counter (8 Aug).** With a batch running, the Library toolbar and the
  queue window on screen together: "3/110" and "Analyzing 3 of 110" must agree
  at every moment, including the first game (1, not 0) and after the drain
  ("110/110" beside "Analysis finished").
- **Per-game saves (D71′).** During a batch, a second window (Players, or a
  Get Info) updates when a game *finishes*, not while it runs — that is the
  cadence change, and it should read as the app being calm rather than stale.
  Skip a game mid-pass and confirm the queue window's cancelled row's promise
  holds: the partial evaluations survive a relaunch.
- **The stutter itself.** The 7 Aug check re-run under D71′: an 80+ ply game
  analyzing with Players open, scrub and type throughout. This sitting's bet
  is that the remaining hitching goes with the per-ply saves; if it does not,
  the next suspect is written down in the audit (the queue window's per-line
  search panel, throttling it the remedy).
- **Engine QoS.** With Threads raised in Settings, the UI stays fluid during a
  batch and Activity Monitor shows stockfish at a lower scheduling tier;
  throughput on a long game should be within normal variance of the last run
  (utility still reaches P-cores when idle — a batch that visibly slowed is
  the `.background` failure this deliberately avoided).
- **The gallery (8 Aug).** Select a rated player in gallery mode: eight facts
  in the grid (Uncertainty, First/Last Played new), the trend line beneath,
  filmstrip still pinned to the bottom edge. An unrated player: em dashes in
  Rating and Uncertainty, no chart, no gap where it would have been. The
  columns detail shows the same eight-fact grid — one grid, both hosts.
- **The Analysis Data window (D73′).** The table button beside the magnifier
  in the Library inspector's Evaluation header opens the per-ply table; on a
  *skipped* game the unscored tail reads em dashes, never "0.0" — that is the
  window's whole honesty claim. Two games' data windows tab together and
  neither floats. The button on an unanalysed game opens the No Analysis
  state. Get Info's File tab shows **no Analysis section** any more.
- **Depth holds still (D73′).** Watch the queue window through a full game:
  the Depth fact reads the configured target (18) from first ply to last, and
  changes only when Settings does. Motion belongs to the progress bar,
  evaluation and speed beside it.

### The 9–10 August sittings (boardless; engine for the first three)

- **Incremental analysis (D74′).** Analyze an already-analyzed game again: it
  finishes immediately and the engine never launches (Activity Monitor shows
  no stockfish). Analyze a game with a gap — a skipped tail, a fresh import:
  only the gap searches, and the queue's ply label reads "N plies to search"
  with progress counting the searchable set.
- **The book skip, visibly.** A freshly analyzed game's Data window reads em
  dashes over its classified opening plies — unscored, never `0.0` — and the
  first scored ply after the book carries **no swing** (D77′'s gap rule).
- **Deepening.** Raise the target depth in Settings and re-analyze one game:
  it searches again, because the stored depths sit below the new target — and
  a second run at the same setting is the instant no-op above.
- **The stamp (D75′).** `category == "players"` logs the heal once, then stays
  silent across Library visits and relaunches. Settings ▸ Data ▸ Erase Library
  re-arms it — the one gesture that must, because it deletes what convergence
  was measured against.
- **Scoped collection (D76′).** The D60′ standing checks verbatim — a
  re-spelled seat vanishes from the menus, a rename onto an exact tag relinks
  and collects — the doors now asking only about the rows the edit displaced.
- **The swing column (D77′).** Signed percentage points per row, `+0` for a
  flat step, bold at |Δ| ≥ 15 pp, and empty beside any em-dashed evaluation.
- **The memo (D78′).** Type in both search fields, re-sort, then export a
  multi-selection after the re-sort: numbering still follows *screen* order —
  the memo must change speed and nothing else.
- **The red ply (D79′).** Get Info game 98 ▸ Move Text: `Qf4+` reads red **on
  open**, the status line naming it. Type the `x` — red clears, Save enables.
  Typing at the edge of a red run must not spread the colour past the token.
- **Companions over full screen (D80′).** Main window full screen: open the
  graph, the data window, a Get Info, the queue window and ⌘J. Each appears
  over the board — no Space switch, no companion claiming its own full
  screen. This is the fix's whole witness; scene modifiers have no unit seam.

### Needs the board

Launch auto-connect on/off; remembered-board-absent is a silent no-op; mid-game
cable pull reconnects silently; discard mid-outage stands the loop down;
recording start → cable pull → stop-and-export produces a coherent file; illegal
move audible with the toggle on and silent off; no idle-sleep across a long think
while the display dims, and the Energy toggle off means the Mac *does* idle-sleep
mid-game; a recording survives an idle window; one desync worked through from the
sidebar checklist; New Game with two known players prefills Round; a game played
and archived this build exports `[Board "DGT …"]` matching the connected board's
serial, and still carries it after a draft resume across a relaunch.

**Piece animation (D47′):** a *slid* pawn glides on the mirror; a deliberate
lift-think-place fades out and in with no false glide between; a fast O-O
animates; the connect-time board dump **fades** in — if thirty-two pieces fly,
the anonymous-key rule is broken. Force a desync and confirm the recovery
overlays and ghost never animate while pieces fade honestly.

### Boardless — the standing list

**Library and Players.** Import one game out and back in clean; multi-selection
export into a folder, numbered in *screen* order after a re-sort (that is the
whole reason the sort lives on the destination); open a Library game and confirm
it loads; ⌘A in each of the four modes selects every *visible* row and no more;
sort by a column then narrow with a query and confirm narrowing survives; single
game delete asks from ⌘⌫ and the row menu, and **plain ⌫ does nothing**; ⎋ during
import keeps the sheet up; the sidebar Tags header's + button opens the editor.
Quit and relaunch: sort, hidden columns, icon size and grid spacing all persist.

**Get Info (three tabs).** Details commits per field on Return *and* on focus
loss; an unchanged value writes nothing (watch `category == "library"` stay
silent); an emptied Event reverts while an emptied Time Control clears to nil.
The File tab has **no Analysis section** since 8 Aug 2026 — coverage lives in
the Analysis Data window (D73′).
Editing White on Details moves *this game*; editing the field on the player tab
rewrites **every** game that player appears in — same-looking field, blast radius
of one versus forty, worth seeing once. Result refuses a value the final position
disproves and accepts anything it cannot. Move Text: an illegal ply disables Save,
names the first bad one and paints it red in the field (D79′); Revert restores
the last *saved* text; Return inserts a newline rather than committing. After any
edit, export and re-import — refused as a duplicate of itself.

**Batch analysis.** Queue 3+, drain count, skip mid-pass, delete waiting and
running, Stop All exits the process, a forced failure persists a warning until
Dismiss. The queue **window** opens once and comes forward rather than
duplicating, is *not* restored at launch, shows the live search panel (move in
chess notation, the configured depth holding still — it climbed and reset per
ply until 8 Aug 2026, which read as the setting bouncing — evaluation, speed),
reads
"Waiting for the engine…" between plies rather than a row of em dashes, lists
finished games newest-first with cancelled as **grey** rather than a warning, and
keeps Stop All pinned below the scroll. Start a batch from a Library tab and
**close that tab** — the run must continue.

**Evaluation bar and graph.** The bar is exactly the board's height, pinned to
the window's leading edge, with the board centred in the *window* rather than in
the leftover space — only visible at wide widths. The score sits in the gap,
vertically centred, never on the bar, and the board must not resize as the score
changes. Flip the board: the fill flips, the label does not. An unanalyzed game
shows neither. The graph window opens once, does not tab with game windows,
tracks the ply under the pointer, and blanks the read-out when the pointer
leaves. Over a full-screen board it appears in place rather than switching
Spaces, as does every companion (D80′).

**Logging (D63′).** ⌘U's console should carry Swift Testing's output and
**nothing from the app**. Then set `DGT_LOG=1` in the test scheme and confirm it
all comes back — **that is the check worth doing**, because a suppression whose
escape hatch does not work is a blind suite, not a quiet one. Only the exact
string `1` arms it.

**Orphan collection (D60′).** Get Info a game, change White to a name nobody has,
Return — the name appears in the seat menus. Change it back, Return — it must
**vanish**. Rename a player onto another's exact tag: the games relink and the
loser disappears, which is the merge replacement D52′ promised without a merge
door.

**Only if the toolchain moves (D27′):** Liquid Glass screenshot pass over the
board chrome and all four view modes × three destinations.

## Reference material worth pinning as fixtures

The 20 July field session's two DESYNC positions — pinned as
`DGTReconstructorTests`' two field-desync fixtures, with Swift Testing PNG
attachments so a failure hands you rendered boards rather than 64 sorted squares.

The three DGT reference exports — `PGNSerializerTests`' bundled resources, under
`DGTStudioProTests/PGN/PGNs/`.

The five lichess ECO volumes — the first data asset the *app* ships rather than
the test target, under `DGTStudioPro/Chess/ECOs/`. Fetched from source, never
transcribed, and not landed until tracked.
