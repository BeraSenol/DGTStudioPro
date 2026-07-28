//
//  PGNParser.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/04/2026.
//

import Foundation
import os

// MARK: PGN Parser
internal enum PGNParser {
    
    // MARK: Static Constants
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "pgnparse"
    )
    
    internal static let requiredTags: Set<String> = Set(
        SevenTagRoster.allCases.map(\.rawValue)
    )
    
    private static let resultTokens: Set<String> = Set(
        GameResult.allCases.map(\.rawValue)
    )
    
    /// Parses `[Date "yyyy.MM.dd"]` tags — pinned to **UTC** so that
    /// parse → `PGNStore.hashDateString(from:)` (also UTC) is a perfect
    /// round-trip. A PGN date is a calendar day with no timezone of its
    /// own; the app's one convention is "PGN dates are UTC days."
    ///
    /// Without the pin this formatter used the machine's local zone, so in
    /// any timezone east of UTC an imported "2026.05.28" parsed to local
    /// midnight — May 27 in UTC — and hash-formatted back as "2026.05.27",
    /// silently breaking one-hash/two-doors deduplication against a
    /// same-day archived twin (requirement 8's import door). West-of-UTC
    /// *display* of UTC-midnight dates is the mirror wrinkle; the fully
    /// general fix — calendar-date storage — is parked in the roadmap.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
    
    // MARK: Errors
    internal enum Error: Swift.Error, Equatable {
        case missingRequiredTags(Set<String>)
        case unbalancedBraces
        case unbalancedParentheses
        /// The file holds more than one game. `parse` returns a single `PGN`,
        /// and the movetext scanner has no notion of SAN shape — every token
        /// that isn't a result token becomes a move — so without this the
        /// second game's `[Event "…"]` block would be stored as plies and the
        /// row would import silently corrupt. Refusing is the honest answer
        /// until a splitting importer exists.
        case multipleGames
    }
    
    // MARK: Entry Point
    internal static func parse(_ text: String) throws(Error) -> PGN {
        let (tagSection, movetextSection) = splitSections(normalizeLineEndings(text))
        
        let tags = parseTags(from: tagSection)
        let missing = missingTags(in: tags)
        if !missing.isEmpty {
            logger.error(
                """
                Parse failed: missing required tags \
                missing=\(missing.sorted().joined(separator: ","), privacy: .public) \
                present=\(tags.keys.sorted().joined(separator: ","), privacy: .public) \
                tagSectionLength=\(tagSection.count)
                """
            )
            throw Error.missingRequiredTags(missing)
        }
        
        // A tag pair can only open a *new* game once the movetext has begun —
        // legal movetext never starts a line with `[Key "`. See `Error.multipleGames`.
        if containsTagPairLine(movetextSection) {
            logger.error("Parse failed: file contains more than one game")
            throw Error.multipleGames
        }
        
        let (moves, evaluations) = try parseMovesAndEvaluations(from: movetextSection)
        
        let hasEvals = evaluations.contains(where: { $0 != nil })
        logger.info(
            """
            Parsed PGN: \
            \(tags[.white] ?? "?", privacy: .public) vs \(tags[.black] ?? "?", privacy: .public) \
            event='\(tags[.event] ?? "?", privacy: .public)' \
            plies=\(moves.count) tags=\(tags.count) hasEvals=\(hasEvals)
            """
        )
        
        return PGN(
            event: tags[.event] ?? "",
            site:  tags[.site]  ?? "",
            date:  parseDate(tags[.date]),
            round: parseRound(tags[.round]),
            white: tags[.white] ?? "",
            black: tags[.black] ?? "",
            moves: moves,
            evaluations: hasEvals ? evaluations : [],
            result: parseResult(tags[.result]),
            timeControl: parseTimeControl(tags["TimeControl"]),
            board: tags["Board"]
        )
    }
    
    // MARK: Tag Parsing
    internal static func missingTags(in tags: [String: String]) -> Set<String> {
        requiredTags.subtracting(tags.keys)
    }
    
    internal static func parseTags(from text: String) -> [String: String] {
        var tags: [String: String] = [:]
        
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if let tag = parseTag(trimmed) {
                tags[tag.key] = tag.value
            }
        }
        
        return tags
    }
    
    internal static func parseTag(_ line: String) -> (key: String, value: String)? {
        guard line.hasPrefix("["), line.hasSuffix("]") else { return nil }
        
        let inner = line.dropFirst().dropLast()
        
        guard let spaceIndex = inner.firstIndex(of: " ") else { return nil }
        
        let key = String(inner[inner.startIndex ..< spaceIndex])
        var value = String(inner[inner.index(after: spaceIndex)...])
            .trimmingCharacters(in: .whitespaces)
        
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        
        return (key, value)
    }
    
    internal static func parseDate(_ date: String?) -> Date? {
        guard let date, !date.contains("?") else { return nil }
        return dateFormatter.date(from: date)
    }
    
    /// The writer's half of `parseDate` — same formatter, so parse and
    /// serialize can't drift on the UTC-calendar-day convention
    /// `PGNParserDateTests` pins. Lives here rather than on `PGNSerializer`
    /// precisely so there is one formatter, not a twin.
    internal static func pgnDateString(_ date: Date?) -> String {
        guard let date else { return RosterSummary.unknownDate }
        return dateFormatter.string(from: date)
    }
    
    internal static func parseRound(_ round: String?) -> Int? {
        guard let round else { return nil }
        return Int(round)
    }
    
    internal static func parseResult(_ string: String?) -> GameResult {
        guard let string, let result = GameResult(rawValue: string) else {
            return .ongoing
        }
        return result
    }
    
    internal static func parseTimeControl(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value != "-" else { return nil }
        return value
    }
    
    // MARK: Movetext Parsing
    
    /// Single-pass scanner that produces both the move list and a parallel
    /// array of evaluations sourced from `{[%eval ...]}` comments.
    ///
    /// `evaluations[i]` is the eval parsed from a brace comment following
    /// `moves[i]` in the movetext, or `nil` if no such comment was present
    /// for that ply. Multiple eval comments on a single move resolve to
    /// the last one — matching Lichess's "most recent annotation wins"
    /// convention. Eval comments inside RAVs (parenthesized variations)
    /// are dropped along with the variations themselves, since variations
    /// aren't preserved in the move list.
    internal static func parseMovesAndEvaluations(
        from movetext: String
    ) throws(Error) -> (moves: [String], evaluations: [Evaluation?]) {
        let chars = Array(movetext)
        var i = 0
        
        var moves: [String] = []
        var evaluations: [Evaluation?] = []
        var currentToken = ""
        var braceContent = ""
        var braceDepth = 0
        var parenDepth = 0
        var inLineComment = false
        
        // Emit the in-progress token (if it's a real move) and reserve
        // its slot in `evaluations`. Result tokens (1-0, 0-1, etc.) and
        // empties are dropped without consuming an eval slot.
        func flushToken() {
            defer { currentToken = "" }
            guard !currentToken.isEmpty else { return }
            if resultTokens.contains(currentToken) { return }
            let san = stripAnnotations(currentToken)
            guard !san.isEmpty else { return }
            moves.append(san)
            evaluations.append(nil)
        }
        
        while i < chars.count {
            let c = chars[i]
            
            if inLineComment {
                if c == "\n" { inLineComment = false }
                i += 1
                continue
            }
            
            if braceDepth > 0 {
                if c == "}" {
                    braceDepth -= 1
                    if braceDepth == 0 {
                        if let eval = extractEval(from: braceContent),
                           !evaluations.isEmpty {
                            evaluations[evaluations.count - 1] = eval
                        }
                        braceContent = ""
                    }
                } else {
                    braceContent.append(c)
                }
                i += 1
                continue
            }
            
            if parenDepth > 0 {
                if c == "(" { parenDepth += 1 }
                else if c == ")" { parenDepth -= 1 }
                i += 1
                continue
            }
            
            switch c {
            case "{":
                flushToken()
                braceDepth = 1
                i += 1
                
            case "(":
                flushToken()
                parenDepth = 1
                i += 1
                
            case ";":
                flushToken()
                inLineComment = true
                i += 1
                
            case "$":
                flushToken()
                i += 1
                while i < chars.count, chars[i].isASCII, chars[i].isNumber { i += 1 }
                
            default:
                if c.isWhitespace {
                    flushToken()
                    i += 1
                } else if currentToken.isEmpty,
                          c.isASCII, c.isNumber,
                          let after = consumeMoveNumber(chars, from: i) {
                    // Move-number prefix (e.g. "12." or "12...") between moves.
                    i = after
                } else {
                    currentToken.append(c)
                    i += 1
                }
            }
        }
        
        flushToken()
        
        if braceDepth != 0 {
            Self.logger.error(
                """
                Movetext parse failed: unbalanced braces \
                finalBraceDepth=\(braceDepth) \
                movetextLength=\(movetext.count) \
                movesParsedBeforeFailure=\(moves.count) \
                head='\(movetext.prefix(200), privacy: .public)'
                """
            )
            throw Error.unbalancedBraces
        }
        if parenDepth != 0 {
            Self.logger.error(
                """
                Movetext parse failed: unbalanced parentheses \
                finalParenDepth=\(parenDepth) \
                movetextLength=\(movetext.count) \
                movesParsedBeforeFailure=\(moves.count) \
                head='\(movetext.prefix(200), privacy: .public)'
                """
            )
            throw Error.unbalancedParentheses
        }
        
        return (moves, evaluations)
    }
    
    /// Scans a brace comment's contents for `[%eval ...]` annotations and
    /// returns the parsed evaluation. Lichess can pack multiple PGN
    /// annotations into a single comment (e.g. `[%eval 0.23] [%clk 0:00:30]`);
    /// when more than one eval is present we return the last, which
    /// matches the "most recent annotation wins" convention.
    private static func extractEval(from braceContent: String) -> Evaluation? {
        var result: Evaluation?
        var search = Substring(braceContent)
        let prefix = "[%eval "
        
        while let startRange = search.range(of: prefix) {
            guard let endRange = search.range(
                of: "]",
                range: startRange.upperBound..<search.endIndex
            ) else {
                break
            }
            let inner = String(search[startRange.upperBound..<endRange.lowerBound])
            if let eval = Evaluation(parsingEvalTagContent: inner) {
                result = eval
            }
            search = search[endRange.upperBound...]
        }
        return result
    }
    
    // MARK: Private Helpers
    /// Normalizes CRLF and lone-CR line endings to LF before parsing. PGN
    /// files exported on Windows (and by some DGT eBoard tooling) use CRLF;
    /// `components(separatedBy: .newlines)` is a *CharacterSet* split, so it
    /// treats the CR and LF of a CRLF as two separators and injects a spurious
    /// empty line after every header line. `splitSections` then reads that
    /// empty line as the end of the tag section and drops every tag after
    /// Event. Collapsing endings to LF first makes parsing line-ending-agnostic.
    private static func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
    
    /// Whether any line of `text` opens a PGN tag pair. Used to detect a
    /// second game inside what should be one game's movetext; deliberately
    /// line-anchored, since `[` inside a brace comment is legal and common.
    private static func containsTagPairLine(_ text: String) -> Bool {
        text.components(separatedBy: .newlines).contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return false }
            return parseTag(trimmed) != nil
        }
    }
    
    private static func splitSections(_ text: String) -> (tags: String, movetext: String) {
        let lines = text.components(separatedBy: .newlines)
        var splitIndex = lines.count
        
        for (i, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                splitIndex = i
                break
            }
        }
        
        let tagLines = lines[..<splitIndex].joined(separator: "\n")
        let movetextLines = lines[splitIndex...].joined(separator: "\n")
        return (tagLines, movetextLines)
    }
    
    // Consumes \d+\.+ at `start`, returns index after; nil if not a move number.
    private static func consumeMoveNumber(_ chars: [Character], from start: Int) -> Int? {
        var i = start
        while i < chars.count, chars[i].isASCII, chars[i].isNumber { i += 1 }
        guard i > start, i < chars.count, chars[i] == "." else { return nil }
        while i < chars.count, chars[i] == "." { i += 1 }
        return i
    }
    
    /// Strips trailing `!`/`?` and **preserves** `+` and `#`.
    ///
    /// Load-bearing and easy to misread: `GameRecord.endedInMate` reads
    /// `moves.last?.hasSuffix("#")`, and D24′ round-trips `Qxg2#` byte for
    /// byte, so mate and check must survive import. The app's *other* suffix
    /// stripper — `GameState.parseSAN`'s cleaning step — drops all four,
    /// which is correct there and wrong here. These are the only two.
    private static func stripAnnotations(_ san: String) -> String {
        var result = san
        while let last = result.last, last == "!" || last == "?" {
            result.removeLast()
        }
        return result
    }
}

extension Dictionary where Key == String, Value == String {
    fileprivate subscript(tag: SevenTagRoster) -> String? { self[tag.rawValue] }
}
