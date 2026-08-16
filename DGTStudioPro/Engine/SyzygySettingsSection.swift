import AppKit
import SwiftUI

/// The Tablebases section: pick a folder, tune the probes, and - the reason it exists -
/// **verify the engine can read it**. Sandbox inheritance covers only static entitlements, so
/// `SyzygyPath` can point somewhere real while Stockfish loads nothing; the check starts an
/// engine and quotes what it says.
struct SyzygySettingsSection: View {

    // MARK: Verification State

    /// The last check's finding. `Equatable` so the reading below is derived, not stored twice.
    enum Verification: Equatable {
        case idle
        case running
        case checked(census: SyzygyLocation.Census, engineReport: String?)
        case failed(String)
    }

    // MARK: Stored Properties

    @AppStorage(StorageKeys.syzygyProbeDepth) private var probeDepth
    = EngineConfiguration.default.syzygyProbeDepth
    @AppStorage(StorageKeys.syzygy50MoveRule) private var fiftyMoveRule
    = EngineConfiguration.default.syzygy50MoveRule
    @AppStorage(StorageKeys.syzygyProbeLimit) private var probeLimit
    = EngineConfiguration.default.syzygyProbeLimit

    /// `@State`, not `@AppStorage`: the picker writes *two* keys at once through
    /// `SyzygyLocation.store`, and an `@AppStorage` binding would be a second writer for one.
    @State private var displayPath: String? = SyzygyLocation.displayPath()
    @State private var verification: Verification = .idle

    // MARK: Body

    var body: some View {
        Section {
            LabeledContent("Folder") {
                HStack(spacing: 8) {
                    Text(displayPath ?? "None")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(displayPath == nil ? .secondary : .primary)
                    Button("Choose…") { chooseFolder() }
                        .accessibilityIdentifier(AccessibilityID.settingsSyzygyChoose)
                    if displayPath != nil {
                        Button("Clear") { clearFolder() }
                    }
                }
            }

            if displayPath != nil {
                Stepper(value: $probeDepth, in: EngineConfiguration.syzygyProbeDepthRange) {
                    LabeledContent("Probe Depth", value: "\(probeDepth)")
                }
                .accessibilityIdentifier(AccessibilityID.settingsSyzygyProbeDepthStepper)

                Stepper(value: $probeLimit, in: EngineConfiguration.syzygyProbeLimitRange) {
                    LabeledContent("Probe Limit", value: "\(probeLimit) pieces")
                }
                .accessibilityIdentifier(AccessibilityID.settingsSyzygyProbeLimitStepper)

                Toggle("Respect the 50-move rule", isOn: $fiftyMoveRule)
                    .accessibilityIdentifier(AccessibilityID.settingsSyzygy50MoveToggle)

                verificationRow
            }
        } header: {
            Text("Endgame Tablebases")
        } footer: {
            Text(footerText)
        }
    }

    // MARK: Verification

    @ViewBuilder
    private var verificationRow: some View {
        LabeledContent("Status") {
            HStack(spacing: 8) {
                switch verification {
                case .running:
                    ProgressView().controlSize(.small)
                    Text("Starting the engine…").foregroundStyle(.secondary)
                default:
                    Text(reading)
                        .foregroundStyle(readingIsGood ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Check") {
                    Task { await verify() }
                }
                .disabled(verification == .running)
                .accessibilityIdentifier(AccessibilityID.settingsSyzygyVerify)
            }
        }
    }

    /// The two numbers as one sentence, ordered by which failure is most likely to be misread.
    private var reading: String {
        switch verification {
        case .idle:
            return "Not checked"
        case .running:
            return "Checking…"
        case .failed(let message):
            return message
        case .checked(let census, let report):
            if census.isEmpty {
                return "The app sees no .rtbw or .rtbz files here. Wrong folder, or the download is incomplete."
            }
            if census.wdl == 0 {
                return "\(census.summary) - DTZ only. Probing needs the WDL (.rtbw) files."
            }
            guard let report else {
                return "The app sees \(census.summary), but the engine loaded nothing. "
                + "That is the sandbox: a folder you pick is granted after launch, "
                + "and the engine subprocess inherits only the app's static rights."
            }
            return "\(census.summary) - engine says: \(report)"
        }
    }

    private var readingIsGood: Bool {
        if case .checked(let census, let report) = verification {
            return !census.isEmpty && census.wdl > 0 && report != nil
        }
        return false
    }

    /// A throwaway engine (the queue's exists only while a batch runs). **The report is read before
    /// `shutdown()`** - teardown clears it, deliberately: a report describes a live engine.
    private func verify() async {
        verification = .running

        guard let access = SyzygyLocation.access() else {
            verification = .failed("The saved folder could not be opened. Choose it again.")
            return
        }
        let census = SyzygyLocation.census(at: access)

        guard let binary = StockfishEngine.defaultBinaryURL else {
            verification = .failed("Stockfish is not bundled in the app.")
            return
        }

        let engine = StockfishEngine(binaryURL: binary)
        do {
            try await engine.start()
            let report = await engine.tablebaseReport
            await engine.shutdown()
            verification = .checked(census: census, engineReport: report)
        } catch {
            await engine.shutdown()
            verification = .failed("The engine did not start: \(error.localizedDescription)")
        }
    }

    // MARK: Folder

    /// Directory mode, the backfill panel's shape.
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Choose the folder holding the .rtbw and .rtbz tablebase files."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard SyzygyLocation.store(url) else {
            verification = .failed("That folder could not be saved for future launches.")
            return
        }
        displayPath = SyzygyLocation.displayPath()
        // Stale by construction the moment the folder changes - a stale "working" line is worse than none.
        verification = .idle
    }

    private func clearFolder() {
        SyzygyLocation.store(nil)
        displayPath = nil
        verification = .idle
    }

    private var footerText: String {
        displayPath == nil
        ? "Syzygy tablebases give exact results for positions with few pieces. "
        + "3-4-5 pieces is about 1 GB; the engine probes whatever it finds."
        : "Applies when the engine next launches. Probe Depth 1 probes everywhere "
        + "and is most accurate; raising it trades tablebase hits for search speed. "
        + "Probe Limit 0 disables probing without forgetting the folder."
    }
}

// MARK: Previews

/// Both arms a canvas can reach. The verification states need Stockfish and a real folder -
/// the boardless checklist's; faking "engine says…" would preview the one thing this section
/// exists to report honestly.
#Preview("No Folder") {
    Form { SyzygySettingsSection() }
        .formStyle(.grouped)
        .defaultAppStorage(UserDefaults(suiteName: "preview")!)
        .frame(width: 520)
}
