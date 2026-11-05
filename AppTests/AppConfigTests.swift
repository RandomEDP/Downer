import Foundation
import Testing
@testable import Downer

struct AppConfigTests {
    @Test func emptyValuesAreNotConfigured() {
        let config = AppConfig(info: ["SupabaseURL": "", "SupabasePublishableKey": " "])
        #expect(config.isSupabaseConfigured == false)
    }

    @Test func filledValuesAreConfigured() {
        let config = AppConfig(info: [
            "SupabaseURL": "https://example.supabase.co",
            "SupabasePublishableKey": "sb_publishable_test",
        ])
        #expect(config.isSupabaseConfigured)
        #expect(config.supabaseURL?.host() == "example.supabase.co")
    }
}
