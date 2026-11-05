import SwiftUI

/// Anyone with the code can follow the scorecard and leaderboard live.
struct JoinGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isJoining = false
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Game code", text: $code)
                        .font(.title2.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($codeFocused)
                        .submitLabel(.join)
                        .onSubmit(join)
                } footer: {
                    Text("Ask the organiser for the 6 character code.")
                }
            }
            .navigationTitle("Join a pub golf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join", action: join)
                        .disabled(!canJoin || isJoining)
                }
            }
            .onAppear { codeFocused = true }
        }
    }

    private var canJoin: Bool { GameCode.isValid(GameCode.normalize(code)) }

    private func join() {
        guard canJoin, !isJoining else { return }
        isJoining = true
        Task {
            if await model.join(code: code) { dismiss() }
            isJoining = false
        }
    }
}

#Preview {
    JoinGameView()
        .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
