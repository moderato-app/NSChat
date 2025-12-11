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
        let email = email
        if let emailURL = URL(string: "mailto:\(email)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
          openURL(emailURL)
        }
      } label: {
        Label {
          Text("Contact Us")
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
