import SwiftData
import SwiftUI

struct ChatOptionView: View {
  @Bindable private var chatOption: ChatOption

  init(_ chatOption: ChatOption) {
    self.chatOption = chatOption
  }

  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    Group {
      NavigationLink(value: NavigationRoute.promptList) {
        HStack {
          Label("Prompt", systemImage: "warninglight")
          if let name = chatOption.prompt?.name {
            Spacer()
            Text(name)
              .foregroundStyle(.secondary)
          }
        }
      }

      NavigationLink(value: NavigationRoute.modelSelection) {
        HStack {
          Label("Model", systemImage: "book")
          Spacer()
          if let model = chatOption.model {
            VStack(alignment: .trailing, spacing: 2) {
              Text(model.resolvedName)
                .foregroundColor(.secondary)
              Text(model.provider.displayName)
                .font(.caption2)
                .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
          }
        }
      }

      VStack(alignment: .leading) {
        Label("History Messages", systemImage: "square.3.layers.3d.down.left")
        Picker("History Messages", selection: $chatOption.historyCount) {
          ForEach(historyCountChoices, id: \.self) { c in
            Text("\(c.lengthString)")
              .tag(c.length)
          }
        }
        .pickerStyle(.segmented)
        .selectionFeedback(chatOption.historyCount)
      }
    }
  }
}

#Preview {
  ModelContainerPreview(ModelContainer.preview) {
    Form {
      ChatOptionView(ChatSample.manyMessages.option)
    }
  }
}
