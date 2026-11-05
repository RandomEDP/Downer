import SwiftUI

struct HomeView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No pub golf yet", systemImage: "flag.and.flag.filled.crossed")
        } description: {
            Text("Start a round or join one with a code.")
        }
        .navigationTitle("Downer")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
