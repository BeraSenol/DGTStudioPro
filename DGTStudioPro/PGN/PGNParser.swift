//
//  PGNParser.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/04/2026.
//

//
//  PGNParser.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/04/2026.
//

import Foundation

// MARK: PGN Parser
internal enum PGNParser {
    
    // MARK: Static Constants
    internal static let requiredTags: Set<String> = Set(
        SevenTagRoster.allCases.map(\.rawValue)
    )
    
    private static let resultTokens: Set<String> = Set(
        GameResult.allCases.map(\.rawValue)
    )
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // MARK: Errors
    internal enum Error: Swift.Error, Equatable {
        case missingRequiredTags(Set<String>)
        case unbalancedBraces
        case unbalancedParentheses
    }
    
    // MARK: Entry Point
    internal static func parse(_ text: String) throws -> PGN {
        let (tagSection, movetextSection) = splitSections(text)
        
        let tags = parseTags(from: tagSection)
        let missing = missingTags(in: tags)
        if !missing.isEmpty {
            throw Error.missingRequiredTags(missing)
        }
        
        let (moves, evaluations) = try parseMovesAndEvaluations(from: movetextSection)
        
        return PGN(
            event: tags[.event] ?? "",
            site:  tags[.site]  ?? "",
            date:  parseDate(tags[.date]),
            round: parseRound(tags[.round]),
            white: tags[.white] ?? "",
            black: tags[.black] ?? "",
            moves: moves,
            evaluations: evaluations.contains(where: { $0 != nil }) ? evaluations : [],
            result: parseResult(tags[.result]),
            timeControl: parseTimeControl(tags["TimeControl"])
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
    internal static func parseMoves(from movetext: String) throws -> [String] {
        let cleaned = try strip(movetext)
        let tokens = cleaned.split(whereSeparator: { $0.isWhitespace })
        
        var result: [String] = []
        for token in tokens {
            let str = String(token)
            if resultTokens.contains(str) { continue }
            let san = stripAnnotations(str)
            if !san.isEmpty {
                result.append(san)
            }
        }
        return result
    }
    
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
    ) throws -> (moves: [String], evaluations: [Evaluation?]) {
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
        
        if braceDepth != 0 { throw Error.unbalancedBraces }
        if parenDepth != 0 { throw Error.unbalancedParentheses }
        
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
    
    private static func strip(_ input: String) throws -> String {
        var output = ""
        var braceDepth = 0
        var parenDepth = 0
        var inLineComment = false
        
        let chars = Array(input)
        var i = 0
        
        while i < chars.count {
            let c = chars[i]
            
            if inLineComment {
                if c == "\n" { inLineComment = false }
                i += 1
                continue
            }
            
            if braceDepth > 0 {
                if c == "}" { braceDepth -= 1 }
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
                braceDepth = 1
                output.append(" ")
                i += 1
                
            case "(":
                parenDepth = 1
                output.append(" ")
                i += 1
                
            case ";":
                inLineComment = true
                i += 1
                
            case "$":
                i += 1
                while i < chars.count, chars[i].isASCII, chars[i].isNumber { i += 1 }
                output.append(" ")
                
            default:
                if c.isASCII, c.isNumber, let after = consumeMoveNumber(chars, from: i) {
                    output.append(" ")
                    i = after
                } else {
                    output.append(c)
                    i += 1
                }
            }
        }
        
        if braceDepth != 0 { throw Error.unbalancedBraces }
        if parenDepth != 0 { throw Error.unbalancedParentheses }
        
        return output
    }
    
    // Consumes \d+\.+ at `start`, returns index after; nil if not a move number.
    private static func consumeMoveNumber(_ chars: [Character], from start: Int) -> Int? {
        var i = start
        while i < chars.count, chars[i].isASCII, chars[i].isNumber { i += 1 }
        guard i > start, i < chars.count, chars[i] == "." else { return nil }
        while i < chars.count, chars[i] == "." { i += 1 }
        return i
    }
    
    // Strip trailing !/? annotations; preserve + (check) and # (mate).
    private static func stripAnnotations(_ san: String) -> String {
        var end = san.endIndex
        while end > san.startIndex {
            let prev = san.index(before: end)
            let c = san[prev]
            if c == "!" || c == "?" {
                end = prev
            } else {
                break
            }
        }
        return String(san[..<end])
    }
}

extension Dictionary where Key == String, Value == String {
    fileprivate subscript(tag: SevenTagRoster) -> String? { self[tag.rawValue] }
}
