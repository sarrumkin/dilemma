import SwiftUI

struct AppRootView: View {
  @State private var dependencies: AppDependencies
  @State private var diaryModel: DiaryListModel
  @State private var statisticsModel: StatisticsModel
  @State private var privacyModel: PrivacySettingsModel

  init(dependencies: AppDependencies = .live()) {
    self._dependencies = State(initialValue: dependencies)
    self._diaryModel = State(initialValue: dependencies.makeDiaryListModel())
    self._statisticsModel = State(initialValue: dependencies.makeStatisticsModel())
    self._privacyModel = State(initialValue: dependencies.makePrivacySettingsModel())
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
        makeAnalysisDetailModel: { entry, analysis in
          AnalysisDetailModel(
            entry: entry,
            analysis: analysis,
            saveFeedback: dependencies.useCases.saveFeedback,
            onFeedbackSaved: {
              statisticsModel.reload()
            }
          )
        }
      )
        .tabItem {
          Label("Diary", systemImage: "list.bullet")
        }

      StatisticsView(model: statisticsModel)
        .tabItem {
          Label("Stats", systemImage: "chart.bar")
        }

      SettingsView(
        model: privacyModel,
        onDeleted: {
          diaryModel.reload()
          statisticsModel.reload()
        }
      )
        .tabItem {
          Label("Privacy", systemImage: "lock.shield")
        }
    }
    .task {
      if await privacyModel.unlockIfNeededAndPrepare() {
        diaryModel.reload()
        statisticsModel.reload()
      } else {
        diaryModel.errorMessage = privacyModel.errorMessage
      }
    }
  }
}
