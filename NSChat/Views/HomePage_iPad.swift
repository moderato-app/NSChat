import SwiftUI

struct HomePage_iPad: View {
  @State var searchString = ""
  @State private var navigationPath = NavigationPath()
  @State private var selectedChat: Chat?
  @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

  var body: some View {
//    //let _ = Self.printChagesWhenDebug()
    NavigationSplitView(columnVisibility: $columnVisibility) {
      // Sidebar - Chat List
      ChatListView_iPad(searchString, navigationPath: $navigationPath, selectedChat: $selectedChat)
        .searchable(text: $searchString)
        .animation(Animation.easeInOut, value: searchString)
        .navigationTitle("Chats")
        .transNavi()
    } detail: {
      // Detail View
      NavigationStack(path: $navigationPath) {
        if let chat = selectedChat {
          ChatDetailView(chat: chat)
            .id(chat.persistentModelID)
            .navigationDestination(for: Prompt.self) { PromptEditorView($0) }
            .navigationDestination(for: String.self) { str in
              switch str {
              case NavigationRoute.providerList:
                ProviderListView()
              case NavigationRoute.promptList:
                PromptListView()
              case NavigationRoute.newPrompt:
                PromptCreateView { _ in }
              case NavigationRoute.modelSelection:
                Text("Model Selection")
              default:
                Text("navigationDestination not found for string: \(str)")
              }
            }
        } else {
          // Empty state when no chat is selected
          ContentUnavailableView(
            "Select a Chat",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Choose a chat from the sidebar to start messaging")
          )
          .navigationDestination(for: Prompt.self) { PromptEditorView($0) }
          .navigationDestination(for: String.self) { str in
            switch str {
            case NavigationRoute.providerList:
              ProviderListView()
            case NavigationRoute.promptList:
              PromptListView()
            case NavigationRoute.newPrompt:
              PromptCreateView { _ in }
            case NavigationRoute.modelSelection:
              Text("Model Selection")
            default:
              Text("navigationDestination not found for string: \(str)")
            }
          }
        }
      }
    }
    .navigationSplitViewStyle(.balanced)
  }
}

#Preview {
  LovelyPreview {
    HomePage_iPad()
  }
}
