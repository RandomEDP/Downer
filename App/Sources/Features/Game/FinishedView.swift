import SwiftUI

struct FinishedView: View {
    let game: Game

    var body: some View {
        let players = Scoring.leaderboard(for: game)
        let teams = Scoring.teamLeaderboard(for: game)
        SplitSections {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text("Round over").font(.title.bold())
                    if let winner = teams.first, winner.hasScores {
                        Text("\(winner.team.name) win at \(Scoring.formatToPar(winner.averageToPar))")
                            .font(.headline)
                    }
                    if let best = players.first, best.holesPlayed > 0 {
                        Text("Best player: \(best.player.name), \(Scoring.formatToPar(best.toPar))")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .multilineTextAlignment(.center)
            }
        } secondary: {
            Section {
                ForEach(players) { entry in
                    LabeledContent {
                        Text(Scoring.formatToPar(entry.toPar)).monospacedDigit()
                    } label: {
                        Text("\(entry.rank). \(entry.player.name)")
                    }
                }
            } header: {
                Text("Final standings")
            }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FinishedView(game: .preview(status: .finished))
    }
}
