#!/usr/bin/env python3
"""Build the bundled production SQLite asset for DecisionKernel.

The script intentionally consumes the already-generated runtime JSON/F16 assets.
That keeps production packaging deterministic after the model choice has been
made: the expensive embedding generation remains in generate_attribute_assets.py,
while this script owns the app-facing SQLite schema and cluster mapping.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sqlite3
import tempfile
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from sklearn.cluster import KMeans

DEFAULT_CSV = Path("Bhatia/Code and Data/2 - Vectorize Reasons/attributes.csv")
DEFAULT_METADATA = Path("DecisionKernel/Resources/Attributes/attributes_l12.json")
DEFAULT_VECTORS = Path("DecisionKernel/Resources/Attributes/attribute_embeddings_l12.f16")
DEFAULT_OUTPUT = Path("DecisionKernel/Resources/Attributes/DilemmaAssets.sqlite")
CLUSTER_COUNT = 25


@dataclass(frozen=True)
class SourceRow:
    row_index: int
    name: str
    source: str
    direction: str
    sentences: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--attributes-csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--metadata", type=Path, default=DEFAULT_METADATA)
    parser.add_argument("--vectors", type=Path, default=DEFAULT_VECTORS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--cluster-count", type=int, default=CLUSTER_COUNT)
    return parser.parse_args()


def load_source_rows(path: Path) -> list[SourceRow]:
    with path.open(newline="", encoding="cp1252") as handle:
        rows = [
            SourceRow(
                row_index=index,
                name=row["Name"],
                source=row["Source"].strip(),
                direction=row["Direction"],
                sentences=row["Sentences"],
            )
            for index, row in enumerate(csv.DictReader(handle))
        ]

    assert len(rows) == 414, f"Expected 414 source rows, got {len(rows)}"
    assert len({row.name for row in rows}) == 207, "Expected 207 unique attributes"
    assert {row.direction for row in rows} == {"pro", "con"}, "Expected pro/con directions"
    return rows


def load_runtime_asset(metadata_path: Path, vectors_path: Path) -> tuple[dict, np.ndarray]:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    dimension = int(metadata["model"]["embedding_dimension"])
    vectors = np.fromfile(vectors_path, dtype="<f2").astype(np.float32)
    expected = len(metadata["attributes"]) * dimension
    assert vectors.shape == (expected,), f"Expected {expected} vector values, got {vectors.shape}"
    return metadata, vectors.reshape(len(metadata["attributes"]), dimension)


def normalize(matrix: np.ndarray) -> np.ndarray:
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    return matrix / norms


def unique_attributes(rows: list[SourceRow]) -> OrderedDict[str, int]:
    attributes: OrderedDict[str, int] = OrderedDict()
    for row in rows:
        attributes.setdefault(row.name, len(attributes) + 1)
    return attributes


def build_attribute_vectors(
    rows: list[SourceRow],
    vectors: np.ndarray,
    attribute_ids: OrderedDict[str, int],
) -> np.ndarray:
    matrix = np.zeros((len(attribute_ids), vectors.shape[1]), dtype=np.float32)
    counts = np.zeros((len(attribute_ids), 1), dtype=np.float32)

    for row in rows:
        index = attribute_ids[row.name] - 1
        matrix[index] += vectors[row.row_index]
        counts[index] += 1

    return normalize(matrix / counts)


def cluster_attributes(
    rows: list[SourceRow],
    attribute_ids: OrderedDict[str, int],
    attribute_vectors: np.ndarray,
    cluster_count: int,
) -> tuple[dict[int, int], list[tuple[int, str, str]]]:
    if cluster_count <= 0:
        raise ValueError("cluster-count must be positive")
    if cluster_count > len(attribute_ids):
        raise ValueError("cluster-count cannot exceed unique attribute count")

    kmeans = KMeans(
        n_clusters=cluster_count,
        random_state=42,
        n_init=50,
        algorithm="lloyd",
    )
    raw_labels = kmeans.fit_predict(attribute_vectors)

    members_by_raw_label: dict[int, list[int]] = {}
    for attribute_id, raw_label in enumerate(raw_labels, start=1):
        members_by_raw_label.setdefault(int(raw_label), []).append(attribute_id)

    # KMeans label ids are arbitrary. Remap them by first attribute position so
    # the public SQLite asset keeps stable cluster ids across deterministic runs.
    raw_to_stable = {
        raw_label: stable_id
        for stable_id, raw_label in enumerate(
            sorted(members_by_raw_label, key=lambda label: min(members_by_raw_label[label])),
            start=1,
        )
    }

    names_by_id = {attribute_id: name for name, attribute_id in attribute_ids.items()}
    assignment: dict[int, int] = {}
    clusters: list[tuple[int, str, str]] = []
    for raw_label, members in members_by_raw_label.items():
        stable_id = raw_to_stable[raw_label]
        centroid = kmeans.cluster_centers_[raw_label]
        member_vectors = attribute_vectors[[member - 1 for member in members]]
        nearest_member_index = int(np.argmax(member_vectors @ centroid))
        representative_id = members[nearest_member_index]
        representative_name = names_by_id[representative_id]
        clusters.append((stable_id, f"Cluster {stable_id}: {representative_name}", representative_name))
        for member in members:
            assignment[member] = stable_id

    return assignment, sorted(clusters)


def write_sqlite(
    output_path: Path,
    source_rows: list[SourceRow],
    metadata: dict,
    vectors: np.ndarray,
    attribute_ids: OrderedDict[str, int],
    cluster_assignment: dict[int, int],
    clusters: list[tuple[int, str, str]],
    cluster_count: int,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.chmod(0o644)

    fd, temp_name = tempfile.mkstemp(prefix=output_path.name, suffix=".tmp", dir=output_path.parent)
    os.close(fd)
    temp_path = Path(temp_name)

    try:
        connection = sqlite3.connect(temp_path)
        connection.execute("PRAGMA journal_mode = DELETE")
        connection.execute("PRAGMA foreign_keys = ON")
        create_schema(connection)
        insert_rows(
            connection,
            source_rows,
            metadata,
            vectors,
            attribute_ids,
            cluster_assignment,
            clusters,
            cluster_count,
        )
        connection.execute("PRAGMA user_version = 1")
        connection.commit()
        connection.close()
        os.replace(temp_path, output_path)
        output_path.chmod(0o444)
    finally:
        if temp_path.exists():
            temp_path.unlink()


def create_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE TABLE attributes (
          attribute_id INTEGER PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          source TEXT NOT NULL,
          source_row_index INTEGER NOT NULL
        );

        CREATE TABLE attribute_directions (
          direction_id INTEGER PRIMARY KEY,
          attribute_id INTEGER NOT NULL REFERENCES attributes(attribute_id),
          row_index INTEGER NOT NULL UNIQUE,
          direction TEXT NOT NULL CHECK (direction IN ('pro', 'con')),
          sentences TEXT NOT NULL,
          vector_offset INTEGER NOT NULL
        );

        CREATE TABLE attribute_embeddings (
          direction_id INTEGER PRIMARY KEY REFERENCES attribute_directions(direction_id),
          embedding BLOB NOT NULL,
          dtype TEXT NOT NULL,
          normalized INTEGER NOT NULL CHECK (normalized IN (0, 1))
        );

        CREATE TABLE clusters (
          cluster_id INTEGER PRIMARY KEY,
          label TEXT NOT NULL,
          representative_attribute_name TEXT NOT NULL,
          sort_order INTEGER NOT NULL UNIQUE
        );

        CREATE TABLE attribute_cluster (
          attribute_id INTEGER PRIMARY KEY REFERENCES attributes(attribute_id),
          cluster_id INTEGER NOT NULL REFERENCES clusters(cluster_id)
        );

        CREATE TABLE asset_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE INDEX attribute_directions_attribute_idx
          ON attribute_directions(attribute_id);

        CREATE INDEX attribute_cluster_cluster_idx
          ON attribute_cluster(cluster_id);
        """
    )


def insert_rows(
    connection: sqlite3.Connection,
    source_rows: list[SourceRow],
    metadata: dict,
    vectors: np.ndarray,
    attribute_ids: OrderedDict[str, int],
    cluster_assignment: dict[int, int],
    clusters: list[tuple[int, str, str]],
    cluster_count: int,
) -> None:
    first_row_by_name: dict[str, SourceRow] = {}
    for row in source_rows:
        first_row_by_name.setdefault(row.name, row)

    connection.executemany(
        """
        INSERT INTO attributes(attribute_id, name, source, source_row_index)
        VALUES (?, ?, ?, ?)
        """,
        [
            (
                attribute_id,
                name,
                first_row_by_name[name].source,
                first_row_by_name[name].row_index,
            )
            for name, attribute_id in attribute_ids.items()
        ],
    )

    connection.executemany(
        """
        INSERT INTO attribute_directions(
          direction_id,
          attribute_id,
          row_index,
          direction,
          sentences,
          vector_offset
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
            (
                row.row_index + 1,
                attribute_ids[row.name],
                row.row_index,
                row.direction,
                row.sentences,
                int(metadata["attributes"][row.row_index]["vector_offset"]),
            )
            for row in source_rows
        ],
    )

    connection.executemany(
        """
        INSERT INTO attribute_embeddings(direction_id, embedding, dtype, normalized)
        VALUES (?, ?, ?, ?)
        """,
        [
            (
                row.row_index + 1,
                sqlite3.Binary(vectors[row.row_index].astype("<f4").tobytes()),
                "float32",
                1,
            )
            for row in source_rows
        ],
    )

    connection.executemany(
        """
        INSERT INTO clusters(cluster_id, label, representative_attribute_name, sort_order)
        VALUES (?, ?, ?, ?)
        """,
        [
            (cluster_id, label, representative, cluster_id)
            for cluster_id, label, representative in clusters
        ],
    )

    connection.executemany(
        """
        INSERT INTO attribute_cluster(attribute_id, cluster_id)
        VALUES (?, ?)
        """,
        [
            (attribute_id, cluster_assignment[attribute_id])
            for attribute_id in range(1, len(attribute_ids) + 1)
        ],
    )

    metadata_rows = {
        "asset_version": str(metadata["asset_version"]),
        "source_doi": metadata["source_doi"],
        "model_id": metadata["model"]["id"],
        "model_short_name": metadata["model"]["short_name"],
        "embedding_dimension": str(metadata["model"]["embedding_dimension"]),
        "embedding_dtype": "float32",
        "embedding_normalized": "true",
        "attribute_count": str(len(attribute_ids)),
        "attribute_direction_count": str(len(source_rows)),
        "cluster_count": str(cluster_count),
        "cluster_method": "kmeans_on_mean_pro_con_attribute_embeddings",
        "cluster_random_state": "42",
    }
    connection.executemany(
        "INSERT INTO asset_metadata(key, value) VALUES (?, ?)",
        sorted(metadata_rows.items()),
    )


def verify_sqlite(path: Path, expected_cluster_count: int) -> None:
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
    assert counts["attributes"] == 207, counts
    assert counts["attribute_directions"] == 414, counts
    assert counts["attribute_embeddings"] == 414, counts
    assert counts["clusters"] == int(metadata["cluster_count"]) == expected_cluster_count, counts
    assert counts["attribute_cluster"] == 207, counts
    assert metadata["source_doi"] == "10.1073/pnas.2406489122"
    connection.close()


def main() -> None:
    args = parse_args()
    source_rows = load_source_rows(args.attributes_csv)
    metadata, vectors = load_runtime_asset(args.metadata, args.vectors)
    attribute_ids = unique_attributes(source_rows)
    attribute_vectors = build_attribute_vectors(source_rows, vectors, attribute_ids)
    cluster_assignment, clusters = cluster_attributes(
        source_rows,
        attribute_ids,
        attribute_vectors,
        args.cluster_count,
    )
    write_sqlite(
        args.output,
        source_rows,
        metadata,
        vectors,
        attribute_ids,
        cluster_assignment,
        clusters,
        args.cluster_count,
    )
    verify_sqlite(args.output, args.cluster_count)


if __name__ == "__main__":
    main()
