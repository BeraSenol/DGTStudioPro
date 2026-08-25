# M17 — Animation hitch capture protocol

**Written 25 Aug 2026, after the first Animation Hitches trace.** That trace measured something
real but mixed two variables, so it cannot attribute. This file is the second measurement, split
so each trace moves one thing. Run it verbatim; it is written for someone who was not there.

---

## What the first trace established

Library, opening and closing the inspector across view modes. 216 hitch events over a 28.17 s
window.

| | |
|---|---|
| Display | **120 Hz** — every duration is an exact multiple of 8.333 ms |
| Total hitch time | 3,391 ms |
| Hitch rate | **120 ms/s** (104 excluding the 466.67 ms opener). Apple's "bad" threshold is 10 |
| Flagged *"Potentially expensive app update(s)"* | 123 events, **59%** of hitch time |
| …of the 37 hitches ≥ 25 ms | **31 flagged**, 84% of the visible-stutter time |

Two populations, and only one is stutter:

- **170 events (79%) are exactly one frame period.** 120 of them sit in **12 sustained runs at a
  dead-steady 55–60 fps** — even cadence, no jitter, 1,000 ms total. That is the app locking to
  half refresh on a 120 Hz panel. It looks smooth. It is a throughput story, not a stutter story.
- **37 events ≥ 25 ms carry 1,825 ms.** These are the visible ones.

**The flag is the diagnosis.** *"Potentially expensive app update"* means the commit phase — body
evaluation, layout, the CA transaction on the main thread — overran, as distinct from GPU render
time. Render is not what is flagged, which largely exonerates the five `.blendMode(.overlay)`
wood-grain layers.

**Burst shape.** Clustering on a >250 ms gap gives 15 bursts, and **12 span 150–275 ms**. Several
are metronomic: seven frames at exactly 33.33 ms (24 fps) at 15.33 s; three separate triples of
exactly 25.00 ms at exactly 33.33 ms spacing at 29.7 s, 31.5 s and 33.1 s. A fixed-cost update
repeating, not a one-off spike.

---

## RESULT — run 25 Aug 2026, all four traces in one 79.3 s Release recording

**The suspect below was wrong.** Recorded here rather than deleted, because the reasoning that
produced it was sound and the failure is the useful half: a hypothesis built from reading code,
confirmed by nothing, and matched to a burst shape that fitted it *and* fitted three other stories
equally well.

`swiftui-updates`, 2,252,222 rows:

| view | total update time | body evaluations |
|---|---|---|
| `LibraryDestination` | **231.7 ms** | 43 |
| `LibraryGameCardView` | **163.2 ms** | 4,415 |
| `IconGridView` | 13.0 ms | 118 |
| `CollapsibleSection` | 1.1 ms | 28 |
| `LoadedSection` | 0.2 ms | 3 |
| **`LibraryInspectorView`** | **0.2 ms** | **5** |

`PGNSerializer`: **zero occurrences.** The discriminator (T2 ≫ T3) failed — the three inspector
phases are indistinguishable.

**The phases segment from the data, no timestamps needed:** 7–22 s, 25–42 s and 44–60 s carry
`LibraryGameCardView` with the inspector at ~0 (traces 1–3); 62–72 s is `LibraryDestination`-topped
with `AppKitOutlineTableRepresentable` and `NavigationSplit` appearing and cards at ~0 (trace 4).
Within each phase the seconds **alternate** — 161, 7, 164, 3, 177, 5, 169, 2, 176 ms — which is the
1.5 s toggle beat against a 2–7 ms idle floor.

**One inspector toggle costs ~170 ms of SwiftUI update time**, agreeing with the first trace's
~200 ms hitch bursts from an independent instrument. It goes to layout, not bodies:

```
535.8 ms  x    324   LazySubviewPlacements<LazyVGridLayout>     (1.65 ms/pass)
197.6 ms  x285,326   Layout: LayoutChildGeometries
~50 ms/s             "Root View for Text"
 56.6 ms  x 71,139   DisplayList Item: InterpolatedDisplayList<Resolved>
 43.0 ms  x 52,654   DisplayList Item: InterpolatedDisplayList<ResolvedStyledText>
```

`Interpolated` means an animation is in flight: the column's width animates, `LazyVGrid` re-places
every subview per frame, every card re-resolves its text.

**`IconGridView`'s 23 Aug column-count quantization is working** — its body ran 118 times and card
bodies ~220 per toggle, not the ~1,200 an animation-rate rebuild would give. The body-invalidation
lever is spent; what remains is the layout pass that fix explicitly left alone.

**Change made:** `InspectorToggleContent` writes the flag inside `Transaction(animation: nil)`.
**Re-run trace 1 before believing it** — expect ~170 ms → single-digit ms per toggle, at the cost of
the slide. `applyInspectorPolicy(for:)` is a second door and still animates, deliberately: that path
measured as `LibraryDestination.body`-dominated, a different shape.

**Two findings that stand on their own:**

- `LibraryDestination.body` costs **5.4 ms per evaluation** — 65% of a 120 Hz frame for one body.
- ~90,000 SwiftUI updates in a second containing a toggle, against 2–7 ms idle.

**Operational notes for the next run.** The `swiftui-updates` export is **4.4 GB** — export it to a
scratch path outside the repo, or expect to delete it. Exporting `time-profile` or `time-sample`
(100 µs, user callstacks) would be far larger; neither was needed.

---

## The suspect that was wrong, and why the census pointed at it

`LibraryInspectorView.rawPGNText` calls `pgn.pgnText` **raw, on every body pass** —
`PGNSerializer.text(roster:board:timeControl:moves:)`, the whole export string — gated only by
the PGN section being expanded.

`LibraryColumnsView.gameDetail` reads the identical accessor **through `pgnTextCache`**, keyed on
`contentHash`.

PROJECT-INSTRUCTIONS' known-costs census says the reverse: *"the Library inspector's PGN section
re-serializes per body pass while expanded (collapse-gated), and the columns detail is a second
such site, ungated."* Columns got its cache and the census was never updated. **The ungated site
is the inspector** — the exact surface being toggled.

## Two couplings that will confound the capture

- **`CollectionViewMode.inspectorPresentationOnEntry`** returns `false` for **columns** and `true`
  for **gallery**. Switching into either *is* an inspector toggle. Only **icons ↔ list** leaves the
  flag alone.
- **The inspector toggle is disabled in columns mode** (`InspectorToggleContent.isDisabled`, set
  where the mode owns its own detail pane).

Use **icons** as the base mode throughout.

---

## Before you start

1. Build and run normally (Debug is fine — the SwiftUI instrument needs it).
2. Instruments → **SwiftUI** template. Confirm these lanes are present, and add from the library
   if not: **View Body**, **View Properties**, **Core Animation Commits**, **Animation Hitches**.
3. Attach to the running `DGTStudioPro`.
4. Open the Library. **Set the window size once and do not change it for the rest of the run** —
   a resized window changes the grid re-flow cost and invalidates comparison between traces.
5. Set the view-mode picker (segmented control, toolbar trailing) to **icons**.

The inspector toggle is the trailing-most toolbar button, `sidebar.trailing`. It has no keyboard
shortcut — click it.

---

## Trace 1 — control: re-flow only

1. Click empty space in the grid so **nothing is selected**. (With no selection
   `LibraryInspectorView` takes the `pgn == nil` branch: no `List`, no PGN section, no serializer.)
2. Record. Wait 2 s.
3. Toggle the inspector **5 times**, roughly 1.5 s apart. Count out loud — an even beat makes the
   bursts separable.
4. Wait 2 s. Stop.

## Trace 2 — the suspect

1. Click **one game** to select it.
2. In the inspector, make sure the **PGN** section is **expanded** (chevron in its header).
3. Record, wait 2 s, **5 toggles at the same beat**, wait 2 s, stop.

## Trace 3 — the discriminator

1. Same single selection.
2. **Collapse** the PGN section.
3. Record, wait 2 s, **5 toggles at the same beat**, wait 2 s, stop.

## Trace 4 — grid re-flow alone

1. Nothing selected. Inspector **closed**.
2. Record, wait 2 s, switch **icons → list → icons → list** (4 switches, same beat), wait 2 s, stop.

---

## Write the numbers down

For each trace: Animation Hitches → total hitch time and event count; View Body → sort by **total
duration** and take the top three view types.

| Trace | Hitch events | Total hitch ms | Max single hitch | Top View Body entries |
|---|---|---|---|---|
| 1 — no selection | | | | |
| 2 — selected, PGN open | | | | |
| 3 — selected, PGN closed | | | | |
| 4 — mode switches | | | | |

## How to read it

- **T2 ≫ T3 ≈ T1**, and `PGNSerializer` or `LibraryInspectorView` tops View Body by total duration
  → **the serializer is the driver.** Fix: give `LibraryInspectorView` the `pgnTextCache` treatment
  `LibraryColumnsView` already has — a `CollectionFoldCache<String, String>` keyed on
  `contentHash`, which is the same shape and the same key.
- **T1 ≈ T2 ≈ T3, all hitching**, and the top of View Body is a card or row view → **content
  re-flow is the driver**, and T4 measures it standalone. The PGN section is exonerated and the
  census entry above should be struck rather than corrected.
- **Neither** — hitches present but View Body is quiet → the app-update flag was not pointing at
  body evaluation. Compare the **Core Animation Commits** lane against render time; the five
  `.blendMode(.overlay)` layers come back onto the table.

Whatever the answer, it belongs in the census in PROJECT-INSTRUCTIONS, replacing the inverted
entry — with the number, the trace it came from, and the date.

## (Struck 25 Aug 2026 — the `Self._printChanges()` shortcut)

A step here suggested putting `Self._printChanges()` on `LibraryInspectorView.body` to shortcut
traces 2–4. It was written for a Debug run and the capture was taken against **Release**, which is
the better measurement and the one PROJECT-INSTRUCTIONS asks for — *"the Debug/Release split is a
coverage gap in every measurement here."* Keep capturing Release; the export answers the same
question without a code change.

## Separate capture — the 466 ms frame

00:06.472 was **56 dropped frames** and carried no app-update flag, so it is not the same
phenomenon as everything above.

If that was near launch, record a 5-second trace from cold launch to first paint. The census's
untested candidate for exactly this shape is the ECO table's ~3,800-row parse, *"warmed off-actor
but never measured"* — `log stream --predicate 'category == "eco"'` shows the table's row count at
load, which dates the parse against the hitch.

If it was **not** near launch, it was a window opening or a first render of a view mode, and the
capture is: record, open that window once, stop.
