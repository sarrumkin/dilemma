import SwiftUI

struct AppRootView: View {
  @StateObject private var model = DilemmaAppModel()

  var body: some View {
    DiaryListView()
      .environmentObject(model)
      .task {
        model.prepare()
      }
  }
}
