//
//  SettingsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 13/04/2026.
//

import os
import SwiftData
import SwiftUI

internal struct SettingsView: View {
    
    // MARK: Static Constants
    // M11.4: the category was "pgnstore", a copy-paste that misled Console
    // filtering. Since 5 Aug 2026 it is a `Category` case rather than a
    // string, so that particular mistake is no longer spellable.
    private static let logger = AppLog.logger(.settings)
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    /// M7.2 — the launch auto-connect preference. The `true` here and the
    /// `?? true` fallback in `DGTConnection.autoConnectAtLaunch()` encode the
    /// same "absent reads as enabled" default in two places, unavoidably: an
    /// `@AppStorage` initial value is supplied at the read site, not
    /// registered where the connection could see it. Change one and you must
    /// change the other, or this toggle and launch behavior disagree about
    /// what "never touched" means. `StorageKeys` documents the contract.
    @AppStorage(StorageKeys.autoConnectOnLaunch) private var autoConnectOnLaunch = true
    
    /// M-ux.1 (D13′) — the illegal-move sound preference. Same twin-default
    /// contract as `autoConnectOnLaunch` above: the `true` here and the
    /// `?? true` fallback in the App's `onDesync` closure encode "absent
    /// reads as enabled" in two places, unavoidably. `StorageKeys`
    /// documents the pairing.
    @AppStorage(StorageKeys.illegalMoveSoundEnabled) private var illegalMoveSoundEnabled = true
    
    // M11 review — the Engine section used to display constants that lived
    // nowhere (and had drifted: "20" against a real default of 18, "128 MB"
    // never sent). These bind to the same keys `EngineConfiguration.current`
    // reads, and the initial values come from `EngineConfiguration.default`,
    // so — unlike the auto-connect twin above — the numbers live exactly
    // once.
    @AppStorage(StorageKeys.analysisDepth) private var analysisDepth
    = EngineConfiguration.default.depth
    @AppStorage(StorageKeys.engineHashMB) private var engineHashMB
    = EngineConfiguration.default.hashMB
    @AppStorage(StorageKeys.engineThreads) private var engineThreads
    = EngineConfiguration.default.threads
    /// D21′ — the board's coordinate labels. Twin default with `BoardView`'s
    /// own read (absent reads as **true**), the same unavoidable pairing as
    /// the two toggles above; `StorageKeys` documents it.
    @AppStorage(StorageKeys.showBoardCoordinates) private var showsBoardCoordinates = true
    
    /// 2 Aug 2026 — the piece glide duration. The `EngineConfiguration`
    /// arrangement: initial value and bounds come from the owning type
    /// (`BoardPieceLayer`), so the numbers live exactly once. The slider's
    /// range makes an out-of-bounds write unrepresentable from here; the
    /// layer additionally clamps its own read against a hand-edited default.
    @AppStorage(StorageKeys.pieceAnimationDuration) private var pieceAnimationDuration
    = BoardPieceLayer.defaultDuration
    
    @Environment(\.modelContext) private var modelContext
    @Environment(SleepInhibitor.self) private var sleepInhibitor
    @Query private var allGames: [PGN]
    
    @State private var showEraseConfirmation = false
    @State private var showEraseError = false
    @State private var eraseErrorMessage = ""
    
    // MARK: Body
    internal var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                generalTab
            }
            Tab("Board", systemImage: "checkerboard.rectangle") {
                boardTab
            }
            Tab("Data", systemImage: "externaldrive") {
                dataTab
            }
        }
        .frame(width: 500)
    }
    
    // MARK: General
    private var generalTab: some View {
        // D25′ — the sleep gate is an observable property on the inhibitor,
        // not an `@AppStorage` mirror of it: the running tracking loop must
        // see the flip so that switching off mid-game releases the
        // assertion on that edge. Consequence for this file: no twin
        // default to document, unlike the three `@AppStorage` toggles above.
        @Bindable var inhibitor = sleepInhibitor
        
        return Form {
            // M7.3 deliberately has no toggle here: standing down mid-game
            // reconnection is a per-incident choice, not a preference — a
            // switch flipped weeks ago shouldn't decide whether a live game
            // gets its board back. The connect dialog's "Stop Trying" button
            // is that per-incident door; the footer states the split so the
            // player isn't left hunting for a setting that doesn't exist.
            Section {
                Toggle("Connect to board automatically", isOn: $autoConnectOnLaunch)
                    .accessibilityIdentifier(AccessibilityID.settingsAutoConnectToggle)
            } header: {
                Text("DGT Board")
            } footer: {
                Text(
                    "At launch, silently connects to your board, if it's "
                    + "attached. Mid-game reconnection is always on."
                )
            }
            
            Section {
                Toggle("Play alert on illegal move", isOn: $illegalMoveSoundEnabled)
                    .accessibilityIdentifier(AccessibilityID.settingsIllegalMoveSoundToggle)
            } header: {
                Text("Live Play")
            } footer: {
                Text(
                    "Plays the system alert sound when the pieces on the "
                    + "board can't be explained by any legal move."
                )
            }
            
            // M11.4 (23 July): the section shipped a single Stepper bound to
            // `analysisDepth` but labelled "Threads" and displaying
            // `engineThreads` — the control said one thing, edited another,
            // and hash/threads had no control at all. The keys were bound;
            // the UI wasn't. Bounds and choices come from
            // `EngineConfiguration`, so the numbers still live exactly once
            // and a value can't leave the range the clamp would repair.
            Section {
                Stepper(value: $analysisDepth, in: EngineConfiguration.depthRange) {
                    LabeledContent("Search Depth", value: "\(analysisDepth)")
                }
                .accessibilityIdentifier(AccessibilityID.settingsEngineDepthStepper)
                
                Picker("Hash", selection: $engineHashMB) {
                    ForEach(EngineConfiguration.hashChoicesMB, id: \.self) { size in
                        Text("\(size) MB").tag(size)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.settingsEngineHashPicker)
                
                Stepper(value: $engineThreads, in: EngineConfiguration.threadsRange) {
                    LabeledContent("Threads", value: "\(engineThreads)")
                }
                .accessibilityIdentifier(AccessibilityID.settingsEngineThreadsStepper)
            } header: {
                Text("Engine")
            } footer: {
                Text(
                    "Applies to the next analysis. Depth trades time for "
                    + "precision; hash and threads take effect when the "
                    + "engine next launches."
                )
            }
            
            Section {
                Toggle("Keep the Mac awake during play", isOn: $inhibitor.isEnabled)
                    .accessibilityIdentifier(AccessibilityID.settingsPreventSleepToggle)
            } header: {
                Text("Energy")
            } footer: {
                Text(
                    "While a game or a board recording is in progress, keeps "
                    + "the Mac from sleeping and dropping the board "
                    + "connection. The display is still allowed to dim."
                )
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: Board
    
    /// D15′(c): the Board tab joins the grouped-form language of the other
    /// two tabs — it was the window's only non-`Form` tab, a bare `VStack`
    /// with ad-hoc padding. The swatch buttons stay as the control: a
    /// visual style is picked visually (a `Picker` of names would hide
    /// exactly the information being chosen).
    private var boardTab: some View {
        Form {
            Section {
                HStack(spacing: 30) {
                    ForEach(BoardStyle.allCases, id: \.self, content: boardStyleButton)
                }
                .frame(maxWidth: .infinity)
            } header: {
                Text("Board Style")
            } footer: {
                Text(
                    "Applies everywhere a board is drawn — the live mirror "
                    + "and game replays."
                )
            }
            
            Section {
                Slider(
                    value: $pieceAnimationDuration,
                    in: BoardPieceLayer.durationRange
                ) {
                    LabeledContent(
                        "Piece Glide",
                        value: pieceAnimationDuration
                            .formatted(.number.precision(.fractionLength(2))) + " s"
                    )
                } minimumValueLabel: {
                    Text("Fast")
                } maximumValueLabel: {
                    Text("Slow")
                }
                .accessibilityIdentifier(AccessibilityID.settingsPieceAnimationSlider)
            } header: {
                Text("Animation")
            } footer: {
                Text(
                    "How long a piece takes to glide to its square, in the "
                    + "live mirror and in replays. Reduce Motion disables "
                    + "the glide entirely."
                )
            }
            
            Section {
                Toggle("Show coordinates", isOn: $showsBoardCoordinates)
                    .accessibilityIdentifier(AccessibilityID.settingsBoardCoordinatesToggle)
            } header: {
                Text("Coordinates")
            } footer: {
                Text(
                    "Draws file letters and rank numbers on the board's "
                    + "frame. Off keeps the frame — only the labels go."
                )
            }
        }
        .formStyle(.grouped)
    }
    
    private func boardStyleButton(_ style: BoardStyle) -> some View {
        let isSelected = boardStyle == style
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        
        return Button {
            boardStyle = style
        } label: {
            VStack {
                boardThumbnail(for: style)
                    .frame(width: 60, height: 60)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(
                            isSelected ? Color.accentColor : .secondary.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1
                        )
                    }
                
                Text(style.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func boardThumbnail(for style: BoardStyle) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { col in
                        Rectangle()
                            .fill((row + col).isMultiple(of: 2) ? style.light : style.dark)
                    }
                }
            }
        }
    }
    
    // MARK: Data
    private var dataTab: some View {
        Form {
            Section("Library") {
                LabeledContent("Stored Games", value: "\(allGames.count)")
            }
            
            Section {
                Button(role: .destructive) {
                    showEraseConfirmation = true
                } label: {
                    Label("Erase Library", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(allGames.isEmpty)
                .accessibilityIdentifier(AccessibilityID.settingsEraseLibraryButton)
            } header: {
                Text("Reset")
            } footer: {
                Text(
                    "Permanently deletes every game in your library. This cannot be undone. Any open game tabs will revert to the live board view."
                )
            }
        }
        .formStyle(.grouped)
        .alert("Erase Entire Library?", isPresented: $showEraseConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(
                "Erase \(allGames.count) Game\(allGames.count == 1 ? "" : "s")",
                role: .destructive
            ) {
                eraseLibrary()
            }
        } message: {
            Text("This permanently deletes all \(allGames.count) games. This action cannot be undone.")
        }
        .alert("Couldn't Erase Library", isPresented: $showEraseError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(eraseErrorMessage)
        }
    }
    
    // MARK: Actions
    
    /// Batch-deletes every `PGN` in a single transaction. Open Board tabs aren't
    /// closed here (that would require window enumeration from this separate
    /// scene); instead each one's `loadIfNeeded` fails its lookup on the next
    /// pass and falls back to the live mirror — acceptable for a deliberate,
    /// nuclear reset.
    private func eraseLibrary() {
        do {
            try modelContext.delete(model: PGN.self)
            // The registry goes too. This is the one deletion path that does
            // not run through `PGNStore.delete(_ pgns:)` and therefore does not
            // get its orphan cascade — a bulk `delete(model:)` never
            // materializes the rows, which is the point of it. Erasing every
            // game orphans every player by definition, so the cascade's own
            // rule gives this exact answer; spelling it as a second bulk
            // delete keeps the nuclear reset from being the one door that
            // leaves a registry full of names behind an empty Library.
            try modelContext.delete(model: Player.self)
            try modelContext.save()
            Self.logger?.info("Library and player registry erased via Settings")
        } catch {
            Self.logger?.error("Library erase failed: \(error.localizedDescription, privacy: .public)")
            eraseErrorMessage = error.localizedDescription
            showEraseError = true
        }
    }
}

// MARK: Previews
#Preview {
    SettingsView()
        .modelContainer(for: PGN.self, inMemory: true)
        .environment(SleepInhibitor.preview)
}
