//
//  PGNStore.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 15/04/2026.
//

import Foundation
import SwiftData
import os

// MARK: PGN Store
internal struct PGNStore {

    // MARK: Static Constants
    private static let logger = Logger(subsystem: "com.berasenol.dgtstudiopro", category: "pgnstore")

    // MARK: Stored Properties
    private let modelContext: ModelContext

    // MARK: Initializers
    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}
