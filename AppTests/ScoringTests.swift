import Foundation
import Testing
@testable import Downer

struct ScoringTests {
    private func makeGame(holes: [Hole], players: [Player], teams: [Team] = [], penalties: [PenaltyRule] = []) -> Game {
        Game(code: "ABCDEF", name: "Test", organiserToken: UUID(), holes: holes, penalties: penalties,
             teams: teams, players: players, status: .live, currentHoleIndex: holes.count - 1)
    }

    @Test func strokesAddPenalties() {
        let toilet = PenaltyRule(name: "Toilet", strokes: 2)
        let spill = PenaltyRule(name: "Spill", strokes: 1)
        let score = Score(playerID: UUID(), holeID: UUID(), sips: 4, penaltyIDs: [toilet.id, spill.id])
        #expect(Scoring.strokes(for: score, penalties: [toilet, spill]) == 7)
    }

    @Test func unknownPenaltiesAreIgnored() {
        let score = Score(playerID: UUID(), holeID: UUID(), sips: 3, penaltyIDs: [UUID()])
        #expect(Scoring.strokes(for: score, penalties: []) == 3)
    }

    @Test func leaderboardRanksByScoreToParAndSharesTies() {
        let holes = [Hole(pubName: "A", drink: "Pint", par: 5), Hole(pubName: "B", drink: "Shot", par: 1)]
        let amy = Player(name: "Amy"), ben = Player(name: "Ben"), cat = Player(name: "Cat"), dan = Player(name: "Dan")
        var game = makeGame(holes: holes, players: [dan, cat, ben, amy])
        game.scores = [
            Score(playerID: amy.id, holeID: holes[0].id, sips: 4),
            Score(playerID: amy.id, holeID: holes[1].id, sips: 1), // -1
            Score(playerID: ben.id, holeID: holes[0].id, sips: 4), // -1 after one hole
            Score(playerID: cat.id, holeID: holes[0].id, sips: 7), // +2
        ]

        let board = Scoring.leaderboard(for: game)
        #expect(board.map(\.player.name) == ["Amy", "Ben", "Cat", "Dan"])
        #expect(board.map(\.rank) == [1, 1, 3, 4])
        #expect(board[0].toPar == -1)
        #expect(board[0].holesPlayed == 2)
        #expect(board[3].holesPlayed == 0)
    }

    @Test func teamsRankOnAveragePlayerScore() {
        let hole = Hole(pubName: "A", drink: "Pint", par: 5)
        let red = Team(name: "Red"), blue = Team(name: "Blue"), empty = Team(name: "Empty")
        let r1 = Player(name: "R1", teamID: red.id), r2 = Player(name: "R2", teamID: red.id)
        let b1 = Player(name: "B1", teamID: blue.id)
        var game = makeGame(holes: [hole], players: [r1, r2, b1], teams: [empty, red, blue])
        game.scores = [
            Score(playerID: r1.id, holeID: hole.id, sips: 4), // -1
            Score(playerID: r2.id, holeID: hole.id, sips: 7), // +2
            Score(playerID: b1.id, holeID: hole.id, sips: 5), // E
        ]

        let board = Scoring.teamLeaderboard(for: game)
        #expect(board.map(\.team.name) == ["Blue", "Red", "Empty"])
        #expect(board[1].averageToPar == 0.5)
        #expect(board[1].players.count == 2)
        #expect(board[2].hasScores == false)
    }

    @Test func formatsToPar() {
        #expect(Scoring.formatToPar(0) == "E")
        #expect(Scoring.formatToPar(3) == "+3")
        #expect(Scoring.formatToPar(-2) == "-2")
        #expect(Scoring.formatToPar(1.5) == "+1.5")
        #expect(Scoring.formatToPar(-0.25) == "-0.3" || Scoring.formatToPar(-0.25) == "-0.2")
        #expect(Scoring.formatToPar(2.0) == "+2")
    }
}

struct GameCodeTests {
    @Test func generatedCodesAreValid() {
        for _ in 0..<100 {
            #expect(GameCode.isValid(GameCode.generate()))
        }
    }

    @Test func normalizesInput() {
        #expect(GameCode.normalize(" abc-23x ") == "ABC23X")
        #expect(GameCode.isValid("ABC23X"))
        #expect(!GameCode.isValid("ABC10X")) // 1 and 0 are excluded
        #expect(!GameCode.isValid("ABC"))
    }
}
