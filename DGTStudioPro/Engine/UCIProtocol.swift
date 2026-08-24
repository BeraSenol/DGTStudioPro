import Foundation

/// Parses line-based UCI output. Parsing only - sending and subprocess management are the engine's.
enum UCIProtocol {
    
    // MARK: Entry Point
    
    /// One line → response, or nil for empty / unrecognized / deliberately-ignored `option` lines
    /// (the app sends its options; it never negotiates against advertisements).
    static func parse(_ line: String) -> UCIResponse? {
        // `.whitespacesAndNewlines`, not `.whitespaces` (space+tab only). The case that decides it
        // is a *keyword* wearing a line ending - `"readyok\n"` matches nothing under the narrower
        // set. A bare `"\n"` does not decide anything: it returns nil either way, through the empty
        // exit here or through the unknown-keyword default below, which is why
        // `keywordSurvivesTrailingNewlineOrCR` is the pin and `parse("\n") == nil` is not.
        // Defensive in production - `ingestStdoutChunk` strips `\n` and `\r` before this sees a line.
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let tokens = trimmed
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let first = tokens.first else { return nil }
        let rest = Array(tokens.dropFirst())
        
        switch first {
        case "info":     return parseInfo(rest)
        case "bestmove": return parseBestMove(rest)
        case "readyok":  return .readyOK
        case "uciok":    return .uciOK
        case "id":       return parseID(rest)
        default:         return nil
        }
    }

    // MARK: Two Kinds of nil

    /// Keywords understood and deliberately not acted on - `option` is the recorded invariant.
    static let deliberatelyIgnoredKeywords: Set<String> = [
        "option", "copyprotection", "registration"
    ]

    /// Whether nil meant *known and ignored* rather than *unrecognized*. This distinction
    /// existed only in prose; ~25 option lines per start made the error channel unreadable.
    static func isDeliberatelyIgnored(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(separator: " ").first else { return false }
        return deliberatelyIgnoredKeywords.contains(String(first))
    }

    // MARK: info Line Parsing
    
    /// `info` fields, walked by keyword; PV terminates the line. Optional for symmetry with its two
    /// siblings only - **this one never returns nil**, so a bare `info` yields an empty `UCIInfo`.
    private static func parseInfo(_ tokens: [String]) -> UCIResponse? {
        var info = UCIInfo()
        var i = 0
        
        while i < tokens.count {
            let key = tokens[i]
            i += 1
            
            switch key {
            case "depth":
                if let v = consumeInt(tokens, at: &i) { info.depth = v }
            case "seldepth":
                if let v = consumeInt(tokens, at: &i) { info.selectiveDepth = v }
            case "nodes":
                if let v = consumeInt(tokens, at: &i) { info.nodes = v }
            case "nps":
                if let v = consumeInt(tokens, at: &i) { info.nodesPerSecond = v }
            case "time":
                if let v = consumeInt(tokens, at: &i) { info.timeMs = v }
            case "score":
                info.score = consumeScore(tokens, at: &i)
            case "pv":
                // PV runs to end of line.
                info.pv = Array(tokens[i...])
                i = tokens.count
            case "multipv", "hashfull", "tbhits", "currmove", "currmovenumber":
                // Recognized, not stored.
                _ = consumeToken(tokens, at: &i)
            case "lowerbound", "upperbound":
                // Aspiration-window qualifiers on `score`, and the only payload-less keywords in
                // the set. Enumerated *because* they are: the default below would eat the keyword
                // after them, costing the field it names.
                break
            case "string":
                // `string` runs to end of line - engine debug text.
                i = tokens.count
            default:
                // Best-effort skip one token in case it had a payload. The bet is that unknown
                // keywords carry values; an unknown payload-less one swallows its successor, which
                // is what the two cases above exist to prevent.
                _ = consumeToken(tokens, at: &i)
            }
        }
        
        return .info(info)
    }
    
    private static func consumeScore(
        _ tokens: [String],
        at i: inout Int
    ) -> UCIScore? {
        guard i < tokens.count else { return nil }
        let kind = tokens[i]
        i += 1
        guard i < tokens.count, let value = Int(tokens[i]) else { return nil }
        i += 1
        
        switch kind {
        case "cp":   return .centipawns(value)
        case "mate": return .mate(value)
        default:     return nil
        }
    }
    
    // MARK: bestmove Line Parsing
    
    /// `bestmove <move> [ponder <move>]` - UCI long algebraic (`e7e8q` for promotions).
    private static func parseBestMove(_ tokens: [String]) -> UCIResponse? {
        guard let move = tokens.first else { return nil }
        var ponder: String? = nil
        
        if tokens.count >= 3, tokens[1] == "ponder" {
            ponder = tokens[2]
        }
        
        return .bestMove(UCIBestMove(move: move, ponder: ponder))
    }
    
    // MARK: id Line Parsing
    
    /// `id name/author <value>`; the value runs to end of line.
    private static func parseID(_ tokens: [String]) -> UCIResponse? {
        guard tokens.count >= 2 else { return nil }
        let key = tokens[0]
        let value = tokens.dropFirst().joined(separator: " ")
        return .id(key: key, value: value)
    }
    
    // MARK: Helpers
    
    private static func consumeInt(_ tokens: [String], at i: inout Int) -> Int? {
        guard i < tokens.count, let value = Int(tokens[i]) else { return nil }
        i += 1
        return value
    }
    
    private static func consumeToken(_ tokens: [String], at i: inout Int) -> String? {
        guard i < tokens.count else { return nil }
        let value = tokens[i]
        i += 1
        return value
    }
}

// MARK: Response Types

enum UCIResponse: Equatable, Sendable {
    case info(UCIInfo)
    case bestMove(UCIBestMove)
    case readyOK
    case uciOK
    case id(key: String, value: String)
}

struct UCIInfo: Equatable, Sendable {
    var depth: Int? = nil
    var selectiveDepth: Int? = nil
    var score: UCIScore? = nil
    var pv: [String]? = nil
    var nodes: Int? = nil
    var timeMs: Int? = nil
    var nodesPerSecond: Int? = nil
}

/// Shape-identical to `Evaluation` and **deliberately not collapsed into it**: this one is
/// side-to-move relative, `Evaluation` is white-relative, and the two are unmixable only because
/// they are different types. `toEvaluation(sideToMove:)` is the single crossing.
enum UCIScore: Equatable, Sendable {
    /// Centipawns, side-to-move perspective (UCI native).
    case centipawns(Int)
    /// Mate distance, side-to-move perspective.
    case mate(Int)

    /// → white-relative `Evaluation`; UCI scores are always side-to-move relative.
    func toEvaluation(sideToMove: PieceColor) -> Evaluation {
        let raw: Evaluation
        switch self {
        case .centipawns(let cp): raw = .centipawns(cp)
        case .mate(let n):        raw = .mate(n)
        }
        return sideToMove == .white ? raw : raw.flipped
    }
}

struct UCIBestMove: Equatable, Sendable {
    /// Move in UCI long algebraic notation, e.g. `"e2e4"` or `"e7e8q"`.
    let move: String
    /// Pondered reply, optional - most engines emit it only when enabled.
    let ponder: String?
}
