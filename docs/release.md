# Releasing (keyword stages)

Archive and TestFlight are **deliberate, keyword-only** stages — never part of the
automatic `format → lint → build → test` pipeline, and never run without an explicit
command or flag.

```bash
./gate archive                 # build an UNSIGNED .xcarchive (local release-build check)
./gate testflight              # signed build + TestFlight upload via the fastlane `beta` lane
./gate all --archive           # run the full gate, then archive only if it's green
./gate branch --testflight     # gate the changed screens, then upload only if green
```

- **`gate archive`** writes to `gate.yml > release.archive_path` (default
  `build/<scheme>.xcarchive`, gitignored). It is unsigned (`CODE_SIGNING_ALLOWED=NO`)
  — for verifying that the release build compiles/links, not for distribution.
- **`gate testflight`** delegates entirely to fastlane (`gate.yml > release.testflight_lane`,
  default `beta`), which handles signing via `fastlane match` and the App Store Connect
  upload. The gate manages no secrets.
- The `--archive` / `--testflight` flags run the keyword stage **only after a green gate**.
  A gate that resolves to nothing (e.g. `gate staged` with no feature files staged) is a
  vacuous pass and does **not** trigger a release.
- `--archive` and `--testflight` are **independent builds** — `gate archive` makes an
  unsigned local archive; `gate testflight` runs fastlane's own signed build from scratch.
  Passing both does two separate builds; it does not upload the unsigned archive.

## Config (`gate.yml`)
```yaml
release:
  archive_path: build/SwiftBaseClassWAC.xcarchive   # optional; default build/<scheme>.xcarchive
  testflight_lane: beta                             # optional; default `beta`
```
Omit the whole `release:` block to use the defaults.
