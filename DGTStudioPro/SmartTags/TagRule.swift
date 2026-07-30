//
//  TagRule.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import Foundation

/// One row of a smart tag (M-prs.5, D12′): field + comparison + value,
/// evaluated against a `GameRecord`. Pure, `Codable`, stored as an array
/// on the `SmartTag` model (the `PGN.evaluations` precedent for Codable
/// value arrays on a `@Model`).
///
/// Value storage is deliberately flat — `text`, `number`, `date`,
/// `gameResult` slots, with the field's kind deciding which one is live.
/// An associated-value enum would be tighter, but the editor binds
/// controls per slot, and dead slots cost a few bytes while enum
/// bindings cost real friction. Boolean fields need no slot at all: the
/// comparison (`isTrue`/`isFalse`) *is* the value.
///
/// Matching rules, recorded:
/// - String comparisons fold **both sides** through `PlayerName.folded` +
///   `lowercased()` (D30′) — the identity philosophy exactly (case and
///   whitespace runs folded, diacritics preserved), not locale collation.
///   Before D30′ the needle trimmed `.whitespaces` only and the subject
///   folded nothing, so a double-spaced tag escaped its own rule; aligning
///   changes matching for already-saved tags, accepted at decision time.
/// - A string rule with empty/whitespace text matches **nothing** — the
///   row-level sibling of "zero rules matches nothing"; without it, a
///   freshly added `contains ""` row would match the whole Library.
/// - `player` means either seat; seats are the *resolved* display names,
///   so an unresolved `"?"` seat is simply absent.
/// - Unknowns never match: a nil `round` fails numeric rules, an undated
///   game fails date rules (its `importedAt` fallback orders folds; it
///   doesn't answer "when was this played").
/// - **Negation included** (D30′, closing the 29 July correction): an
///   unknown single subject — an unresolved `white`/`black` seat, a `""`
///   or `"?"` `event`/`site` — fails `.notEquals` too. "White is not X"
///   means *the white player is known and isn't X*; a game that doesn't
///   say can neither prove nor disprove it, same as `.player`. Positive
///   comparisons are deliberately untouched: "Event is ?" still finds
///   ?-event games — explicit is different from accidental.
internal struct TagRule: Sendable, Hashable, Codable, Identifiable {
    
    // MARK: Field
    
    internal enum Field: String, Codable, CaseIterable, Identifiable, Sendable {
        case white, black, player, event, site, name
        case result
        case round, moves
        case date
        case checkmate, analyzed, timed
        
        internal enum Kind { case string, result, number, date, boolean }
        
        internal var id: String { rawValue }
        
        internal var kind: Kind {
            switch self {
            case .white, .black, .player, .event, .site, .name: return .string
            case .result: return .result
            case .round, .moves: return .number
            case .date: return .date
            case .checkmate, .analyzed, .timed: return .boolean
            }
        }
        
        internal var displayName: String {
            switch self {
            case .player: return "Player (either)"
            case .moves:  return "Moves (plies)"
            default:      return rawValue.capitalized
            }
        }
        
        /// The comparisons this field's kind admits; the first is the
        /// editor's default when the field changes.
        internal var comparisons: [Comparison] {
            switch kind {
            case .string:  return [.contains, .equals, .notEquals, .beginsWith]
            case .result:  return [.equals, .notEquals]
            case .number:  return [.equals, .lessThan, .greaterThan]
            case .date:    return [.before, .after]
            case .boolean: return [.isTrue, .isFalse]
            }
        }
    }
    
    // MARK: Comparison
    
    internal enum Comparison: String, Codable, CaseIterable, Identifiable, Sendable {
        case contains = "contains"
        case equals = "is"
        case notEquals = "is not"
        case beginsWith = "begins with"
        case lessThan = "is less than"
        case greaterThan = "is greater than"
        case before = "is before"
        case after = "is after"
        case isTrue = "is true"
        case isFalse = "is false"
        
        internal var id: String { rawValue }
        internal var displayName: String { rawValue }
    }
    
    // MARK: Stored Properties
    
    internal var id: UUID
    internal var field: Field
    internal var comparison: Comparison
    internal var text: String
    internal var number: Int
    internal var date: Date
    internal var gameResult: GameResult
    
    // MARK: Initializers
    
    internal init(
        id: UUID = UUID(),
        field: Field = .white,
        comparison: Comparison = .contains,
        text: String = "",
        number: Int = 1,
        date: Date = .now,
        gameResult: GameResult = .whiteWins
    ) {
        self.id = id
        self.field = field
        self.comparison = comparison
        self.text = text
        self.number = number
        self.date = date
        self.gameResult = gameResult
    }
    
    // MARK: Matching
    
    internal func matches(_ record: GameRecord) -> Bool {
        switch field.kind {
        case .string:
            let needle = fold(text)
            guard !needle.isEmpty else { return false }
            switch field {
            case .player:
                let seats = [record.white?.name, record.black?.name]
                    .compactMap { $0.map(fold) }
                // Unknowns never match, negation included: a game with no
                // resolved seat can neither prove nor disprove a player rule.
                guard !seats.isEmpty else { return false }
                // A negated comparison over two seats flips the quantifier.
                // "Player is not Bera" has to mean *neither* seat is Bera;
                // `contains` made it "some seat isn't Bera", which is true of
                // every game Bera played against anyone — the exact inverse.
                return comparison == .notEquals
                ? seats.allSatisfy { compareString($0, needle) }
                : seats.contains { compareString($0, needle) }
            default:
                let subject = fold(stringSubject(of: record))
                // D30′ — the `.player` guard, extended to single subjects for
                // the negated case only (see the type doc's recorded rules).
                if comparison == .notEquals {
                    guard !subject.isEmpty, subject != "?" else { return false }
                }
                return compareString(subject, needle)
            }
            
        case .result:
            let hit = record.result == gameResult
            return comparison == .notEquals ? !hit : hit
            
        case .number:
            guard let subject = numberSubject(of: record) else { return false }
            switch comparison {
            case .lessThan:    return subject < number
            case .greaterThan: return subject > number
            default:           return subject == number
            }
            
        case .date:
            guard let subject = record.date else { return false }
            return comparison == .before ? subject < date : subject > date
            
        case .boolean:
            let subject = booleanSubject(of: record)
            return comparison == .isFalse ? !subject : subject
        }
    }
    
    /// The tag-level combinator: `matchAll` picks all/any; **zero rules
    /// matches nothing** (D12′ — an empty tag is inert, never a
    /// select-all).
    internal static func evaluate(
        _ rules: [TagRule],
        matchAll: Bool,
        against record: GameRecord
    ) -> Bool {
        guard !rules.isEmpty else { return false }
        return matchAll
        ? rules.allSatisfy { $0.matches(record) }
        : rules.contains { $0.matches(record) }
    }
    
    // MARK: Private Helpers

    /// The D30′ string fold — `PlayerName.folded` + `lowercased()`, i.e. the
    /// identity fold `Player.normalizedKey` and the content hash compose.
    /// Applied to *both* sides of every string comparison, so a rule and a
    /// tag can never disagree about what "Magnus  Carlsen" is.
    private func fold(_ value: String) -> String {
        PlayerName.folded(value).lowercased()
    }

    private func compareString(_ subject: String, _ needle: String) -> Bool {
        switch comparison {
        case .equals:     return subject == needle
        case .notEquals:  return subject != needle
        case .beginsWith: return subject.hasPrefix(needle)
        default:          return subject.contains(needle)
        }
    }
    
    private func stringSubject(of record: GameRecord) -> String {
        switch field {
        case .white: return record.white?.name ?? ""
        case .black: return record.black?.name ?? ""
        case .event: return record.event
        case .site:  return record.site
        case .name:  return record.name
        default:     return ""
        }
    }
    
    private func numberSubject(of record: GameRecord) -> Int? {
        switch field {
        case .round: return record.round
        case .moves: return record.plyCount
        default:     return nil
        }
    }
    
    private func booleanSubject(of record: GameRecord) -> Bool {
        switch field {
        case .checkmate: return record.endedInMate
        case .analyzed:  return record.hasAnalysis
        case .timed:     return record.isTimed
        default:         return false
        }
    }
}
