import SwiftUI

struct HomeView: View {
    @State private var sheet: Sheet?

    private enum Sheet: String, Identifiable {
        case create, join
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "flag.and.flag.filled.crossed")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
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
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .bottomActionBar {
            VStack(spacing: 12) {
                Button {
                    sheet = .create
                } label: {
                    Text("Create a pub golf").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    sheet = .join
                } label: {
                    Text("Join with a code").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .navigationTitle("Downer")
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create: CreateGameView()
            case .join: JoinGameView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppModel(repository: LocalGameRepository(fileURL: nil)))
}
