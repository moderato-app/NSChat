import SwiftUI

fileprivate let email = "support@moderato.app"

extension SettingView {
  @ViewBuilder
  var supportSection: some View {
    Section(
      header: Text("Support"),
      footer: Text(verbatim: email)
        .textSelection(.enabled)
    ) {
      Button {
        showLogExportSheet = true
      } label: {
        Label {
          Text("Contact Support")
            .tint(.primary)
        } icon: {
          Image(systemName: "envelope")
        }
      }
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        Button {
          withAnimation {
            showViewLogs.toggle()
          }
        } label: {
          VStack {
            Image(systemName: showViewLogs ? "ladybug.slash" : "ladybug")
            Text(showViewLogs ? "Hide" : "Show")
          }
        }
        .tint(.indigo)
      }
      .sheet(isPresented: $showLogExportSheet) {
        LogExportSheet()
      }

      if showViewLogs {
        NavigationLink {
          LogView()
        } label: {
          Label {
            Text("View Logs")
              .tint(.primary)
          } icon: {
            Image(systemName: "doc.text")
          }
        }
      }
    }
    .textCase(.none)
  }
}
