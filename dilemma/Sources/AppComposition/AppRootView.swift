import SwiftUI

struct AppRootView: View {
  @StateObject private var model = DilemmaAppModel()

  var body: some View {
    TabView {
      DiaryListView()
        .tabItem {
          Label("Diary", systemImage: "list.bullet")
        }

      StatisticsView()
        .tabItem {
          Label("Stats", systemImage: "chart.bar")
        }
    }
    .environmentObject(model)
      .task {
        model.prepare()
      }
  }
}
