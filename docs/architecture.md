# Архитектура Dilemma

Проект строится как локальный iOS-дневник решений без backend. Архитектура
должна поддерживать плавный roadmap по слайсам: сначала production assets и
analysis engine, затем storage, UI, feedback, statistics и privacy controls.

Главная идея: `DecisionModels` фиксирует общий app/storage-facing контракт,
`DecisionUseCases` оркестрирует workflows, `DecisionKernel` локально считает
analysis, а долговременное хранение пользовательских данных остаётся отдельной
зоной ответственности.

## Базовые Решения

- `DecisionKernel` — локальное аналитическое ядро.
- Для MVP `DecisionKernel` остаётся одним Tuist target с внутренними папками.
- `DiaryVault` — отдельный приватный storage layer.
- `DecisionUseCases` — физический Tuist target между UI, kernel и vault.
- `DecisionModels` — физический Tuist target с canonical commands, diary
  records, analysis snapshots, feedback, statistics и export DTO.
- UI features работают через use cases и `DecisionModels`, а не напрямую через
  kernel/database/storage models.
- UI state держится в feature-level Observation models, без глобального
  `ObservableObject`/`EnvironmentObject` фасада.
- Документ фиксирует направление, а не финальную реализацию всех feature
  boundaries.

## Граф

```text
DilemmaApp
  -> AppComposition
      -> Feature modules
      -> DecisionModels
      -> DecisionUseCases
      -> DesignSystem

DecisionUseCases
  -> DecisionModels
  -> DecisionKernel
  -> DiaryVault

DiaryVault
  -> DecisionModels

DecisionKernel
  -> local assets
  -> local embedding runtime
```

## Модули

| Модуль | Роль |
| --- | --- |
| `DilemmaApp` | App target, lifecycle, root view. |
| `AppComposition` | Composition root и сборка зависимостей. |
| `EntryCreationFeature` | Flow создания dilemma. |
| `AnalysisDetailFeature` | Просмотр analysis и feedback. |
| `DiaryFeature` | Список и просмотр сохранённых entries. |
| `DecisionModels` | Canonical app/storage-facing commands, diary models, feedback, statistics, export. |
| `DecisionUseCases` | Application layer orchestration между app, kernel и vault. |
| `DecisionKernel` | Локальный analysis engine. |
| `DiaryVault` | Приватное долговременное хранилище entries, analyses и feedback. |
| `DesignSystem` | Общие UI primitives без business logic. |

## Model Boundary

`DecisionModels` зависит только от `Foundation` и не импортирует
`DecisionKernel`, `DiaryVault`, `SwiftUI` или `Observation`.

Публичный контракт target:

- commands: `EntryDraftCommand`, `FeedbackCommand`;
- diary graph: `DiaryEntry`, `DiaryOption`, `DiaryReason`;
- analysis data: `DiaryAnalysis`, `AttributeConflict`, `ClusterProfile`;
- aggregate data: `DiarySnapshot`, `PreferenceStatistics`, `ClusterFrequency`,
  `DiaryExport`.

`DiaryVault` хранит и возвращает эти canonical models напрямую. Отдельных
`Stored*` storage records и отдельных UI snapshot types больше нет.

## Application Layer

`DecisionUseCases` — app-facing target для business workflows. App target
импортирует `DecisionUseCases` и `DecisionModels`, но не импортирует
`DecisionKernel` или `DiaryVault` напрямую.

Слой отвечает за:

- use cases: prepare/unlock diary, create analyzed entry, load diary snapshot,
  save feedback, load statistics, export data, delete data.
- private mapping: `EntryDraftCommand` -> kernel `DecisionDraft`,
  `EntryDraftCommand` -> `DiaryEntry`, kernel `DecisionAnalysisResult` ->
  `DiaryAnalysis`, `FeedbackCommand` -> `Feedback`.

UI получает models из `DecisionModels`, а kernel/storage implementation details
остаются внутри `DecisionUseCases` и `DiaryVault`.

## UI State And Observation

App composition создаёт live use cases и long-lived feature models:

```text
AppDependencies
  -> DecisionUseCases.live()
  -> DiaryListModel
  -> StatisticsModel
  -> PrivacySettingsModel
```

Feature models объявлены как `@MainActor @Observable` и держат локальные
loading/error состояния. SwiftUI root владеет долгоживущими моделями через
`@State`, child views получают models через init parameters, а mutable form
bindings используют `@Bindable`.

Cross-feature refresh выполняется closures из composition root. Общего
`DilemmaAppModel` больше нет.

## DecisionKernel

На ближайшие слайсы kernel — один Tuist target:

```text
DecisionKernel/
  Sources/
    Schema/
    Core/
    Runtime/
    Assets/
    Pipeline/
  Resources/
    Attributes/
    Models/
```

Внутренние зоны:

| Зона | Роль |
| --- | --- |
| `Schema` | Domain value types: draft, options, reasons, scores, analysis metadata. |
| `Core` | Чистая математика analysis без UI/storage/runtime details. |
| `Runtime` | Локальная embedding-модель; единственное место для `swift-embeddings`. |
| `Assets` | Read-only reference attribute assets; production format уточняется в Slice 2. |
| `Pipeline` | Оркестрация от structured input до `DecisionAnalysis`. |

```text
DecisionDraft
  -> validate input
  -> embed reasons
  -> map reasons to attributes
  -> row-center scores
  -> build option profiles
  -> aggregate clusters
  -> extract conflicts
  -> DecisionAnalysis
```

## Privacy Islands

Это правило границ, а не отдельная технология:

```text
Assets read public bundled data.
Runtime/Pipeline may temporarily process user input.
Vault is the only place that persists private user data.
Export/Delete flows are the only exits for private user data.
```

```text
Kernel computes.
Vault remembers.
Privacy controls export/delete.
Features express user intent.
```

Практический смысл:

- kernel не зависит от vault;
- UI не пишет private data на диск напрямую;
- runtime/core не логируют raw dilemma text, reasons или feedback notes.
- feature models не импортируют storage/kernel targets напрямую.

## Что Не Фиксируем Сейчас

- финальную DB schema;
- точный набор feature targets;
- export format;
- конкретную навигационную структуру SwiftUI.

## Когда Делить DecisionKernel

Разделение kernel на несколько targets откладывается до реального давления:

- `Core/` загрязняется runtime/storage imports;
- тестам нужен analysis core без model/runtime dependencies;
- сборка становится заметно медленной;
- появляется reuse ядра отдельно от iOS app.
