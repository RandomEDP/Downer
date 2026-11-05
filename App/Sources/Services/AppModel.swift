import Foundation
import Observation

/// App-wide state: which game this phone is following, and whether it's the organiser's phone.
@MainActor
@Observable
final class AppModel {
    private(set) var game: Game?
    var errorMessage: String?

    @ObservationIgnored private let repository: any GameRepository
    @ObservationIgnored private let defaults: UserDefaults

    private static let gameKey = "session.gameID"
    private static let tokenKey = "device.organiserToken"

    init(repository: any GameRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    /// Stable per install. Stands in for the signed-in user until Supabase auth is on.
    var organiserToken: UUID {
        if let saved = defaults.string(forKey: Self.tokenKey).flatMap(UUID.init(uuidString:)) { return saved }
        let token = UUID()
        defaults.set(token.uuidString, forKey: Self.tokenKey)
        return token
    }

    var isOrganiser: Bool { game?.organiserToken == organiserToken }

    /// Reopens the game this phone was following last time.
    func restore() async {
        guard game == nil,
              let gameID = defaults.string(forKey: Self.gameKey).flatMap(UUID.init(uuidString:)) else { return }
        do {
            enter(try await repository.game(id: gameID))
        } catch {
            leave()
        }
    }

    func refresh() async {
        guard let id = game?.id else { return }
        do {
            game = try await repository.game(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func create(_ setup: GameSetup) async -> Bool {
        await attempt { enter(try await repository.createGame(setup, organiserToken: organiserToken)) }
    }

    @discardableResult
    func join(code: String) async -> Bool {
        await attempt { enter(try await repository.joinGame(code: code)) }
    }

    @discardableResult
    func perform(_ action: OrganiserAction) async -> Bool {
        guard let gameID = game?.id else { return false }
        return await attempt {
            game = try await repository.perform(action, in: gameID, organiserToken: organiserToken)
        }
    }

    /// Stops following on this phone; the game and its scores are kept.
    func leave() {
        game = nil
        defaults.removeObject(forKey: Self.gameKey)
    }

    private func enter(_ game: Game) {
        self.game = game
        defaults.set(game.id.uuidString, forKey: Self.gameKey)
    }

    private func attempt(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
