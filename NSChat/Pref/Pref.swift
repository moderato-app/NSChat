import SwiftData
import SwiftUI

class Pref: ObservableObject {
  static var shared = Pref()

  @AppStorage("haptics") var haptics: Bool = true
  @AppStorage("doubleTapAction") var doubleTapAction: DoubleTapAction = .reuse
  @AppStorage("trippleTapAction") var trippleTapAction: DoubleTapAction = .showInfo
  @AppStorage("magicScrolling") var magicScrolling: Bool = true

  @AppStorage("colorScheme") var colorScheme: AppColorScheme = .system

  // ChatGPT
  @AppStorage("gptApiKey") var gptApiKey: String = ""
  @AppStorage("gptUseProxy") var gptEnableEndpoint: Bool = false
  @AppStorage("gptEndpoint") var gptEndpoint: String = "https://api.openai.com"

  // Pref for new chat
  @AppStorage("newChatPref-historyMessageCount") var newChatPrefHistoryMessageCount: Int = 4
  @AppStorage("newChatPref-webSearchContextSize") var newChatPrefWebSearchContextSize: WebSearchContextSize = .low

  // Fill data record
  @AppStorage("fillDataRecordPrompts") var fillDataRecordPrompts: Bool = false

  func reset() {
    let newPref = Pref()
    self.haptics = newPref.haptics
    self.doubleTapAction = newPref.doubleTapAction
    self.magicScrolling = newPref.magicScrolling
    self.colorScheme = newPref.colorScheme
    self.fillDataRecordPrompts = newPref.fillDataRecordPrompts
    self.newChatPrefHistoryMessageCount = newPref.newChatPrefHistoryMessageCount
    self.newChatPrefWebSearchContextSize = newPref.newChatPrefWebSearchContextSize
  }
}

enum DoubleTapAction: String, CaseIterable, Codable {
  case none = "None", reuse = "Reuse Text", copy = "Copy Text", showInfo = "Info"
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
