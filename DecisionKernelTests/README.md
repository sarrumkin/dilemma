# DecisionKernelTests

`DecisionKernelTests` проверяет локальный `DecisionKernel`: scoring, загрузку SQLite/vector assets,
интеграционный `DecisionAnalysisRunner` и эксперимент поиска похожих дилемм.

## Структура

- `Sources/Scoring` - быстрые unit-тесты для F16 loader, attribute scoring, option profiles и conflict vector.
- `Sources/Integration` - интеграционные проверки `DecisionAnalysisRunner` на bundled model/assets.
- `Sources/Experiments` - проверки similarity dataset, formatter-ов и постоянный runner эксперимента.
- `Sources/Support` - общие test fixtures для synthetic similarity dataset.
- `Resources/SimilarityExperiment/synthetic_dataset.json` - синтетический набор дилемм для эксперимента.
- `Resources/SimilarityExperiment/Runs` - результаты запусков similarity-эксперимента.

`Resources` подключена в Tuist как folder reference. После `tuist generate --no-open`
она отображается в Xcode как синяя папка, поэтому новые run-каталоги видны без ручного добавления файлов.

## Предусловия

Быстрые unit-тесты не требуют локальной модели. Интеграционные тесты и similarity experiment требуют:

- `DecisionKernel/Resources/Models/all-MiniLM-L12-v2`
- `DecisionKernel/Resources/Attributes/DilemmaAssets.sqlite`
- `DecisionKernel/Resources/Attributes/DilemmaAssetsKMeans.sqlite`

Если model assets отсутствуют, подготовь их локально через tooling из root `README.md`.

## Команды запуска

Полный suite проекта:

```bash
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
```

Только `DecisionKernelTests`:

```bash
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' -only-testing:DecisionKernelTests
```

Если bundled model/assets доступны, полный `DecisionKernelTests` также запустит `SimilarityExperimentRunTests`
и создаст новый каталог в `Resources/SimilarityExperiment/Runs`.

Быстрый kernel-прогон без записи нового отчета:

```bash
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' -only-testing:DecisionKernelTests/AttributeScoringTests -only-testing:DecisionKernelTests/SimilarityExperimentTests
```

Только integration suite:

```bash
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' -only-testing:DecisionKernelTests/DecisionAnalysisRunnerIntegrationTests
```

Только similarity experiment runner:

```bash
xcodebuild test -workspace dilemma.xcworkspace -scheme dilemma -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' -only-testing:DecisionKernelTests/SimilarityExperimentRunTests
```

## Similarity Experiment

Эксперимент сравнивает три способа поиска похожих дилемм:

- `Bhatia clusters` - conflict vector агрегируется по восстановленной Bhatia Ward-карте.
- `KMeans clusters` - тот же набор 207 Bhatia attributes агрегируется по альтернативной KMeans-карте.
- `Full-text embedding` - baseline, который сравнивает embedding полного canonical text без attribute clusters.

Каждый запуск runner создает новый каталог:

```text
DecisionKernelTests/Resources/SimilarityExperiment/Runs/<run_id>/
```

Внутри:

- `metadata.json` - run id, время запуска, model, asset names, counts, checksum dataset и duration.
- `similarity_experiment_run.md` - человекочитаемый отчет.
- `similarity_experiment_run.csv` - табличные результаты для анализа.

`run_id` строится как UTC timestamp и короткий UUID, поэтому отчеты не перезаписывают друг друга.
