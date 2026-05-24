# MVP Hardening And Release Prep

Этот чеклист закрывает Slice 9 относительно архитектурного правила из
`docs/architecture.md`: kernel считает, vault хранит приватные данные, а
export/delete являются единственными пользовательскими выходами private data.

## Scope

- Local-only iOS diary without backend.
- Structured two-option dilemma input with three benefits and three costs per
  option.
- Bundled `DecisionKernel` assets and local embedding runtime.
- Private diary persistence through `DiaryVault`.
- Local feedback, descriptive statistics, JSON export, and delete-all-data flow.

## Current Performance Baseline

Measured by `DecisionAnalysisRunnerIntegrationTests` on May 24, 2026 using the
iPhone 16 simulator on iOS 18.2:

| Measurement | Value |
| --- | ---: |
| Model load | 561.9 ms |
| 12-reason embedding | 127.6 ms |
| Analysis scoring | 11.8 ms |
| Approximate memory delta | 128.9 MB |

Before TestFlight, repeat the same integration test on a physical device and
record the real-device values here.

## Verification Commands

```bash
.venv/bin/python -m pytest tools/test_attribute_assets.py
tuist generate --no-open
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
```

## Automated Coverage

| Area | Coverage |
| --- | --- |
| Production assets | `tools/test_attribute_assets.py` verifies deterministic SQLite counts and metadata. |
| Analysis math | `AttributeScoringTests` covers direction selection, row-centering, aggregation, and validation. |
| Runtime smoke | `DecisionAnalysisRunnerIntegrationTests` loads bundled assets/model and records timing. |
| Storage/export/delete | `DiaryVaultTests` saves a full entry, analysis, feedback, decodes JSON export schema v1, deletes data, and reopens the vault. |

## Manual QA Gate

- Fresh install opens to an empty diary state.
- Full valid entry can be created and analyzed in Airplane Mode.
- Incomplete entry cannot run analysis.
- Analysis detail contains no recommendation language such as "you should choose".
- Feedback can be saved, then statistics update after refresh.
- JSON export can be prepared and shared from Privacy settings.
- Delete all user data removes entries, analyses, feedback, and recreates an empty vault.
- Face ID/passcode toggle prompts on next app preparation when enabled.
- Long dilemma, option, reason, cluster, and attribute text remains readable.
- VoiceOver can find the primary actions by their accessibility identifiers.

## Error-Handling Gate

- Missing or corrupted `DilemmaAssets.sqlite` surfaces a kernel asset error.
- Missing bundled model surfaces a model-load error instead of writing private data.
- Authentication failure surfaces a local unlock error and does not prepare the vault.
- SQLite prepare/save/export/delete failures are routed to the app-level error banner.
- Exported JSON includes `schemaVersion: 1` so future migrations can branch safely.

## Known Implementation Note

The Slice 4 storage boundary is implemented as a replaceable local SQLite vault
with Keychain-managed key material and `LocalAuthentication` unlock. The app
does not yet link GRDB + SQLCipher directly; that swap should happen inside
`DiaryVault` without changing kernel or feature boundaries.
