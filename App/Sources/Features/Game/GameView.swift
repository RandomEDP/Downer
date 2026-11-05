import SwiftUI

/// In-game tabs. The organiser's phone can score and manage; everyone else follows live.
struct GameView: View {
    let game: Game
    let isOrganiser: Bool

    var body: some View {
        TabView {
            Tab("Hole", systemImage: "flag.fill") {
                NavigationStack {
                    Group {
                        switch game.status {
                        case .lobby: LobbyView(game: game, isOrganiser: isOrganiser)
                        case .live: CurrentHoleView(game: game, isOrganiser: isOrganiser)
                        case .finished: FinishedView(game: game)
                        }
                    }
                    .toolbar { gameMenu }
                }
            }
            Tab("Leaderboard", systemImage: "trophy.fill") {
                NavigationStack {
                    LeaderboardView(game: game)
                        .toolbar { gameMenu }
                }
            }
            Tab("Scorecard", systemImage: "list.number") {
                NavigationStack {
                    ScorecardView(game: game, isOrganiser: isOrganiser)
                        .toolbar { gameMenu }
                }
            }
        }
    }

    private var gameMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            GameMenu(game: game, isOrganiser: isOrganiser)
        }
    }
}

struct GameMenu: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let isOrganiser: Bool

    var body: some View {
        Menu("Game", systemImage: "ellipsis.circle") {
            ShareLink(item: GameView.invite(for: game)) {
                Label("Share code \(game.code)", systemImage: "square.and.arrow.up")
            }
            if isOrganiser && game.status == .live {
                Button("Finish round", systemImage: "flag.checkered") {
                    Task { await model.perform(.finish) }
                }
            }
            Button("Leave game", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                model.leave()
            }
        }
    }
}

extension GameView {
    static func invite(for game: Game) -> String {
        "Follow \(game.name) on Downer with code \(game.code)"
    }
}

#Preview {
    GameView(game: .preview(status: .live), isOrganiser: true)
        .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
