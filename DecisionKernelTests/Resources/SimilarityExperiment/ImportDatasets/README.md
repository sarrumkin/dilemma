# Blocked Dilemma Import Datasets

These files are valid JSON and can be imported through the app JSON import flow.

- `dilemmas_en_blocks.json`: 12 conflict blocks, 120 English dilemmas.
- `dilemmas_ru_blocks.json`: 12 conflict blocks, 120 Russian dilemmas.
- `dilemmas_en_blocks.txt`: human-readable English version.
- `dilemmas_ru_blocks.txt`: human-readable Russian version.

Each top-level item is a conflict block with human-readable `comment` and `intent`
fields followed by a `dilemmas` array. Real `//` comments are intentionally not
used because the app imports JSON through `JSONDecoder`.

The block format is:

```json
[
  {
    "schemaVersion": 1,
    "id": "ambition_vs_belonging",
    "title": "Ambition and growth vs closeness and stability",
    "comment": "Human-readable block description.",
    "intent": "What this block is testing.",
    "dilemmas": [
      {
        "schemaVersion": 1,
        "id": "ambition_vs_belonging-promotion-family",
        "conflictCluster": "ambition_vs_belonging",
        "rawText": "Should I accept the promotion or keep the calmer role?",
        "options": [
          {
            "title": "Accept the promotion",
            "benefits": ["...", "...", "..."],
            "costs": ["...", "...", "..."]
          },
          {
            "title": "Keep the calmer role",
            "benefits": ["...", "...", "..."],
            "costs": ["...", "...", "..."]
          }
        ]
      }
    ]
  }
]
```

Regenerate both JSON files with:

```sh
node tools/generate_dilemma_import_datasets.js
```
