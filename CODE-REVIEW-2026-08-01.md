# DGT Studio Pro — code review, 1 August 2026: cleanliness, error handling, performance, staleness

Read against `c540d4f` plus the working tree as found. **Companion to
`AUDIT-2026-08-01.md`**, which was already sitting untracked at the repo root
when this pass opened: that document owns chess correctness (its C1–C10) and
process/architecture (its A1–A6), and nothing there is re-derived here. This
review covers the axes it left alone — code cleanliness, error handling,
performance, out-of-date comments, and dead code — from full reads of the
store, session, engine, movegen and all six M8 sources, plus repo-wide greps
whose commands are in the appendix.

House rules observed: no D-numbers minted, every count carries its method,
anything needing a run is an expectation and not a claim.

---

## Tree state at read time

`git status` first, per the standing agreement. Not clean, three entries, all
explained:

- `AUDIT-2026-08-01.md` — untracked, the earlier audit itself.
- `DGTStudioPro/Players/PlayersInspectorView.swift` — modified: the UNVERIFIED
  comment that audit's § Zero says it added. Consistent with its account.
- `DGTStudioPro/Players/PlayerCardView.swift` — modified:
  `.lineLimit(2, reservesSpace: true)` → `.lineLimit(2)`, **still contradicting
  the comment three lines above it** ("Two lines, always"), exactly as that
  audit flagged. If the change is deliberate, the comment must travel with it
  (the two-homes rule); if it was an experiment, it is a `git checkout` away.
  It has now survived into a second pass unresolved.

`HEAD` is `c540d4f`, one commit past the instructions' "tree at delivery
`caae1d7`" — the M8 recording commit itself. Consistent, not a finding.
Sources: 217 by `git ls-files '*.swift' | wc -l`, splitting 135/81/1 — all
three documented numbers reproduce.

---

## What checked out

Named with methods, because the findings below are only credible against the
clean runs — the project's own argument.

**Hygiene, all clean in the app target.** Zero TODO/FIXME/HACK markers. Zero
`DispatchQueue` / `NotificationCenter` / `Thread.sleep` / `import Combine`.
Zero concurrency opt-outs (the two prohibited spellings, grepped verbatim).
Zero `print(`. Zero `as!`. Zero legacy observation (`ObservableObject`,
`@Published`, `onReceive`, `Timer.publish` — repo-wide, including tests). Zero
raw accessibility-identifier string literals in views. One `try!`, inside a
`#Preview` body (`LibraryDestination.swift:764`) where crashing is the correct
behaviour. One `fatalError`, at `ModelContainer` creation, which is the
conventional and defensible place. Two `assertionFailure`s, both seed paths,
both paired with a log line for release builds.

**`try?` sites: 12 in code** (15 grep matches minus three that are comments
*about* `try?` — and this sentence was wrong twice in draft, 16→15 and 13→12,
caught by this review's own verification pass; the irony is noted). Every one
judged: six are cancellation-aware `Task.sleep`s; two are the engine-teardown
writes whose doc explains why swallowing is load-bearing
(`StockfishEngine.swift:325`); four are parse guards with an explicit fallback
path (`GameClassification:67` returns nil by design, `ECOTable:133`
skips-and-logs trusted content by decision, `parseSAN` guards in the driver
and preview-state each handle the miss). None swallows an error the design
says must surface.

**Every "one door" claim grep-verified.** `Player` construction only in
`resolvePlayer`. Classification columns written only in `classify`.
`recordDesync` called once, from `enterRecovery`. `NSSound` once, in the App
wiring. `Insecure.MD5` once, in `contentHash`. Seat-tag assignments outside
`retag` are `init`s, the seat picker's roster, and `BoardDestination:491` —
which is inside the `applyEdit` closure, i.e. the documented "user's own
metadata edit" exception, so the D37′/D38′ invariant holds. `Binding(present:`
call sites: **seven**, matching the helper's freshly-corrected doc.

**Dead-symbol scan: nothing new.** A declaration-vs-reference scan over all
135 app sources (every `func`/`var`/`let`/type declaration, references counted
repo-wide including tests) flags exactly one symbol referenced nowhere beyond
its declaration: `DGTSerialPort.isOpen` — the standing open item, undisturbed.
Method caveats, stated so the result is worth what it costs: a name mentioned
in a comment counts as a reference, and enum cases weren't scanned; so this is
a floor, not a proof. It agrees with the 30 July 495-declaration sweep, and M8
is the only code since.

**`InspectorSection` arithmetic reconciles.** The enum has **10 cases**; the
instructions say "fifteen sections". Both are right: `.roster` serves three
inspectors, `.opening`, `.evaluation` and `.moves` two each — 10 identities
over 15 host-sections. Recorded here so nobody burns a pass on the apparent
mismatch.

**GameAnalysisDriver, StockfishEngine, DGTLiveSession, PGNStore read in
full**: error paths route through `recordError` / typed errors / the teardown
invariants consistently. The engine actor's shutdown discipline (grace-period
`try?`, handshake-failure fan-in, idempotent teardown) is the best
error-handling code in the project and is documented as exactly what it is.

---

## Findings

### S — stale comments and decayed counts

**S1 · The registry count in the instructions is stale: 144 → 148.**
`grep -c 'static let\|static func' DGTStudioPro/App/AccessibilityID.swift`
gives **148** at head; the identical command against `f64b8d4` gives 144, so
the method reproduces the old number exactly and M8 moved it (the disclosure
function, the magnifier, the two window identifiers). `PROJECT-INSTRUCTIONS.md:518`
still says "the 144 identifiers are grep-audited at every sweep" — present
tense, D43′'s species. Cheapest durable fix is the countless form ("the
registry is grep-audited at every sweep"); a number there will decay again at
the next registry-touching milestone.

**S2 · `InspectorSectionHeader`'s head doc contradicts its own second
preview.** Line 31-33: "`InspectorEditButtonView` is what every host currently
passes, and a host with nothing to offer passes nothing." Two hundred lines
down, the *Actions — Every Arity* preview exists precisely because hosts now
pass four arities — lone pencil, chevron-plus-copy-glyph, pencil-plus-menu,
nothing — and its doc says so. The sentence was true before M5, misleading
after it, and false inside its own file since M8. One sentence to fix, in the
file that otherwise carries the best comments in the codebase.

**S3 · A caller count decayed inside the milestone that wrote it.**
`InspectorSectionCollapse.preview`'s doc: "thirty-one previews across fourteen
files need one." Greps: **33** `InspectorSectionCollapse.preview` references
across **15** files (`grep -rn`, one injection line per preview needing it —
method's the proxy, stated as such). The two build-fix commits after the D45′
pair added previews without touching the comment — which is the
enumerated-caller-list anti-pattern the `Binding(present:)` doc two files away
*names in itself as having been wrong twice*. Same remedy: drop the numbers
("every preview that renders an inspector section"), keep the reason.

**S4 · `InspectorSectionCollapse.preview` promises isolation it doesn't
provide.** Its doc: "a fresh instance per access is the *right* behaviour here
anyway — a preview that toggles a chevron should not leave that state behind
for the next canvas to inherit." But the accessor hands the fresh instance
`UserDefaults(suiteName: "preview")` — a **persistent** domain — and `persist()`
writes every toggle into it, so the next canvas's fresh instance reads the last
canvas's toggles back. The claimed behaviour needs one line, and the precedent
is one file away in the same target: `UITestSeed.scratchDefaults` calls
`removePersistentDomain` (`UITestSeed.swift:62`) for exactly this reason.
Second, smaller: the fallback is `?? .standard`, so the one failure mode ends
with a canvas *editing the developer's own defaults* — the M1 leak in
miniature — where `SettingsView:315`'s sibling site force-unwraps and would
crash instead. A crashing preview beats a silently leaking one. Suggested
shape:

```swift
internal static var preview: InspectorSectionCollapse {
    let name = "preview"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return InspectorSectionCollapse(defaults: defaults)
}
```

**S5 · `CollapsibleSection`'s doc says the environment is read "in one
place".** It is read in two — this type gates the body, and
`InspectorSectionHeader` draws the chevron — which the instructions record
correctly ("two files, both in `Inspector/`"). One word; worth it only because
the sentence sits in a doc whose entire subject is where state is read.

**S6 · A count without its method, flagged before it becomes the next 295.**
The instructions: "Re-run in full by the 30 July sweep across all fifteen
`.disabled(…)` sites." A raw grep today finds 18 matches — 17 code sites plus
one *doc comment* containing the pattern (`BoardInspectorView:28`) — and the
same grep at the sweep-era commit also finds 18. So "fifteen" was a different
counting method, and the method wasn't written down; that gap is exactly how
the unattributable 295 happened. Not necessarily stale — but the next sweep
can't re-run a check whose denominator it can't reproduce. For the record, the
17 current enabling conditions were re-checked and every one is producible;
the only site added since the sweep is D40′'s own `orphans.isEmpty`.

Micro, same family: the first `InspectorSectionHeader` preview is titled and
documented "All four inspectors' headers"; the app has five inspectors.

### E — error handling

**E1 · A pass whose saves all fail still reports `.done`.**
`GameAnalysisDriver.runAnalysis` logs and swallows each per-ply
`modelContext.save()` failure (`GameAnalysisDriver.swift:265-271`) and never
lets it touch `status`. For a dropped save or two that's the right call — the
next ply's save persists the whole context. The unhandled tail is systemic
failure (disk full, store wedged): every save fails, the pass ends `.done`,
the graph renders from the in-memory model, and the work is gone at relaunch
with nothing but Console knowing. Two honest shapes: escalate after N
consecutive failures into the `.failed` path the driver already has (its
message grammar already handles "kept up to here"), or record the swallow as
an accepted decision so it stops being an accident. The first is ~6 lines.

That is the only error-handling finding. The other axis — an interrupted
analysis being indistinguishable from a converged one — is the companion
audit's C5/C6 and isn't repeated here.

### P — performance

All unmeasured, so all M7-shaped: the suggestion in each case is a line on the
known-costs list, not a change ahead of Instruments. None is scale-critical at
one person, one Mac.

**P1 · Pawn movegen allocates its capture-offset table per pawn per call.**
`appendPseudoLegalPawnMoves` builds `captureOffsets = color == .white ? [7, 9]
: [-9, -7]` — a fresh array literal — on every invocation, in the innermost
loop of the hottest path (`legalMoves()` → per-candidate `applying`, the pair
the known-costs list already names). The step/slide tables are static on
`Square`; the pawn's is the one that isn't. Two static constants make it
mechanical, invisible to behaviour, and — because it touches `Chess/` — it
inherits the companion audit's C1 rule: not landed until deep perft has run
against it. Bundle with M7.

**P2 · The Library's filter fold is missing from the known-costs census.**
With a tag filter active, `filteredGames` runs `filter.matches(pgn)` →
`tag.matches(pgn.gameRecord)` (`LibraryFilter.swift:24`) — **a `GameRecord`
projection per game per body pass**. The known-costs list carries the
Players/Rankings folds and the seat-picker fold; this one is the same family,
triggered by the most body-invalidation-prone destination in the app, and
absent. One line to add. (In-memory matching itself is load-bearing by
invariant — nothing to fix, just to count.)

**P3 · Two M8 micro-notes, for consistency rather than cost.**
`EvaluationGraphWindow.curve(for:)` re-maps `pgn.evaluations` →
`[Double]` on every body pass, and body re-runs per pointer move — the same
class its own line-64 comment hoisted the store lookup to avoid, one order
cheaper. At 63 plies it is nothing; noted because the file's own standard was
set higher. And the Library inspector's PGN row re-serializes the game per
body pass — documented at the site, gated by the D45′ collapse, and also
absent from the known-costs list; if the list is the census, both belong on it.

### D — dead code

Nothing new. `DGTSerialPort.isOpen` remains the app target's one
consumer-less symbol, exactly as the open item records; the test-only-by-
decision set all show suite references in the scan. `SquareView.pieceID` and
`BoardView.selectedSquare` remain threaded-and-unread / built-and-unsurfaced
respectively — standing items with recorded dispositions (M6's currency, an
undecided surface), so deliberately not re-reported.

---

## Suggested order

1. **S4** — one real behaviour-vs-comment defect, a five-line fix with an
   in-repo precedent. **S2** and **S5** ride the same commit as one-sentence
   comment corrections in the same directory.
2. **S1, S3, S6** — the three decayed/unreproducible counts. Countless forms
   where possible; where a count must stay, its command next to it. One doc
   pass.
3. **E1** — decide (escalate or waive); either outcome is a few lines.
4. **P2 / P3** — known-costs list adoptions, one line each, next time the
   instructions are edited anyway.
5. **P1** — bundled into M7's measurement pass, with the deep-perft re-run as
   its landing gate.
6. The `PlayerCardView` working-tree change needs an owner: commit with its
   comment updated, or revert. It is two passes old now.

The honest headline: after full reads of the five biggest files and the six
newest, the findings are one preview-isolation defect, one swallowed-error
policy question, three stale sentences, three stale counts, and two missing
census lines. For 26,141 lines of app code that is an unusually clean result,
and it is what the clean-run section above predicts.

---

## Disposition — applied same day, same pass

**Applied.** S1 (registry sentence countless, the grep now beside it), S2 (head
doc names the four arities and points at the preview that witnesses them), S3
(preview census uncounted, the decay recorded in place), S4 (the accessor
wipes its suite and force-unwraps — the doc now credits the wipe, not the
instance freshness), S5 (two files, named), S6 (the `.disabled` count carries
its method and the reproducible denominator), E1 (escalation implemented:
tolerance 3, reset on success, `.failed` in the walk's exit grammar — the
change is transport under the driver's standing waiver, so the witness is ⌘U
plus the batch checklist, expected green and not claimed), and P1–P3's census
lines on the known-costs list.

**Deliberately not applied.** P1's *code* change (the static capture-offset
tables): it touches `Chess/`, so it is not landed until deep perft has run
against it — a run only Bera's machine can perform — and the companion audit's
C1 already owes that run for `ab33bdf`. One run can gate both; until then the
census line is the honest form. The `PlayerCardView` working-tree change stays
untouched a third time: it is Bera's uncommitted edit and needs his intent,
not a reviewer's guess — commit it with its comment corrected, or revert it.
The companion audit's own findings (C1–C10, A1–A6) remain its to own.

Post-edit verification: every touched comment re-read against its code; the
three instructions edits re-grepped — the present-tense "144 identifiers"
claim is gone (the string survives exactly once, quoted, as the struck-value
record the document keeps on purpose), and the grep-method strings are present
at both new sites; the modified sources re-swept for the prohibited tokens and
marker vocabulary — clean.

## Appendix — commands behind the claims

```bash
# Tree, counts
git status --porcelain && git log --oneline -1
git ls-files '*.swift' | wc -l                                  # 217
git ls-files '*.swift' | grep -c '^DGTStudioProTests/'          # 81
git ls-files '*.swift' | grep -c '^DGTStudioProUITests/'        # 1

# Hygiene (all empty in DGTStudioPro/ except the judged sites listed above)
grep -rn 'TODO\|FIXME\|HACK\b' --include='*.swift' DGTStudioPro/
grep -rn 'DispatchQueue\|NotificationCenter\|Thread\.sleep\|import Combine' --include='*.swift' DGTStudioPro/
grep -rn '\bprint(\|as!' --include='*.swift' DGTStudioPro/
grep -rn 'ObservableObject\|@Published\|onReceive\|Timer\.publish' --include='*.swift' .
grep -rn 'try?' --include='*.swift' DGTStudioPro/               # 15 lines, 12 code sites
grep -rn 'accessibilityIdentifier("' --include='*.swift' DGTStudioPro/   # empty

# S1
grep -c 'static let\|static func' DGTStudioPro/App/AccessibilityID.swift          # 148
git show f64b8d4:DGTStudioPro/App/AccessibilityID.swift | grep -c 'static let\|static func'  # 144
grep -n '144 identifiers' PROJECT-INSTRUCTIONS.md

# S3
grep -rn 'InspectorSectionCollapse.preview' --include='*.swift' DGTStudioPro/ | wc -l   # 33
grep -rln 'InspectorSectionCollapse.preview' --include='*.swift' DGTStudioPro/ | wc -l  # 15

# S4
grep -n 'suiteName: "preview"' -r DGTStudioPro/                 # the two siblings
grep -n 'removePersistentDomain' DGTStudioPro/App/UITestSeed.swift

# S6
grep -rn '\.disabled(' --include='*.swift' DGTStudioPro/ | wc -l          # 18 (17 + 1 comment)
git grep -n '\.disabled(' 3f785a3 -- '*.swift' | grep -v Tests | wc -l    # 18

# One-door verifications
grep -rn '= Player(' --include='*.swift' DGTStudioPro/          # resolvePlayer only
grep -rn '\.white = \|\.black = ' --include='*.swift' DGTStudioPro/
grep -rn 'recordDesync(\|NSSound\|Insecure\.' --include='*.swift' DGTStudioPro/
grep -rn 'Binding(present:' --include='*.swift' . | wc -l       # 7

# P1 / P2
grep -n 'captureOffsets' DGTStudioPro/Chess/GameState+MoveGeneration.swift
grep -n 'gameRecord' DGTStudioPro/Library/LibraryFilter.swift
```
