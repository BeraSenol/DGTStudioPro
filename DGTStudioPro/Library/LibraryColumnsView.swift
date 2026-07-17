//
//  LibraryColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/05/2026.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: Grouping Dimension
internal enum LibraryGroupingDimension: String, CaseIterable, Identifiable {
    case event
    case player
    case year
    
    internal var id: String { rawValue }
    
    internal var displayName: String {
        switch self {
        case .event:  return "Event"
        case .player: return "Player"
        case .year:   return "Year"
        }
    }
    
    internal var systemImage: String {
        switch self {
        case .event:  return "trophy"
        case .player: return "person"
        case .year:   return "calendar"
        }
    }
}

// MARK: Group
internal struct LibraryGroup: Identifiable, Hashable {
    internal let id: String
    internal let displayName: String
    internal let games: [PGN]
    
    internal var gameCount: Int { games.count }
    
    internal static func == (lhs: LibraryGroup, rhs: LibraryGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: Columns View
internal struct LibraryColumnsView: View {
    
    // MARK: Stored Properties
    internal let games: [PGN]
    @Binding internal var selectedPGNs: Set<PGN.ID>
    internal let onOpen: (PGN) -> Void
    let onAnalyze: (PGN) -> Void
    internal let onDelete: (PGN) -> Void
    
    // MARK: Private Properties
    @State private var dimension: LibraryGroupingDimension = .event
    @State private var selectedGroupID: String?
    
    // MARK: Computed Properties
    
    /// Grouping is a pure function of the current games + dimension. It's
    /// recomputed on each body run, which is what SwiftUI is built for: a
    /// `Dictionary(grouping:)` over the library is cheap, and computing it
    /// directly avoids both the one-frame empty flash and the stale-cache
    /// hazard of caching it keyed on game *identity* (the contents that drive
    /// the grouping — event / players / year — can change without the ID set
    /// changing, which matters once games become editable).
    private var groups: [LibraryGroup] {
        Self.makeGroups(from: games, dimension: dimension)
    }
    
    private var selectedGroup: LibraryGroup? {
        guard let id = selectedGroupID else { return nil }
        return groups.first(where: { $0.id == id })
    }
    
    private var selectedPGN: PGN? {
        guard let id = selectedPGNs.first else { return nil }
        return games.first(where: { $0.id == id })
    }
    
    // MARK: Body
    internal var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 360, maxHeight: .infinity)
            
            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: dimension) { _, _ in
            // Group IDs are dimension-scoped; clear stale selection when
            // the user switches dimensions.
            selectedGroupID = nil
            selectedPGNs.removeAll()
        }
    }
    
    // MARK: Instance Methods
    private var sidebar: some View {
        VStack(spacing: 0) {
            dimensionPicker
            Divider()
            groupList
        }
    }
    
    private var dimensionPicker: some View {
        Picker("Group By", selection: $dimension) {
            ForEach(LibraryGroupingDimension.allCases) { dim in
                Label(dim.displayName, systemImage: dim.systemImage).tag(dim)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(8)
    }
    
    @ViewBuilder
    private var groupList: some View {
        if groups.isEmpty {
            VStack {
                Spacer()
                Text("No \(dimension.displayName.lowercased())s")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(selection: $selectedGroupID) {
                ForEach(groups) { group in
                    HStack {
                        Label(group.displayName, systemImage: dimension.systemImage)
                            .lineLimit(1)
                        Spacer()
                        Text("\(group.gameCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .tag(group.id)
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    @ViewBuilder
    private var detail: some View {
        Group {
            if let group = selectedGroup {
                groupGames(group)
            } else {
                ContentUnavailableView(
                    "No \(dimension.displayName) Selected",
                    systemImage: "square.dashed",
                    description: Text("Select a \(dimension.displayName.lowercased()) on the left to see its games.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func groupGames(_ group: LibraryGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                groupHeader(group)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(group.games) { game in
                        LibraryGameCardView(
                            game: game,
                            isSelected: selectedPGNs.contains(game.id),
                            onSelect:  { selectedPGNs = [game.id] },
                            onOpen:    { onOpen(game) },
                            onAnalyze: { onAnalyze(game) },
                            onDelete:  { onDelete(game) }
                        )
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func groupHeader(_ group: LibraryGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.displayName)
                .font(.title2)
                .fontWeight(.semibold)
            Text("\(group.gameCount) game\(group.gameCount == 1 ? "" : "s")")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: Static Methods
    private static func makeGroups(
        from games: [PGN],
        dimension: LibraryGroupingDimension
    ) -> [LibraryGroup] {
        switch dimension {
        case .event:  return groupByEvent(games)
        case .player: return groupByPlayer(games)
        case .year:   return groupByYear(games)
        }
    }
    
    private static func groupByEvent(_ games: [PGN]) -> [LibraryGroup] {
        let buckets = Dictionary(grouping: games, by: \.event)
        return buckets
            .map { LibraryGroup(id: "event:\($0.key)", displayName: $0.key, games: $0.value) }
            .sorted { $0.displayName < $1.displayName }
    }
    
    private static func groupByPlayer(_ games: [PGN]) -> [LibraryGroup] {
        var buckets: [String: [PGN]] = [:]
        for game in games {
            let whiteKey = game.whiteDisplayName
            let blackKey = game.blackDisplayName
            buckets[whiteKey, default: []].append(game)
            if blackKey != whiteKey {
                buckets[blackKey, default: []].append(game)
            }
        }
        return buckets
            .map { LibraryGroup(id: "player:\($0.key)", displayName: $0.key, games: $0.value) }
            .sorted { $0.displayName < $1.displayName }
    }
    
    private static func groupByYear(_ games: [PGN]) -> [LibraryGroup] {
        let calendar = Calendar.current
        var buckets: [Int?: [PGN]] = [:]
        for game in games {
            let year = game.date.map { calendar.component(.year, from: $0) }
            buckets[year, default: []].append(game)
        }
        return buckets
            .map { year, games in
                let display = year.map(String.init) ?? "Undated"
                let id = year.map { "year:\($0)" } ?? "year:undated"
                return LibraryGroup(id: id, displayName: display, games: games)
            }
        // Most recent year first, undated last.
            .sorted { lhs, rhs in
                if lhs.displayName == "Undated" { return false }
                if rhs.displayName == "Undated" { return true }
                return lhs.displayName > rhs.displayName
            }
    }
}

// MARK: Previews
private func columnsPreviewGames() -> [PGN] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    
    return [
        PGN(event: "World Championship", site: "Dubai",
            date: formatter.date(from: "2021.12.10"),
            round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "World Championship", site: "Dubai",
            date: formatter.date(from: "2021.12.07"),
            round: 9,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .draw),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee",
            date: formatter.date(from: "2024.01.20"),
            round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger",
            date: formatter.date(from: "2023.06.03"),
            round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        PGN(event: "Candidates Tournament", site: "Madrid",
            date: formatter.date(from: "2022.07.04"),
            round: 14,
            white: "Nepomniachtchi, Ian", black: "Ding, Liren", result: .ongoing),
        PGN(event: "Norway Chess", site: "Stavanger",
            date: nil,
            round: 5,
            white: "Carlsen, Magnus", black: "Firouzja, Alireza", result: .whiteWins)
    ]
}

#Preview("With Games") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    LibraryColumnsView(
        games: columnsPreviewGames(),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    
    LibraryColumnsView(
        games: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 600)
    .modelContainer(for: PGN.self, inMemory: true)
}
