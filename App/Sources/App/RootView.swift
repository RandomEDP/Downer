import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let game = model.game {
                GameView(game: game, isOrganiser: model.isOrganiser)
            } else {
                NavigationStack {
                    HomeView()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Catch up on anything that changed while the app was in the background.
            if phase == .active { Task { await model.refresh() } }
        }
        .alert("Something went wrong", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

#Preview {
    RootView()
        .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
