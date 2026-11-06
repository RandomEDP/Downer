import SwiftUI

/// Before the round: share the code, set up teams and players, then start.
struct LobbyView: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let isOrganiser: Bool

    @State private var newTeamName = ""
    @State private var newPlayerName = ""
    @State private var newPlayerTeam: Team.ID?
    @State private var playerToRemove: Player?

    var body: some View {
        SplitSections {
            Section {
                VStack(spacing: 8) {
                    Text("Game code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(game.code)
                        .font(.largeTitle.monospaced().bold())
                        .textSelection(.enabled)
                    ShareLink(item: GameView.invite(for: game)) {
                        Label("Share code", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Game code \(game.code.map(String.init).joined(separator: " "))")
            } footer: {
                Text("Anyone with the code can follow the leaderboard live.")
            }

            if isOrganiser {
                Section {
                    ForEach(game.teams) { team in
                        TeamRow(team: team, playerCount: game.players(in: team.id).count)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { game.teams[$0].id }
                        Task { for id in ids { await model.perform(.removeTeam(id)) } }
                    }
                    HStack {
                        TextField("New team", text: $newTeamName)
                            .onSubmit(addTeam)
                        Button("Add", action: addTeam)
                            .buttonStyle(.borderless)
                            .disabled(newTeamName.trimmed.isEmpty)
                    }
                } header: {
                    Text("Teams")
                } footer: {
                    Text("Teams are ranked on their players' average score.")
                }

                Section {
                    TextField("Player name", text: $newPlayerName)
                        .textContentType(.givenName)
                        .onSubmit(addPlayer)
                    if !game.teams.isEmpty {
                        TeamPicker(teams: game.teams, selection: $newPlayerTeam)
                    }
                    Button("Add player", systemImage: "person.badge.plus", action: addPlayer)
                        .disabled(newPlayerName.trimmed.isEmpty)
                } header: {
                    Text("Add a player")
                }
            }
        } secondary: {
            PlayersByTeamSection(game: game, isOrganiser: isOrganiser, playerToRemove: $playerToRemove)
        }
        .navigationTitle(game.name)
        .bottomActionBar {
            if isOrganiser {
                Button {
                    Task { await model.perform(.start) }
                } label: {
                    Text("Start round at \(game.holes.first?.pubName ?? "hole 1")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(game.players.isEmpty)
            } else {
                Label("Waiting for the organiser to start", systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .refreshable { await model.refresh() }
        .confirmationDialog(
            "Remove \(playerToRemove?.name ?? "player")?",
            isPresented: removeDialogShown,
            titleVisibility: .visible,
            presenting: playerToRemove
        ) { player in
            Button("Remove \(player.name)", role: .destructive) {
                Task { await model.perform(.removePlayer(player.id)) }
            }
        } message: { _ in
            Text("Their scores are deleted too.")
        }
    }

    private var removeDialogShown: Binding<Bool> {
        Binding(
            get: { playerToRemove != nil },
            set: { if !$0 { playerToRemove = nil } }
        )
    }

    private func addTeam() {
        let name = newTeamName
        guard !name.trimmed.isEmpty else { return }
        Task {
            if await model.perform(.addTeam(name: name)) { newTeamName = "" }
        }
    }

    private func addPlayer() {
        let name = newPlayerName
        let team = newPlayerTeam
        guard !name.trimmed.isEmpty else { return }
        Task {
            if await model.perform(.addPlayer(name: name, teamID: team)) { newPlayerName = "" }
        }
    }
}

private struct TeamRow: View {
    let team: Team
    let playerCount: Int

    var body: some View {
        LabeledContent(team.name, value: playerCount == 1 ? "1 player" : "\(playerCount) players")
    }
}

struct TeamPicker: View {
    let teams: [Team]
    @Binding var selection: Team.ID?

    var body: some View {
        Picker("Team", selection: $selection) {
            Text("No team").tag(Team.ID?.none)
            ForEach(teams) { team in
                Text(team.name).tag(Team.ID?.some(team.id))
            }
        }
    }
}

/// Players grouped under their team. The organiser can move or remove them.
struct PlayersByTeamSection: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let isOrganiser: Bool

    @Binding var playerToRemove: Player?

    var body: some View {
        ForEach(groups) { group in
            Section(group.title) {
                if group.players.isEmpty {
                    Text("No players yet").foregroundStyle(.secondary)
                }
                ForEach(group.players) { player in
                    playerRow(player)
                        .swipeActions(edge: .trailing) {
                            if canManage {
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    playerToRemove = player
                                }
                            }
                        }
                }
            }
        }
    }

    private var canManage: Bool { isOrganiser && game.status != .finished }

    private struct PlayerGroup: Identifiable {
        let id: String
        let title: String
        let players: [Player]
    }

    private var groups: [PlayerGroup] {
        var groups = game.teams.map { team in
            PlayerGroup(id: team.id.uuidString, title: team.name, players: game.players(in: team.id))
        }
        let unassigned = game.players(in: nil)
        if game.teams.isEmpty || !unassigned.isEmpty {
            groups.append(PlayerGroup(id: "none", title: game.teams.isEmpty ? "Players" : "No team", players: unassigned))
        }
        return groups
    }

    @ViewBuilder
    private func playerRow(_ player: Player) -> some View {
        if canManage {
            Menu {
                Picker("Team", selection: teamBinding(for: player)) {
                    Text("No team").tag(Team.ID?.none)
                    ForEach(game.teams) { team in
                        Text(team.name).tag(Team.ID?.some(team.id))
                    }
                }
                Button("Remove \(player.name)", systemImage: "trash", role: .destructive) {
                    playerToRemove = player
                }
            } label: {
                HStack {
                    Text(player.name)
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .tint(.primary)
            .accessibilityHint("Change team or remove")
        } else {
            Text(player.name)
        }
    }

    private func teamBinding(for player: Player) -> Binding<Team.ID?> {
        Binding(
            get: { player.teamID },
            set: { team in Task { await model.perform(.movePlayer(player.id, teamID: team)) } }
        )
    }
}

#Preview {
    NavigationStack {
        LobbyView(game: .preview(status: .lobby), isOrganiser: true)
    }
    .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
