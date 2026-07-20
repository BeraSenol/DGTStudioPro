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
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "settings"  // M11.4: was "pgnstore", a copy-paste that misled Console filtering
    )
    
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
    
    @Environment(\.modelContext) private var modelContext
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
        Form {
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
                    "At launch, silently reconnects to the last board you "
                    + "used, if it's attached. Mid-game reconnection is "
                    + "always on."
                )
            }
            
            Section {
                Stepper(value: $analysisDepth, in: EngineConfiguration.depthRange) {
                    LabeledContent("Analysis Depth", value: "\(analysisDepth)")
                }
                Picker("Hash Size", selection: $engineHashMB) {
                    ForEach(EngineConfiguration.hashChoicesMB, id: \.self) { megabytes in
                        Text("\(megabytes) MB").tag(megabytes)
                    }
                }
                Stepper(value: $engineThreads, in: EngineConfiguration.threadsRange) {
                    LabeledContent("Threads", value: "\(engineThreads)")
                }
            } header: {
                Text("Engine")
            } footer: {
                Text(
                    "Applies to the next analysis. Depth trades time for "
                    + "precision; hash and threads take effect when the "
                    + "engine next launches."
                )
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: Board
    private var boardTab: some View {
        VStack {
            HStack(spacing: 20) {
                ForEach(BoardStyle.allCases, id: \.self, content: boardStyleButton)
            }
            .padding()
            Spacer()
        }
    }
    
    private func boardStyleButton(_ style: BoardStyle) -> some View {
        let isSelected = boardStyle == style
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        
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
                    Label("Erase Library…", systemImage: "trash")
                }
                .disabled(allGames.isEmpty)
                .accessibilityIdentifier(AccessibilityID.settingsEraseLibraryButton)
            } header: {
                Text("Reset")
            } footer: {
                Text(
                    "Permanently deletes every game in your library. This cannot be "
                    + "undone. Any open game tabs will revert to the live board view."
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
            try modelContext.save()
            Self.logger.info("Library erased via Settings")
        } catch {
            Self.logger.error("Library erase failed: \(error.localizedDescription, privacy: .public)")
            eraseErrorMessage = error.localizedDescription
            showEraseError = true
        }
    }
}

// MARK: Previews
#Preview {
    SettingsView()
        .modelContainer(for: PGN.self, inMemory: true)
}
