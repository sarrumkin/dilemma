# Архитектура Dilemma

Проект строится как локальный iOS-дневник решений без backend. Архитектура
должна поддерживать плавный roadmap по слайсам: сначала production assets и
analysis engine, затем storage, UI, feedback, statistics и privacy controls.

Главная идея: `DecisionKernel` локально считает analysis, а долговременное
хранение пользовательских данных остаётся отдельной зоной ответственности.

## Базовые Решения

- `DecisionKernel` — локальное аналитическое ядро.
- Для MVP `DecisionKernel` остаётся одним Tuist target с внутренними папками.
- `DiaryVault` появляется позже как отдельный приватный storage layer.
- UI features работают через use cases, а не напрямую через kernel/database.
- Документ фиксирует направление, а не финальную реализацию всех targets.

## Граф

```text
DilemmaApp
  -> AppComposition
      -> Feature modules
      -> DecisionUseCases
      -> DesignSystem

DecisionUseCases
  -> DecisionKernel
  -> DiaryVault

DecisionKernel
  -> local assets
  -> local embedding runtime

DiaryVault
  -> local private storage
```

## Модули

| Модуль | Роль |
| --- | --- |
| `DilemmaApp` | App target, lifecycle, root view. |
| `AppComposition` | Composition root и сборка зависимостей. |
| `EntryCreationFeature` | Flow создания dilemma. |
| `AnalysisDetailFeature` | Просмотр analysis и feedback. |
| `DiaryFeature` | Список и просмотр сохранённых entries. |
| `DecisionUseCases` | Application layer между UI, kernel и vault. |
| `DecisionKernel` | Локальный analysis engine. |
| `DiaryVault` | Приватное долговременное хранилище, начиная с Slice 4. |
| `DesignSystem` | Общие UI primitives без business logic. |

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
