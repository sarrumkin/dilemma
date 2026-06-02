# dilemma

Local iOS decision diary for structured, offline dilemma analysis.

The app stores private diary data locally, maps structured benefits/costs to
Bhatia-style attribute directions, shows descriptive analysis and feedback, and
keeps export/delete flows inside the local privacy boundary.

Current prototype default: `swift-embeddings + paraphrase-multilingual-MiniLM-L12-v2`.

## Local shape

- `dilemma/` - SwiftUI app target with composition and feature-level
  Observation models for diary, entry, analysis, statistics, and privacy UI.
- `DecisionModels/` - Foundation-only canonical commands, diary models,
  analysis records, feedback, statistics, and export DTOs.
- `DecisionUseCases/` - application layer target with use-case orchestration
  between the app, kernel, vault, and shared models.
- `DecisionKernel/` - local analysis framework with schema, core math, runtime, assets, and pipeline.
- `DiaryVault/` - local private storage boundary for entries, analyses,
  feedback, JSON export, and delete-all-data.
- `DecisionModelsTests/` - Swift Testing tests for shared model validation and Codable shape.
- `DecisionUseCasesTests/` - Swift Testing tests for full use-case roundtrips.
- `DecisionKernelTests/` - Swift Testing tests for scoring, F16 loading, aggregation, and bundled runtime.
- `DiaryVaultTests/` - Swift Testing tests for save/load/export/delete.
- `tools/` - offline Python tooling for regenerating reference attribute assets.
- `reports/` - measured prototype output and recommendation.
- `docs/architecture.md` - concise Russian architecture document.
- `docs/mvp_release_prep.md` - MVP hardening checklist, performance baseline, and QA gate.
- `Bhatia/` - local reference materials; raw large datasets are ignored by git.
- `Project.swift` - Tuist manifest; generated `.xcodeproj`/`.xcworkspace` are ignored.

## Regenerating assets

Use Python 3.12:

```bash
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/generate_attribute_assets.py --model all-MiniLM-L6-v2
.venv/bin/python tools/generate_attribute_assets.py --model all-MiniLM-L12-v2
.venv/bin/python tools/generate_attribute_assets.py --model paraphrase-multilingual-MiniLM-L12-v2 --quality-report reports/quality_multi_l12.json --baseline-quality-report reports/quality_l12.json
.venv/bin/python tools/generate_production_assets.py
.venv/bin/python -m pytest tools/test_attribute_assets.py
```

The app runtime must not download from Hugging Face. Model files are prepared by
offline tooling and loaded from the app bundle. `DilemmaAssets.sqlite` is the
production read-only attribute asset used by the app. Its cluster mapping comes
from `DecisionKernel/Resources/Attributes/bhatia_attribute_clusters.csv`, a
frozen reconstruction of Bhatia's Ward clustering over Reddit option profiles.
If the source reconstruction needs to be repeated, use
`tools/reconstruct_bhatia_clusters.py benchmark`, then `build-matrix`, then
`cluster`; the large intermediate CSVs stay under ignored
`outputs/bhatia_reconstruction/`.

## Local app workflow

```bash
brew tap tuist/tuist
brew install --formula tuist
.venv/bin/python tools/download_bundled_model.py --model all-MiniLM-L6-v2
.venv/bin/python tools/download_bundled_model.py --model paraphrase-multilingual-MiniLM-L12-v2
tuist generate --no-open
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
```

`DecisionKernel/Resources/Models` is ignored by git because bundled model weights are
large. Regenerate or download them locally before running integration tests.

Tuist uses buildable folders for `dilemma/Sources`, `DecisionModels/Sources`,
`DecisionUseCases/Sources`, `DecisionKernel/Sources`, `DiaryVault/Sources`, and
their test source folders, so adding new Swift files under those folders does
not require regenerating only to update file references. Regenerate when
targets, packages, resources, or settings change.

The app target imports `DecisionModels` for shared data types and
`DecisionUseCases` as its business boundary. UI code does not import
`DecisionKernel` or `DiaryVault` directly.
