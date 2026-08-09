import Foundation

/// The one rendering of a player name (D23′): PGN carries "Last, First", surfaces show
/// "First Last". Storage untouched — the hash covers tags and D24′ round-trips them. No
/// inverse exists: names travel tag → display only.
internal enum PlayerName {
    
    /// **Idempotent by construction** — the output never contains a comma, so double application is
    /// a no-op; "apply exactly once" stopped being a rule callers must remember.
    internal static func displayForm(of raw: String) -> String {
        let parts = raw.split(
            separator: ",", maxSplits: 1, omittingEmptySubsequences: false
        )
        // No comma: already display order — a fold, not a flip.
        guard parts.count == 2 else { return folded(String(raw)) }
        
        let last = folded(String(parts[0]))
        // Further commas fold to spaces ("Carlsen, Magnus, Jr" — PGN separates players with ":"), which
        // is what keeps the output comma-free and this function idempotent.
        let given = folded(parts[1].replacingOccurrences(of: ",", with: " "))
        
        if given.isEmpty { return last }
        if last.isEmpty { return given }
        return "\(given) \(last)"
    }
    
    /// **The** whitespace fold: trim + collapse runs. Identity and the content hash are this plus
    /// `lowercased()`, and both call through here — a display name, its key and its hash input can
    /// never disagree about "Magnus  Carlsen".
    internal static func folded(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
