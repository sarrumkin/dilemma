#!/usr/bin/env python3
"""Download the minimal Hugging Face model files expected by swift-embeddings."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from huggingface_hub import snapshot_download

MODELS = {
    "all-MiniLM-L6-v2": "sentence-transformers/all-MiniLM-L6-v2",
    "all-MiniLM-L12-v2": "sentence-transformers/all-MiniLM-L12-v2",
    "paraphrase-multilingual-MiniLM-L12-v2": "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
}

TOKENIZER_CLASS_OVERRIDES = {
    # The HF config advertises PreTrainedTokenizerFast, but tokenizer.json is
    # Unigram. swift-transformers needs the concrete supported tokenizer class.
    "paraphrase-multilingual-MiniLM-L12-v2": "XLMRobertaTokenizer",
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
    parser.add_argument("--output-root", type=Path, default=Path("DecisionKernel/Resources/Models"))
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

    if args.model in TOKENIZER_CLASS_OVERRIDES:
        tokenizer_config_path = target / "tokenizer_config.json"
        tokenizer_config = json.loads(tokenizer_config_path.read_text(encoding="utf-8"))
        tokenizer_config["tokenizer_class"] = TOKENIZER_CLASS_OVERRIDES[args.model]
        tokenizer_config_path.write_text(
            json.dumps(tokenizer_config, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )

    print(f"Prepared {model_id} at {target}")


if __name__ == "__main__":
    main()
