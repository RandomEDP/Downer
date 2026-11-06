import SwiftUI

/// In-game tabs. The organiser's phone can score and manage; everyone else follows live.
struct GameView: View {
    let game: Game
    let isOrganiser: Bool

    var body: some View {
        TabView {
            Tab("Hole", systemImage: "flag") {
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
            Tab("Leaderboard", systemImage: "trophy") {
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

    @State private var confirmingFinish = false

    var body: some View {
        Menu("Game", systemImage: "ellipsis.circle") {
            ShareLink(item: GameView.invite(for: game)) {
                Label("Share code \(game.code)", systemImage: "square.and.arrow.up")
            }
            if isOrganiser && game.status == .live {
                Button("Finish round", systemImage: "flag.checkered") {
                    confirmingFinish = true
                }
            }
            Button("Leave game", systemImage: "rectangle.portrait.and.arrow.right") {
                model.leave()
            }
        }
        .confirmationDialog("Finish the round now?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Finish round", role: .destructive) {
                Task { await model.perform(.finish) }
            }
        } message: {
            Text("Scores are locked once the round is finished.")
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
