import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
    let s = SFSafariViewController(url: url)
    s.modalPresentationStyle = .pageSheet
    return s
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
    // Nothing to update here
  }
}

extension String: @retroactive Identifiable {
  public var id: String { self }
}

