import SwiftUI

private let privacyHTTPS = "https://nschat.moderato.app/privacy"
private let termsHTTPS = "https://nschat.moderato.app/terms"
private let testFlightHTTPS = "https://testflight.apple.com/join/axaO3S26"
private let appHTTPS = "https://apps.apple.com/app/id6478404197"
private let githubHTTPS = "https://github.com/moderato-app/NSChat"

extension SettingView {
  @ViewBuilder
  var aboutSection: some View {
    Section(
      header: Text("About")
        .foregroundStyle(.primary),
      footer: Text("Copyright © Moderato, LTD")
    ) {
      Button {
        safariAddr = privacyHTTPS
      } label: {
        Label {
          Text("Privacy Policy")
            .tint(.primary)
        } icon: {
          Image(systemName: "lock.circle")
        }
      }

      Button {
        safariAddr = termsHTTPS
      } label: {
        Label {
          Text("Terms & Conditions")
            .tint(.primary)
        } icon: {
          Image(systemName: "book.pages")
        }
      }

      Button {
        safariAddr = testFlightHTTPS
      } label: {
        Label {
          Text("Join TestFlight")
            .tint(.primary)
        } icon: {
          Image(systemName: "fan")
        }
      }
      .sheet(item: $safariAddr) {
        SafariView(url: URL(string: $0)!)
          .presentationDetents([.large])
      }

      VersionView()

      Button {
        safariAddr = appHTTPS
      } label: {
        Label {
          Text("View on App Store")
            .tint(.primary)
        } icon: {
          Image(systemName: "apple.logo")
        }
      }

      Button {
        safariAddr = githubHTTPS
      } label: {
        Label {
          Text("View on GitHub")
            .tint(.primary)
        } icon: {
          Image(systemName: "cat.circle.fill")
        }
      }
    }
    .textCase(.none)
  }
}
