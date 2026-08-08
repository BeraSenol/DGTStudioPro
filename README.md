# DGT Studio Pro

A native macOS application for recording, analyzing, and managing over-the-board chess games played on DGT electronic boards.

Connect your DGT eBoard via USB, play your game, and get Stockfish-powered analysis, Glicko-1 rating tracking, and a full game library without ever touching a mouse.

DGT Studio Pro is a ground-up rewrite of [DGT Studio](https://github.com/BeraSenol/DGTStudio), built for production. The original was an ambitious first dive into IOKit serial I/O, SwiftData, binary protocols, and bitwise operations all at once — less a finished product, more a proof of concept that survived contact with the hardware. This version takes everything learned from that experiment and rebuilds it properly: clean architecture, a full test suite, correct data models, and none of the technical debt that accumulates when you're figuring out how a DGT board actually talks to a Mac at the same time as learning Swift.

## Screenshots

### Board

The live mirror of the physical board — coordinates printed for both seats, the stage kept clear, and the sidebar owning all connection and session status.

![The Board destination awaiting a DGT board connection](Screenshots/board-no-connection.png)

### Library

Every archived game in four view modes — icons, list, columns, and gallery — with live search, smart-tag filtering, and batch engine analysis running behind the toolbar's counter.

![The Library in icons view during a batch analysis, with the inspector showing a game's roster, evaluation graph and PGN](Screenshots/library-icons-during-batch-analysis.png)

![The Library in list view with sortable columns for ordinal, players, result and ECO code](Screenshots/library-list-during-batch-analysis.png)

![The Library in columns view, the selected game's full PGN and facts in the detail pane](Screenshots/library-columns-game-detail.png)

![The Library in gallery view, previewing a finished game's final position with the checkmated king highlighted](Screenshots/library-gallery-game-preview.png)

![The Library's filter menu: result facets and analysis state as search tokens](Screenshots/library-filter-menu.png)

### Analysis

Batch analysis with bundled Stockfish: a queue window showing the live search, per-game progress and the projected time left — and every game's evaluation curve, enlarged in its own window with a read-out under the pointer.

![The analysis queue window mid-batch: the running game's search, the line still to go, and Stop All](Screenshots/analysis-queue-window.png)

![The evaluation graph in its own window, naming the ply under the pointer](Screenshots/evaluation-graph-window.png)

### Get Info

One window over any game, recording or player — the editable Seven Tag Roster on Details, the movetext as a validated score sheet on Move Text, and the file's derived facts on File.

![Get Info's Details tab: native controls for the Seven Tag Roster and equipment tags](Screenshots/get-info-details.png)

![Get Info's Move Text tab: the score sheet, validated by full replay on every keystroke](Screenshots/get-info-move-text.png)

### Players

Every player the Library knows, ranked on a configurable ladder (wins, win rate, or Glicko-1 rating), with a full profile — record, rating trend over games played, and recent encounters — in every view mode.

![The Players ladder in icons view with the selected player's profile, rating trend and recent games](Screenshots/players-icons-profile.png)

![The Players ladder as a sortable table: rank, record, win rate, special mates and rating](Screenshots/players-list-ladder.png)

![Players in columns view, the profile and recent games in the detail pane](Screenshots/players-columns-profile.png)

![Players in gallery view, one profile at full size over the filmstrip](Screenshots/players-gallery-profile.png)
