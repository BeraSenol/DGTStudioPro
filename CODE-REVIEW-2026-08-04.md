# DGT Studio Pro — code review, 4 August 2026 (evening): dead code, stale claims, the unrecorded milestone

Read against `7390227` ("Way Too Much Sorry") plus the working tree as found.
Successor to `CODE-REVIEW-2026-08-01.md` and the 3 Aug audit; nothing they
closed is re-derived here. This pass covers the four commits and the working
tree that post-date them — which turns out to be where nearly everything
lives, because the tree contains **a milestone the record does not**.

House rules observed: no D-numbers minted, every count carries its method,
anything needing a run is an expectation and not a claim. Commands in the
appendix.

---

## Tree state at read time

`git status` first, per the standing agreement. Not clean, three entries:

- `DGTStudioPro/Library/LibraryColumnsView.swift` — modified: `.layoutPriority(1)`
  on the list pane plus a `.width(min:ideal:max:)` on the Name column, both
  documented to house standard with observed-on-4-Aug provenance.
- `DGTStudioPro/Players/PlayersColumnsView.swift` — modified: the same
  priority fix, plus the `List` → one-column `Table` conversion (the Library
  twin's shape) and the per-row context menu moving to a selection-typed one.
- `DGTStudioPro/Players/PlayerActionsMenu.swift` — **untracked**, 52 lines,
  created today.

The dirt is a coherent in-progress pass, named rather than discovered — but it
carries a live hazard the previous seven instances did not: **the untracked
file is load-bearing for a tracked one.** `PlayersColumnsView.swift:112`
references `PlayerActionsMenu`, so committing the two modified files without
`git add`-ing the third produces a tree that does not build. This is the
30 July resource-death shape (unstaged deletes beside untracked copies) with
the failure upgraded from "a test can't find its fixture" to "the app target
doesn't compile." One `git add` retires it.

`HEAD` is `7390227`; 223 tracked sources by `git ls-files '*.swift' | wc -l`,
reconciling with the instructions' "221 at `b2f3c32` plus edits" via the tip
commit's +3/−1 (`GetInfoWindow`, `GameActionsMenu`, `PlayerRatingGraph` in;
`MergePlayerSheet` out). Counted, not assumed.

---

## What checked out

Named with methods, because the findings below are only credible against the
clean runs.

**Hygiene, all clean in the app target.** Zero TODO/FIXME/HACK markers. Zero
`DispatchQueue` / `NotificationCenter` / `Thread.sleep` / `import Combine`.
Zero concurrency opt-outs (both prohibited spellings, grepped verbatim). Zero
`print(`. Zero `as!`/`try!` outside one `#Preview` container build and the
App's container `fatalError`, both correct. Every `try?` site read: all are
best-effort sends, sleeps, or guard-let parses — no swallowed save.

**Symbol-level dead code: the scan reproduces.** 1,809 declared names
extracted and cross-referenced against the full token stream (the 3 Aug
audit's method; it saw 1,589 at `772ecb3` — the delta is the burst's new
files). Exactly two names occur only at their declaration, both in
`AccessibilityID` (finding R3/R4 below). `DGTSerialPort.isOpen` keeps its
open-items seat; nothing new joined it.

**Invariants hold where they are checkable by grep.** One content-hash recipe
(model-typed forwarding to field-taking, `Insecure.MD5` once).
`CollapsibleSection` is the only `InspectorSectionHeader` caller. Every
`StorageKeys` entry has a consumer. Every `.disabled(…)` guard's enabling
value is producible — including the four in `GameNavigationCommands` — with
one vacuous case noted at R2 (a guard inside a sheet that cannot present).
`Destination` has three cases; no `rankings` residue outside past-tense
provenance. The two waived `Binding(present:)` warnings remain the register's
only compiler entry, unchanged.

**`PlayerRatingGraph`, read in full: clean.** The y-domain is degenerate-safe,
the 1-based x-domain pin and the de-localized axis labels carry their reasons,
and the four previews include the fixture whose point is what it *doesn't*
show. No findings in the file most-touched by hand tonight.

---

## Findings

### The headline: M10 exists only in code

`grep -c "M10" PROJECT-INSTRUCTIONS.md ROADMAP.md` → **0 and 0**, against
thirteen `M10` references across eight app sources and one test suite. What
shipped under that number, reconstructed from the sites: the Get Info system
(`GetInfoRequest`, `GetInfoMenuItem`, `GetInfoWindow`, the third `WindowGroup`,
a registry group, ⌘I on six context menus); the **removal of the Players
rename pencil**; the **removal of the Library inspector's name editor**
(`nameEditor` / `beginEdit` / `commitEdit`, deletion-commented in place); the
**removal of the Board's Edit Moves pencil** — movetext now read-only in both
branches, deliberately, with Decision #1 argued at the site; a recorder growth
bound (M10.2, suited); and a planned `PGN.libraryIndex` ("M10 batch 1").

Individually these are documented to house standard *at their sites* — the
Board comment even names what goes surface-less. What's missing is the record:
no roadmap entry, no D-number, no strike-through on the claims it falsifies.
The instructions' "Built and in use" list still asserts **movetext editing by
full replay** and **players can be renamed through one store door** — both
false in the running app today (R1, R2). This is the working agreements'
recurring failure at a new size: not an uncommitted delivery but an
**unrecorded milestone**, sitting in a commit whose message is an apology.
Two of its removals also overturn surfaces that locked decisions built (D18′'s
editor, D37′'s dialog); reversals at that grade have always gotten their own
D-numbers.

### R — reachability dead code

The token scan cannot see these: every symbol is referenced, and no control
invokes the chain. A quantifier over *surfaces*, checked by walking each
closure to a rendered control.

**R1 — player rename is unreachable.** The full chain survives:
`beginRename(stats:)` → `RenameRequest` → `.sheet` → `RenamePlayerSheet` →
`rename(key:to:)` → `PGNStore.retag` with D39′'s pre-flight and the refusal
alert. Its sole trigger is `PlayersInspectorView`'s `onRename`, threaded to
`ProfileContent` and invoked by nothing — the pencil is gone (M10) and Get
Info, the declared successor, is read-only (S1). The site comment is honest
("`onRename` deliberately survives with no caller for the length of one pass…
this comment is a deadline, not a description") — but with merge removed
(D52′) and the pencil removed, **the app currently has no door that writes a
player's name**, and the deadline exists only in a comment the roadmap has
never heard of. `RenamePlayerSheet`'s three previews are now its only render
context (W2).

**R2 — movetext editing is unreachable.** `BoardDestination` still wires the
`.movetext` editor case, presents `MovetextEditorSheet`, and calls
`applyMovetextEdit`; the only setter is `onEditMoves:  { activeEditor =
.movetext }`, which `BoardInspectorView` accepts and never renders a control
for (verified: no menu-bar item either — `GameNavigationCommands` is four
navigation buttons). D18′'s replay validator, the splice refusal, the store
door and its suite all stand as compiled, tested, dead weight behind a closure
nobody calls. The five `movetextEditor*` identifiers now name controls that
cannot render — they pass the registry's referenced-grep while being
unreachable, which is that grep's blind spot. Either the read-only decree gets
recorded and this wiring (sheet, editor case, identifiers) leaves with it, or
the pencil returns; the current state is the worst of both.

**R3 — `getInfoBoardMenuItem` was minted for a control that was never
built.** `GetInfoWindow`'s doc: "The Board's copy lives in
`GameNavigationCommands` instead." It does not — zero Get Info references in
`Game/` (grep). A named consumer that doesn't consume, in a file created
today. Consequence: **the Board destination and the live game have no Get
Info door at all** — ⌘I exists only on Library/Players context-menu items, so
`GetInfoRequest.live` is constructible and nothing constructs it (the `.live`
arm of the window is reachable only via scene restoration of a window that
could never have been opened).

**R4 — `boardEditMovesButton` survived its affordance.** The Edit Moves
pencil is deleted; the identifier stays. D40′'s rule — a removal is as
breaking as a rename and travels with the affordance — applied to
`players.inspector.deleteItem` and `library.inspector.pgn.disclosure`; this
one was missed. With R3 it makes the registry two entries over-true: 141
constants/functions by grep against the header's "143," both dead ones minted
or stranded inside a week.

### S — stale comments and false claims

**S1 — `GetInfoWindow` describes its destination, not its code.** The header:
"the one editable surface behind every inspector's subject." The App scene
comment: "Get Info is *edited*, so it takes focus" (justifying the non-floating
level). Every row in all three forms is `LabeledContent` — the window edits
nothing. Two comments assert a capability that is somewhere between planned
and removed-with-the-pencils; until batch 2 lands they are the
comment-asserting-a-guarantee shape, in the newest file in the repo.

**S2 — the unavailable state claims a case the mechanism cannot deliver.**
Its doc: "every way a subject can be absent — deleted between the gesture and
the render, **a live game that ended**, a window restored from a previous
launch." Resolution runs in `.task(id: request)`; for `.live` the request
never changes, and nothing in `body` observes `session.liveGame`. A live Get
Info window open at archive time keeps rendering the retained `LiveGame`
under "Recording" indefinitely — the ended game never lands on `unavailable`.
The D44′ species: a claim no caller is positioned to contradict (today
nothing can even *open* that window — R3 — which is why it has never been
seen). If the Board door lands, this becomes user-visible; the fix is either
observing `session.liveGame` in `body` or re-resolving on it.

**S3 — both of today's extractions say "once" and neither is.** The
fifth-species shape, twice, in files created today. `GameActionsMenu`: "The
Library's context menu, once" — narrating that editing three menus by hand
"stopped being tolerable" — while `LibraryListView` still hand-builds
Open / Get Info / Analyze / Export / Delete (the superset shape the type says
it was built around). Adoption: 2 of 3. `PlayerActionsMenu` (untracked):
"three hosts had three hand-built copies" — `PlayersListView` and
`PlayerCardView` still carry theirs. Adoption: 1 of 3. Both docs read as
completed unification; both describe the intended end state of a pass that is
mid-flight. Finish the adoptions in this pass, or make the docs name the
deliberate non-adopters — the sentence "which is how the Library's three
drifted" is currently describing the file it lives in.

**S4 — one present-tense survivor of the D51′ tense sweep.**
`SmartTagCommands.swift:38`: "reachable by everything — pointer, keyboard,
VoiceOver, **and the UITest suite, which already drives** the Game and
Diagnostics menus by title." The suite is deleted; the sweep's own grep
(`grep -rn "UITest" DGTStudioPro/`, read for tense) surfaces it. One hit in a
sweep that corrected roughly a dozen — a good ratio, and still one.

**S5 — `InspectorEditButtonView` anchors on a deleted precedent.** Its header
justifies the header placement by agreement with "`BoardInspectorView`'s Edit
Moves," which no longer exists. The paragraph's argument stands on its own;
the witness it cites is gone (M10). Same file, same week, second instance of
the pattern its own doc history records.

**S6 — the instructions' "no note-to-self arrows anywhere in production
sources" is no longer true.** Two scheduled-work comments live in the tree:
"The Index row lands with `PGN.libraryIndex` (M10 batch 1)" and the R1
deadline comment. Both are better-written than the class the claim was minted
against, and both are still scheduling work in comments while the roadmap —
the document that owns scheduling — has never heard of M10. Either the
roadmap absorbs them or the claim gets struck.

**S7 — in the dirty diff itself: "min only" beside three arguments.**
`PlayersColumnsView`'s new column comment opens "160 floor, min only — the
Library twin's reasoning applies verbatim," and the next line passes
`min: 160, ideal: 200, max: .infinity`. The Library twin's reasoning is
explicitly *all three, not min alone* ("the min-only spelling did not hold
the floor in practice"). The comment contradicts both its code and the twin
it cites — cheapest possible fix while the hunk is still uncommitted.

**S8 — D52′'s "the header is back to pencil + chevron" lasted hours.** The
same commit that records it also removes the pencil (M10). Docs-follow-code
already owes this line a correction as part of the M10 recording; noted so
the recording pass catches it.

### W — witness gaps

**W1 — the burst's view types have neither previews nor waiver rows.**
`GetInfoWindow` (four render branches, zero previews), `GameActionsMenu`,
`PlayerActionsMenu`, and `AnalysisLabel` (a `View` living beside the
`AnalysisGlyph` enum — the 4 Aug waiver row covers the enum's three statics,
arguably not the view). `SessionPhase` — "the ordering is the content," two
consumers that must agree — has no suite and no register entry, despite being
exactly the `RecoveryGuidance` shape whose ordering the project considers
pin-worthy. The agreement is one row or one preview each; `GetInfoWindow`'s
three forms are `#Preview`-able with an in-memory container, and the two
menus are trivially so.

**W2 — `RenamePlayerSheet` is witnessed only by previews of an unreachable
feature** (R1's corollary). Whatever R1's resolution, the register should say
which side this row is on.

### P — performance

Nothing new rises above the census. The known-costs list is honest and
current — the D48′ `Glicko1.histories`-per-render line and the
`AnalysisGlyph` scans are already recorded there; the flat-columns `pgnText`
serialization is censused at its site. One small observation for the census
only if it is ever felt: `GetInfoWindow`'s player form faults both
relationship arrays to answer three counts — correct at personal scale, and
the doc already argues why it doesn't fold `PlayerStats`.

### H — judgment calls worth one line each, not defects

**H1 — the one-board decree now fails silent instead of noisy.** Pinning
`kIOTTYDeviceKey` to `usbmodem01`'s TTY name means a re-enumerated board
(different port, hub, or a replaced cable changing the modem suffix) is
*invisible* to discovery rather than filtered late — the log's
present/absent echo is the only tell, and "absent" is indistinguishable from
"unplugged." Accepted under the decree (one person, one Mac, one board);
named because the failure mode changed shape today, and the person debugging
it in six months is the person who chose it.

**H2 — `contextShowInLibrary` is one identifier for up to three surfaces**
(list, columns menu, card). At most one view mode renders at a time, so no
collision is possible today; the parametrized-per-destination pattern
(`getInfoMenuItem`) exists one line away if a per-mode distinction is ever
needed. Fine as is.

---

## Suggested order

1. **`git add DGTStudioPro/Players/PlayerActionsMenu.swift`** before anything
   else touches the tree — it converts a build-breaking partial commit into
   an ordinary one. (Tree state, above.)
2. **Finish the dirty pass's own claims**: S7's comment, and either complete
   the two menu adoptions (S3 — `LibraryListView`, `PlayersListView`,
   `PlayerCardView`) or re-word both "once" docs. All four files are already
   in motion; this is the cheap moment.
3. **Record M10** — roadmap entry, D-numbers for Get Info and for the
   movetext-read-only reversal (it overturns a locked decision's surface),
   strike the two false "Built and in use" claims, absorb S6's two scheduled
   comments, fold in S8.
4. **Resolve R1/R2 by decision, not by drift**: land Get Info editing (which
   discharges R1 and S1 together) or restore/record; for R2, either the
   read-only decree takes the sheet, the editor case, and five identifiers
   with it, or the affordance returns. Half-states are what the token scan
   can't see.
5. **Registry hygiene**: delete `boardEditMovesButton` and
   `getInfoBoardMenuItem` (R3/R4, with deletion comments per the rule);
   decide the `movetextEditor*` family under R2; build the Board's Get Info
   door if the window's doc is to stay true.
6. **Comment corrections** S1, S2 (or the `liveGame` observation fix), S4,
   S5.
7. **Witness rows** for W1's five types — previews where cheap, register rows
   where not.

⌘U owed after 2, 4 and 5; expected green, never claimed.

---

## Appendix — commands behind the claims

```
git status --porcelain=v1                            # 2 M + 1 ??
git ls-files '*.swift' | wc -l                       # 223
grep -c "M10" PROJECT-INSTRUCTIONS.md ROADMAP.md     # 0, 0
grep -rn "M10" --include="*.swift" DGTStudioPro DGTStudioProTests   # 13 sites
grep -rn "onRename\|onEditMoves" --include="*.swift" DGTStudioPro   # R1, R2 chains
grep -rn "Get Info\|getInfo" DGTStudioPro/Game/      # 0 → R3
grep -rn "TODO\|FIXME\|HACK" --include="*.swift" DGTStudioPro       # 0
# declaration/token cross-reference (R-scan, 1,809 names):
grep -rhoE "(func|var|let|struct|class|enum|typealias) +[A-Za-z_][A-Za-z0-9_]*" \
  --include="*.swift" DGTStudioPro | awk '{print $2}' | sort -u > decls
grep -rhoE "[A-Za-z_][A-Za-z0-9_]*" --include="*.swift" DGTStudioPro DGTStudioProTests \
  | sort | uniq -c > tokens
awk 'NR==FNR{c[$2]=$1;next}{if(c[$1]==1)print $1}' tokens decls
                                                     # boardEditMovesButton,
                                                     # getInfoBoardMenuItem
grep -c "internal static let\|internal static func" DGTStudioPro/App/AccessibilityID.swift  # 141
grep -rln "InspectorSectionHeader(" --include="*.swift" DGTStudioPro \
  | grep -v CollapsibleSection                       # only the type's own file
for k in $(StorageKeys names); do grep -rl "StorageKeys.$k" …; done  # all ≥ 1
grep -c "#Preview" <each new view file>              # W1 zeros
```
