//
//  Board.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

typealias Square = Int

extension Square {
    var file: Int { self % 8 }
    var rank: Int { self / 8 }
}
