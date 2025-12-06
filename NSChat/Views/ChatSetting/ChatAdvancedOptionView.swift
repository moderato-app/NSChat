import SwiftData
import SwiftUI

struct ChatAdvancedOptionView: View {
  @Bindable private var chatOption: ChatOption

  init(_ chatOption: ChatOption) {
    self.chatOption = chatOption
  }

  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    Group {
      WheelPickerView(name: "Temperature",value: $chatOption.temperature,
                      start: 0, end: 2, defaultValue: 1,  systemImage: "t.square")
      WheelPickerView(name: "Presence Penalty",value: $chatOption.presencePenalty,
                      start: -2, end: 2, defaultValue: 0,  systemImage: "p.square",spacing: 6)
      WheelPickerView(name: "Frequency Penalty",value: $chatOption.frequencyPenalty,
                      start: -2, end: 2, defaultValue: 0,  systemImage: "f.square" ,spacing: 6)
    }
  }
}

#Preview {
  ModelContainerPreview(ModelContainer.preview) {
    Form {
      ChatAdvancedOptionView(ChatSample.manyMessages.option)
    }
  }
}
