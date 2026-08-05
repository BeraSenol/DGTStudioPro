# DGT Studio Pro — activity diagrams

Five Mermaid activity diagrams over the app's real control flow, plus the checks
that keep them honest.

**Provenance, stated because it is the only thing that makes the rest worth
reading.** Authored 5 August 2026 against the tree at **`75a02d3`** plus that
day's uncommitted work — column sorting, and D59′'s move of the movetext editor
into Get Info — read from source, not from a description of the source. Every
node traces to a file that was open at the time; the decision citations were
verified to resolve against `PROJECT-INSTRUCTIONS.md` by the grep below rather
than by recollection.

**Naming the base *and* the delta is the point**, not pedantry: a diagram set
that cites a commit while describing a working tree is a claim about the
filesystem that nothing checks, and this project has recorded that exact shape
enough times to write it down. When this lands, the base is whatever commit
carries D59′.

A clean parse says nothing about whether these are *true*. The parse checks the
grammar; the content is checked by a read against the sources, and that read has
a date on it. Anything committed after `75a02d3` is unrepresented until someone
re-reads.

| File | Subject |
|---|---|
| `dgt-studio-pro-00-master.mermaid` | Launch, hook wiring, the hermetic guard, scene declaration, the three destinations |
| `dgt-studio-pro-01-live-play.mermaid` | Serial bytes → quiescence → settle → reconstruct → commit → archive, with recovery and the D49′ resync gate |
| `dgt-studio-pro-02-library-analysis.mermaid` | Import, the narrowing pipeline, the four view modes, ⌘A, and every bulk action |
| `dgt-studio-pro-03-players-registry.mermaid` | The pure folds, the ladder, rename through `retag`, the collision pre-flight, the orphan sweep |
| `dgt-studio-pro-04-scenes-services.mermaid` | `openWindow(value:)` routing by type, Get Info's three subjects and **three** tabs, the movetext editor, the evaluation graph, the Commands scenes |

---

## Legend

Six node classes. The style block is **byte-identical in all five files** — one
vocabulary, pasted verbatim, so this legend is true everywhere rather than true
of whichever file you happen to have open. A file that uses only four of the six
is normal and is not dead code; the block is shared deliberately, and trimming it
per-file is what makes a legend start lying.

| Class | Colour | Means |
|---|---|---|
| `act` | blue | An ordinary step — something the app does |
| `dec` | amber, diamond | A decision. **Every guard drawn is one the code actually evaluates**, and where a guard is real but *unreachable on the drawn path* it is demoted to a `note` rather than left as a live branch (see `STAR` in 01) |
| `bad` | red | A refusal, a rejection, or a recorded/accepted cost |
| `note` | purple | An invariant, a trap, or a field-test result. **Not a step** |
| `drill` | green | Hands off to another diagram |
| `term` | dark | A start or a terminal state |

Three edge kinds:

| Edge | Means |
|---|---|
| `-->` solid | Control flow |
| `-.->` dotted | Attaches a `note` to the thing it is about. Carries no flow |
| `==>` thick | Reserved for a data binding — a real dependency that is not control flow. Currently unused; it exists so that when one is drawn it cannot be mistaken for a marginal comment |

---

## Verifying

One command, from this directory. It needs a local install, which
`.gitignore` excludes:

```bash
npm install mermaid@11 jsdom && node check.mjs
```

Four checks run in order of what they can catch:

1. **Parse** — grammar only.
2. **Structure** — every node classed, the style block identical to the shared
   one, nothing dangling that isn't a note, a terminal or a drill-down.
3. **Placement** — the hazard a parse cannot see. A node first *referenced*
   outside a subgraph but *declared* inside it renders **outside the box it
   belongs to**, and parses identically either way. This check caught exactly one
   such node while these files were being written (`SW0`, which entitled the
   sweep subgraph and was rendering outside it).
4. **Render** — layout completes. Text metrics are stubbed, because jsdom ships
   no SVG layout engine, so this proves the graph *resolves*; it does not prove
   it *looks* right.

Expected: `parse 5/5 | render 5/5 | structural issues 0 | placement issues 0`,
and the run prints its own denominator. **A run that examined nothing must not be
able to report success** — if it says anything other than five files, the glob
missed something and every number above it is meaningless.

Then look at the SVGs. A branch nobody has rendered has layout nobody has
checked, and check 4 is not a substitute for opening them.

---

## Standing greps

Run from the repo root, with `PROJECT-INSTRUCTIONS.md` in it. Both are written to
be run verbatim by someone who was not there — the method belongs in the command,
not in the person who wrote it.

**1. Citations to decisions that do not exist** — catches a typo or an invented
number:

```bash
comm -23 <(grep -ohE "D[0-9]+′" Diagrams/*.mermaid | sort -u) \
         <(grep -ohE "D[0-9]+′" PROJECT-INSTRUCTIONS.md | sort -u)
```

Expected output: **empty**. Current denominator: 35 distinct decisions cited.

Note the `′` (U+2032 PRIME). It is load-bearing: `D13` and `D13′` do not grep
against each other, so a diagram set that drops the primes is one whose every
citation is unverifiable by the cheap method this project relies on everywhere
else.

**2. Decisions with an anchor but no node** — catches the milestone-shaped gap:

```bash
comm -13 <(grep -ohE "D[0-9]+′" Diagrams/*.mermaid | sort -u) \
         <(grep -ohE "^### D[0-9]+′" PROJECT-INSTRUCTIONS.md | grep -ohE "D[0-9]+′" | sort -u)
```

This one is **expected non-empty**, which makes it the weaker of the two. Its
value is entirely in the exclusion list being *written down here* rather than
remembered, so that a seventeenth entry is visibly new:

| Not drawn | Why |
|---|---|
| D17′ | Superseded by D24′, which **is** drawn |
| D19′ | Its trigger was revised by D34′, which **is** drawn |
| D21′ | Board coordinates — a rendering preference, no activity |
| D26′ | Inspector chrome — shared components, structure not flow |
| D27′ | Toolchain policy — process |
| D31′ | Rounds are integers — a parser contract with no branch |
| D33′ | The evaluation bar — presentation, no decision point |
| D36′ | Extends D30′'s rule to two fields; D30′ **is** drawn |
| D38′ | Merge — removed as surface by D52′ |
| D41′ | A deleted stored property |
| D42′ | swift-format declined — process |
| D43′ | Swift language mode 6 — build configuration |
| D44′ | An isolation attribute deleted — compile-time, not runtime |
| D45′ | Inspector section collapse — structure |
| D51′ | The UI test target deleted — process |
| D52′ | Merge removed — a deletion |

Sixteen. Anything else appearing is unrecorded drawable behaviour.

---

## Deliberately not drawn: the structural half

`04` is **flow only**. Settings, the sleep inhibitor, logging and the
cross-cutting registries are *structure*, and drawing flowchart arrows over
structure produced a file that was mostly nodes with no edges — a taxonomy
wearing an activity diagram's notation. They live here instead, as a table,
which is the notation they actually wanted:

| Piece | Owner and shape | Worth knowing |
|---|---|---|
| `StorageKeys` | Constants namespace | The single home for every `@AppStorage` key. A preference stated in two places is the twin-read-site pattern D25′ names |
| `SleepInhibitor` | App-owned, injected into **Settings only** | D14′ / D25′. Idle sleep is inhibited while a game is live or a recording runs; **display** sleep deliberately is not, and that is structural — it would take naming a second option, not editing a comment. The gate is an observable property, not an `@AppStorage` read, so switching it off mid-game releases the token on that edge |
| `InspectorSectionCollapse` | App-owned, injected into the **WindowGroup** | D45′. Stores the **collapsed** set, not the expanded one — so an absent key and an empty set are the same state, and "sections default open" is a property of the representation rather than a fourth `?? true` |
| `DGTSessionLog` | App-owned, wired to both DGT objects | Ring-bounded. `record` buffers and mirrors to Console, `capture` buffers only, `recordDesync` carries the full context for an irreconcilable board |
| `AccessibilityID` | Constants registry | Dotted lowercase, `String`-only signatures. **No longer a tested contract** since D51′ deleted the UI suite, so the discipline is carried by the sweep's grep alone. The count deliberately lives in the grep, not in prose: `grep -c 'static let\|static func' DGTStudioPro/App/AccessibilityID.swift` |
| `OpenGamesRegistry` | App-owned, injected into the WindowGroup | Drives the Library's delete-path discard confirmation. `markDirty` has no app caller **by honest pre-wiring** — every editor commits on OK, so `isDirty` is always false and that branch is dormant by design rather than dead |

---

## Three findings this set recorded rather than drew

Each was a question asked of the tree while authoring, and each has an answer
that belongs in the record rather than in a node.

**The glide preference does not clamp under the quiescence window.**
`BoardPieceLayer.durationRange` is `0.1...1.0`, clamped on every read, default
`0.22`. Above 0.3 s a glide can still be in flight when the 300 ms quiescence
settles the move. That is **visual only** — the animation retargets mid-flight
and nothing about commit timing reads it — and the declaration says so. Drawn as
a note on `01`'s mirror invariant, because D47′'s original "under the 300 ms
quiescence" geometry stopped holding at every setting when the speed became a
preference on 2 Aug 2026.

**The resync dump takes no private path.** `requestBoardResync` sends
`.sendBoard` fire-and-forget; the dump returns as an ordinary inbound message on
the same `.boardDump` arm, so the mirror publishes and a fresh quiescence
settles. `01` draws it returning to the publish step for that reason, and not
straight into `settle`.

**The archive door's star guard cannot fire on the live path.**
`LiveGame.isFinished` *is* `result != .ongoing`, so
`guard game.isFinished, game.result != .ongoing` is tautological at both doors.
The redundancy is deliberate and documented — "the guard keeps it structural" —
so nothing needs fixing in source, but drawing it as a live branch would be a
guard whose enabling value the drawn path cannot supply, which is the
`.disabled(…)` shape D40′ exists to stop. It is a `note` in `01`; the reachable
source of a star result is the **import** door, in `02`.
