import os
import SwiftData
import SwiftUI

struct SettingsView: View {
    
    // MARK: Static Constants
    private static let logger = AppLog.logger(.settings)
    
    // MARK: Private Properties
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    /// Twin default with `autoConnectAtLaunch()`'s `?? true` - unavoidable (`@AppStorage` initials
    /// live at the read site). `StorageKeys` documents the contract.
    @AppStorage(StorageKeys.autoConnectOnLaunch) private var autoConnectOnLaunch = true
    
    // The illegal-move toggle used to sit here as a second `@AppStorage`, twinned with the App's
    // `onDesync` closure. It is now `boardSounds.playsIllegal` like every other cue, which retires
    // that twin - the pairing above survives only because `autoConnectAtLaunch()` has no owner to
    // move it to.

    // Engine values bind to the keys `EngineConfiguration.current` reads; initials come from
    // `EngineConfiguration.default`, so the numbers live exactly once.
    @AppStorage(StorageKeys.analysisDepth) private var analysisDepth
    = EngineConfiguration.default.depth
    @AppStorage(StorageKeys.engineHashMB) private var engineHashMB
    = EngineConfiguration.default.hashMB
    @AppStorage(StorageKeys.engineThreads) private var engineThreads
    = EngineConfiguration.default.threads
    /// Twin default with `BoardView`'s own read (absent reads true).
    @AppStorage(StorageKeys.showBoardCoordinates) private var showsBoardCoordinates = true
    
    /// Glide duration - initial value and bounds from `BoardPieceLayer`, so the numbers live once;
    /// the slider's range makes out-of-bounds unrepresentable from here.
    @AppStorage(StorageKeys.pieceAnimationDuration) private var pieceAnimationDuration
    = BoardPieceLayer.defaultDuration
    
    @Environment(\.modelContext) private var modelContext
    @Environment(SleepInhibitor.self) private var sleepInhibitor
    /// The four cue gates. An owning type, not four more `@AppStorage` twins: playback and
    /// this form must agree about the defaults, and the way to guarantee that is to have one.
    @Environment(BoardSounds.self) private var boardSounds
    @Query private var allGames: [PGN]
    
    @State private var showEraseConfirmation = false
    @State private var showEraseError = false
    @State private var eraseErrorMessage = ""
    
    // MARK: Body

    /// Five tabs, split out of three on 12 Aug 2026 by request. General had grown to six sections
    /// - connection, an alert, the board cues, engine options, tablebases and the sleep gates -
    /// which is a drawer rather than a category.
    ///
    /// The split is **pure relocation**: not one control, default, storage key or identifier
    /// changed, only which tab draws it. Kept that way deliberately, per "mechanical changes travel
    /// alone", so a behaviour regression cannot hide inside a reshuffle.
    ///
    /// Order is by how often a setting is touched, not alphabetically: the two that answer "why is
    /// the app doing that" come first, the two that are set once sit behind them, and Data is last
    /// because it holds the destructive button.
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                generalTab
            }
            Tab("Board", systemImage: "checkerboard.rectangle") {
                boardTab
            }
            Tab("Sounds", systemImage: "speaker.wave.2") {
                soundsTab
            }
            Tab("Engine", systemImage: "cpu") {
                engineTab
            }
            Tab("Data", systemImage: "externaldrive") {
                dataTab
            }
        }
        // Unchanged at five tabs: the five labels are short and the bar was not close to full at
        // three. If a sixth ever crowds it, this is the number to raise.
        .frame(width: 500)
    }
    
    // MARK: General

    /// What is left once sounds and the engine have their own tabs: the board connection and the
    /// sleep gates. Energy stays here rather than following the engine, because only *half* of it
    /// is engine-shaped - one gate is about analysis and one about live play, under a single
    /// footer that deliberately covers both causes at once. Splitting it to satisfy a tab
    /// would mean splitting that footer.
    private var generalTab: some View {
        // The sleep gates are observable properties on the inhibitor, not `@AppStorage`
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
                // One multiline literal per footer, never literal `+` chains: the canvas thunk wraps
                // each literal in `__designTimeString`, and a `+` chain of those against `Text`'s
                // overloads is un-type-checkable in reasonable time (16 Aug 2026, canvas-only failure
                // - the app target compiled fine). The `\` continuations keep the bytes identical.
                Text(
                    """
                    At launch, silently connects to your board, if it's \
                    attached. Mid-game reconnection is always on.
                    """
                )
            }
            
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
                // because it is true of both (the non-goal, still structural).
                Text(
                    """
                    During play, keeps the Mac from sleeping and dropping the \
                    board connection mid-think. During analysis, keeps a \
                    batch from stalling part-way through - a long queue can \
                    outlast the idle timer. The display is still allowed to \
                    dim either way.
                    """
                )
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Sounds

    /// Everything the app can make a noise with, in one place for the first time.
    ///
    /// Board Sounds leads because it is the section with a choice in it; Alerts follows as the one
    /// switch. **That section was headed "Live Play" under General and is renamed here**, which is
    /// the one non-mechanical edit in the whole split and is worth its sentence: "Live Play"
    /// describes *when* a sound happens, which was a useful label while the section sat beside
    /// connection settings, and is the wrong axis beside a section describing *what* a sound is.
    /// "Alerts" also puts the distinction on screen - an alert about the board contradicting
    /// the game, at the system alert volume, against feedback that a move landed, at app volume.
    private var soundsTab: some View {
        // An owning type, not `@AppStorage`: playback and this form must agree about the
        // four defaults, and the way to guarantee that is to have one owner.
        @Bindable var sounds = boardSounds

        return Form {
            Section {
                // Listed in precedence order, most general first, which is the order the footer
                // then explains. Alphabetical would put Capture above Castle and Checkmate above
                // Check, and the list would stop teaching the rule.
                Toggle("Move", isOn: $sounds.playsMove)
                    .accessibilityIdentifier(AccessibilityID.settingsMoveSoundToggle)

                Toggle("Castle", isOn: $sounds.playsCastle)
                    .accessibilityIdentifier(AccessibilityID.settingsCastleSoundToggle)

                Toggle("Capture", isOn: $sounds.playsCapture)
                    .accessibilityIdentifier(AccessibilityID.settingsCaptureSoundToggle)

                Toggle("Promotion", isOn: $sounds.playsPromote)
                    .accessibilityIdentifier(AccessibilityID.settingsPromoteSoundToggle)

                Toggle("Check", isOn: $sounds.playsCheck)
                    .accessibilityIdentifier(AccessibilityID.settingsCheckSoundToggle)

                Toggle("Checkmate", isOn: $sounds.playsCheckmate)
                    .accessibilityIdentifier(AccessibilityID.settingsCheckmateSoundToggle)
            } header: {
                Text("Board Sounds")
            } footer: {
                // States the precedence rule, because it is the one thing about this section that
                // is not obvious from the labels and the one that reads as a bug when unexplained:
                // turning Move off does not silence a capture, and a checking capture is one sound.
                Text(
                    """
                    Plays as moves land on the live board and as you step \
                    through a game with the arrow keys. Each move makes one \
                    sound, the most specific one that fits - a capture that \
                    gives check is a check, and a promotion that captures is \
                    a promotion. Promotion uses the move sound, and checkmate \
                    plays the move and the game-end sound together. Jumping \
                    to the start or end of a game is silent.
                    """
                )
            }

            Section {
                Toggle("Game start", isOn: $sounds.playsGameStart)
                    .accessibilityIdentifier(AccessibilityID.settingsGameStartSoundToggle)

                Toggle("Game end", isOn: $sounds.playsGameEnd)
                    .accessibilityIdentifier(AccessibilityID.settingsGameEndSoundToggle)

                Toggle("Illegal move", isOn: $sounds.playsIllegal)
                    .accessibilityIdentifier(AccessibilityID.settingsIllegalMoveSoundToggle)
            } header: {
                Text("Alerts")
            } footer: {
                // The volume sentence that used to live here is gone with the beep it described.
                Text(
                    """
                    Game start and end play as a game begins and as it reaches \
                    a result, however it got there - mate, resignation or an \
                    agreed draw. Illegal move plays once when the pieces on the \
                    board can't be explained by any legal move, not repeatedly \
                    while they stay that way. All three follow the app's volume.
                    """
                )
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Engine

    /// The engine's own settings and the tablebases it probes. Syzygy follows the steppers here
    /// rather than staying in General because it is engine configuration in every sense - it sets
    /// probe depth and limits, and it verifies by *launching an engine*.
    private var engineTab: some View {
        Form {
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
                    """
                    Applies to the next analysis. Depth trades time for \
                    precision; hash and threads take effect when the \
                    engine next launches.
                    """
                )
            }

            // Syzygy is its own file: unlike the steppers it carries a state machine - a folder
            // re-openable across launches and a verification that starts an engine.
            SyzygySettingsSection()
        }
        .formStyle(.grouped)
    }

    // MARK: Board

    /// The Board tab in the grouped-form language of the other tabs. Swatches stay the control - a
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
                    """
                    Applies everywhere a board is drawn, the live mirror \
                    and game replays.
                    """
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
                    """
                    How long a piece takes to glide to its square, in the \
                    live mirror and in replays. Reduce Motion disables \
                    the glide entirely.
                    """
                )
            }
            
            Section {
                Toggle("Show coordinates", isOn: $showsBoardCoordinates)
                    .accessibilityIdentifier(AccessibilityID.settingsBoardCoordinatesToggle)
            } header: {
                Text("Coordinates")
            } footer: {
                Text(
                    """
                    Draws file letters and rank numbers on the board's \
                    frame. Off keeps the frame, only the labels go.
                    """
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
    
    /// Batch-deletes every `PGN` in one transaction. Open tabs aren't closed - each `loadIfNeeded`
    /// fails its next lookup and falls back to the mirror; acceptable for a nuclear reset.
    private func eraseLibrary() {
        do {
            try modelContext.delete(model: PGN.self)
            // The registry goes too: this is the one deletion path outside `PGNStore.delete` and gets no
            // orphan cascade - a bulk `delete(model:)` never materializes rows, which is its point.
            try modelContext.delete(model: Player.self)
            try modelContext.save()
            // The converged stamp described the store this just emptied - a fresh library
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
        .environment(BoardSounds.preview)
}
