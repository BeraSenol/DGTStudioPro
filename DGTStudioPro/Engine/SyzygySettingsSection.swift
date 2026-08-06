import AppKit
import SwiftUI

/// The Settings pane's Tablebases section: pick a folder, tune the three probe
/// options, and — the part this section exists for — **find out whether the
/// engine can actually read it**.
///
/// **The verification is the feature, not a garnish.** Stockfish probes
/// tablebases from its own process, and this app is sandboxed, so the files
/// have to be reachable by a *child* rather than by the app. Apple's rule is
/// that a child inherits only the static rights in the entitlements file, not
/// rights granted after launch — and a folder chosen in an open panel is
/// exactly the latter. If that applies here, `SyzygyPath` points somewhere real
/// and Stockfish loads nothing, and the only symptom is that analysis quietly
/// stops being tablebase-perfect in endgames. Nobody would notice for months.
///
/// So the check reports **two numbers from two processes** and lets them
/// disagree out loud:
///
/// | App sees | Engine reports | Reading |
/// |---|---|---|
/// | 0 | — | Wrong folder, or the download never finished |
/// | 290 WDL, 0 DTZ | anything | Half a download — WDL is what probing needs |
/// | 290 | nothing | **The sandbox blocked the subprocess.** The real finding |
/// | 290 | "Found 290 …" | Working |
///
/// A single "tablebases: on/off" indicator could not tell the third row from
/// the first, which is the row worth building a section around.
internal struct SyzygySettingsSection: View {

    // MARK: Verification State

    /// What the last check found. `Equatable` so the view diffs cleanly and so
    /// the reading below is derived rather than stored twice.
    internal enum Verification: Equatable {
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

    /// The folder's path for display. `@State` seeded from defaults rather than
    /// `@AppStorage`, because the picker writes *two* keys at once through
    /// `SyzygyLocation.store` — the bookmark and this label — and an
    /// `@AppStorage` binding here would be a second writer for one of them.
    @State private var displayPath: String? = SyzygyLocation.displayPath()
    @State private var verification: Verification = .idle

    // MARK: Body

    internal var body: some View {
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

    /// The two numbers turned into one sentence. Ordered by which failure is
    /// most likely to be misread as a different one.
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
                return "\(census.summary) — DTZ only. Probing needs the WDL (.rtbw) files."
            }
            guard let report else {
                return "The app sees \(census.summary), but the engine loaded nothing. "
                + "That is the sandbox: a folder you pick is granted after launch, "
                + "and the engine subprocess inherits only the app's static rights."
            }
            return "\(census.summary) — engine says: \(report)"
        }
    }

    private var readingIsGood: Bool {
        if case .checked(let census, let report) = verification {
            return !census.isEmpty && census.wdl > 0 && report != nil
        }
        return false
    }

    /// Starts a throwaway engine, asks it what it loaded, and stands it down.
    ///
    /// A second engine rather than asking the analysis queue's: the queue's
    /// engine exists only while a batch runs (decision 4 releases it at drain),
    /// so a check would answer "no engine" most of the time. This one lives for
    /// about a handshake.
    ///
    /// **The report is read before `shutdown()`, and that ordering is load
    /// bearing** — teardown clears it, deliberately, because a report describes
    /// the tables a specific subprocess loaded and a stale one would answer for
    /// a process that no longer exists.
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

    /// Directory mode, the `presentBackfillPanel` shape — the same gesture D58′
    /// uses to point at a folder of PGNs.
    ///
    /// Unlike that one, this selection is **kept**: a backfill is a one-shot
    /// where the panel's own session grant suffices, while a tablebase folder
    /// has to survive relaunches. That is the whole reason `SyzygyLocation`
    /// stores a security-scoped bookmark and this app has one at all.
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
        // Stale by construction the moment the folder changes, and a stale
        // "working" line under a new path is worse than no line at all.
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

/// Both arms, which is all a canvas can reach: the section with no folder set,
/// and the section with one. The *verification* states need a Stockfish
/// subprocess and a real folder, so they are the boardless checklist's — named
/// there rather than faked here, since a fabricated "engine says…" line would
/// preview the one thing this section exists to report honestly.
#Preview("No Folder") {
    Form { SyzygySettingsSection() }
        .formStyle(.grouped)
        .defaultAppStorage(UserDefaults(suiteName: "preview")!)
        .frame(width: 520)
}
