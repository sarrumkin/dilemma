#!/usr/bin/env python3
"""Reconstruct Bhatia empirical attribute clusters from local coded Reddit data.

This is intentionally a runnable adaptation of Bhatia's Step 2/3/5 pipeline:

1. read GPT-coded reasons from ``data - Advice.csv``;
2. embed reasons with ``sentence-transformers/all-mpnet-base-v2``;
3. score benefits against pro attributes and costs against con attributes;
4. cluster attributes with Ward linkage over Reddit option profiles.

The script does not change app assets. It writes intermediate reconstruction
artifacts under ``outputs/bhatia_reconstruction`` by default.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator

import numpy as np
from scipy.cluster.hierarchy import fcluster, linkage

SOURCE_DOI = "10.1073/pnas.2406489122"
DEFAULT_ADVICE_CSV = Path("Bhatia/Code and Data/1 - Code Posts/data - Advice.csv")
DEFAULT_ATTRIBUTES_CSV = Path("Bhatia/Code and Data/2 - Vectorize Reasons/attributes.csv")
DEFAULT_ATTRIBUTE_VECTORS = Path("reports/reference_assets/attribute_embeddings_mpnet.f16")
DEFAULT_OUTPUT_DIR = Path("outputs/bhatia_reconstruction")
DEFAULT_MODEL_ID = "sentence-transformers/all-mpnet-base-v2"
DEFAULT_CLUSTER_THRESHOLD = 40.0
EXPECTED_ATTRIBUTE_COUNT = 207
EXPECTED_DIRECTION_ROWS = 414
EXPECTED_CLUSTER_COUNT = 25

REASON_BLOCKS = [
    ("choice1_benefits", ("benefits1_1", "benefits1_2", "benefits1_3"), "pro"),
    ("choice1_costs", ("costs1_1", "costs1_2", "costs1_3"), "con"),
    ("choice2_benefits", ("benefits2_1", "benefits2_2", "benefits2_3"), "pro"),
    ("choice2_costs", ("costs2_1", "costs2_2", "costs2_3"), "con"),
]
REASON_COLUMNS = [column for _, columns, _ in REASON_BLOCKS for column in columns]

BHATIA_CLUSTER_LABELS = [
    "Risk and Stability",
    "Competence Perception",
    "Happiness and Pleasure",
    "Harm and Group Morality",
    "Money and Finance",
    "Professional Skills and Ability",
    "Discipline and Ambition",
    "Warmth and Morality Perception",
    "Justice and Fairness",
    "Security and Dependability",
    "Religion and Personal Causes",
    "Achievement",
    "Freedom and Courage",
    "Intellectual Development",
    "Pragmatism and Financial Prudence",
    "Cleanliness and Control",
    "Charity and Loyalty",
    "Social Desirability",
    "Social Connection",
    "Sex and Romance",
    "Art and Entertainment",
    "Marital Fulfillment",
    "Family Closeness and Security",
    "Physical Health",
    "Mental Health",
]


@dataclass(frozen=True)
class AttributeRow:
    row_index: int
    attribute_id: int
    name: str
    source: str
    direction: str


@dataclass(frozen=True)
class ReasonStats:
    total_rows: int
    complete_rows: int
    incomplete_rows: int
    unique_reasons: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reconstruct empirical Bhatia clusters from GPT-coded Reddit reasons."
    )
    subcommands = parser.add_subparsers(dest="command", required=True)

    def add_common_inputs(command: argparse.ArgumentParser) -> None:
        command.add_argument("--advice-csv", type=Path, default=DEFAULT_ADVICE_CSV)
        command.add_argument("--attributes-csv", type=Path, default=DEFAULT_ATTRIBUTES_CSV)
        command.add_argument("--attribute-vectors", type=Path, default=DEFAULT_ATTRIBUTE_VECTORS)

    benchmark = subcommands.add_parser("benchmark", help="Time reason embedding on a small sample.")
    add_common_inputs(benchmark)
    benchmark.add_argument("--model-id", default=DEFAULT_MODEL_ID)
    benchmark.add_argument("--cache-folder", type=Path, default=Path(".hf_cache"))
    benchmark.add_argument("--device", help="Optional SentenceTransformer device, e.g. cpu, mps, cuda.")
    benchmark.add_argument("--max-reasons", type=int, default=10_000)
    benchmark.add_argument("--batch-size", type=int, default=64)
    benchmark.add_argument("--output", type=Path)

    build = subcommands.add_parser("build-matrix", help="Build Bhatia Step 3 attribute matrix.")
    add_common_inputs(build)
    build.add_argument("--model-id", default=DEFAULT_MODEL_ID)
    build.add_argument("--cache-folder", type=Path, default=Path(".hf_cache"))
    build.add_argument("--device", help="Optional SentenceTransformer device, e.g. cpu, mps, cuda.")
    build.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR / "output - Advice - reconstructed.csv")
    build.add_argument("--batch-size", type=int, default=64)
    build.add_argument("--chunk-rows", type=int, default=256)
    build.add_argument("--limit", type=int, help="Limit complete rows for smoke tests.")
    build.add_argument("--overwrite", action="store_true")

    cluster = subcommands.add_parser("cluster", help="Run Bhatia Step 5 Ward clustering.")
    cluster.add_argument("--matrix-csv", type=Path, default=DEFAULT_OUTPUT_DIR / "output - Advice - reconstructed.csv")
    cluster.add_argument("--attributes-csv", type=Path, default=DEFAULT_ATTRIBUTES_CSV)
    cluster.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR / "bhatia_attribute_clusters.csv")
    cluster.add_argument("--summary", type=Path, default=DEFAULT_OUTPUT_DIR / "bhatia_attribute_clusters.summary.json")
    cluster.add_argument("--threshold", type=float, default=DEFAULT_CLUSTER_THRESHOLD)
    cluster.add_argument("--expected-clusters", type=int, default=EXPECTED_CLUSTER_COUNT)
    cluster.add_argument("--overwrite", action="store_true")

    return parser.parse_args()


def load_attribute_rows(path: Path) -> list[AttributeRow]:
    rows: list[AttributeRow] = []
    attribute_ids: dict[str, int] = {}

    with path.open(newline="", encoding="cp1252") as handle:
        for row_index, row in enumerate(csv.DictReader(handle)):
            name = row["Name"]
            if name not in attribute_ids:
                attribute_ids[name] = len(attribute_ids) + 1
            rows.append(
                AttributeRow(
                    row_index=row_index,
                    attribute_id=attribute_ids[name],
                    name=name,
                    source=row["Source"].strip(),
                    direction=row["Direction"],
                )
            )

    if len(rows) != EXPECTED_DIRECTION_ROWS:
        raise ValueError(f"Expected {EXPECTED_DIRECTION_ROWS} attribute rows, got {len(rows)}")
    if len(attribute_ids) != EXPECTED_ATTRIBUTE_COUNT:
        raise ValueError(f"Expected {EXPECTED_ATTRIBUTE_COUNT} unique attributes, got {len(attribute_ids)}")
    if {row.direction for row in rows} != {"pro", "con"}:
        raise ValueError("Expected exactly pro/con attribute directions")

    return rows


def unique_attribute_rows(rows: list[AttributeRow]) -> list[AttributeRow]:
    output: list[AttributeRow] = []
    seen: set[str] = set()
    for row in rows:
        if row.name not in seen:
            seen.add(row.name)
            output.append(row)
    return output


def direction_indices(rows: list[AttributeRow], direction: str) -> list[int]:
    return [index for index, row in enumerate(rows) if row.direction == direction]


def validate_attribute_direction_order(rows: list[AttributeRow]) -> None:
    pro_names = [rows[index].name for index in direction_indices(rows, "pro")]
    con_names = [rows[index].name for index in direction_indices(rows, "con")]
    if pro_names != con_names:
        raise ValueError("Pro and con attribute rows are not in the same attribute order")


def load_attribute_vectors(path: Path, rows: list[AttributeRow]) -> tuple[np.ndarray, np.ndarray]:
    vectors = np.fromfile(path, dtype="<f2").astype(np.float32)
    if vectors.size % len(rows) != 0:
        raise ValueError(f"{path} does not divide evenly into {len(rows)} attribute rows")
    dimension = vectors.size // len(rows)
    matrix = vectors.reshape(len(rows), dimension)
    matrix = normalize(matrix)
    pro = matrix[direction_indices(rows, "pro")]
    con = matrix[direction_indices(rows, "con")]
    if pro.shape[0] != EXPECTED_ATTRIBUTE_COUNT or con.shape[0] != EXPECTED_ATTRIBUTE_COUNT:
        raise ValueError("Expected 207 pro and 207 con vectors")
    return pro, con


def normalize(matrix: np.ndarray) -> np.ndarray:
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    return matrix / norms


def valid_reason(value: str | None) -> bool:
    if value is None:
        return False
    stripped = value.strip()
    return bool(stripped) and stripped.upper() != "NA" and stripped.lower() != "nan"


def is_complete_reason_row(row: dict[str, str]) -> bool:
    return all(valid_reason(row.get(column)) for column in REASON_COLUMNS)


def iter_complete_reason_rows(path: Path, limit: int | None = None) -> Iterator[tuple[int, dict[str, str]]]:
    emitted = 0
    with path.open(newline="", encoding="utf-8") as handle:
        for source_row_index, row in enumerate(csv.DictReader(handle)):
            if not is_complete_reason_row(row):
                continue
            yield source_row_index, row
            emitted += 1
            if limit is not None and emitted >= limit:
                return


def count_reason_stats(path: Path) -> ReasonStats:
    total_rows = 0
    complete_rows = 0
    unique_reasons: set[str] = set()

    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            total_rows += 1
            if not is_complete_reason_row(row):
                continue
            complete_rows += 1
            for column in REASON_COLUMNS:
                unique_reasons.add(row[column].strip())

    return ReasonStats(
        total_rows=total_rows,
        complete_rows=complete_rows,
        incomplete_rows=total_rows - complete_rows,
        unique_reasons=len(unique_reasons),
    )


def collect_unique_reasons(path: Path, max_reasons: int) -> list[str]:
    reasons: list[str] = []
    seen: set[str] = set()
    for _, row in iter_complete_reason_rows(path):
        for column in REASON_COLUMNS:
            reason = row[column].strip()
            if reason in seen:
                continue
            seen.add(reason)
            reasons.append(reason)
            if len(reasons) >= max_reasons:
                return reasons
    return reasons


def score_column_names(attribute_count: int = EXPECTED_ATTRIBUTE_COUNT) -> list[str]:
    return [
        f"{block_name}{attribute_id}"
        for block_name, _, _ in REASON_BLOCKS
        for attribute_id in range(1, attribute_count + 1)
    ]


def load_sentence_transformer(model_id: str, cache_folder: Path, device: str | None):
    from sentence_transformers import SentenceTransformer

    kwargs = {"cache_folder": str(cache_folder)}
    if device:
        kwargs["device"] = device
    return SentenceTransformer(model_id, **kwargs)


def run_benchmark(args: argparse.Namespace) -> None:
    rows = load_attribute_rows(args.attributes_csv)
    validate_attribute_direction_order(rows)
    pro_vectors, _ = load_attribute_vectors(args.attribute_vectors, rows)
    stats = count_reason_stats(args.advice_csv)
    reasons = collect_unique_reasons(args.advice_csv, args.max_reasons)
    if not reasons:
        raise ValueError("No complete reasons found for benchmark")

    model = load_sentence_transformer(args.model_id, args.cache_folder, args.device)
    start = time.perf_counter()
    embeddings = model.encode(
        reasons,
        batch_size=args.batch_size,
        convert_to_numpy=True,
        normalize_embeddings=True,
        show_progress_bar=True,
    ).astype(np.float32)
    embedding_seconds = time.perf_counter() - start

    scoring_start = time.perf_counter()
    _ = embeddings[: min(len(embeddings), 1_000)] @ pro_vectors.T
    scoring_seconds = time.perf_counter() - scoring_start

    reasons_per_second = len(reasons) / embedding_seconds if embedding_seconds > 0 else math.inf
    estimated_seconds = stats.unique_reasons / reasons_per_second if reasons_per_second > 0 else math.inf
    report = {
        "model_id": args.model_id,
        "device": args.device or "auto",
        "batch_size": args.batch_size,
        "sample_reasons": len(reasons),
        "embedding_seconds": embedding_seconds,
        "reasons_per_second": reasons_per_second,
        "estimated_unique_reasons": stats.unique_reasons,
        "estimated_full_embedding_hours": estimated_seconds / 3600,
        "scoring_seconds_for_1000x207": scoring_seconds,
        "advice_rows": stats.total_rows,
        "complete_advice_rows": stats.complete_rows,
        "incomplete_advice_rows": stats.incomplete_rows,
    }
    text = json.dumps(report, ensure_ascii=False, indent=2)
    print(text)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")


def row_reason_texts(row: dict[str, str]) -> list[str]:
    return [row[column].strip() for _, columns, _ in REASON_BLOCKS for column in columns]


def format_float(value: float) -> str:
    return f"{value:.8g}"


def run_build_matrix(args: argparse.Namespace) -> None:
    if args.output.exists() and not args.overwrite:
        raise FileExistsError(f"{args.output} already exists; pass --overwrite to replace it")

    rows = load_attribute_rows(args.attributes_csv)
    validate_attribute_direction_order(rows)
    pro_vectors, con_vectors = load_attribute_vectors(args.attribute_vectors, rows)
    model = load_sentence_transformer(args.model_id, args.cache_folder, args.device)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    header = ["source_row_index", "id"] + score_column_names()
    complete_rows = iter_complete_reason_rows(args.advice_csv, limit=args.limit)
    written = 0
    start = time.perf_counter()

    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        for chunk in chunked(complete_rows, args.chunk_rows):
            source_indices = [source_index for source_index, _ in chunk]
            source_rows = [row for _, row in chunk]
            texts = [text for row in source_rows for text in row_reason_texts(row)]
            embeddings = model.encode(
                texts,
                batch_size=args.batch_size,
                convert_to_numpy=True,
                normalize_embeddings=True,
                show_progress_bar=False,
            ).astype(np.float32)
            embeddings = embeddings.reshape(len(source_rows), len(REASON_COLUMNS), -1)

            output_blocks: list[np.ndarray] = []
            reason_offset = 0
            for _, columns, direction in REASON_BLOCKS:
                block_embeddings = embeddings[:, reason_offset : reason_offset + len(columns), :]
                target_vectors = pro_vectors if direction == "pro" else con_vectors
                block_scores = block_embeddings @ target_vectors.T
                output_blocks.append(block_scores.mean(axis=1))
                reason_offset += len(columns)

            for local_index, row in enumerate(source_rows):
                values: list[str] = [str(source_indices[local_index]), row.get("id", "")]
                for block_scores in output_blocks:
                    values.extend(format_float(float(score)) for score in block_scores[local_index])
                writer.writerow(values)

            written += len(source_rows)
            elapsed = time.perf_counter() - start
            rate = written / elapsed if elapsed > 0 else 0
            print(f"wrote_rows={written} elapsed_s={elapsed:.1f} rows_per_s={rate:.2f}", flush=True)

    print(f"matrix_csv={args.output} rows={written}")


def chunked(iterator: Iterable[tuple[int, dict[str, str]]], size: int) -> Iterator[list[tuple[int, dict[str, str]]]]:
    if size <= 0:
        raise ValueError("chunk size must be positive")
    chunk: list[tuple[int, dict[str, str]]] = []
    for item in iterator:
        chunk.append(item)
        if len(chunk) >= size:
            yield chunk
            chunk = []
    if chunk:
        yield chunk


def run_cluster(args: argparse.Namespace) -> None:
    if args.output.exists() and not args.overwrite:
        raise FileExistsError(f"{args.output} already exists; pass --overwrite to replace it")
    if args.summary.exists() and not args.overwrite:
        raise FileExistsError(f"{args.summary} already exists; pass --overwrite to replace it")

    rows = unique_attribute_rows(load_attribute_rows(args.attributes_csv))
    matrix_hash = sha256_file(args.matrix_csv)
    row_count = count_csv_data_rows(args.matrix_csv)
    x = np.empty((row_count * 2, EXPECTED_ATTRIBUTE_COUNT), dtype=np.float32)

    with args.matrix_csv.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required_columns = set(score_column_names())
        missing = required_columns - set(reader.fieldnames or [])
        if missing:
            sample = ", ".join(sorted(missing)[:5])
            raise ValueError(f"Matrix CSV is missing score columns: {sample}")

        for row_index, row in enumerate(reader):
            x[row_index] = block_values(row, "choice1_benefits") - block_values(row, "choice1_costs")
            x[row_count + row_index] = block_values(row, "choice2_benefits") - block_values(row, "choice2_costs")

    z = linkage(x.T, "ward")
    cluster_ids = fcluster(z, args.threshold, criterion="distance").astype(int)
    unique_clusters = sorted(set(int(value) for value in cluster_ids))
    if len(unique_clusters) != args.expected_clusters:
        raise ValueError(
            f"Expected {args.expected_clusters} clusters at threshold {args.threshold}, "
            f"got {len(unique_clusters)}: {unique_clusters}"
        )

    label_by_cluster = {
        cluster_id: BHATIA_CLUSTER_LABELS[cluster_id - 1]
        if 1 <= cluster_id <= len(BHATIA_CLUSTER_LABELS)
        else f"Cluster {cluster_id}"
        for cluster_id in unique_clusters
    }
    counts = {cluster_id: int(np.sum(cluster_ids == cluster_id)) for cluster_id in unique_clusters}

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "attribute_id",
                "attribute_name",
                "source",
                "cluster_id",
                "cluster_label",
            ],
            lineterminator="\n",
        )
        writer.writeheader()
        for row, cluster_id in zip(rows, cluster_ids):
            writer.writerow(
                {
                    "attribute_id": row.attribute_id,
                    "attribute_name": row.name,
                    "source": row.source,
                    "cluster_id": int(cluster_id),
                    "cluster_label": label_by_cluster[int(cluster_id)],
                }
            )

    summary = {
        "source_doi": SOURCE_DOI,
        "cluster_method": "bhatia_hierarchical_ward_reddit_option_profiles",
        "matrix_csv": str(args.matrix_csv),
        "matrix_sha256": matrix_hash,
        "option_profile_rows": int(x.shape[0]),
        "attribute_count": EXPECTED_ATTRIBUTE_COUNT,
        "threshold": args.threshold,
        "cluster_count": len(unique_clusters),
        "cluster_counts": {str(key): counts[key] for key in unique_clusters},
        "cluster_labels": {str(key): label_by_cluster[key] for key in unique_clusters},
    }
    args.summary.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


def block_values(row: dict[str, str], block_name: str) -> np.ndarray:
    return np.fromiter(
        (float(row[f"{block_name}{attribute_id}"]) for attribute_id in range(1, EXPECTED_ATTRIBUTE_COUNT + 1)),
        dtype=np.float32,
        count=EXPECTED_ATTRIBUTE_COUNT,
    )


def count_csv_data_rows(path: Path) -> int:
    with path.open(newline="", encoding="utf-8") as handle:
        return max(0, sum(1 for _ in handle) - 1)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    args = parse_args()
    if args.command == "benchmark":
        run_benchmark(args)
    elif args.command == "build-matrix":
        run_build_matrix(args)
    elif args.command == "cluster":
        run_cluster(args)
    else:
        raise ValueError(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()
