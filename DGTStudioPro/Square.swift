//
//  Square.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

typealias Square = Int

enum Squares {
    static let a1 = 0,  b1 = 1,  c1 = 2,  d1 = 3,  e1 = 4,  f1 = 5,  g1 = 6,  h1 = 7
    static let a2 = 8,  b2 = 9,  c2 = 10, d2 = 11, e2 = 12, f2 = 13, g2 = 14, h2 = 15
    static let a3 = 16, b3 = 17, c3 = 18, d3 = 19, e3 = 20, f3 = 21, g3 = 22, h3 = 23
    static let a4 = 24, b4 = 25, c4 = 26, d4 = 27, e4 = 28, f4 = 29, g4 = 30, h4 = 31
    static let a5 = 32, b5 = 33, c5 = 34, d5 = 35, e5 = 36, f5 = 37, g5 = 38, h5 = 39
    static let a6 = 40, b6 = 41, c6 = 42, d6 = 43, e6 = 44, f6 = 45, g6 = 46, h6 = 47
    static let a7 = 48, b7 = 49, c7 = 50, d7 = 51, e7 = 52, f7 = 53, g7 = 54, h7 = 55
    static let a8 = 56, b8 = 57, c8 = 58, d8 = 59, e8 = 60, f8 = 61, g8 = 62, h8 = 63
}

extension Square {
    public var isOnBoard: Bool { UInt(bitPattern: self) < 64 }
    
    public var file: Int { self % 8 }
    public var rank: Int { self / 8 }
    
    public var fileIndicator: Character {
        Character(UnicodeScalar(Int(UnicodeScalar("a").value) + file)!)
    }
    
    public var rankIndicator: Character {
        Character(UnicodeScalar(Int(UnicodeScalar("1").value) + rank)!)
    }
    
    public var algebraicNotation: String {
        Int.algebraicNotationTable[self]
    }
    
    internal static func fromAlgebraicNotation(_ name: String) -> Square? {
        var utf8 = name.utf8.makeIterator()
        
        guard let fileByte = utf8.next(),
              let rankByte = utf8.next(),
              utf8.next() == nil else {
            print("fromAlgebraic: expected 2 characters, got '\(name)'")
            return nil
        }
        
        let file = Int(fileByte) - Int(UInt8(ascii: "a"))
        let rank = Int(rankByte) - Int(UInt8(ascii: "1"))
        
        guard UInt(bitPattern: file) < 8,
              UInt(bitPattern: rank) < 8 else {
            print("fromAlgebraic: '\(name)' out of bounds")
            return nil
        }
        
        return rank * 8 + file
    }
    
    private static let algebraicNotationTable: [String] = {
        (0..<64).map { square in
            let file = Character(UnicodeScalar(Int(UnicodeScalar("a").value) + square % 8)!)
            let rank = Character(UnicodeScalar(Int(UnicodeScalar("1").value) + square / 8)!)
            
            return String(file) + String(rank)
        }
    }()
}
