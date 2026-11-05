import SwiftUI

struct HomeView: View {
    @State private var showingCreate = false
    @State private var showingJoin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "flag.and.flag.filled.crossed")
                    .font(.system(.largeTitle))
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Pub golf, sorted")
                        .font(.title2.bold())
                    Text("Plan the route, set par for each drink, and keep a live scorecard and leaderboard as you go.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    showingCreate = true
                } label: {
                    Text("Create a pub golf").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingJoin = true
                } label: {
                    Text("Join with a code").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(16)
            .background(.bar)
        }
        .navigationTitle("Downer")
        .sheet(isPresented: $showingCreate) { CreateGameView() }
        .sheet(isPresented: $showingJoin) { JoinGameView() }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
