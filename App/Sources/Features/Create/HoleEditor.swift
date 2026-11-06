import SwiftUI
import UIKit

/// Edit one hole: find the pub on Apple Maps (or just type a name), then set the drink and par.
struct HoleEditor: View {
    @Binding var hole: Hole
    let number: Int

    @State private var search = PubSearch()
    @FocusState private var searchFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Search for a pub", text: $search.query)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                ForEach(search.suggestions.prefix(6)) { suggestion in
                    Button {
                        choose(suggestion)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title).foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Label("Find on the map", systemImage: "magnifyingglass")
            } footer: {
                LocationFooter(access: search.locationAccess) { search.requestLocationAccess() }
            }

            Section {
                TextField("Pub name", text: $hole.pubName)
                TextField("Address (optional)", text: $hole.address, axis: .vertical)
                    .textContentType(.fullStreetAddress)
            } header: {
                Text("Pub")
            } footer: {
                Text("Can't find it? Just type the name.")
            }

            Section {
                TextField("Drink", text: $hole.drink)
                Stepper(value: $hole.par, in: Hole.parRange) {
                    LabeledContent("Par", value: "\(hole.par) sips")
                }
            } header: {
                Text("Drink")
            }
        }
        .navigationTitle("Hole \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { search.start() }
    }

    private func choose(_ suggestion: PubSuggestion) {
        hole.pubName = suggestion.title
        hole.address = suggestion.subtitle
        search.query = ""
        searchFocused = false
    }
}

/// Explains why location helps before the system prompt, and points to Settings if it was denied.
private struct LocationFooter: View {
    let access: PubSearch.LocationAccess
    let requestAccess: () -> Void

    var body: some View {
        switch access {
        case .notAsked:
            VStack(alignment: .leading, spacing: 8) {
                Text("Share your location to see pubs near you first. It's only used for this search.")
                Button("Use my location", systemImage: "location.fill", action: requestAccess)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .textCase(nil)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Location is off, so results may not be nearby.")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }
        case .unknown, .allowed:
            EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var hole = Hole(pubName: "The Crown", drink: "Pint", par: 5)
    NavigationStack {
        HoleEditor(hole: $hole, number: 1)
    }
}
