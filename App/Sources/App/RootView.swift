import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

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
