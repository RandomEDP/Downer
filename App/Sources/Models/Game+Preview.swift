import Foundation

extension Game {
    /// Sample data for previews and tests only.
    static func preview(status: GameStatus) -> Game {
        let teams = [Team(name: "Bogeymen"), Team(name: "Hole in Ones")]
        let players = [
            Player(name: "Ethan", teamID: teams[0].id),
            Player(name: "Sam", teamID: teams[0].id),
            Player(name: "Alex", teamID: teams[1].id),
            Player(name: "Jo", teamID: teams[1].id),
        ]
        let holes = Hole.defaultCourse()
        let penalties = PenaltyRule.defaultRules()
        var game = Game(
            code: "PUB123", name: "Ethan's birthday", organiserToken: UUID(),
            holes: holes, penalties: penalties, teams: teams, players: players,
            status: status, currentHoleIndex: status == .lobby ? 0 : 2
        )
        if status != .lobby {
            for (p, player) in players.enumerated() {
                for (h, hole) in holes.prefix(status == .finished ? holes.count : 2).enumerated() {
                    game.scores.append(Score(
                        playerID: player.id, holeID: hole.id,
                        sips: max(1, hole.par + (p + h) % 3 - 1),
                        penaltyIDs: (p + h) % 4 == 0 ? [penalties[0].id] : []
                    ))
                }
            }
        }
        return game
    }
}
