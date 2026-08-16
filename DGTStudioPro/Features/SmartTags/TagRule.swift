import Foundation

/// One smart-tag rule: field + comparison + value over a `GameRecord`. Pure, `Codable`, stored
/// as an array blob on `SmartTag`. Flat value storage - dead slots cost bytes, enum
/// bindings cost friction. Rules of record: both sides fold through
/// `PlayerName.folded` + lowercase; unknowns never match, negation included; zero rules match nothing.
struct TagRule: Sendable, Hashable, Codable, Identifiable {
    
    // MARK: Field
    
    enum Field: String, Codable, CaseIterable, Identifiable, Sendable {
        case white, black, player, event, site, name
        /// A string field over the *full* opening name, so a rule can reach a variation -
        /// `is` matches variation-less lines only, `begins with` is family-level, `contains` is what
        /// most rules want.
        case opening
        case result
        case round, moves
        case date
        case checkmate, analyzed, timed
        /// Which checkmate type - distinct from `checkmate` (whether it was mate at all).
        /// **The raw value stays `"matePattern"` and must**: it is encoded in every saved tag's blob,
        /// and following the Swift name would silently drop the rule from every tag using it.
        case checkmateType = "matePattern"

        enum Kind { case string, result, number, date, boolean, checkmateType }

        var id: String { rawValue }

        var kind: Kind {
            switch self {
            case .white, .black, .player, .event, .site, .name, .opening: return .string
            case .result: return .result
            case .round, .moves: return .number
            case .date: return .date
            case .checkmate, .analyzed, .timed: return .boolean
            case .checkmateType: return .checkmateType
            }
        }

        var displayName: String {
            switch self {
            case .player:      return "Player (either)"
            case .moves:       return "Moves (plies)"
            case .checkmateType: return "Checkmate Type"
            default:           return rawValue.capitalized
            }
        }

        /// The comparisons this field's kind admits; the first is the editor's default.
        var comparisons: [Comparison] {
            switch kind {
            case .string:           return [.contains, .equals, .notEquals, .beginsWith]
            case .result:           return [.equals, .notEquals]
            case .number:           return [.equals, .lessThan, .greaterThan]
            case .date:             return [.before, .after]
            case .boolean:          return [.isTrue, .isFalse]
            case .checkmateType: return [.equals, .notEquals]
            }
        }
    }
    
    // MARK: Comparison
    
    enum Comparison: String, Codable, CaseIterable, Identifiable, Sendable {
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
        
        var id: String { rawValue }
        var displayName: String { rawValue }
    }
    
    // MARK: Stored Properties
    
    var id: UUID
    var field: Field
    var comparison: Comparison
    var text: String
    var number: Int
    var date: Date
    var gameResult: GameResult
    var specialCheckmate: SpecialCheckmate

    // MARK: Initializers

    init(
        id: UUID = UUID(),
        field: Field = .white,
        comparison: Comparison = .contains,
        text: String = "",
        number: Int = 1,
        date: Date = .now,
        gameResult: GameResult = .whiteWins,
        specialCheckmate: SpecialCheckmate = .smothered
    ) {
        self.id = id
        self.field = field
        self.comparison = comparison
        self.text = text
        self.number = number
        self.date = date
        self.gameResult = gameResult
        self.specialCheckmate = specialCheckmate
    }

    // MARK: Codable

    /// A **defaulting** decoder: `[TagRule]` is one blob on `SmartTag`, and synthesized decoding
    /// would fail every saved tag when a field is added - the sidebar silently emptying. Fallbacks
    /// come from a default-constructed instance, not a second list of literals.
    private enum CodingKeys: String, CodingKey {
        case id, field, comparison, text, number, date, gameResult, specialCheckmate
    }

    init(from decoder: any Decoder) throws {
        let fallback = TagRule()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? fallback.id
        field = try container.decodeIfPresent(Field.self, forKey: .field) ?? fallback.field
        comparison = try container.decodeIfPresent(Comparison.self, forKey: .comparison)
            ?? fallback.comparison
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? fallback.text
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? fallback.number
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? fallback.date
        gameResult = try container.decodeIfPresent(GameResult.self, forKey: .gameResult)
            ?? fallback.gameResult
        specialCheckmate = try container.decodeIfPresent(
            SpecialCheckmate.self, forKey: .specialCheckmate
        ) ?? fallback.specialCheckmate
    }
    
    // MARK: Matching
    
    func matches(_ record: GameRecord) -> Bool {
        switch field.kind {
        case .string:
            let needle = fold(text)
            guard !needle.isEmpty else { return false }
            switch field {
            case .player:
                let seats = [record.white?.name, record.black?.name]
                    .compactMap { $0.map(fold) }
                // Unknowns never match, negation included: no resolved seat proves nothing.
                guard !seats.isEmpty else { return false }
                // A negated comparison over two seats flips the quantifier: "player is not X" means *neither*
                // seat is X - `contains` made it true of every game X played.
                return comparison == .notEquals
                ? seats.allSatisfy { compareString($0, needle) }
                : seats.contains { compareString($0, needle) }
            default:
                let subject = fold(stringSubject(of: record))
                // The unknown guard, `.notEquals` only (positive comparisons deliberately untouched).
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

        case .checkmateType:
            // Unknowns never match, negation included: a nil motif means "ordinary mate" or "not
            // classified yet", and the rule cannot tell - reading nil as "not X" would match every
            // unclassified game.
            guard let subject = record.specialCheckmate else { return false }
            let hit = subject == specialCheckmate
            return comparison == .notEquals ? !hit : hit
        }
    }
    
    /// The combinator: `matchAll` picks all/any; **zero rules matches nothing** (a fresh tag is
    /// inert, never select-all).
    static func evaluate(
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

    /// The string fold - the same fold `Player.normalizedKey` and the hash compose, applied to
    /// *both* sides.
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
        // Full name, so a rule can reach a variation; unclassified yields "", which `.notEquals` treats
        // as unknown.
        case .opening: return record.opening?.fullName ?? ""
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
