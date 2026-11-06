import SwiftUI

/// The live view: where the group is now, who has scored, and what's next.
struct CurrentHoleView: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let isOrganiser: Bool

    @State private var scoring: ScoreTarget?
    @State private var confirmingNext = false

    var body: some View {
        SplitSections {
            if let hole = game.currentHole {
                Section {
                    HoleHeader(hole: hole, number: game.currentHoleIndex + 1, of: game.holes.count)
                }
            }
            NextPubSection(next: game.nextHole)
        } secondary: {
            if let hole = game.currentHole {
                Section {
                    ForEach(game.players) { player in
                        PlayerHoleRow(
                            player: player,
                            team: game.team(player.teamID),
                            score: game.score(player: player.id, hole: hole.id),
                            par: hole.par,
                            penalties: game.penalties,
                            canEdit: isOrganiser
                        ) {
                            scoring = ScoreTarget(playerID: player.id, holeID: hole.id)
                        }
                    }
                } header: {
                    Text("Scores this hole")
                } footer: {
                    if isOrganiser {
                        Text("Tap a player to enter their sips and penalties.")
                    }
                }
            }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .bottomActionBar {
            if isOrganiser {
                OrganiserControls(game: game, confirmingNext: $confirmingNext)
            } else {
                Label("Following live. The organiser moves everyone on.", systemImage: "dot.radiowaves.left.and.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: game.currentHoleIndex)
        .sensoryFeedback(trigger: game.scores) { _, _ in isOrganiser ? .success : nil }
        .confirmationDialog(nextTitle, isPresented: $confirmingNext, titleVisibility: .visible) {
            Button(game.isOnLastHole ? "Finish round" : "Move everyone on") {
                Task { await model.perform(.nextHole) }
            }
        } message: {
            if missingScores > 0 {
                Text("\(missingScores) of \(game.players.count) players have no score for this hole.")
            }
        }
        .sheet(item: $scoring) { target in
            if let player = game.player(target.playerID), let hole = game.holes.first(where: { $0.id == target.holeID }) {
                ScoreEntryView(game: game, player: player, hole: hole)
            }
        }
    }

    private var nextTitle: String {
        if game.isOnLastHole { return "Finish the round?" }
        return "Move everyone to \(game.nextHole?.pubName ?? "the next pub")?"
    }

    private var missingScores: Int {
        guard let hole = game.currentHole else { return 0 }
        return game.players.filter { game.score(player: $0.id, hole: hole.id) == nil }.count
    }
}

struct ScoreTarget: Identifiable, Hashable {
    let playerID: Player.ID
    let holeID: Hole.ID
    var id: String { playerID.uuidString + holeID.uuidString }
}

private struct NextPubSection: View {
    let next: Hole?

    var body: some View {
        Section("Next pub") {
            if let next {
                VStack(alignment: .leading, spacing: 4) {
                    Text(next.pubName).font(.headline)
                    if !next.address.isEmpty {
                        Text(next.address).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(next.drink) · par \(next.par)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                DirectionsLink(hole: next)
            } else {
                Text("This is the last hole.").foregroundStyle(.secondary)
            }
        }
    }
}

private struct HoleHeader: View {
    let hole: Hole
    let number: Int
    let of: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hole \(number) of \(of)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(hole.pubName)
                .font(.title.bold())
            if !hole.address.isEmpty {
                Text(hole.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { drinkAndPar }
                VStack(alignment: .leading, spacing: 8) { drinkAndPar }
            }
            .font(.headline)
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        DirectionsLink(hole: hole)
    }

    @ViewBuilder
    private var drinkAndPar: some View {
        Label(hole.drink, systemImage: "mug.fill")
        Label("Par \(hole.par)", systemImage: "flag.fill")
    }
}

/// Opens Apple Maps at the pub.
struct DirectionsLink: View {
    let hole: Hole

    var body: some View {
        if let url {
            Link(destination: url) {
                Label("Directions", systemImage: "map")
            }
        }
    }

    private var url: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        let query = [hole.pubName, hole.address].filter { !$0.isEmpty }.joined(separator: ", ")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

private struct PlayerHoleRow: View {
    let player: Player
    let team: Team?
    let score: Score?
    let par: Int
    let penalties: [PenaltyRule]
    let canEdit: Bool
    let edit: () -> Void

    var body: some View {
        if canEdit {
            Button(action: edit) { content }
                .tint(.primary)
        } else {
            content
        }
    }

    private var content: some View {
        AdaptiveRow {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                if let team {
                    Text(team.name).font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if let score {
                let strokes = Scoring.strokes(for: score, penalties: penalties)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(strokes)")
                        .font(.title3.monospacedDigit().bold())
                    Text(Scoring.formatToPar(strokes - par))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(strokes) strokes, \(Scoring.formatToPar(strokes - par)) to par")
            } else {
                Text("No score").foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(canEdit ? "Enter score" : "")
    }
}

private struct OrganiserControls: View {
    @Environment(AppModel.self) private var model
    let game: Game
    @Binding var confirmingNext: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.perform(.previousHole) }
            } label: {
                Label("Back a hole", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44)
            }
            .buttonStyle(.bordered)
            .disabled(game.currentHoleIndex == 0)

            Button {
                confirmingNext = true
            } label: {
                Text(game.isOnLastHole ? "Finish round" : "Next pub")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
    }
}

#Preview {
    NavigationStack {
        CurrentHoleView(game: .preview(status: .live), isOrganiser: true)
    }
    .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
