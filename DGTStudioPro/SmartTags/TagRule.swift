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
/// - The M4 pair (D34′) inherits both rules rather than inventing any:
///   `opening` is an ordinary string field over the full opening name, so an
///   unclassified game presents `""` and fails negation like any other
///   unknown; `checkmateType` is the first field whose subject is an optional
///   *enum*, and it guards nil the same way — see the switch arm for why
///   that is less obvious than it sounds.
internal struct TagRule: Sendable, Hashable, Codable, Identifiable {
    
    // MARK: Field
    
    internal enum Field: String, Codable, CaseIterable, Identifiable, Sendable {
        case white, black, player, event, site, name
        /// The M4 addition (D34′). A string field over the *full* opening
        /// name — `"French Defense: Winawer Variation"` — not the family
        /// alone, so a rule can reach a variation. The consequence worth
        /// knowing: `opening is French Defense` matches only games whose
        /// line has no variation, while `opening begins with French Defense`
        /// is the family-level query and `contains` (the string default)
        /// does what most rules want. One subject for every comparison,
        /// deliberately — switching subjects per comparison would be the
        /// kind of cleverness that reads as a bug six months on.
        case opening
        case result
        case round, moves
        case date
        case checkmate, analyzed, timed
        /// Which recognised checkmate type the game ended on — distinct from
        /// `checkmate`, which only asks *whether* it ended in mate.
        ///
        /// **The raw value stays `"matePattern"` and must.** This case was
        /// spelled `matePattern` until 5 Aug 2026, when the user-facing name
        /// became "Checkmate Type"; `Field` is `String, Codable` and its raw
        /// values are encoded into every saved `SmartTag`'s rule blob, so
        /// letting the implicit raw value follow the Swift name would have
        /// silently dropped the rule from every tag that used it — including
        /// the seeded "Smothered Mates" default. Hand-written for exactly the
        /// reason `InspectorSection`'s raw values are: a rename that reads as a
        /// refactor must not reset stored state.
        case checkmateType = "matePattern"

        internal enum Kind { case string, result, number, date, boolean, checkmateType }

        internal var id: String { rawValue }

        internal var kind: Kind {
            switch self {
            case .white, .black, .player, .event, .site, .name, .opening: return .string
            case .result: return .result
            case .round, .moves: return .number
            case .date: return .date
            case .checkmate, .analyzed, .timed: return .boolean
            case .checkmateType: return .checkmateType
            }
        }

        internal var displayName: String {
            switch self {
            case .player:      return "Player (either)"
            case .moves:       return "Moves (plies)"
            case .checkmateType: return "Checkmate Type"
            default:           return rawValue.capitalized
            }
        }

        /// The comparisons this field's kind admits; the first is the
        /// editor's default when the field changes.
        internal var comparisons: [Comparison] {
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
    internal var specialCheckmate: SpecialCheckmate

    // MARK: Initializers

    internal init(
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

    /// A **defaulting** decoder, because `[TagRule]` is stored as one Codable
    /// blob on `SmartTag` (D12′).
    ///
    /// Synthesized decoding requires every non-optional key to be present, so
    /// the moment this type grew its eighth slot every previously-saved tag
    /// would have failed to decode — the sidebar silently emptying, with the
    /// rules the user wrote gone. That is the D28′ draft-schema stance
    /// (additive fields are not breaking) owed to the *other* Codable-on-a-
    /// model type, and paying it once here makes every future slot free.
    ///
    /// The fallbacks come from a default-constructed instance rather than
    /// being spelled again per key: two lists of defaults that must agree is
    /// the twin-read-site pattern this codebase keeps finding and fixing, and
    /// the designated initializer is the one place they should live.
    /// `encode(to:)` stays synthesized against these same keys.
    ///
    /// The keys are spelled out rather than left to synthesis. The compiler
    /// would synthesize them here — it still synthesizes `encode(to:)`, which
    /// brings `CodingKeys` along — but the on-disk key names of a type whose
    /// blobs must survive a schema change are not something to leave to a
    /// behaviour you'd have to look up. They match the property names, which
    /// is what every already-saved tag was written with.
    /// `private`: synthesis of `encode(to:)` and the hand-written
    /// `init(from:)` both live in this file, so nothing outside it has any
    /// business naming the on-disk keys.
    private enum CodingKeys: String, CodingKey {
        case id, field, comparison, text, number, date, gameResult, specialCheckmate
    }

    internal init(from decoder: any Decoder) throws {
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

        case .checkmateType:
            // Unknowns never match, negation included — the D30′ rule, and
            // the tension is worth naming rather than glossing: a nil motif
            // means either "classified, and it's an ordinary mate" or "not
            // classified yet", and the rule cannot tell them apart (the same
            // conflation `backfillClassifications` makes with `ecoCode`).
            // Reading nil as "not smothered" would make "checkmate type is not
            // smothered" quietly true for every unclassified game in the
            // Library — precisely the failure D30′ closed for "White is
            // not X".
            guard let subject = record.specialCheckmate else { return false }
            let hit = subject == specialCheckmate
            return comparison == .notEquals ? !hit : hit
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
        // The full name, so a rule can reach a variation. An unclassified
        // game yields "", which the `.notEquals` guard above then treats as
        // an unknown — the same reading `event` and `site` get.
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
