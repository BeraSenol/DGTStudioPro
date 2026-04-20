//
//  PGNParser.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/04/2026.
//

import Foundation

// MARK: PGN Parser
internal struct PGNParser {
    
    // MARK: Static Constants
    internal static let requiredTags: Set<String> = [
        "Event", "Site", "Date", "Round", "White", "Black", "Result"
    ]
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // MARK: Static Methods
    internal static func missingTags(in tags: [String: String]) -> Set<String> {
        requiredTags.subtracting(tags.keys)
    }
    
    internal static func parseTags(from text: String) -> [String: String] {
        var tags: [String: String] = [:]
        
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if let (key, value) = parseTag(trimmed) {
                tags[key] = value
            }
        }
        
        return tags
    }
    
    internal static func parseTag(_ line: String) -> (String, String)? {
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
    
    internal static func parseDate(string date: String?) -> Date? {
        guard let date, !date.contains("?") else { return nil }
        return dateFormatter.date(from: date)
    }
    
    internal static func parseRound(string round: String?) -> Int? {
        guard let round else { return nil }
        return Int(round)
    }
    
    internal static func parseResult(_ string: String?) -> GameResult {
        guard let string, let result = GameResult(rawValue: string) else {
            return .ongoing
        }
        return result
    }
}
