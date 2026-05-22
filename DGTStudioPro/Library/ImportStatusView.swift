//
//  ImportStatusView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 22/05/2026.
//

import SwiftUI

// MARK: - Result Model

/// Outcome of importing a single PGN file in a batch. Drives one row in
/// the import status sheet.
internal struct ImportResult: Identifiable {
    internal let id = UUID()
    internal let fileName: String
    internal let outcome: Outcome
    
    internal enum Outcome {
        case imported(name: String)
        case failed(PGNStore.Error)
    }
}

/// Live state of a running (or finished) import batch. The Library owns
/// one of these as `@State` and mutates it per file; the sheet renders it.
internal struct ImportProgress {
    internal var total: Int
    internal var results: [ImportResult] = []
    internal var isFinished: Bool = false
    
    internal var completed: Int { results.count }
    
    internal var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
    
    internal var importedCount: Int {
        results.filter {
            if case .imported = $0.outcome { return true }
            return false
        }.count
    }
    
    internal var duplicateCount: Int {
        results.filter {
            if case .failed(.duplicate) = $0.outcome { return true }
            return false
        }.count
    }
    
    internal var failedCount: Int {
        results.filter {
            switch $0.outcome {
            case .failed(.duplicate): return false
            case .failed:             return true
            case .imported:           return false
            }
        }.count
    }
}

// MARK: - Sheet

internal struct ImportStatusView: View {
    
    internal let progress: ImportProgress
    internal let onDismiss: () -> Void
    
    internal var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            List(progress.results) { result in
                ImportResultRow(result: result)
            }
            .listStyle(.inset)
            .frame(minHeight: 200)
            
            Divider()
            
            footer
        }
        .frame(width: 460, height: 420)
    }
    
    // MARK: Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.isFinished ? "Import Complete" : "Importing…")
                .font(.headline)
            
            ProgressView(
                value: Double(progress.completed),
                total: Double(max(progress.total, 1))
            )
            
            Text("\(progress.completed) of \(progress.total)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding()
    }
    
    // MARK: Footer
    
    private var footer: some View {
        HStack {
            if progress.isFinished {
                summaryText
            }
            Spacer()
            Button(progress.isFinished ? "Done" : "Cancel", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .disabled(!progress.isFinished)
        }
        .padding()
    }
    
    @ViewBuilder
    private var summaryText: some View {
        let parts: [String] = {
            var p: [String] = []
            if progress.importedCount > 0  { p.append("\(progress.importedCount) imported") }
            if progress.duplicateCount > 0 { p.append("\(progress.duplicateCount) duplicate") }
            if progress.failedCount > 0    { p.append("\(progress.failedCount) failed") }
            return p
        }()
        Text(parts.isEmpty ? "Nothing imported" : parts.joined(separator: ", "))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Row

private struct ImportResultRow: View {
    
    let result: ImportResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.body)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var icon: String {
        switch result.outcome {
        case .imported:            return "checkmark.circle.fill"
        case .failed(.duplicate):  return "doc.on.doc"
        case .failed:              return "exclamationmark.triangle.fill"
        }
    }
    
    private var tint: Color {
        switch result.outcome {
        case .imported:            return .green
        case .failed(.duplicate):  return .orange
        case .failed:              return .red
        }
    }
    
    private var title: String {
        switch result.outcome {
        case .imported(let name):           return name
        case .failed(.duplicate(let pgn)):  return pgn.name
        case .failed:                       return result.fileName
        }
    }
    
    private var detail: String {
        switch result.outcome {
        case .imported:
            return result.fileName
        case .failed(.duplicate):
            return "Already in your library — skipped."
        case .failed(.missingRequiredTags(let tags)):
            return "Missing required tags: \(tags.sorted().joined(separator: ", "))."
        case .failed(.malformedPGN(let reason)):
            return reason
        case .failed(.fileReadFailed):
            return "Couldn't read the file."
        }
    }
}
