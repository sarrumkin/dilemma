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
    .preferredColorScheme(settingsModel.usesDarkTheme ? .dark : .light)
    .task {
      if await settingsModel.unlockIfNeededAndPrepare() {
        diaryModel.reload()
        statisticsModel.reload()
      } else {
        diaryModel.errorMessage = settingsModel.errorMessage
      }
    }
  }
}
