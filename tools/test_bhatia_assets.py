from pathlib import Path
import csv
import json

import numpy as np

CSV_PATH = Path("Bhatia/Code and Data/2 - Vectorize Reasons/attributes.csv")
ASSET_DIR = Path("dilemma/Resources/Attributes")
REFERENCE_DIR = Path("reports/reference_assets")
QUALITY_REPORTS = [
    Path("reports/quality_l6.json"),
    Path("reports/quality_l12.json"),
    Path("reports/quality_mpnet.json"),
]


def test_source_csv_shape():
    with CSV_PATH.open(newline="", encoding="cp1252") as handle:
        rows = list(csv.DictReader(handle))

    assert len(rows) == 414
    assert len({row["Name"] for row in rows}) == 207
    assert {row["Direction"] for row in rows} == {"pro", "con"}
    assert sum(row["Direction"] == "pro" for row in rows) == 207
    assert sum(row["Direction"] == "con" for row in rows) == 207


def test_generated_runtime_assets_if_present():
    for short_name, dimension in [("l6", 384), ("l12", 384)]:
        metadata_path = ASSET_DIR / f"attributes_{short_name}.json"
        vector_path = ASSET_DIR / f"attribute_embeddings_{short_name}.f16"
        if not metadata_path.exists() or not vector_path.exists():
            continue

        assert_normalized_asset(metadata_path, vector_path, dimension)


def test_generated_mpnet_reference_asset_if_present():
    metadata_path = REFERENCE_DIR / "attributes_mpnet.json"
    vector_path = REFERENCE_DIR / "attribute_embeddings_mpnet.f16"
    if not metadata_path.exists() or not vector_path.exists():
        return

    assert_normalized_asset(metadata_path, vector_path, 768)


def test_quality_smoke_reports_if_present():
    expected_by_reason = {
        "save me money": {"money", "buying things i want", "being able to meet my financial needs"},
        "career prospects": {"career", "having a career", "keeping up to date with career-related knowledge"},
        "mental health": {"being mentally healthy", "protecting my wellbeing", "health"},
        "more independence": {"being independent", "having freedom", "having freedom of choice"},
        "enjoyable and exciting": {"pleasure", "having an exciting life", "stimulation"},
        "safer long-term path": {"security", "feeling safe and secure", "safety vs. risk"},
    }

    for report_path in QUALITY_REPORTS:
        if not report_path.exists():
            continue

        report = json.loads(report_path.read_text(encoding="utf-8"))
        rows = report["quality_smoke"]
        for fragment, accepted in expected_by_reason.items():
            row = next(item for item in rows if fragment in item["reason"])
            top_names = {match["name"] for match in row["top_5"]}
            assert top_names & accepted, f"{report_path.name}: {row['reason']} => {top_names}"


def assert_normalized_asset(metadata_path: Path, vector_path: Path, dimension: int):
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    assert metadata["asset_version"] == 1
    assert metadata["model"]["embedding_dimension"] == dimension
    assert len(metadata["attributes"]) == 414
    assert metadata["vectors"]["normalized"] is True

    vectors = np.fromfile(vector_path, dtype="<f2").astype(np.float32)
    assert vectors.shape == (414 * dimension,)
    matrix = vectors.reshape(414, dimension)
    norms = np.linalg.norm(matrix, axis=1)
    assert np.all(norms > 0.99)
    assert np.all(norms < 1.01)
