import SwiftUI

struct CreateGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var organiserName = ""
    @State private var organiserPlays = true
    @State private var holes = Hole.defaultCourse()
    @State private var penalties = PenaltyRule.defaultRules()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Ethan's birthday", text: $name)
                    Toggle("I'm playing too", isOn: $organiserPlays)
                    if organiserPlays {
                        TextField("Your name", text: $organiserName)
                            .textContentType(.givenName)
                    }
                } footer: {
                    Text("You keep score for everyone. Add teams and players once the game is created.")
                }

                Section {
                    ForEach($holes) { $hole in
                        NavigationLink {
                            HoleEditor(hole: $hole, number: number(of: hole))
                        } label: {
                            HoleRow(hole: hole, number: number(of: hole))
                        }
                    }
                    .onDelete { holes.remove(atOffsets: $0) }
                    .onMove { holes.move(fromOffsets: $0, toOffset: $1) }

                    Button("Add a pub", systemImage: "plus") {
                        holes.append(Hole(pubName: "Pub \(holes.count + 1)", drink: "Pint", par: 5))
                    }
                } header: {
                    Text("Route")
                } footer: {
                    Text("Tap a hole to search for the pub. Par is the number of sips to finish the drink. \(holes.count) holes, par \(holes.reduce(0) { $0 + $1.par }).")
                }

                Section {
                    ForEach($penalties) { $rule in
                        PenaltyEditorRow(rule: $rule)
                    }
                    .onDelete { penalties.remove(atOffsets: $0) }

                    Button("Add a penalty", systemImage: "plus") {
                        penalties.append(PenaltyRule(name: "", strokes: 1))
                    }
                } header: {
                    Text("Penalties")
                } footer: {
                    Text("Strokes added to a player's hole when they break a rule.")
                }
            }
            .navigationTitle("New pub golf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(!canCreate || isSaving)
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var canCreate: Bool {
        !name.trimmed.isEmpty && (!organiserPlays || !organiserName.trimmed.isEmpty)
            && !holes.isEmpty && holes.allSatisfy { !$0.pubName.trimmed.isEmpty }
    }

    private func number(of hole: Hole) -> Int {
        (holes.firstIndex { $0.id == hole.id } ?? 0) + 1
    }

    private func create() {
        isSaving = true
        let setup = GameSetup(
            name: name, organiserName: organiserName, organiserPlays: organiserPlays,
            holes: holes, penalties: penalties
        )
        Task {
            if await model.create(setup) { dismiss() }
            isSaving = false
        }
    }
}

struct HoleRow: View {
    let hole: Hole
    let number: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(hole.pubName.isEmpty ? "Unnamed pub" : hole.pubName)
                    .foregroundStyle(hole.pubName.isEmpty ? .secondary : .primary)
                Text("\(hole.drink) · par \(hole.par)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hole \(number), \(hole.pubName), \(hole.drink), par \(hole.par)")
    }
}

struct PenaltyEditorRow: View {
    @Binding var rule: PenaltyRule

    var body: some View {
        HStack {
            TextField("Rule, e.g. Toilet break", text: $rule.name)
            Stepper(value: $rule.strokes, in: PenaltyRule.strokeRange) {
                Text("+\(rule.strokes)")
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .fixedSize()
            .accessibilityLabel("Penalty strokes")
            .accessibilityValue("\(rule.strokes)")
        }
    }
}

#Preview {
    CreateGameView()
        .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
