import SwiftUI

struct BrowserLinkHandler: ViewModifier {
  @State private var safariURL: String?
  @State private var fullScreenURL: String?

  func body(content: Content) -> some View {
    content
      .sheet(item: $safariURL) { urlString in
        SafariView(url: URL(string: urlString)!)
          .presentationDetents([.large])
      }
      .fullScreenCover(item: $fullScreenURL) { urlString in
        SafariView(url: URL(string: urlString)!)
          .onDisappear {
            fullScreenURL = nil
          }
      }
      .environment(\.openURL, OpenURLAction { url in
        handleLinkClick(url: url)
      })
  }

  private func handleLinkClick(url: URL) -> OpenURLAction.Result {
    switch Pref.shared.linkOpenMode {
    case .inAppSheet:
      safariURL = url.absoluteString
      return .handled
    case .inAppFullScreen:
      fullScreenURL = url.absoluteString
      return .handled
    case .system:
      return .systemAction
    }
  }
}

extension View {
  func browserLinkHandler() -> some View {
    modifier(BrowserLinkHandler())
  }
}
