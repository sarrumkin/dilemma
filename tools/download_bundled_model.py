#!/usr/bin/env python3
"""Download the minimal Hugging Face model files expected by swift-embeddings."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from huggingface_hub import snapshot_download

MODELS = {
    "all-MiniLM-L6-v2": "sentence-transformers/all-MiniLM-L6-v2",
    "all-MiniLM-L12-v2": "sentence-transformers/all-MiniLM-L12-v2",
}

ALLOW_PATTERNS = [
    "config.json",
    "model.safetensors",
    "tokenizer.json",
    "tokenizer_config.json",
    "vocab.txt",
    "special_tokens_map.json",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", choices=sorted(MODELS), default="all-MiniLM-L6-v2")
    parser.add_argument("--output-root", type=Path, default=Path("dilemma/Resources/Models"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    model_id = MODELS[args.model]
    target = args.output_root / args.model
    cache_dir = Path(".hf_cache")

    downloaded = Path(
        snapshot_download(
            repo_id=model_id,
            cache_dir=cache_dir,
            allow_patterns=ALLOW_PATTERNS,
        )
    )

    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)

    for file_name in ALLOW_PATTERNS:
        source = downloaded / file_name
        if source.exists():
            shutil.copy2(source, target / file_name)

    print(f"Prepared {model_id} at {target}")


if __name__ == "__main__":
    main()
