# DGT Studio Pro

![Platform](https://img.shields.io/badge/platform-macOS%2026.2%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)

A native macOS application for recording, analyzing, and managing over-the-board chess games played on DGT electronic boards.

Connect your DGT eBoard via USB, play your game, and get Stockfish-powered analysis, Glicko-1 rating tracking, and a full game library without ever touching a mouse.

DGT Studio Pro is a ground-up rewrite of [DGT Studio](https://github.com/BeraSenol/DGTStudio), built for production. The original was an ambitious first dive into IOKit serial I/O, SwiftData, binary protocols, and bitwise operations all at once - less a finished product, more a proof of concept that survived contact with the hardware. This version takes everything learned from that experiment and rebuilds it properly: clean architecture, a full test suite, correct data models, and none of the technical debt that accumulates when you're figuring out how a DGT board actually talks to a Mac at the same time as learning Swift.

## At a glance

- **Live recording** - moves played on the physical board are reconstructed into SAN in real time by a hand-built serial stack: IOKit transport, byte framer with resync, message decoder, board diff, and a move reconstructor that only commits a move when it is the single legal explanation of the whole board. Desync recovery guidance, crash-safe drafts, and automatic archiving of finished games.
- **Game library** - SwiftData-backed, with four view modes (icons, list, columns, gallery), live search with token filters, rule-based smart tags, sortable columns, and batch import with content-hash deduplication.
- **Engine analysis** - batch Stockfish analysis with a live queue window and time estimates, per-ply evaluation storage, Syzygy tablebase support, and evaluation graphs with a read-out under the pointer.
- **Players and ratings** - an automatic player registry, Glicko-1 ratings, a configurable ranking ladder (wins, win rate, or rating), and full profiles with rating trends and head-to-head records.
- **Openings and checkmates** - engine-free classification: ECO opening names by longest-prefix match against the bundled lichess table, and special-checkmate detection (smothered, back rank) from the final position.
- **PGN fidelity** - export byte-pinned to DGT's own reference files; a Get Info window where the Seven Tag Roster is edited through native controls and movetext edits are validated by full legal replay before they are accepted.

## Screenshots

### Board

The live mirror, coordinates printed for both seats. Session status floats over the board; the inspector holds the roster, the moves, and the lifecycle verbs.

#### No board attached
![The Board destination with no DGT board attached](Screenshots/boardview-no-board-connected.png)
![The connection sheet reporting nothing at /dev/cu.usbmodem01, offering Try Again](Screenshots/boardviewwindow-board-connection-not-found.png)
![The connection sheet resetting the board and reading its starting position](Screenshots/boardviewwindow-board-connecting.png)
![The connection sheet reporting the board's serial and firmware](Screenshots/boardviewwindow-board-connected.png)

#### Ready to record
![A connected board at the starting position, the floating card inviting a new game](Screenshots/boardview-board-connected-no-live-game.png)

#### New Game
![The New Game window, both seats picked from the player registry](Screenshots/boardviewwindow-new-game.png)

#### Live recording
![A live recording after 1. d4 e5, the played squares lit](Screenshots/boardview-board-connected-during-live-game.png)

### Library
Four view modes, live search, smart tags, batch analysis.

#### Icons view
![The Library in icons view](Screenshots/libraryview-iconsview.png)

#### List view
![The Library in list view, sortable on every column](Screenshots/libraryview-listview.png)

#### Columns view
![The Library in columns view](Screenshots/libraryview-columnsview.png)

#### Gallery view
![The Library in gallery view, the mated king highlighted](Screenshots/libraryview-galleryview.png)

#### Batch selection
![All 111 games selected, with the batch menu](Screenshots/libraryview-listview-all-games-selected-contextmenu.png)

#### Details
![The Seven Tag Roster in native controls](Screenshots/window-getinfo-details.png)

#### Move Text
![The score sheet, validated by legal replay](Screenshots/window-getinfo-movetext-editor.png)

#### File
![Content hash, ECO and checkmate type](Screenshots/window-getinfo-file.png)

#### View Options
![Library View Options: sort, icon size, grid spacing](Screenshots/libraryviewwindow-viewoptions.png)

#### Smart Tag editor
![A named, coloured tag built from rules](Screenshots/window-smarttag-editor.png)

### Analysis
Bundled Stockfish, run as a batch.
![The analysis queue mid-batch, with time remaining](Screenshots/window-analysis-queue.png)
![The evaluation graph, reading out the ply under the pointer](Screenshots/window-evaluation-graph.png)

### Players
A configurable ladder - wins, win rate, or Glicko-1 rating - with a profile in every view mode.

#### Icons view
![The Players ladder in icons view](Screenshots/playersview-iconview.png)

#### List view
![The ladder as a table: record, win rate, special mates, rating](Screenshots/playersview-listview.png)

#### Columns view
![Players in columns view](Screenshots/playersview-columnsview.png)

#### Gallery view
![Players in gallery view, with rating trend and head-to-head](Screenshots/playersview-galleryview.png)

### Get Info
One window over any game or player.
![A player's record and rating trend](Screenshots/playersviewwindow-getinfo-profile.png)
![Head-to-head against one opponent](Screenshots/playersviewwindow-getinfo-matchup.png)

#### View Options
![Players View Options: sort, icon size, grid spacing](Screenshots/playerviewwindow-viewoptions.png)

### Settings
![Auto-connect and two sleep guards](Screenshots/window-settings-general.png)
![Four board styles and the piece-glide duration](Screenshots/window-settings-board.png)
![A sound set and per-event toggles](Screenshots/window-settings-sounds.png)
![Depth, hash, threads, and an optional Syzygy folder](Screenshots/window-settings-engine.png)
![The stored game count and Erase Library](Screenshots/window-settings-data.png)

### Previews
Xcode previews, each holding every state of one view at once.

#### Import results
![Each rejected file with its reason](Screenshots/previews-importstatusview.png)

#### Game card
![A Library game card in its selection states](Screenshots/previews-librarygamecardview.png)

## License

MIT - see [LICENSE](LICENSE). Stockfish is a separate work under GPL-3.0 and is not distributed with this repository. Opening classification data is from [lichess-org/chess-openings](https://github.com/lichess-org/chess-openings) (CC0). This is a personal project, not affiliated with or endorsed by DGT.
