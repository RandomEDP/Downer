import SwiftUI

/// Organiser enters one player's sips and penalties for a hole.
struct ScoreEntryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let game: Game
    let player: Player
    let hole: Hole

    @State private var sips: Int
    @State private var penaltyIDs: Set<PenaltyRule.ID>
    @State private var isSaving = false

    init(game: Game, player: Player, hole: Hole) {
        self.game = game
        self.player = player
        self.hole = hole
        // One-time seed from the saved score; edits stay local until Save.
        let existing = game.score(player: player.id, hole: hole.id)
        _sips = State(initialValue: existing?.sips ?? hole.par)
        _penaltyIDs = State(initialValue: Set(existing?.penaltyIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SipCounter(sips: $sips, par: hole.par)
                } header: {
                    Text("\(hole.drink) · par \(hole.par)")
                }

                if !game.penalties.isEmpty {
                    Section("Penalties") {
                        ForEach(game.penalties) { rule in
                            Toggle(isOn: binding(for: rule)) {
                                LabeledContent(rule.name, value: "+\(rule.strokes)")
                            }
                        }
                    }
                }

                Section {
                    LabeledContent("Strokes") {
                        Text("\(strokes)  (\(Scoring.formatToPar(strokes - hole.par)))")
                            .font(.headline.monospacedDigit())
                    }
                }
            }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().accessibilityLabel("Saving")
                    } else {
                        Button("Save", action: save)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var strokes: Int {
        sips + game.penalties.filter { penaltyIDs.contains($0.id) }.reduce(0) { $0 + $1.strokes }
    }

    private func binding(for rule: PenaltyRule) -> Binding<Bool> {
        Binding(
            get: { penaltyIDs.contains(rule.id) },
            set: { on in
                if on { penaltyIDs.insert(rule.id) } else { penaltyIDs.remove(rule.id) }
            }
        )
    }

    private func save() {
        isSaving = true
        let score = Score(
            playerID: player.id,
            holeID: hole.id,
            sips: sips,
            penaltyIDs: game.penalties.map(\.id).filter(penaltyIDs.contains)
        )
        Task {
            if await model.perform(.saveScore(score)) { dismiss() }
            isSaving = false
        }
    }
}

/// Big minus / count / plus control that's easy to hit in a busy pub.
private struct SipCounter: View {
    @Binding var sips: Int
    let par: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Button("Fewer sips", systemImage: "minus") { sips -= 1 }
                .disabled(sips <= Score.sipRange.lowerBound)
            Spacer()
            VStack(spacing: 2) {
                Text("\(sips)")
                    .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
                    .contentTransition(.numericText(value: Double(sips)))
                Text(sips == 1 ? "sip" : "sips")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("More sips", systemImage: "plus") { sips += 1 }
                .disabled(sips >= Score.sipRange.upperBound)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .animation(reduceMotion ? nil : .snappy, value: sips)
        .sensoryFeedback(.selection, trigger: sips)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sips")
        .accessibilityValue("\(sips), par \(par)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: sips = min(sips + 1, Score.sipRange.upperBound)
            case .decrement: sips = max(sips - 1, Score.sipRange.lowerBound)
            @unknown default: break
            }
        }
    }
}
