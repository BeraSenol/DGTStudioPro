import SwiftData
import SwiftUI

/// One recent game of the selected player: name over date, the result trailing, tap opens the
/// game's Get Info. **One view since the 26 Aug 2026 DRY sweep** - the columns detail pane and
/// the Players inspector each carried a byte-identical private copy with nothing tying them, the
/// twin-read-site shape in row clothes: a reword in one would have drifted the other silently.
/// Same subject, same meaning, one spelling - section identity is what a row shows, not where.
struct PlayerRecentGameRow: View {

    let game: PGN

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(value: game.persistentModelID)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .lineLimit(1)
                    Text(game.displayDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(game.result.rawValue)
                    .font(.callout.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
