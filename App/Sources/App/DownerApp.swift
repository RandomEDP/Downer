import SwiftUI

@main
struct DownerApp: App {
    @State private var model = AppModel(repository: LocalGameRepository.onDisk())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.restore() }
        }
    }
}
