# Internal working documents

These three files are the project's working memory — written for the people and tools building it, not for a first-time reader. They are kept verbatim rather than edited for presentation, because their value is that they were written at the moment decisions were made.

- **DECISIONS.md** — the append-only decision log. Every numbered decision (D-numbers, sequential, never reused) with its full argument and the rejected alternatives. Superseded entries stay in place, struck where overturned. This file owns the next free D-number; source comments cite these numbers as provenance.
- **PROJECT-INSTRUCTIONS.md** — the standing context: architecture invariants, working agreements, the waiver register, manual check lists for hardware paths, and toolchain forward notes.
- **ROADMAP.md** — milestone slices with written gates; landed milestones move to the bottom with their evidence.

If you are new to the project, start with the [README](../../README.md) and [ARCHITECTURE.md](../ARCHITECTURE.md) instead — they are written for you.

Note: path-relative commands quoted inside these documents predate their move to `docs/internal/` and should be run from this directory.
