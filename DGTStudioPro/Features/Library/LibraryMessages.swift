// MARK: Alert Message Formatters

/// The Library's alert copy, split out of the destination: string builders with no view state.
/// `@MainActor` because `deletion(for:lead:)` asks the store's main-actor orphan pre-flight,
/// and every caller is view code — the isolation the old home inherited from `View`.
@MainActor
enum LibraryMessages {

    /// Confirmation body; players clause appended only when the cascade would take any.
    /// Advisory — `PGNStore.delete(_:)` recomputes at write time.
    static func deletion(for games: [PGN], lead: String) -> String {
        let stranded = PGNStore.playersOrphaned(byDeleting: games)
        guard !stranded.isEmpty else { return lead }
        let shown = stranded.prefix(5).map(\.name)
        let more = stranded.count > shown.count
        ? " And \(stranded.count - shown.count) more."
        : ""
        let subject = shown.joined(separator: ", ")
        let clause = stranded.count == 1
        ? "\(subject) is in no other game and will be removed from Players."
        : "\(subject) are in no other games and will be removed from Players."
        return lead + " " + clause + more
    }

    /// Leads with what did not happen when nothing did; `unmatched` is a finding, not a fault (three names max).
    static func backfill(for report: PGNStore.LibraryIndexBackfill) -> String {
        guard report.scanned > 0 else {
            return "That folder has no PGN files in it."
        }
        guard report.stamped > 0 || report.alreadyNumbered > 0 else {
            return "Scanned \(report.scanned) file\(report.scanned == 1 ? "" : "s") and matched "
            + "none of them to games in your Library. If these are your games, "
            + "check that you picked the folder they were imported from."
        }

        var parts: [String] = []
        if report.stamped > 0 {
            parts.append("Numbered \(report.stamped) game\(report.stamped == 1 ? "" : "s").")
        }
        if report.alreadyNumbered > 0 {
            parts.append("\(report.alreadyNumbered) already had a number and were left alone.")
        }
        if !report.unmatched.isEmpty {
            let shown = report.unmatched.prefix(3).joined(separator: ", ")
            let more = report.unmatched.count > 3
            ? " and \(report.unmatched.count - 3) more"
            : ""
            parts.append("\(report.unmatched.count) file\(report.unmatched.count == 1 ? " is" : "s are") "
                         + "not in your Library yet (\(shown)\(more)).")
        }
        if !report.unnumbered.isEmpty {
            parts.append("\(report.unnumbered.count) filename\(report.unnumbered.count == 1 ? " carries" : "s carry") no number.")
        }
        if !report.skipped.isEmpty {
            parts.append("\(report.skipped.count) couldn’t be read.")
        }
        return parts.joined(separator: " ")
    }
}
