import SwiftData
import SwiftUI

class Pref: ObservableObject {
  static var shared = Pref()

  @AppStorage("haptics") var haptics: Bool = true
  @AppStorage("doubleTapAction") var doubleTapAction: DoubleTapAction = .reuse
  @AppStorage("trippleTapAction") var tripleTapAction: DoubleTapAction = .showInfo
  @AppStorage("magicScrolling") var magicScrolling: Bool = true
  @AppStorage("linkOpenMode") var linkOpenMode: LinkOpenMode = .inAppSheet

  @AppStorage("colorScheme") var colorScheme: AppColorScheme = .system

  // ChatGPT
  @AppStorage("gptApiKey") var gptApiKey: String = ""
  @AppStorage("gptUseProxy") var gptEnableEndpoint: Bool = false
  @AppStorage("gptEndpoint") var gptEndpoint: String = "https://api.openai.com"

  // Pref for new chat
  @AppStorage("newChatPref-historyMessageCount") var newChatPrefHistoryMessageCount: Int = 4
  @AppStorage("newChatPref-webSearchEnabled") var newChatPrefWebSearchEnabled: Bool = false
  @AppStorage("newChatPref-webSearchContextSize") var newChatPrefWebSearchContextSize: WebSearchContextSize = .low
  @AppStorage("autoGenerateTitle") var autoGenerateTitle: Bool = true

  // Fill data record
  @AppStorage("fillDataRecordPrompts") var fillDataRecordPrompts: Bool = false

  // Log policy
  @AppStorage("logPolicy") var logPolicy: Privacy = .private

  func reset() {
    let newPref = Pref()
    self.haptics = newPref.haptics
    self.doubleTapAction = newPref.doubleTapAction
    self.magicScrolling = newPref.magicScrolling
    self.linkOpenMode = newPref.linkOpenMode
    self.colorScheme = newPref.colorScheme
    self.fillDataRecordPrompts = newPref.fillDataRecordPrompts
    self.newChatPrefHistoryMessageCount = newPref.newChatPrefHistoryMessageCount
    self.newChatPrefWebSearchEnabled = newPref.newChatPrefWebSearchEnabled
    self.newChatPrefWebSearchContextSize = newPref.newChatPrefWebSearchContextSize
    self.autoGenerateTitle = newPref.autoGenerateTitle
    self.logPolicy = newPref.logPolicy
  }
}

enum DoubleTapAction: String, CaseIterable, Codable {
  case none = "None", reuse = "Reuse", copy = "Copy", showInfo = "Show Info"
}

enum LinkOpenMode: String, CaseIterable, Codable {
  case inAppSheet = "In-App Browser(Sheet)"
  case inAppFullScreen = "In-App Browser(Full Screen)"
  case system = "System Browser"
}

extension Pref {
  enum AppColorScheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
  }

  var computedColorScheme: ColorScheme? {
    switch self.colorScheme {
    case .light:
      return ColorScheme.light
    case .dark:
      return ColorScheme.dark
    case .system:
      return nil
    }
  }
}

private let privacyOrder: [Privacy] = [.private, .sensitive, .public]

/// Privacy level for log entries (compatible with OSLog privacy parameter)
public enum Privacy: String, CaseIterable, Codable, Comparable {
  case `private` = "Private"
  case sensitive = "Sensitive"
  case `public` = "Public"

  public static func < (lhs: Privacy, rhs: Privacy) -> Bool {
    guard let lhsIndex = privacyOrder.firstIndex(of: lhs),
          let rhsIndex = privacyOrder.firstIndex(of: rhs)
    else {
      return false
    }
    return lhsIndex < rhsIndex
  }

  var effectivePolicy: Self {
    if self < Pref.shared.logPolicy {
      return Pref.shared.logPolicy
    }
    return self
  }
}
