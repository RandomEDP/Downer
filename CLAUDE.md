# Downer

iPhone app (SwiftUI) for running and managing pub golfs, including live use by players mid-round. Backend is Supabase.

## Layout
- `project.yml`: XcodeGen spec. The `.xcodeproj` is generated (`xcodegen generate`) and not committed.
- `App/Sources`: app code, grouped by `App/`, `Features/<Feature>/`, `Services/`.
- `AppTests`: Swift Testing unit tests.
- `Config/App.xcconfig`: build settings. Secrets go in `Config/Local.xcconfig` (gitignored); CI writes it from repo secrets.
- `supabase/migrations`: SQL migrations named `NNNN_snake_case.sql`, numbered from 0001 with no gaps. Check main for the next number (`scripts/check-migrations.sh` prints it).
- `supabase/functions`: edge functions.

## Rules
- Before any UI work, load `.claude/skills/swiftui-expert-skill` and `.claude/skills/ios-design-guidelines`.
- Every PR into main runs CI (`.github/workflows/ci.yml`). Merge your own PR once CI is green if there are no open questions.
- Never run the TestFlight workflow (`ios.yml` with `testflight=true`) from a feature thread.
- Never link to this repository anywhere public (emails, posts, ads, app links, App Store text).
- Media and clips go to cloud storage, never local folders.
- Real charging, real ads and live payment keys stay off until Ethan says the accounts are ready.
- Never commit keys. The Supabase publishable key and URL come from secrets; the service role key never goes in the app.
