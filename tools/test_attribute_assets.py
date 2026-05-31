from pathlib import Path
import csv
import json
import sqlite3

import numpy as np

CSV_PATH = Path("Bhatia/Code and Data/2 - Vectorize Reasons/attributes.csv")
ASSET_DIR = Path("DecisionKernel/Resources/Attributes")
PRODUCTION_SQLITE = ASSET_DIR / "DilemmaAssets.sqlite"
KMEANS_SQLITE = ASSET_DIR / "DilemmaAssetsKMeans.sqlite"
CLUSTER_MAPPING = ASSET_DIR / "bhatia_attribute_clusters.csv"
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


def test_bhatia_cluster_mapping_if_present():
    if not CLUSTER_MAPPING.exists():
        return

    with CLUSTER_MAPPING.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    assert len(rows) == 207
    assert len({row["attribute_id"] for row in rows}) == 207
    assert len({row["attribute_name"] for row in rows}) == 207

    cluster_ids = {int(row["cluster_id"]) for row in rows}
    assert cluster_ids == set(range(1, 26))
    for cluster_id in cluster_ids:
        assert any(int(row["cluster_id"]) == cluster_id for row in rows)

    labels = {row["cluster_label"] for row in rows}
    assert "Risk and Stability" in labels
    assert "Money and Finance" in labels
    assert "Family Closeness and Security" in labels


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


def test_production_sqlite_asset_if_present():
    if not PRODUCTION_SQLITE.exists():
        return

    metadata, first_embedding = assert_sqlite_asset(
        PRODUCTION_SQLITE,
        "bhatia_hierarchical_ward_reddit_option_profiles",
    )
    assert metadata["asset_version"] == "1"
    assert metadata["source_doi"] == "10.1073/pnas.2406489122"
    assert metadata["model_short_name"] == "l12"
    assert "cluster_source_sha256" in metadata
    assert int(metadata["embedding_dimension"]) == 384
    assert len(first_embedding) == 384 * 4


def test_kmeans_sqlite_asset_if_present():
    if not KMEANS_SQLITE.exists():
        return

    metadata, first_embedding = assert_sqlite_asset(
        KMEANS_SQLITE,
        "kmeans_on_mean_pro_con_attribute_embeddings",
    )
    assert metadata["model_short_name"] == "l12"
    assert metadata["cluster_random_state"] == "42"
    assert metadata["cluster_n_init"] == "50"
    assert metadata["cluster_algorithm"] == "lloyd"
    assert int(metadata["embedding_dimension"]) == 384
    assert len(first_embedding) == 384 * 4


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


def assert_sqlite_asset(path: Path, expected_cluster_method: str):
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    counts = {
        table: connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        for table in [
            "attributes",
            "attribute_directions",
            "attribute_embeddings",
            "clusters",
            "attribute_cluster",
            "asset_metadata",
        ]
    }
    metadata = dict(connection.execute("SELECT key, value FROM asset_metadata"))
    first_embedding = connection.execute(
        """
        SELECT embedding
        FROM attribute_embeddings
        ORDER BY direction_id
        LIMIT 1
        """
    ).fetchone()[0]
    connection.close()

    assert counts["attributes"] == 207
    assert counts["attribute_directions"] == 414
    assert counts["attribute_embeddings"] == 414
    assert counts["clusters"] == 25
    assert counts["attribute_cluster"] == 207
    assert metadata["cluster_method"] == expected_cluster_method
    return metadata, first_embedding
