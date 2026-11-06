import SwiftUI

struct LeaderboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let game: Game

    @State private var mode = Mode.teams

    enum Mode: String, CaseIterable, Identifiable {
        case teams = "Teams"
        case players = "Players"
        var id: Self { self }
    }

    var body: some View {
        Group {
            if game.teams.isEmpty {
                List { playerSection }
            } else if horizontalSizeClass == .regular {
                // Wide screens (iPhone Duo open, landscape): both boards side by side.
                SplitSections { teamSection } secondary: { playerSection }
            } else {
                List {
                    Picker("Show", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    switch mode {
                    case .teams: teamSection
                    case .players: playerSection
                    }
                }
            }
        }
        .overlay {
            if game.players.isEmpty {
                ContentUnavailableView("No players yet", systemImage: "person.3", description: Text("The organiser adds players before the round starts."))
            }
        }
        .navigationTitle("Leaderboard")
        .refreshable { await model.refresh() }
    }

    private var teamSection: some View {
        Section("Teams") {
            ForEach(Scoring.teamLeaderboard(for: game)) { entry in
                TeamStandingRow(entry: entry)
            }
        }
    }

    private var playerSection: some View {
        Section("Players") {
            ForEach(Scoring.leaderboard(for: game)) { entry in
                PlayerStandingRow(entry: entry, team: game.team(entry.player.teamID))
            }
        }
    }
}

struct RankBadge: View {
    let rank: Int
    let hasScores: Bool
    @ScaledMetric(relativeTo: .headline) private var size = 32.0

    var body: some View {
        Text(hasScores ? "\(rank)" : "–")
            .font(.headline.monospacedDigit())
            .frame(minWidth: size, minHeight: size)
            .background(rank == 1 && hasScores ? AnyShapeStyle(.yellow.opacity(0.35)) : AnyShapeStyle(.quaternary), in: .circle)
            .accessibilityLabel(hasScores ? "Position \(rank)" : "No scores yet")
    }
}

private struct PlayerStandingRow: View {
    let entry: LeaderboardEntry
    let team: Team?

    var body: some View {
        AdaptiveRow {
            HStack(spacing: 12) {
                RankBadge(rank: entry.rank, hasScores: entry.holesPlayed > 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.player.name).font(.headline)
                    Text([team?.name, "thru \(entry.holesPlayed)"].compactMap(\.self).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                Text(Scoring.formatToPar(entry.toPar))
                    .font(.title3.monospacedDigit().bold())
                Text("\(entry.strokes) strokes")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TeamStandingRow: View {
    let entry: TeamLeaderboardEntry

    var body: some View {
        AdaptiveRow {
            HStack(spacing: 12) {
                RankBadge(rank: entry.rank, hasScores: entry.hasScores)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.team.name).font(.headline)
                    Text(entry.players.isEmpty ? "No players" : entry.players.map(\.player.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                Text(Scoring.formatToPar(entry.averageToPar))
                    .font(.title3.monospacedDigit().bold())
                Text("avg per player")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        LeaderboardView(game: .preview(status: .live))
    }
    .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
