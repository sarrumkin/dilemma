# dilemma

Minimal iOS research prototype for local Bhatia-style embedding mapping.

Slice 1 checks whether an iOS 18+ app can run `swift-embeddings` fully offline,
load a bundled SentenceTransformers-compatible model, map 12 hardcoded English
reasons to Bhatia decision attributes, and produce enough latency/quality data
to choose the runtime path before Slice 2.

## Local shape

- `dilemma/` - SwiftUI app sources and compact runtime resources.
- `dilemmaTests/` - Swift tests for scoring, F16 loading, and aggregation.
- `tools/` - offline Python tooling for regenerating Bhatia attribute assets.
- `reports/` - measured prototype output and recommendation.
- `Bhatia/` - local reference materials; raw large datasets are ignored by git.

## Regenerating assets

Use Python 3.12:

```bash
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/generate_bhatia_assets.py --model all-MiniLM-L6-v2
```

The app runtime must not download from Hugging Face. Model files are prepared by
offline tooling and loaded from the app bundle.
