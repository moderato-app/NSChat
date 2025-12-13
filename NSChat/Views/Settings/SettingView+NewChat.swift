import SwiftUI

extension SettingView {
  @ViewBuilder
  var newChatPreferenceSection: some View {
    Section {
      HStack {
        Label("Generate Title", systemImage: "text.line.2.summary")
          .modifier(RippleEffect(at: .zero, trigger: pref.autoGenerateTitle))
        Toggle("", isOn: $pref.autoGenerateTitle)
      }
      .selectionFeedback(pref.autoGenerateTitle)

      HStack {
        Label("History Messages", systemImage: "clock")
        Spacer()
        Picker("History Messages", selection: $pref.newChatPrefHistoryMessageCount) {
          ForEach(historyCountChoices, id: \.self) { choice in
            Text(choice.lengthString)
              .tag(choice.length)
          }
        }
        .labelsHidden()
        .selectionFeedback(pref.newChatPrefHistoryMessageCount)
      }

      VStack(alignment: .leading) {
        HStack {
          Label("Web Search Context", systemImage: "square.3.layers.3d.down.left")
            .modifier(RippleEffect(at: .zero, trigger: pref.newChatPrefWebSearchEnabled))
          Toggle("", isOn: $pref.newChatPrefWebSearchEnabled)
        }
        .selectionFeedback(pref.newChatPrefWebSearchEnabled)

        Picker("Web Search Context", selection: $pref.newChatPrefWebSearchContextSize) {
          ForEach(WebSearchContextSize.allCases, id: \.self) { size in
            Text(size.title)
              .tag(size)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .selectionFeedback(pref.newChatPrefWebSearchContextSize)
        .disabled(!pref.newChatPrefWebSearchEnabled)
      }

    } header: {
      Text("New Chat")
    } footer: {
      Text("Default preferences for newly created chats.")
    }
    .textCase(.none)
  }
}
