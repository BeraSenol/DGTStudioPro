# DGT Studio Pro

A native macOS application for recording, analyzing, and managing over-the-board chess games played on DGT electronic boards.

Connect your DGT eBoard via USB, play your game, and get Stockfish-powered analysis, Elo tracking, and a full game library without ever touching a mouse.

DGT Studio Pro is a ground-up rewrite of [DGT Studio](https://github.com/BeraSenol/DGTStudio), built for production. The original was an ambitious first dive into IOKit serial I/O, SwiftData, binary protocols, and bitwise operations all at once — less a finished product, more a proof of concept that survived contact with the hardware. This version takes everything learned from that experiment and rebuilds it properly: clean architecture, a full test suite, correct data models, and none of the technical debt that accumulates when you're figuring out how a DGT board actually talks to a Mac at the same time as learning Swift.
