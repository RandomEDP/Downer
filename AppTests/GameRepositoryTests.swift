import Foundation
import Testing
@testable import Downer

struct GameRepositoryTests {
    private let organiser = UUID()

    private func setup(organiserPlays: Bool = true) -> GameSetup {
        GameSetup(
            name: "  Friday golf ", organiserName: "Ethan", organiserPlays: organiserPlays,
            holes: Hole.defaultCourse(), penalties: PenaltyRule.defaultRules() + [PenaltyRule(name: "  ", strokes: 3)]
        )
    }

    @Test func createTrimsAndAddsOrganiserAsPlayer() async throws {
        let repo = LocalGameRepository(fileURL: nil)
        let game = try await repo.createGame(setup(), organiserToken: organiser)
        #expect(game.name == "Friday golf")
        #expect(game.players.map(\.name) == ["Ethan"])
        #expect(game.holes.count == 9)
        #expect(game.penalties.count == 3) // blank rule dropped
        #expect(GameCode.isValid(game.code))
        #expect(game.status == .lobby)
    }

    @Test func organiserCanSitOut() async throws {
        let repo = LocalGameRepository(fileURL: nil)
        let game = try await repo.createGame(setup(organiserPlays: false), organiserToken: organiser)
        #expect(game.players.isEmpty)
    }

    @Test func createRejectsUnnamedPub() async {
        let repo = LocalGameRepository(fileURL: nil)
        var bad = setup()
        bad.holes[2].pubName = " "
        await #expect(throws: GameError.invalidInput("Every hole needs a pub name.")) {
            try await repo.createGame(bad, organiserToken: organiser)
        }
    }

    @Test func joinByCodeIsCaseInsensitive() async throws {
        let repo = LocalGameRepository(fileURL: nil)
        let game = try await repo.createGame(setup(), organiserToken: organiser)
        let joined = try await repo.joinGame(code: game.code.lowercased())
        #expect(joined.id == game.id)
        await #expect(throws: GameError.gameNotFound) { try await repo.joinGame(code: "ZZZZZZ") }
        await #expect(throws: GameError.invalidCode) { try await repo.joinGame(code: "AB") }
    }

    @Test func onlyOrganiserCanChangeTheGame() async throws {
        let repo = LocalGameRepository(fileURL: nil)
        let game = try await repo.createGame(setup(), organiserToken: organiser)
        await #expect(throws: GameError.notAllowed) {
            try await repo.perform(.start, in: game.id, organiserToken: UUID())
        }
    }

    @Test func fullRoundWithTeams() async throws {
        let repo = LocalGameRepository(fileURL: nil)
        var game = try await repo.createGame(setup(), organiserToken: organiser)
        let id = game.id

        game = try await repo.perform(.addTeam(name: "Red"), in: id, organiserToken: organiser)
        let red = try #require(game.teams.first)
        await #expect(throws: GameError.invalidInput("There's already a team called red.")) {
            try await repo.perform(.addTeam(name: "red"), in: id, organiserToken: organiser)
        }
        game = try await repo.perform(.addPlayer(name: "Sam", teamID: red.id), in: id, organiserToken: organiser)
        let ethan = try #require(game.players.first { $0.name == "Ethan" })
        let sam = try #require(game.players.first { $0.name == "Sam" })
        game = try await repo.perform(.movePlayer(ethan.id, teamID: red.id), in: id, organiserToken: organiser)
        #expect(game.players(in: red.id).count == 2)

        // Can't score before the round starts.
        let firstHole = game.holes[0]
        await #expect(throws: GameError.invalidInput("That hole hasn't started yet.")) {
            try await repo.perform(.saveScore(Score(playerID: sam.id, holeID: firstHole.id, sips: 3)), in: id, organiserToken: organiser)
        }

        game = try await repo.perform(.start, in: id, organiserToken: organiser)
        #expect(game.status == .live)
        game = try await repo.perform(.saveScore(Score(playerID: sam.id, holeID: firstHole.id, sips: 3)), in: id, organiserToken: organiser)
        // Saving again replaces rather than duplicates.
        game = try await repo.perform(.saveScore(Score(playerID: sam.id, holeID: firstHole.id, sips: 200)), in: id, organiserToken: organiser)
        #expect(game.scores.count == 1)
        #expect(game.scores[0].sips == Score.sipRange.upperBound)

        // Can't score a hole the group hasn't reached.
        await #expect(throws: GameError.invalidInput("That hole hasn't started yet.")) {
            try await repo.perform(.saveScore(Score(playerID: sam.id, holeID: game.holes[1].id, sips: 3)), in: id, organiserToken: organiser)
        }

        for _ in 0..<(game.holes.count - 1) {
            game = try await repo.perform(.nextHole, in: id, organiserToken: organiser)
        }
        #expect(game.status == .live)
        #expect(game.isOnLastHole)
        game = try await repo.perform(.nextHole, in: id, organiserToken: organiser)
        #expect(game.status == .finished)

        await #expect(throws: GameError.gameFinished) {
            try await repo.perform(.saveScore(Score(playerID: sam.id, holeID: firstHole.id, sips: 3)), in: id, organiserToken: organiser)
        }
    }

    @Test func removingTeamUnassignsPlayersAndRemovingPlayerDropsScores() async throws {
        var game = Game.preview(status: .live)
        let team = game.teams[0]
        let player = game.players[0]
        try GameRules.apply(.removeTeam(team.id), to: &game)
        #expect(game.player(player.id)?.teamID == nil)
        #expect(game.scores.contains { $0.playerID == player.id })
        try GameRules.apply(.removePlayer(player.id), to: &game)
        #expect(!game.scores.contains { $0.playerID == player.id })
    }

    @Test func gamesPersistToDisk() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "downer-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let game = try await LocalGameRepository(fileURL: url).createGame(setup(), organiserToken: organiser)
        let reloaded = try await LocalGameRepository(fileURL: url).game(id: game.id)
        #expect(reloaded == game)
    }
}

@MainActor
struct AppModelTests {
    private func makeModel() -> AppModel {
        let defaults = UserDefaults(suiteName: "downer-tests-\(UUID())")!
        return AppModel(repository: LocalGameRepository(fileURL: nil), defaults: defaults)
    }

    @Test func creatorIsOrganiserAndViewerIsNot() async throws {
        let repo = LocalGameRepository(fileURL: nil)
        let organiserPhone = AppModel(repository: repo, defaults: UserDefaults(suiteName: "a-\(UUID())")!)
        let friendPhone = AppModel(repository: repo, defaults: UserDefaults(suiteName: "b-\(UUID())")!)

        let created = await organiserPhone.create(GameSetup(
            name: "Test", organiserName: "Ethan", organiserPlays: true,
            holes: Hole.defaultCourse(), penalties: []
        ))
        #expect(created)
        #expect(organiserPhone.isOrganiser)

        let code = try #require(organiserPhone.game?.code)
        #expect(await friendPhone.join(code: code))
        #expect(friendPhone.isOrganiser == false)
        #expect(await friendPhone.perform(.start) == false)
        #expect(friendPhone.errorMessage == GameError.notAllowed.errorDescription)
    }

    @Test func leaveForgetsTheGame() async {
        let model = makeModel()
        await model.create(GameSetup(name: "Test", organiserName: "", organiserPlays: false, holes: Hole.defaultCourse(), penalties: []))
        #expect(model.game != nil)
        model.leave()
        #expect(model.game == nil)
    }
}
