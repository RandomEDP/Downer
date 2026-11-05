import SwiftUI

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

#Preview {
    @Previewable @State var hole = Hole(pubName: "The Crown", drink: "Pint", par: 5)
    NavigationStack {
        HoleEditor(hole: $hole, number: 1)
    }
}
