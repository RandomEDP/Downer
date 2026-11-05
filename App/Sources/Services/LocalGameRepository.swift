import Foundation

/// Keeps games on this phone in a JSON file. Joining by code only finds games created on the
/// same phone; real sharing between phones arrives with the Supabase backend.
actor LocalGameRepository: GameRepository {
    private var games: [Game.ID: Game]
    private let fileURL: URL?

    /// `fileURL` nil keeps everything in memory (tests and previews).
    init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL,
           let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Game].self, from: data) {
            games = Dictionary(saved.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        } else {
            games = [:]
        }
    }

    static func onDisk() -> LocalGameRepository {
        LocalGameRepository(fileURL: URL.applicationSupportDirectory.appending(path: "games.json"))
    }

    func createGame(_ setup: GameSetup, organiserToken: UUID) async throws -> Game {
        var code = GameCode.generate()
        while games.values.contains(where: { $0.code == code }) {
            code = GameCode.generate()
        }
        let game = try GameRules.makeGame(setup, code: code, organiserToken: organiserToken)
        try store(game)
        return game
    }

    func joinGame(code: String) async throws -> Game {
        let code = GameCode.normalize(code)
        guard GameCode.isValid(code) else { throw GameError.invalidCode }
        guard let game = games.values.first(where: { $0.code == code }) else { throw GameError.gameNotFound }
        return game
    }

    func game(id: Game.ID) async throws -> Game {
        guard let game = games[id] else { throw GameError.gameNotFound }
        return game
    }

    func perform(_ action: OrganiserAction, in gameID: Game.ID, organiserToken: UUID) async throws -> Game {
        guard var game = games[gameID] else { throw GameError.gameNotFound }
        guard game.organiserToken == organiserToken else { throw GameError.notAllowed }
        try GameRules.apply(action, to: &game)
        try store(game)
        return game
    }

    private func store(_ game: Game) throws {
        games[game.id] = game
        guard let fileURL else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(Array(games.values))
        try data.write(to: fileURL, options: .atomic)
    }
}
