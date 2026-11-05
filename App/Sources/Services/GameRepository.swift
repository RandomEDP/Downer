import Foundation

struct GameSetup: Sendable {
    var name: String
    var organiserName: String
    var organiserPlays: Bool
    var holes: [Hole]
    var penalties: [PenaltyRule]
}

/// Changes only the organiser can make.
enum OrganiserAction: Sendable {
    case start
    case nextHole
    case previousHole
    case finish
    case addTeam(name: String)
    case renameTeam(Team.ID, name: String)
    case removeTeam(Team.ID)
    case addPlayer(name: String, teamID: Team.ID?)
    case movePlayer(Player.ID, teamID: Team.ID?)
    case removePlayer(Player.ID)
    case saveScore(Score)
}

enum GameError: LocalizedError, Equatable {
    case gameNotFound
    case invalidCode
    case gameFinished
    case notAllowed
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .gameNotFound: "No pub golf found with that code."
        case .invalidCode: "Codes are 6 letters and numbers."
        case .gameFinished: "This pub golf has finished."
        case .notAllowed: "Only the organiser can do that."
        case .invalidInput(let message): message
        }
    }
}

/// Where games live. `LocalGameRepository` keeps them on this phone until a Supabase
/// project exists; a Supabase-backed version will implement the same protocol.
protocol GameRepository: Sendable {
    func createGame(_ setup: GameSetup, organiserToken: UUID) async throws -> Game
    /// Anyone with the code can follow the game live.
    func joinGame(code: String) async throws -> Game
    func game(id: Game.ID) async throws -> Game
    func perform(_ action: OrganiserAction, in gameID: Game.ID, organiserToken: UUID) async throws -> Game
}

/// Rules shared by every repository, so local and remote behave the same.
enum GameRules {
    static func makeGame(_ setup: GameSetup, code: String, organiserToken: UUID) throws -> Game {
        let name = setup.name.trimmed
        let organiserName = setup.organiserName.trimmed
        guard !name.isEmpty else { throw GameError.invalidInput("Give the pub golf a name.") }
        guard !setup.organiserPlays || !organiserName.isEmpty else { throw GameError.invalidInput("Enter your name.") }
        guard !setup.holes.isEmpty else { throw GameError.invalidInput("Add at least one pub.") }
        let holes = setup.holes.map { hole in
            var hole = hole
            hole.pubName = hole.pubName.trimmed
            hole.address = hole.address.trimmed
            hole.drink = hole.drink.trimmed
            hole.par = hole.par.clamped(to: Hole.parRange)
            return hole
        }
        guard holes.allSatisfy({ !$0.pubName.isEmpty }) else {
            throw GameError.invalidInput("Every hole needs a pub name.")
        }
        let penalties = setup.penalties
            .map { rule in
                var rule = rule
                rule.name = rule.name.trimmed
                rule.strokes = rule.strokes.clamped(to: PenaltyRule.strokeRange)
                return rule
            }
            .filter { !$0.name.isEmpty }
        return Game(
            code: code,
            name: name,
            organiserToken: organiserToken,
            holes: holes,
            penalties: penalties,
            players: setup.organiserPlays ? [Player(name: organiserName)] : []
        )
    }

    static func apply(_ action: OrganiserAction, to game: inout Game) throws {
        switch action {
        case .start:
            guard game.status == .lobby else { return }
            guard !game.players.isEmpty else { throw GameError.invalidInput("Add some players first.") }
            game.status = .live
            game.currentHoleIndex = 0
        case .nextHole:
            guard game.status == .live else { throw GameError.gameFinished }
            if game.isOnLastHole {
                game.status = .finished
            } else {
                game.currentHoleIndex += 1
            }
        case .previousHole:
            guard game.status == .live else { throw GameError.gameFinished }
            game.currentHoleIndex = max(0, game.currentHoleIndex - 1)
        case .finish:
            game.status = .finished

        case .addTeam(let name):
            try requireNotFinished(game)
            let name = try uniqueName(name, among: game.teams.map(\.name), kind: "team")
            game.teams.append(Team(name: name))
        case .renameTeam(let id, let name):
            guard let index = game.teams.firstIndex(where: { $0.id == id }) else { return }
            let others = game.teams.filter { $0.id != id }.map(\.name)
            game.teams[index].name = try uniqueName(name, among: others, kind: "team")
        case .removeTeam(let id):
            try requireNotFinished(game)
            game.teams.removeAll { $0.id == id }
            for index in game.players.indices where game.players[index].teamID == id {
                game.players[index].teamID = nil
            }

        case .addPlayer(let name, let teamID):
            try requireNotFinished(game)
            let name = try uniqueName(name, among: game.players.map(\.name), kind: "player")
            game.players.append(Player(name: name, teamID: game.team(teamID)?.id))
        case .movePlayer(let id, let teamID):
            guard let index = game.players.firstIndex(where: { $0.id == id }) else { return }
            game.players[index].teamID = game.team(teamID)?.id
        case .removePlayer(let id):
            try requireNotFinished(game)
            game.players.removeAll { $0.id == id }
            game.scores.removeAll { $0.playerID == id }

        case .saveScore(let score):
            try save(score, in: &game)
        }
    }

    private static func save(_ score: Score, in game: inout Game) throws {
        guard game.player(score.playerID) != nil,
              let hole = game.holes.first(where: { $0.id == score.holeID }) else {
            throw GameError.invalidInput("That hole or player isn't in this game.")
        }
        try requireNotFinished(game)
        guard game.isHoleOpen(hole) else { throw GameError.invalidInput("That hole hasn't started yet.") }

        var score = score
        score.sips = score.sips.clamped(to: Score.sipRange)
        score.penaltyIDs = score.penaltyIDs.filter { id in game.penalties.contains { $0.id == id } }
        score.updatedAt = .now
        if let index = game.scores.firstIndex(where: { $0.playerID == score.playerID && $0.holeID == score.holeID }) {
            score.id = game.scores[index].id
            game.scores[index] = score
        } else {
            game.scores.append(score)
        }
    }

    private static func requireNotFinished(_ game: Game) throws {
        guard game.status != .finished else { throw GameError.gameFinished }
    }

    private static func uniqueName(_ name: String, among existing: [String], kind: String) throws -> String {
        let name = name.trimmed
        guard !name.isEmpty else { throw GameError.invalidInput("Enter a \(kind) name.") }
        guard !existing.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw GameError.invalidInput("There's already a \(kind) called \(name).")
        }
        return name
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
