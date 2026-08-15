# Architecture

DGT Studio Pro records over-the-board chess from a DGT electronic board, archives the games into a SwiftData library, and analyzes them with a hosted Stockfish. It is built for one person, one Mac, one board — a standing input that shapes real trade-offs: personal-scale libraries are the performance envelope, and correctness is enforced by tests and invariants rather than by defensive UI.

The app is first-party Swift throughout: no third-party packages, no reactive frameworks, no dispatch queues. Concurrency is structured Swift concurrency plus Observation, compiled in Swift 6 language mode with complete concurrency checking on every target.

## Module map

| Folder | What lives there |
|---|---|
| `App/` | The composition root. `DGTStudioProApp` wires every seam exactly once: session hooks, stores, window scenes. Registries for accessibility identifiers, storage keys, and logging policy. |
| `Chess/` | The pure core: `Position`, `GameState` (+ move generation, SAN, application), `FEN`, `Move`, `Square`, `CastlingRights`, piece tracking. Also the engine-free classifiers: ECO openings (bundled lichess table) and special checkmates, plus the movetext replay validator. |
| `DGT/` | The hardware stack: serial transport over IOKit, the DGT wire protocol, byte framer, message decoder, board diff, move reconstructor, the live session state machine, session logging and recording, auto-connect policy. |
| `Game/` | The live game: `LiveGame` (append-only), crash-safe JSON draft sidecar, open-games registry, session phase. |
| `Engine/` | Stockfish hosting: a `StockfishEngine` actor over a UCI subprocess, the analysis queue (pure core + main-actor controller), evaluations, Syzygy tablebase configuration. |
| `PGN/` | Persistence and interchange: the SwiftData model and its store (single-door writes), parser, byte-pinned serializer, the `GameRecord` value projection, export. |
| `Features/` | The destinations: Board, Library, Players, Get Info, smart tags, view options. |
| `Shared/` | Collection and inspector chrome shared across destinations. |

## The layering rule

Pure logic never sees the frameworks. Statistics, ratings, tag matching, and pairing all consume `GameRecord` — a `Sendable` value projected from the SwiftData model at one seam — and never import SwiftData. The chess core is stricter still: value types with no I/O, no logging, no actor isolation. This is what lets most of the test suite run nonisolated with no fixtures.

Every fold over game records has a documented ordering contract ending in a total tiebreak, because a fold's output is only as deterministic as its order.

## The DGT pipeline

```
serial bytes (IOKit)
  → DGTFramer        reframes a lossy byte stream, resyncing on the MSB
  → DGTDecoder       wire messages → typed board events
  → physical board   the mirror renders this. Always.
  → DGTBoardDiff     vacated / placed squares, decided by end-occupancy
  → DGTReconstructor commits a move only when it is the single legal
                     explanation of the entire board position
  → DGTLiveSession   state machine: quiescence settling, ghost and
                     correction overlays, desync escalation
```

Two invariants carry the design:

**The mirror renders the physical board — always.** Game state contributes overlays only. Pieces animate only under *proven* identity (parity with the committed position, or the reconstructor's own verified move); everything unproven fades rather than glides, because a glide would be a guess drawn as fact.

**The live game is append-only.** The physical board is truth; there are no takebacks and no rollback API. A game in progress survives crashes through an atomic draft sidecar, archives exactly once when finished, and an unfinished result never archives.

The stream is not lossless — adapters drop bytes. An unexplained board therefore earns one full board dump before recovery is offered; a board the dump also cannot explain escalates to a guided recovery checklist in the sidebar.

## Headless by construction

The session's side effects — logging, draft persistence, archiving, desync alerts, board identity, resync requests — are settable closures, wired once in `App.init`. Unit tests leave them nil, so the entire suite runs with no board, no engine, and no network. The same idiom gates logging: the logger factory returns nil under the test host, and optional chaining short-circuits message interpolation before it happens.

## Persistence and identity

Three SwiftData models: the game, the player registry, and smart tags. All writes go through single-door store methods, one transaction each.

- **Game identity is a content hash** — a normalized digest over roster, result, and moves. It is what deduplicates imports, and any in-place edit rehashes in the same transaction. A rename that would collide two games' hashes is refused whole, naming the games, before a single field is written.
- **Player identity follows the tags.** Players are machine-managed rows resolved from PGN seat tags through one creation door; names travel one way (tag form → display form, no inverse). Renaming a player rewrites the stored tags of every linked game — because export writes tags byte-for-byte, and a registry-only rename would make the app disagree with its own files. Orphaned rows are collected automatically: the PGN files are the source of truth, and a row nothing references describes nobody.
- **PGN export is byte-pinned** to DGT's own reference files, committed as test fixtures. Where the PGN standard and the reference files disagree, the files win. Derived data (openings, checkmate types, evaluations) is deliberately never exported — inference does not belong in interchange.

## Engine hosting

`StockfishEngine` is an actor owning a Stockfish subprocess over UCI, exposing analysis as an `AsyncStream` of typed progress. Teardown is guaranteed to complete under cancellation without stranding a waiter. Batch analysis splits into a pure queue core (all branching decisions, fully suited) and a thin main-actor controller (process and SwiftData transport). Evaluations are written per ply, Syzygy tablebases are consulted when configured, and a queue window shows the live search with a projected time remaining.

The engine binary is not in the repository; the engine layer treats its absence as a normal state, and the engine test suites gate on its presence.

## Ratings and classification

- **Glicko-1**, implemented from the paper as a pure deterministic fold: initial 1500 / RD 350, RD floor 30, no wall-clock decay, one game per rating period, provisional while RD > 110. Reference values are pinned at full double precision — the paper's rounded intermediates are reproduced exactly by the formulas, not by copying its rounded results.
- **The ranking ladder** defaults to wins → win rate → stable key, with win-rate and rating orderings user-selectable. Rank is a fact about the player, not a position in the current sort — an alphabetical list still shows each player's rank.
- **Classification is engine-free**: ECO openings by longest-prefix match against the bundled ~3,800-row lichess table, special checkmates (smothered, back rank) by pure predicates over the final position. Stored, re-derived on movetext edits, backfilled for older games.

## Testing

Swift Testing throughout: about 1,180 test functions across 80+ files, green as a gate for every change. The strategy, in order of leverage:

- **Perft is both witness and veto** for move generation — node counts against published reference values, including deep positions, tagged so the slow tier is separable.
- **Byte-pinned fixtures**: the serializer round-trips DGT's real exported files byte-for-byte; field-recorded desync positions are replayed against the reconstructor with rendered-board attachments on failure.
- **Contract pins**: hashes, ordering chains, refusal payloads, and display grammars are asserted against their shared source rather than against literals, so two consumers cannot drift apart silently.
- **Isolation discipline**: `@MainActor` suites for main-actor types, nonisolated suites for value types — a rule the Swift 6 migration confirmed compiler-clean.
- **Manual check lists** cover what automation structurally cannot: hardware paths (cable pulls, desync recovery, sleep inhibition) are written procedures in the internal docs, not untested assumptions.

UI automation was tried and deliberately retired: at one-person scale its flaky launches cost more than its coverage protected. The accessibility-identifier registry it consumed is kept — a future suite's day-one need, at zero runtime cost.

## Conventions

Code is truth: documentation follows code, and a correction lands in both homes in the same pass. Every non-obvious decision is a numbered, argued entry in the append-only [decision log](internal/DECISIONS.md), recorded with the alternatives it rejected. Doc comments carry the *why*; enumerated caller lists and asserted guarantees are treated as anti-patterns, because they read as settled and decay silently.

## Where to look first

For a reader with ten minutes:

1. `DGTStudioPro/DGT/DGTReconstructor.swift` — turning board diffs into the one legal move that explains them.
2. `DGTStudioPro/Chess/GameState+MoveGeneration.swift` and `DGTStudioProTests/Chess/PerftDeepTests.swift` — the move generator and its reference counts.
3. `DGTStudioPro/DGT/DGTLiveSession.swift` — the state machine that keeps a physical game honest.
4. `DGTStudioPro/Engine/StockfishEngine.swift` — an actor hosting a UCI subprocess safely.
5. `DGTStudioPro/PGN/PGNSerializer.swift` and its byte-pinned tests — interchange as a contract.
6. [`docs/internal/DECISIONS.md`](internal/DECISIONS.md) — why all of the above is the way it is.
