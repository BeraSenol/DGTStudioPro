import Testing
@testable import DGTStudioPro

@Suite("Position")
struct PositionTests {

    // MARK: Quiet Moves
    @Test func quietPawnPush() {
        let move = Move.make(
            from: Squares.e2, to: Squares.e3,
            pieceType: .pawn, pieceColor: .white
        )
        let result = Position.starting.applying(move)

        #expect(result[Squares.e3] == .whitePawn)
        #expect(result[Squares.e2] == .empty)
    }

    @Test func doublePawnPush() {
        let move = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        let result = Position.starting.applying(move)

        #expect(result[Squares.e4] == .whitePawn)
        #expect(result[Squares.e2] == .empty)
    }

    @Test func sourceUntouchedByApplying() {
        let starting = Position.starting
        let move = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        _ = starting.applying(move)

        // Receiver must be unchanged.
        #expect(starting[Squares.e2] == .whitePawn)
        #expect(starting[Squares.e4] == .empty)
    }

    // MARK: Captures
    @Test func regularCapture() {
        // White e4, black d5: white plays exd5.
        var position = Position.empty
        position[Squares.e4] = .whitePawn
        position[Squares.d5] = .blackPawn

        let move = Move.make(
            from: Squares.e4, to: Squares.d5,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .pawn
        )
        let result = position.applying(move)

        #expect(result[Squares.d5] == .whitePawn)
        #expect(result[Squares.e4] == .empty)
    }

    @Test func enPassantCapture() {
        // White e5, black d5: white plays exd6 e.p., captures pawn on d5 (not d6).
        var position = Position.empty
        position[Squares.e5] = .whitePawn
        position[Squares.d5] = .blackPawn

        let move = Move.make(
            from: Squares.e5, to: Squares.d6,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .pawn,
            isEnPassant: true
        )
        let result = position.applying(move)

        #expect(result[Squares.d6] == .whitePawn)
        #expect(result[Squares.e5] == .empty)
        #expect(result[Squares.d5] == .empty)
    }

    @Test func enPassantCaptureBlack() {
        // Mirror: black e4, white d4, black plays exd3 e.p., captures on d4.
        var position = Position.empty
        position[Squares.e4] = .blackPawn
        position[Squares.d4] = .whitePawn

        let move = Move.make(
            from: Squares.e4, to: Squares.d3,
            pieceType: .pawn, pieceColor: .black,
            capturedPieceType: .pawn,
            isEnPassant: true
        )
        let result = position.applying(move)

        #expect(result[Squares.d3] == .blackPawn)
        #expect(result[Squares.e4] == .empty)
        #expect(result[Squares.d4] == .empty)
    }

    // MARK: Castling
    @Test(arguments: [
        (color: PieceColor.white, kingFrom: Squares.e1, kingTo: Squares.g1, rookFrom: Squares.h1, rookTo: Squares.f1),
        (color: PieceColor.white, kingFrom: Squares.e1, kingTo: Squares.c1, rookFrom: Squares.a1, rookTo: Squares.d1),
        (color: PieceColor.black, kingFrom: Squares.e8, kingTo: Squares.g8, rookFrom: Squares.h8, rookTo: Squares.f8),
        (color: PieceColor.black, kingFrom: Squares.e8, kingTo: Squares.c8, rookFrom: Squares.a8, rookTo: Squares.d8),
    ])
    func castling(
        color: PieceColor,
        kingFrom: Square, kingTo: Square,
        rookFrom: Square, rookTo: Square
    ) async {
        var position = Position.empty
        position[kingFrom] = Piece(color, .king)
        position[rookFrom] = Piece(color, .rook)

        let move = Move.make(
            from: kingFrom, to: kingTo,
            pieceType: .king, pieceColor: color,
            isCastling: true
        )
        let result = position.applying(move)

        #expect(result[kingTo]   == Piece(color, .king))
        #expect(result[rookTo]   == Piece(color, .rook))
        #expect(result[kingFrom] == .empty)
        #expect(result[rookFrom] == .empty)
    }

    // MARK: Promotion
    @Test(arguments: [PieceType.queen, .rook, .bishop, .knight])
    func promotion(to type: PieceType) async {
        var position = Position.empty
        position[Squares.e7] = .whitePawn

        let move = Move.make(
            from: Squares.e7, to: Squares.e8,
            pieceType: .pawn, pieceColor: .white,
            promotionType: type
        )
        let result = position.applying(move)

        #expect(result[Squares.e8] == Piece(.white, type))
        #expect(result[Squares.e7] == .empty)
    }

    @Test func promotionWithCapture() {
        // White e7, black rook on f8: white plays exf8=Q.
        var position = Position.empty
        position[Squares.e7] = .whitePawn
        position[Squares.f8] = .blackRook

        let move = Move.make(
            from: Squares.e7, to: Squares.f8,
            pieceType: .pawn, pieceColor: .white,
            capturedPieceType: .rook,
            promotionType: .queen
        )
        let result = position.applying(move)

        #expect(result[Squares.f8] == .whiteQueen)
        #expect(result[Squares.e7] == .empty)
    }

    // MARK: Composition
    @Test func chainedApplications() {
        // 1. e4 e5 2. Nf3 Nc6 - multi-move composition.
        let result = Position.starting
            .applying(.make(from: Squares.e2, to: Squares.e4, pieceType: .pawn, pieceColor: .white, isDoublePawnPush: true))
            .applying(.make(from: Squares.e7, to: Squares.e5, pieceType: .pawn, pieceColor: .black, isDoublePawnPush: true))
            .applying(.make(from: Squares.g1, to: Squares.f3, pieceType: .knight, pieceColor: .white))
            .applying(.make(from: Squares.b8, to: Squares.c6, pieceType: .knight, pieceColor: .black))

        #expect(result[Squares.e4] == .whitePawn)
        #expect(result[Squares.e5] == .blackPawn)
        #expect(result[Squares.f3] == .whiteKnight)
        #expect(result[Squares.c6] == .blackKnight)
        #expect(result[Squares.e2] == .empty)
        #expect(result[Squares.e7] == .empty)
        #expect(result[Squares.g1] == .empty)
        #expect(result[Squares.b8] == .empty)
    }
}
