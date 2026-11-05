# Downer

Run and manage pub golfs from your iPhone.

## Local setup
1. `brew install xcodegen supabase/tap/supabase`
2. `cp Config/Local.xcconfig.example Config/Local.xcconfig` and fill in your team ID and Supabase values.
3. `xcodegen generate && open Downer.xcodeproj`

Local database: `supabase start` applies everything in `supabase/migrations`.

## CI and releases
- `CI` runs on every PR into main: iOS build + tests on a simulator, and the Supabase migrations against a local database.
- `iOS release` is manual. Run it on main with `testflight=true` to upload a build to TestFlight. The build number is the workflow run number.

### Repository secrets used by `iOS release`
| Secret | What it is |
| --- | --- |
| `APPLE_TEAM_ID` | 10-character Apple Developer team ID |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_PRIVATE_KEY` | Full contents of the `AuthKey_XXXX.p8` file |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable (anon) key |
