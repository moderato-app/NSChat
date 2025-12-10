import SwiftUI

struct EmptyChatCard: View {
  let onNewChat: () -> Void
  
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "message")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("No Chats")
        .font(.headline)

      Text("Create a chat to get started")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button {
        onNewChat()
      } label: {
        HStack {
          Image(systemName: "plus.circle.fill")
            .backgroundStyle(.foreground)
          Text("New Chat")
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .padding(.horizontal, 20)
  }
}

