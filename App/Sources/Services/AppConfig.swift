import Foundation

/// Values injected at build time via Config/*.xcconfig -> Info.plist.
struct AppConfig: Sendable {
    let supabaseURL: URL?
    let supabasePublishableKey: String?

    init(bundle: Bundle = .main) {
        self.init(info: bundle.infoDictionary ?? [:])
    }

    init(info: [String: Any]) {
        let url = (info["SupabaseURL"] as? String).flatMap(Self.nonEmpty)
        supabaseURL = url.flatMap(URL.init(string:))
        supabasePublishableKey = (info["SupabasePublishableKey"] as? String).flatMap(Self.nonEmpty)
    }

    var isSupabaseConfigured: Bool { supabaseURL != nil && supabasePublishableKey != nil }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
