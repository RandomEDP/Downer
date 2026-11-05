import Foundation

struct LeaderboardEntry: Identifiable, Hashable, Sendable {
    let player: Player
    let rank: Int
    let strokes: Int
    let parPlayed: Int
    let holesPlayed: Int

    var id: Player.ID { player.id }
    var toPar: Int { strokes - parPlayed }
}

/// Teams rank on their players' average score to par, so team sizes can differ.
struct TeamLeaderboardEntry: Identifiable, Hashable, Sendable {
    let team: Team
    let rank: Int
    let players: [LeaderboardEntry]
    let averageToPar: Double
    let strokes: Int

    var id: Team.ID { team.id }
    var hasScores: Bool { players.contains { $0.holesPlayed > 0 } }
}

enum Scoring {
    static func strokes(for score: Score, penalties: [PenaltyRule]) -> Int {
        let penaltyStrokes = score.penaltyIDs.reduce(0) { total, id in
            total + (penalties.first { $0.id == id }?.strokes ?? 0)
        }
        return score.sips + penaltyStrokes
    }

    /// Ranked by score relative to par so players who are a hole behind still compare fairly.
    /// Ties share a rank (1, 1, 3). Players with no holes played go last.
    static func leaderboard(for game: Game) -> [LeaderboardEntry] {
        struct Row {
            let player: Player
            let strokes: Int
            let par: Int
            let holes: Int
            var toPar: Int { strokes - par }
        }

        let rows: [Row] = game.players.map { player in
            var strokes = 0, par = 0, holes = 0
            for hole in game.holes {
                guard let score = game.score(player: player.id, hole: hole.id) else { continue }
                strokes += Scoring.strokes(for: score, penalties: game.penalties)
                par += hole.par
                holes += 1
            }
            return Row(player: player, strokes: strokes, par: par, holes: holes)
        }

        let sorted = rows.sorted { a, b in
            if (a.holes == 0) != (b.holes == 0) { return a.holes > 0 }
            if a.toPar != b.toPar { return a.toPar < b.toPar }
            if a.holes != b.holes { return a.holes > b.holes }
            return a.player.name.localizedCaseInsensitiveCompare(b.player.name) == .orderedAscending
        }

        var entries: [LeaderboardEntry] = []
        for (index, row) in sorted.enumerated() {
            var rank = index + 1
            if let previous = entries.last,
               previous.toPar == row.toPar,
               (previous.holesPlayed > 0) == (row.holes > 0) {
                rank = previous.rank
            }
            entries.append(LeaderboardEntry(
                player: row.player, rank: rank, strokes: row.strokes,
                parPlayed: row.par, holesPlayed: row.holes
            ))
        }
        return entries
    }

    static func teamLeaderboard(for game: Game) -> [TeamLeaderboardEntry] {
        let individual = leaderboard(for: game)
        let rows = game.teams.map { team in
            let members = individual.filter { $0.player.teamID == team.id }
            let played = members.filter { $0.holesPlayed > 0 }
            let average = played.isEmpty ? 0 : Double(played.reduce(0) { $0 + $1.toPar }) / Double(played.count)
            return (team: team, members: members, average: average, strokes: members.reduce(0) { $0 + $1.strokes }, hasScores: !played.isEmpty)
        }
        let sorted = rows.sorted { a, b in
            if a.hasScores != b.hasScores { return a.hasScores }
            if a.average != b.average { return a.average < b.average }
            return a.team.name.localizedCaseInsensitiveCompare(b.team.name) == .orderedAscending
        }
        var entries: [TeamLeaderboardEntry] = []
        for (index, row) in sorted.enumerated() {
            var rank = index + 1
            if let previous = entries.last, previous.averageToPar == row.average, previous.hasScores == row.hasScores {
                rank = previous.rank
            }
            entries.append(TeamLeaderboardEntry(
                team: row.team, rank: rank, players: row.members, averageToPar: row.average, strokes: row.strokes
            ))
        }
        return entries
    }

    /// Team averages with one decimal place, e.g. "+1.5", "E".
    static func formatToPar(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return formatToPar(Int(rounded)) }
        return rounded > 0 ? String(format: "+%.1f", rounded) : String(format: "%.1f", rounded)
    }

    /// Golf style: "E" for even, "+3", "-2".
    static func formatToPar(_ value: Int) -> String {
        switch value {
        case 0: "E"
        case let v where v > 0: "+\(v)"
        default: "\(value)"
        }
    }
}
