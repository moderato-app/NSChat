import SwiftData
import SwiftUI

struct ChatOptionView: View {
  @Bindable private var chatOption: ChatOption

  @Query private var allModels: [ModelEntity]

  init(_ chatOption: ChatOption) {
    self.chatOption = chatOption
  }

  private var selectedModel: ModelEntity? {
    allModels.first { $0.id == chatOption.model?.id }
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
          if let model = selectedModel {
            VStack(alignment: .trailing, spacing: 2) {
              Text(model.resolvedName)
                .foregroundColor(.secondary)
              Text(model.provider.displayName)
                .font(.caption2)
                .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
          } else {
            Text(chatOption.model?.resolvedName ?? "")
              .foregroundColor(.secondary)
          }
        }
      }

      VStack(alignment: .leading) {
        Label("Context Length", systemImage: "square.3.layers.3d.down.left")
        Picker("Context Length", selection: $chatOption.contextLength) {
          ForEach(contextLengthChoices, id: \.self) { c in
            Text("\(c.lengthString)")
              .tag(c.length)
          }
        }
        .pickerStyle(.segmented)
        .selectionFeedback(chatOption.contextLength)
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
