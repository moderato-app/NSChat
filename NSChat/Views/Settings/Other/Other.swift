import SwiftUI

let privacyHTTPS = "https://nschat.moderato.app/privacy"
let termsHTTPS = "https://nschat.moderato.app/terms"
let testFlightHTTPS = "https://testflight.apple.com/join/axaO3S26"
let appHTTPS = "https://apps.apple.com/us/app/chato/id6478404197"

struct OtherViewGroup: View {
  @Environment(\.openURL) private var openURL
  let email = "support@moderato.app"
  @State var safariAddr: String? = nil

  var body: some View {
    Group {
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
        
        ShareLink(item: URL(string: appHTTPS)!) {
          Label {
            Text("Share App")
            .tint(.primary)
          } icon: {
            Image(systemName: "heart")
              .foregroundStyle(.pink)
          }
        }

        Button {
          safariAddr = appHTTPS
        } label: {
          Label {
            Text("Show in App Store")
              .tint(.primary)
          } icon: {
            Image(systemName: "apple.logo")
          }
        }

      }
      .textCase(.none)
      
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
      }.textCase(.none)
    }
  }
}

#Preview {
  Form{
    OtherViewGroup()
  }
}
