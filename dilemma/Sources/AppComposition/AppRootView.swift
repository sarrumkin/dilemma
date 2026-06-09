import DecisionModels
import DecisionUseCases
import SwiftUI

struct AppRootView: View {
  @State private var dependencies: AppDependencies
  @State private var diaryModel: DiaryListModel
  @State private var statisticsModel: StatisticsModel
  @State private var settingsModel: SettingsModel

  init(dependencies: AppDependencies = .live()) {
    self._dependencies = State(initialValue: dependencies)
    self._diaryModel = State(initialValue: dependencies.makeDiaryListModel())
    self._statisticsModel = State(initialValue: dependencies.makeStatisticsModel())
    self._settingsModel = State(initialValue: dependencies.makeSettingsModel())
  }

  var body: some View {
    TabView {
      DiaryListView(
        model: diaryModel,
        makeNewEntryModel: {
          dependencies.makeNewEntryModel { snapshot in
            diaryModel.apply(snapshot)
            statisticsModel.reload()
          }
        },
        makeJSONImportModel: {
          dependencies.makeDilemmaJSONImportModel { result in
            diaryModel.apply(result.snapshot)
            statisticsModel.reload()
          }
        },
        onDeleted: {
          statisticsModel.reload()
        },
        makeAnalysisDetailModel: { entry, analysis in
          makeAnalysisDetailModel(entry: entry, analysis: analysis)
        }
      )
        .tabItem {
          Label("Diary", systemImage: "list.bullet")
        }

      StatisticsView(
        model: statisticsModel,
        makeAnalysisDetailModel: { entry, analysis in
          makeAnalysisDetailModel(entry: entry, analysis: analysis)
        }
      )
        .tabItem {
          Label("Stats", systemImage: "chart.pie")
        }

      SettingsView(
        model: settingsModel,
        onDeleted: {
          diaryModel.reload()
          statisticsModel.reload()
        }
      )
        .tabItem {
          Label("Settings", systemImage: "gearshape")
      }
    }
    .environment(\.locale, settingsModel.appLanguage.locale)
    .preferredColorScheme(settingsModel.usesDarkTheme ? .dark : .light)
    .overlay(alignment: .bottom) {
      if let progress = settingsModel.analysisMigrationProgress {
        AnalysisMigrationProgressBanner(progress: progress)
          .padding(.horizontal, 16)
          .padding(.bottom, 12)
      }
    }
    .task {
      if settingsModel.prepareDiaryForUse() {
        diaryModel.reload()
        statisticsModel.reload()
        if let result = await settingsModel.reanalyzeIncompleteAnalysesForUse(),
           result.updatedCount > 0 {
          diaryModel.apply(result.snapshot)
          statisticsModel.reload()
        }
      } else {
        diaryModel.errorMessage = settingsModel.errorMessage
      }
    }
  }

  private func makeAnalysisDetailModel(
    entry: DiaryEntry,
    analysis: DecisionAnalysis?
  ) -> AnalysisDetailModel {
    AnalysisDetailModel(
      entry: entry,
      analysis: analysis,
      allEntries: diaryModel.entries,
      latestAnalyses: diaryModel.latestAnalyses,
      saveFeedback: dependencies.useCases.saveFeedback,
      loadFeedbackForAnalysis: dependencies.useCases.loadFeedbackForAnalysis,
      loadLikelyChoiceAdvice: dependencies.useCases.loadLikelyChoiceAdvice,
      exportDilemmaDraft: dependencies.useCases.exportDilemmaDraft,
      onFeedbackSaved: {
        statisticsModel.reload()
      }
    )
  }
}

private struct AnalysisMigrationProgressBanner: View {
  let progress: ReanalyzeIncompleteAnalysesProgress

  private var percentText: String {
    "\(Int(progress.fractionCompleted * 100))%"
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "arrow.triangle.2.circlepath")
        .font(.title3)
        .foregroundStyle(.tint)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text("Migrating saved analyses")
            .font(.subheadline.weight(.semibold))
          Spacer(minLength: 12)
          Text(percentText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }

        ProgressView(value: progress.fractionCompleted, total: 1)
          .progressViewStyle(.linear)
          .accessibilityIdentifier("analysis-migration-progress-loader")

        Text(progressText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
          .accessibilityIdentifier("analysis-migration-progress-count")
      }
    }
    .padding(14)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    .shadow(radius: 10, y: 4)
  }

  private var progressText: String {
    let base = "\(progress.completedCount) of \(progress.totalCount) analyses, \(progress.remainingCount) remaining"
    guard progress.failedCount > 0 else { return base }
    return "\(base), \(progress.failedCount) failed"
  }
}
