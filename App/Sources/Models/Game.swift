import Foundation

enum GameStatus: String, Codable, Sendable {
    /// Players are joining; no scores yet.
    case lobby
    /// Round in progress at `Game.currentHoleIndex`.
    case live
    /// Round over; scores are read-only.
    case finished
}

/// One pub on the route. Par is the target number of sips for the drink.
struct Hole: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var pubName: String
    var address: String = ""
    var drink: String
    var par: Int

    static let parRange = 1...30
}

/// A rule break that adds strokes, e.g. "Toilet break +2".
struct PenaltyRule: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var strokes: Int

    static let strokeRange = 1...10
}

struct Team: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
}

struct Player: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var teamID: Team.ID?
}

/// A player's result on one hole. Strokes = sips + penalty strokes.
struct Score: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var playerID: Player.ID
    var holeID: Hole.ID
    var sips: Int
    var penaltyIDs: [PenaltyRule.ID] = []
    var updatedAt = Date()

    static let sipRange = 1...99
}

struct Game: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var code: String
    var name: String
    /// Secret that identifies the organiser's phone (the auth user id once Supabase is on).
    var organiserToken: UUID
    var holes: [Hole]
    var penalties: [PenaltyRule]
    var teams: [Team] = []
    var players: [Player] = []
    var scores: [Score] = []
    var status: GameStatus = .lobby
    var currentHoleIndex = 0
    var createdAt = Date()

    var currentHole: Hole? { hole(at: currentHoleIndex) }
    var nextHole: Hole? { hole(at: currentHoleIndex + 1) }
    var isOnLastHole: Bool { currentHoleIndex >= holes.count - 1 }
    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }

    func hole(at index: Int) -> Hole? {
        holes.indices.contains(index) ? holes[index] : nil
    }

    func holeNumber(of hole: Hole) -> Int {
        (holes.firstIndex { $0.id == hole.id } ?? 0) + 1
    }

    func player(_ id: Player.ID) -> Player? {
        players.first { $0.id == id }
    }

    func team(_ id: Team.ID?) -> Team? {
        id.flatMap { id in teams.first { $0.id == id } }
    }

    func players(in team: Team.ID?) -> [Player] {
        players.filter { $0.teamID == team }
    }

    func score(player: Player.ID, hole: Hole.ID) -> Score? {
        scores.first { $0.playerID == player && $0.holeID == hole }
    }

    /// Holes that can be scored: every hole reached so far while live, none otherwise.
    func isHoleOpen(_ hole: Hole) -> Bool {
        guard status == .live, let index = holes.firstIndex(where: { $0.id == hole.id }) else { return false }
        return index <= currentHoleIndex
    }
}

extension Hole {
    /// Starter route the organiser edits: 9 holes with common drinks and par in sips.
    static func defaultCourse() -> [Hole] {
        let drinks: [(String, Int)] = [
            ("Pint", 5), ("Half pint", 3), ("Shot", 1),
            ("Cider", 5), ("Glass of wine", 4), ("Pint", 5),
            ("Shot", 1), ("Half pint", 3), ("Pint", 5),
        ]
        return drinks.enumerated().map { index, drink in
            Hole(pubName: "Pub \(index + 1)", drink: drink.0, par: drink.1)
        }
    }
}

extension PenaltyRule {
    static func defaultRules() -> [PenaltyRule] {
        [
            PenaltyRule(name: "Toilet break", strokes: 2),
            PenaltyRule(name: "Spilt drink", strokes: 1),
            PenaltyRule(name: "Phone on the table", strokes: 1),
        ]
    }
}
