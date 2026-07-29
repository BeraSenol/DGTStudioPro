//
//  UCIProtocol.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 14/05/2026.
//

import Foundation

/// Parses the line-based UCI (Universal Chess Interface) protocol that
/// Stockfish and most chess engines speak over stdin/stdout.
///
/// This module handles **parsing** only; sending UCI commands and managing
/// the engine subprocess is the `StockfishEngine` actor's concern (7.5b).
/// The split keeps the parser pure and deterministically testable without
/// needing a real engine binary.
internal enum UCIProtocol {
    
    // MARK: Entry Point
    
    /// Parses a single line of UCI output. Returns `nil` if the line is
    /// empty, whitespace-only, or doesn't match a recognized response form
    /// (including `option` discovery lines, which are deliberately ignored:
    /// the app *sends* its options from `EngineConfiguration.uciOptionLines`
    /// rather than negotiating against the engine's advertised catalogue, so
    /// there is nothing to do with an inbound `option` line. Parsing them
    /// would only matter if option support ever became engine-dependent.)
    internal static func parse(_ line: String) -> UCIResponse? {
        // `.whitespacesAndNewlines`, not `.whitespaces` (which is space +
        // tab only): the framer upstream strips \n before calling, so this
        // is correctness of the pure function, not a production bug — a
        // bare "\n" takes the empty exit instead of falling through as an
        // unknown keyword, and a keyword carrying a stray \r or \n still
        // parses rather than silently reading as garbage. Pinned by
        // `keywordSurvivesTrailingNewlineOrCR`.
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
    
    // MARK: info Line Parsing
    
    /// Parses an `info` line's fields. UCI info lines have variable-length
    /// PV terminating the line, so the parser walks tokens by keyword and
    /// consumes the appropriate number of values per keyword type.
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
                // Single-value fields we recognize but don't store.
                _ = consumeToken(tokens, at: &i)
            case "lowerbound", "upperbound":
                // Aspiration-window qualifiers on `score`; no payload.
                break
            case "string":
                // `string` runs to end of line and carries engine debug text.
                i = tokens.count
            default:
                // Unknown keyword: best-effort skip one token in case it
                // had a payload. Robust for almost all real UCI variants.
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
    
    /// Parses `bestmove <move> [ponder <move>]`. Move syntax is UCI's long
    /// algebraic notation (4 chars for normal moves, 5 chars with trailing
    /// piece letter for promotions, e.g. `"e7e8q"`).
    private static func parseBestMove(_ tokens: [String]) -> UCIResponse? {
        guard let move = tokens.first else { return nil }
        var ponder: String? = nil
        
        if tokens.count >= 3, tokens[1] == "ponder" {
            ponder = tokens[2]
        }
        
        return .bestMove(UCIBestMove(move: move, ponder: ponder))
    }
    
    // MARK: id Line Parsing
    
    /// Parses `id name <value>` or `id author <value>`. The value runs to
    /// end of line and may contain spaces.
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

internal enum UCIResponse: Equatable, Sendable {
    case info(UCIInfo)
    case bestMove(UCIBestMove)
    case readyOK
    case uciOK
    case id(key: String, value: String)
}

internal struct UCIInfo: Equatable, Sendable {
    internal var depth: Int? = nil
    internal var selectiveDepth: Int? = nil
    internal var score: UCIScore? = nil
    internal var pv: [String]? = nil
    internal var nodes: Int? = nil
    internal var timeMs: Int? = nil
    internal var nodesPerSecond: Int? = nil
}

internal enum UCIScore: Equatable, Sendable {
    /// Centipawns from side-to-move perspective (UCI native form).
    case centipawns(Int)
    /// Mate distance from side-to-move perspective (UCI native form).
    case mate(Int)
    
    /// Converts to a white-relative `Evaluation`, given the side to move
    /// at the time this score was emitted. UCI scores are always side-to-
    /// move relative; app storage is always white-relative.
    internal func toEvaluation(sideToMove: PieceColor) -> Evaluation {
        let raw: Evaluation
        switch self {
        case .centipawns(let cp): raw = .centipawns(cp)
        case .mate(let n):        raw = .mate(n)
        }
        return sideToMove == .white ? raw : raw.flipped
    }
}

internal struct UCIBestMove: Equatable, Sendable {
    /// Move in UCI long algebraic notation, e.g. `"e2e4"` or `"e7e8q"`.
    internal let move: String
    /// Engine's pondered reply, if announced. UCI ponder hints are
    /// optional and most engines emit them only when explicitly enabled.
    internal let ponder: String?
}
