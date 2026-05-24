# Slice 1 Report: Reference-Study Embedding Runtime для iOS

Дата: 2026-05-20  
Проект: `dilemma`  
Branch: `slice-1/bhatia-embedding-runtime`

## Stop Decision

Рекомендация для Slice 2: **`swift-embeddings + sentence-transformers/all-MiniLM-L12-v2`**.

Почему:
- `swift-embeddings` успешно грузит bundled model folder из app bundle через `Bert.loadModelBundle(from:)`, без `hubRepoId` и без runtime-сети.
- L6 и L12 обе проходят performance targets на iOS 18.2 simulator.
- L12 дает более устойчивые top matches на obvious examples: `money` top-1, `career` top-1, relationship/family/independence/security попадают ожидаемо.
- L6 остается fallback, если размер app bundle станет главным ограничением.
- Core ML conversion пока **не нужен как основной путь**, но остается fallback, если real-device validation покажет проблемы с памятью, загрузкой или latency.
- Debug screen `Run Analysis` теперь запускает L12 path по умолчанию; L6 покрыт integration test как fallback.

## Что Воспроизведено Из Reference Pipeline

- `attributes.csv` читается offline как `cp1252`.
- Проверяется структура: `414 rows`, `207 unique attribute names`, `207 pro`, `207 con`.
- `Sentences` разбиваются совместимо с notebook: `replace(".", "").split("; ")`.
- Каждое sentence embedding считается выбранной SentenceTransformers-моделью.
- Sentence vectors усредняются в один vector для `attribute + direction`.
- Attribute vectors L2-normalized и сохраняются в deterministic assets:
  - `attributes_l6.json` + `attribute_embeddings_l6.f16`
  - `attributes_l12.json` + `attribute_embeddings_l12.f16`
  - mpnet reference только для offline comparison в `reports/reference_assets/`
- Benefit reasons сравниваются только с `pro`, cost reasons только с `con`.
- Cosine similarity считается как dot product normalized vectors.
- Reason scores row-centered перед aggregation.
- Option profile считается как `benefits_mean - costs_mean`.
- Conflict output формулируется как “предполагаемый attribute conflict”, без рекомендации выбора.

## Изменения Из-За iOS Constraints

- `output - attributesdict.pkl` не используется в app runtime.
- Все app vectors пересчитаны под конкретную runtime model.
- Runtime model грузится только из bundled folder `Models/<model>` в `DecisionKernel` resource bundle.
- Не используется `ModelBundle.encode`, потому что текущий BERT wrapper возвращает CLS vector; в app реализован masked mean pooling + normalization для SentenceTransformers parity.
- Attribute vectors хранятся как Float16 row-major binary, а в runtime разворачиваются в Float и score считаются через Accelerate/vDSP.
- Cluster output не реализован: готовый `attribute -> cluster` mapping в workspace не подключен.

## Bundled Model Files

Для `swift-embeddings` model folder содержит:
- `config.json`
- `model.safetensors`
- `tokenizer.json`
- `tokenizer_config.json`
- `vocab.txt`
- `special_tokens_map.json`

Runtime path: `DecisionKernel` resource bundle, `Models/<model-name>/...`.
Download/generation scripts остаются offline tooling и не вызываются из app.

## Simulator Measurements

Среда: iOS 18.2 simulator, `iPhone 16`, Xcode 26.0.1, Debug test run.

| Model | Runtime status | Model weights | Dim | Load time | 12-reason embedding | 12 x 414 scoring | Approx memory |
|---|---:|---:|---:|---:|---:|---:|---:|
| all-MiniLM-L6-v2 | bundled app OK | 87 MB | 384 | 468 ms isolated / 308 ms warm | 83 ms isolated / 73 ms warm | 12 ms | 67-105 MB |
| all-MiniLM-L12-v2 | bundled app OK | 127 MB | 384 | 520 ms | 144 ms | 12 ms | 126 MB |
| all-mpnet-base-v2 | offline reference only | 418 MB | 768 | not tested in iOS | not tested in iOS | not tested in iOS | not tested in iOS |

Notes:
- Первичная Swift scoring реализация была 186-206 ms в Debug simulator. После плоского vector store и Accelerate/vDSP dot product scoring стал ~12 ms.
- Real iPhone не был доступен из текущего окружения; это обязательная проверка перед Slice 2.

## Quality Notes

L6:
- `money` попадает top-2, но top-1 был `having freedom of choice`.
- `career`, `mental health`, `relationship`, `family`, `independence`, `reputation`, `pleasure`, `security` дают приемлемые top-5.
- `time and work` слабее: top matches уходят в consumption/perception attributes, не в exact `complexity and effort`.

L12:
- `money` top-1.
- `career`, `mental health`, relationship/family/autonomy/reputation/pleasure/security выглядят устойчиво.
- `time and work` лучше L6 по смыслу (`agency perception`, `grit perception`, `ability perception`), но exact `complexity and effort` не попал в top-5.

mpnet reference:
- Лучше сохраняет research parity на части obvious examples, например `complexity and effort` для time/work.
- Слишком тяжелый для текущего app runtime spike без отдельной Core ML / optimized encoder проверки.

## Verification

Passed:
- `tuist generate --no-open`
- `.venv/bin/pytest tools/test_attribute_assets.py` -> `4 passed`
- `xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'` -> `5 Swift Testing tests passed`
- `xcrun simctl install` + `xcrun simctl launch ... com.local.dilemma` -> app launched on iPhone 16 simulator

Test coverage:
- Python asset tests: CSV shape, direction counts, deterministic metadata, vector dimension, normalized nonzero vectors.
- Python quality smoke: fixed 12 reasons against L6/L12/mpnet assets.
- Swift tests: Float16 loader, dot scoring, benefit/pro and cost/con filtering, row-centering, profile aggregation.
- Swift integration: bundled L6 and L12 model loading, masked mean pooling, scoring, conflict dimensions, metrics printout.

## Blockers Перед Slice 2

- Прогнать L12 на real iPhone в Airplane Mode.
- Решить app size budget: L12 лучше quality, L6 легче на 40 MB.
- Зафиксировать expected attribute smoke suite: сейчас quality notes ручные и минимальные.
- Если нужен cluster output, подготовить deterministic `attribute -> cluster` asset.
- Если real device покажет проблемы с `swift-embeddings`, запустить Core ML conversion prototype как fallback.
