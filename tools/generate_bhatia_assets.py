#!/usr/bin/env python3
"""Generate deterministic Bhatia attribute assets for the iOS prototype."""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer

SOURCE_DOI = "10.1073/pnas.2406489122"
DEFAULT_CSV = Path("Bhatia/Code and Data/2 - Vectorize Reasons/attributes.csv")
DEFAULT_OUTPUT_DIR = Path("dilemma/Resources/Attributes")

MODELS = {
    "all-MiniLM-L6-v2": "sentence-transformers/all-MiniLM-L6-v2",
    "all-MiniLM-L12-v2": "sentence-transformers/all-MiniLM-L12-v2",
    "all-mpnet-base-v2": "sentence-transformers/all-mpnet-base-v2",
}

RUNTIME_SHORT_NAMES = {
    "all-MiniLM-L6-v2": "l6",
    "all-MiniLM-L12-v2": "l12",
    "all-mpnet-base-v2": "mpnet",
}

DEFAULT_REASONS = [
    ("This option would save me money.", "benefit"),
    ("There is a chance I could lose stability.", "cost"),
    ("It could improve my career prospects.", "benefit"),
    ("It may hurt my mental health.", "cost"),
    ("It could strengthen the relationship.", "benefit"),
    ("It would give me more time with my family.", "benefit"),
    ("I would have more independence.", "benefit"),
    ("It requires a lot of time and work.", "cost"),
    ("I would learn useful new skills.", "benefit"),
    ("It may damage my reputation.", "cost"),
    ("It sounds enjoyable and exciting.", "benefit"),
    ("It gives me a safer long-term path.", "benefit"),
]


@dataclass(frozen=True)
class AttributeRow:
    row_index: int
    name: str
    source: str
    direction: str
    sentences: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", choices=sorted(MODELS), default="all-MiniLM-L6-v2")
    parser.add_argument("--attributes-csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--quality-report", type=Path)
    parser.add_argument("--batch-size", type=int, default=64)
    return parser.parse_args()


def load_attribute_rows(path: Path) -> list[AttributeRow]:
    rows: list[AttributeRow] = []

    # Bhatia's CSV is cp1252 encoded. Reading as UTF-8 fails on curly quotes in
    # several attributes, so keep the source encoding explicit and tested.
    with path.open(newline="", encoding="cp1252") as handle:
        reader = csv.DictReader(handle)
        for row_index, row in enumerate(reader):
            # This sentence split intentionally mirrors the Bhatia notebook:
            # remove periods, then split on semicolon-space.
            sentences = [part for part in row["Sentences"].replace(".", "").split("; ") if part]
            rows.append(
                AttributeRow(
                    row_index=row_index,
                    name=row["Name"],
                    source=row["Source"],
                    direction=row["Direction"],
                    sentences=sentences,
                )
            )

    assert len(rows) == 414, f"Expected 414 rows, got {len(rows)}"
    assert len({row.name for row in rows}) == 207, "Expected 207 unique attribute names"
    assert {row.direction for row in rows} == {"pro", "con"}, "Expected pro/con directions"
    assert sum(row.direction == "pro" for row in rows) == 207
    assert sum(row.direction == "con" for row in rows) == 207
    return rows


def normalize(matrix: np.ndarray) -> np.ndarray:
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    return matrix / norms


def embed_attributes(
    rows: list[AttributeRow],
    model: SentenceTransformer,
    batch_size: int,
) -> np.ndarray:
    vectors: list[np.ndarray] = []
    for row in rows:
        sentence_vectors = model.encode(
            row.sentences,
            batch_size=batch_size,
            convert_to_numpy=True,
            normalize_embeddings=False,
            show_progress_bar=False,
        )
        vectors.append(np.mean(sentence_vectors, axis=0))
    return normalize(np.vstack(vectors).astype(np.float32))


def metadata_for(rows: list[AttributeRow], model_key: str, dimension: int) -> dict:
    short_name = RUNTIME_SHORT_NAMES[model_key]
    vector_file = f"attribute_embeddings_{short_name}.f16"
    return {
        "asset_version": 1,
        "source_doi": SOURCE_DOI,
        "model": {
            "id": MODELS[model_key],
            "short_name": short_name,
            "embedding_dimension": dimension,
        },
        "vectors": {
            "file": vector_file,
            "dtype": "float16",
            "layout": "row-major",
            "normalized": True,
        },
        "attributes": [
            {
                "row_index": row.row_index,
                "name": row.name,
                "source": row.source,
                "direction": row.direction,
                "vector_offset": row.row_index * dimension,
            }
            for row in rows
        ],
    }


def write_assets(output_dir: Path, metadata: dict, vectors: np.ndarray) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    short_name = metadata["model"]["short_name"]
    metadata_path = output_dir / f"attributes_{short_name}.json"
    vector_path = output_dir / metadata["vectors"]["file"]

    metadata_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    # Store compact row-major Float16 vectors. The Swift loader reads the same
    # little-endian binary layout and expands values to Float for scoring.
    vectors.astype("<f2").tofile(vector_path)


def quality_smoke(
    rows: list[AttributeRow],
    attribute_vectors: np.ndarray,
    model: SentenceTransformer,
    batch_size: int,
) -> list[dict]:
    reasons = [text for text, _ in DEFAULT_REASONS]
    polarities = [polarity for _, polarity in DEFAULT_REASONS]
    reason_vectors = model.encode(
        reasons,
        batch_size=batch_size,
        convert_to_numpy=True,
        normalize_embeddings=True,
        show_progress_bar=False,
    ).astype(np.float32)

    output: list[dict] = []
    for reason, polarity, reason_vector in zip(reasons, polarities, reason_vectors):
        direction = "pro" if polarity == "benefit" else "con"
        candidate_indices = [index for index, row in enumerate(rows) if row.direction == direction]
        scores = attribute_vectors[candidate_indices] @ reason_vector
        ranked = np.argsort(-scores)[:5]
        output.append(
            {
                "reason": reason,
                "polarity": polarity,
                "top_5": [
                    {
                        "name": rows[candidate_indices[int(rank)]].name,
                        "direction": rows[candidate_indices[int(rank)]].direction,
                        "score": float(scores[int(rank)]),
                    }
                    for rank in ranked
                ],
            }
        )
    return output


def main() -> None:
    args = parse_args()
    rows = load_attribute_rows(args.attributes_csv)
    model = SentenceTransformer(MODELS[args.model])
    vectors = embed_attributes(rows, model, args.batch_size)
    metadata = metadata_for(rows, args.model, vectors.shape[1])
    write_assets(args.output_dir, metadata, vectors)

    if args.quality_report:
        args.quality_report.parent.mkdir(parents=True, exist_ok=True)
        report = {
            "model_id": MODELS[args.model],
            "embedding_dimension": int(vectors.shape[1]),
            "quality_smoke": quality_smoke(rows, vectors, model, args.batch_size),
        }
        args.quality_report.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
