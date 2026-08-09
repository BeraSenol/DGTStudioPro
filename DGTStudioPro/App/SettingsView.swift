import os
import SwiftData
import SwiftUI

internal struct SettingsView: View {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.settings)
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    /// Twin default with `autoConnectAtLaunch()`'s `?? true` — unavoidable (`@AppStorage` initials
    /// live at the read site). `StorageKeys` documents the contract.
    @AppStorage(StorageKeys.autoConnectOnLaunch) private var autoConnectOnLaunch = true
    
    /// Twin default with the App's `onDesync` closure (D13′) — same unavoidable pairing.
    @AppStorage(StorageKeys.illegalMoveSoundEnabled) private var illegalMoveSoundEnabled = true
    
    // Engine values bind to the keys `EngineConfiguration.current` reads; initials come from
    // `EngineConfiguration.default`, so the numbers live exactly once.
    @AppStorage(StorageKeys.analysisDepth) private var analysisDepth
    = EngineConfiguration.default.depth
    @AppStorage(StorageKeys.engineHashMB) private var engineHashMB
    = EngineConfiguration.default.hashMB
    @AppStorage(StorageKeys.engineThreads) private var engineThreads
    = EngineConfiguration.default.threads
    /// Twin default with `BoardView`'s own read (D21′; absent reads true).
    @AppStorage(StorageKeys.showBoardCoordinates) private var showsBoardCoordinates = true
    
    /// Glide duration — initial value and bounds from `BoardPieceLayer`, so the numbers live once;
    /// the slider's range makes out-of-bounds unrepresentable from here.
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
        // D25′ — the sleep gates are observable properties on the inhibitor, not `@AppStorage`
        // mirrors: the tracking loop must see the flip mid-game. No twin default to document.
        @Bindable var inhibitor = sleepInhibitor
        
        return Form {
            // M7.3 deliberately has no toggle: standing down reconnection is per-incident ("Stop Trying"),
            // not a preference. The footer states the split.
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
            
            // M11.4: this section once had one Stepper labelled "Threads" editing `analysisDepth`.
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

            // Syzygy is its own file: unlike the steppers it carries a state machine — a folder re-openable
            // across launches and a verification that starts an engine.
            SyzygySettingsSection()
            
            Section {
                Toggle(
                    "Keep the Mac awake during play",
                    isOn: $inhibitor.preventsSleepDuringPlay
                )
                .accessibilityIdentifier(AccessibilityID.settingsPreventSleepDuringPlayToggle)

                Toggle(
                    "Keep the Mac awake during analysis",
                    isOn: $inhibitor.preventsSleepDuringAnalysis
                )
                .accessibilityIdentifier(AccessibilityID.settingsPreventSleepDuringAnalysisToggle)
            } header: {
                Text("Energy")
            } footer: {
                // One footer for two toggles, naming each cause's own consequence; the display sentence is last
                // because it is true of both (D14′'s non-goal, still structural).
                Text(
                    "During play, keeps the Mac from sleeping and dropping the "
                    + "board connection mid-think. During analysis, keeps a "
                    + "batch from stalling part-way through — a long queue can "
                    + "outlast the idle timer. The display is still allowed to "
                    + "dim either way."
                )
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: Board
    
    /// The Board tab in the grouped-form language of the other tabs. Swatches stay the control — a
    /// visual style is picked visually.
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
                    "Applies everywhere a board is drawn, the live mirror "
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
                    + "frame. Off keeps the frame, only the labels go."
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
    
    /// Batch-deletes every `PGN` in one transaction. Open tabs aren't closed — each `loadIfNeeded`
    /// fails its next lookup and falls back to the mirror; acceptable for a nuclear reset.
    private func eraseLibrary() {
        do {
            try modelContext.delete(model: PGN.self)
            // The registry goes too: this is the one deletion path outside `PGNStore.delete` and gets no
            // orphan cascade — a bulk `delete(model:)` never materializes rows, which is its point.
            try modelContext.delete(model: Player.self)
            try modelContext.save()
            // The converged stamp described the store this just emptied (D75′) — a fresh library
            // earns its own clean pass.
            UserDefaults.standard.set(false, forKey: StorageKeys.playerBackfillsConverged)
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
