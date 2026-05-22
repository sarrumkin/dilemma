# dilemma

Minimal iOS research prototype for local reference-study embedding mapping.

Slice 1 checks whether an iOS 18+ app can run `swift-embeddings` fully offline,
load a bundled SentenceTransformers-compatible model, map 12 hardcoded English
reasons to decision attributes, and produce enough latency/quality data
to choose the runtime path before Slice 2.

Current prototype default: `swift-embeddings + all-MiniLM-L12-v2`.

## Local shape

- `dilemma/` - SwiftUI app target with composition, use cases, and debug feature UI.
- `DecisionKernel/` - local analysis framework with schema, core math, runtime, assets, and pipeline.
- `DecisionKernelTests/` - Swift Testing tests for scoring, F16 loading, aggregation, and bundled runtime.
- `tools/` - offline Python tooling for regenerating reference attribute assets.
- `reports/` - measured prototype output and recommendation.
- `docs/architecture.md` - concise Russian architecture document.
- `Bhatia/` - local reference materials; raw large datasets are ignored by git.
- `Project.swift` - Tuist manifest; generated `.xcodeproj`/`.xcworkspace` are ignored.

## Regenerating assets

Use Python 3.12:

```bash
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/generate_attribute_assets.py --model all-MiniLM-L6-v2
.venv/bin/python tools/generate_attribute_assets.py --model all-MiniLM-L12-v2
```

The app runtime must not download from Hugging Face. Model files are prepared by
offline tooling and loaded from the app bundle.

## Local app workflow

```bash
brew tap tuist/tuist
brew install --formula tuist
.venv/bin/python tools/download_bundled_model.py --model all-MiniLM-L6-v2
.venv/bin/python tools/download_bundled_model.py --model all-MiniLM-L12-v2
tuist generate --no-open
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
```

`DecisionKernel/Resources/Models` is ignored by git because bundled model weights are
large. Regenerate or download them locally before running integration tests.

Tuist uses buildable folders for `dilemma/Sources`, `DecisionKernel/Sources`,
and `DecisionKernelTests`, so adding
new Swift files under those folders does not require regenerating only to update
file references. Regenerate when targets, packages, resources, or settings
change.
