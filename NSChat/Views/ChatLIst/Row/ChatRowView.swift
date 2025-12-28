import os
import SwiftData
import SwiftUI

struct ChatRowView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.editMode) private var editMode
  @EnvironmentObject var em: EM

  @State private var message: Message?

  var chat: Chat

  func loadLatestMsg() {
    let chatId = chat.persistentModelID
    let predicate = #Predicate<Message> { msg in
      msg.chat?.persistentModelID == chatId
    }
    let fetcher = FetchDescriptor<Message>(predicate: predicate, sortBy: [SortDescriptor(\Message.createdAt, order: .reverse)], fetchLimit: 1)
    do {
      message = try modelContext.fetch(fetcher).first
    } catch {
      AppLogger.data.error("message = try modelContext.fetch(fetcher).first :\(error.localizedDescription)")
    }
  }

  var body: some View {
    // let _ = Self.printChagesWhenDebug()

    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline) {
        Text(chat.name)
          .fontWeight(.semibold)
          .lineLimit(1)
        Spacer()
        Text(formatAgo(from: message?.updatedAt ?? chat.updatedAt))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        if editMode?.wrappedValue.isEditing ?? false {
        } else {
          Image(systemName: "chevron.forward")
            .foregroundStyle(.tertiary)
            .fontWeight(.semibold)
            .imageScale(.small)
        }
      }
      Group {
        if chat.input.isMeaningful {
          Text(Image(systemName: "pencil.and.outline")).foregroundStyle(.primary) + Text(" " + chat.input.meaningfulString)
        } else {
          if let message {
            let sender = message.role == .user ? "You: " : ""
            Text(sender + message.message + String(repeating: " ", count: 50))
          } else {
            Text(String(repeating: " ", count: 50))
          }
        }
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .lineLimit(2)
    }
    .fixedSize(horizontal: false, vertical: true)
    .onAppear {
      loadLatestMsg()
    }
    .onReceive(em.messageCountChange) { id in
      if id == chat.persistentModelID {
        loadLatestMsg()
      }
    }
  }
}

#Preview {
  ModelContainerPreview(ModelContainer.preview) {
    NavigationStack {
      List {
        ChatRowView(chat: ChatSample.manyMessages)
        ChatRowView(chat: ChatSample.emptyMessage)
      }
    }
  }
}
