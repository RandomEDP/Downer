import SwiftUI

/// Hole-by-hole card for one player. The organiser can fix any score on holes already reached.
struct ScorecardView: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let isOrganiser: Bool

    @State private var selectedPlayerID: Player.ID?
    @State private var scoring: ScoreTarget?

    var body: some View {
        List {
            if let player = selectedPlayer {
                Section {
                    Picker("Player", selection: $selectedPlayerID) {
                        ForEach(game.players) { player in
                            Text(player.name).tag(Player.ID?.some(player.id))
                        }
                    }
                }

                Section {
                    ForEach(Array(game.holes.enumerated()), id: \.element.id) { index, hole in
                        ScorecardRow(
                            number: index + 1,
                            hole: hole,
                            score: game.score(player: player.id, hole: hole.id),
                            penalties: game.penalties,
                            isCurrent: game.status == .live && index == game.currentHoleIndex,
                            canEdit: isOrganiser && game.isHoleOpen(hole)
                        ) {
                            scoring = ScoreTarget(playerID: player.id, holeID: hole.id)
                        }
                    }
                } footer: {
                    let entry = Scoring.leaderboard(for: game).first { $0.player.id == player.id }
                    if let entry {
                        Text("Total \(entry.strokes) strokes, \(Scoring.formatToPar(entry.toPar)) through \(entry.holesPlayed) of \(game.holes.count). Course par \(game.totalPar).")
                    }
                }
            }
        }
        .overlay {
            if game.players.isEmpty {
                ContentUnavailableView("No players yet", systemImage: "list.number")
            }
        }
        .navigationTitle("Scorecard")
        .onAppear {
            if selectedPlayerID == nil { selectedPlayerID = game.players.first?.id }
        }
        .refreshable { await model.refresh() }
        .sheet(item: $scoring) { target in
            if let player = game.player(target.playerID), let hole = game.holes.first(where: { $0.id == target.holeID }) {
                ScoreEntryView(game: game, player: player, hole: hole)
            }
        }
    }

    private var selectedPlayer: Player? {
        selectedPlayerID.flatMap(game.player) ?? game.players.first
    }
}

private struct ScorecardRow: View {
    let number: Int
    let hole: Hole
    let score: Score?
    let penalties: [PenaltyRule]
    let isCurrent: Bool
    let canEdit: Bool
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 28)
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(hole.pubName)
                    Text("\(hole.drink) · par \(hole.par)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let score {
                    let strokes = Scoring.strokes(for: score, penalties: penalties)
                    Text("\(strokes)")
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(strokes <= hole.par ? AnyShapeStyle(.green) : AnyShapeStyle(.primary))
                    if !score.penaltyIDs.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Includes penalties")
                    }
                } else {
                    Text("–").foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .tint(.primary)
        .disabled(!canEdit)
        .accessibilityHint(canEdit ? "Edit score" : "")
    }
}

#Preview {
    NavigationStack {
        ScorecardView(game: .preview(status: .live), isOrganiser: true)
    }
    .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
