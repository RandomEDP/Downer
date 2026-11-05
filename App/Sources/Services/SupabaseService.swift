import Foundation
import Supabase

/// Single shared Supabase client. `nil` until the build is configured with a project URL and key.
enum SupabaseService {
    static let client: SupabaseClient? = {
        let config = AppConfig()
        guard let url = config.supabaseURL, let key = config.supabasePublishableKey else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
