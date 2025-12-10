import os
import SwiftData
import SwiftUI

struct ChatListView: View {
  private static let sortOrder = [SortDescriptor(\Chat.order, order: .reverse)]

  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject var em: EM
  @Query(sort: \Chat.createdAt) private var chats: [Chat]
  @Query private var providers: [Provider]

  @Binding var navigationPath: NavigationPath

  @State private var isSettingPresented = false
  @State private var isAddProviderPresented = false

  @State var isDeleteConfirmPresented: Bool = false
  @State var isMultiDeleteConfirmPresented: Bool = false
  @State var isClearMessageConfirmPresented: Bool = false
  @State var chatToClearMessages: Chat?
  @State var chatToDelete: Chat?

  @State var editMode: EditMode = .inactive

  init(_ searchString: String, navigationPath: Binding<NavigationPath>) {
    _chats = Query(
      filter: #Predicate {
        if searchString.isEmpty {
          return true
        } else {
          return $0.name.localizedStandardContains(searchString)
        }
      }, sort: Self.sortOrder
    )
    _navigationPath = navigationPath
  }

  var body: some View {
    list()
      .softFeedback(
        editMode.isEditing, isAddProviderPresented,
        isMultiDeleteConfirmPresented
      )
      .sheet(isPresented: $isSettingPresented) {
        SettingView()
          .preferredColorScheme(colorScheme)
          .presentationDetents([.large])
      }
      .sheet(isPresented: $isAddProviderPresented) {
        let provider = Provider(type: .openAI)
        ProviderView(provider: provider, mode: .Add)
      }
  }

  @State var selectedChatIDs = Set<PersistentIdentifier>()

  @ViewBuilder
  func list() -> some View {
    List(selection: $selectedChatIDs) {
      if providers.isEmpty {
        Section {
          emptyProviderCard()
        }
        .listSectionSeparator(.hidden)
      } else if chats.isEmpty {
        Section {
          emptyChatCard()
        }
        .listSectionSeparator(.hidden)
      }

      ForEach(chats, id: \.persistentModelID) { chat in
        ChatRowView(chat: chat)
          .listRowInsets(SwiftUICore.EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 10))
          .background(
            NavigationLink(value: chat) {}
              .opacity(0)
          )
          .contextMenu(menuItems: { menuItems(chat: chat) })
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Avoid using the `chat` variable in the confirm dialog. Swipe actions seem to re-calculate
            // the list, which might delete the wrong chat.
            // Don't use role = .destructive, or confirmation dialog animation becomes unstable https://stackoverflow.com/questions/71442998/swiftui-confirmationdialog-disappearing-after-one-second
            DeleteButton {
              chatToDelete = chat
              isDeleteConfirmPresented.toggle()
            }
          }
          .swipeActions(edge: .leading, allowsFullSwipe: true) {
            DupButton {
              duplicate(chat)
            }
          }
        //        .swipeActions(edge: .leading, allowsFullSwipe: true) {
        //          Button("", systemImage: "message.badge.fill") {
        //            store.send(.chats(.element(id: chat.id, action: .onRead(!chat.read))))
        //          }.tint(.blue)
        //        }
      }
      .onMove(perform: onMove)
    }
    .listStyle(.plain)
    .animation(.default, value: chats.count)
    .confirmationDialog(
      chatToDelete?.name ?? "",
      isPresented: $isDeleteConfirmPresented,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        if let c = chatToDelete {
          modelContext.delete(c)
        }
      }
    } message: {
      Text("This chat will be permanently deleted.")
    }
    .confirmationDialog(
      "Delete \(selectedChatIDs.count) Chats",
      isPresented: $isMultiDeleteConfirmPresented,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        removeChats(selectedChatIDs)
        selectedChatIDs = .init()
      }
    } message: {
      Text("\(selectedChatIDs.count) chat\(selectedChatIDs.count == 1 ? "" : "s") will be permanently deleted.")
    }
    .confirmationDialog(
      "Clear \(chatToClearMessages?.messages.count ?? 0) Messages",
      isPresented: $isClearMessageConfirmPresented,
      titleVisibility: .visible
    ) {
      Button("Clear", role: .destructive) {
        if let chatToClearMessages {
          for m in chatToClearMessages.messages {
            modelContext.delete(m)
          }
          em.messageCountChange.send(chatToClearMessages.persistentModelID)
        }
      }
    } message: {
      let count = chatToClearMessages?.messages.count ?? 0
      Text("\(count) message\(count == 1 ? "" : "s") will be cleared from this chat.")
    }
    .toolbar {
      toolbarItems()
    }
    // ensure the .environment() modifier is placed after the .toolbar() modifier
    .environment(\.editMode, $editMode)
    .onAppear {
      selectedChatIDs = .init()
    }
  }

  @ToolbarContentBuilder
  func toolbarItems() -> some ToolbarContent {
    ToolbarItem {
      if editMode == .active {
        Button("Done") {
          withAnimation {
            editMode = .inactive
            selectedChatIDs = .init()
          }
        }.fontWeight(.semibold)
      } else {
        Menu("", systemImage: "ellipsis.circle") {
          NavigationLink(value: NavigationRoute.providerList) {
            Label("Providers", systemImage: "bolt.fill")
          }
          NavigationLink(value: NavigationRoute.promptList) {
            Label("Prompts", systemImage: "lightbulb.fill")
          }
          if !chats.isEmpty {
            Button("Select Chats", systemImage: "checkmark") {
              withAnimation {
                editMode = .active
              }
            }
          }
          Section {
            Button("Settings", systemImage: "gear") {
              isSettingPresented.toggle()
            }
          }
        }
      }
    }
    ToolbarItem(placement: ToolbarItemPlacement.navigationBarTrailing) {
      if editMode != .active {
        Button {
          createAndNavigateToNewChat()
        } label: {
          PlusIcon()
        }
      }
    }
    ToolbarItem(placement: .bottomBar) {
      if editMode == .active {
        HStack {
          Spacer()
          Button("Delete", role: .destructive) {
            isMultiDeleteConfirmPresented.toggle()
          }
          .tint(.red)
          .disabled(selectedChatIDs.isEmpty)
        }
      }
    }
  }

  private func createAndNavigateToNewChat() {
    do {
      if let chat = try? modelContext.createNewChat() {
        modelContext.insert(chat)
        try modelContext.save()
        Task { @MainActor in
          // Wait a bit for the query to update
          try? await Task.sleep(for: .milliseconds(100))
          navigationPath.append(chat)
        }
      }
    } catch {
      AppLogger.logError(
        .from(
          error: error,
          operation: "Save new chat",
          component: "ChatListView",
          userMessage: "Failed to save chat"
        ))
    }
  }

  @ViewBuilder
  func emptyProviderCard() -> some View {
    EmptyProviderCard {
      isAddProviderPresented = true
    }
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(uiColor: .secondarySystemBackground))
    }
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
  }

  @ViewBuilder
  func emptyChatCard() -> some View {
    EmptyChatCard {
      createAndNavigateToNewChat()
    }
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(uiColor: .secondarySystemBackground))
    }
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
  }

  @ViewBuilder
  func menuItems(chat: Chat) -> some View {
    let msgCount = chat.messages.count
    Button("Duplicate", systemImage: "document.on.document") {
      duplicate(chat)
    }
    Section {
      Button("Clear \(msgCount) Messages", systemImage: "paintbrush", role: .destructive) {
        chatToClearMessages = chat
        isClearMessageConfirmPresented.toggle()
      }
      .disabled(msgCount == 0)

      Button("Delete", systemImage: "trash", role: .destructive) {
        chatToDelete = chat
        isDeleteConfirmPresented.toggle()
      }
    }
  }

  private func removeChats(_ selectedChatIDs: Set<PersistentIdentifier>) {
    for id in selectedChatIDs {
      if let chatToDelete = chats.filter({ $0.persistentModelID == id }).first {
        modelContext.delete(chatToDelete)
      }
    }
  }

  func onMove(from source: IndexSet, to destination: Int) {
    var updatedItems = chats
    updatedItems.move(fromOffsets: source, toOffset: destination)
    updatedItems.reIndex()
  }

  private func duplicate(_ chat: Chat) {
    let newChat = chat.clone()
    modelContext.insert(newChat)
    do {
      try modelContext.save()
    } catch {
      AppLogger.logError(
        .from(
          error: error,
          operation: "Insert new chat",
          component: "ChatListView",
          userMessage: "Failed to create chat"
        ))
    }
  }
}

#Preview {
  LovelyPreview {
    HomePage()
  }
}
