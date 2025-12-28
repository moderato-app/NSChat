import os
import SwiftData
import SwiftUI

struct ChatListView_iPad: View {
  private static let sortOrder = [SortDescriptor(\Chat.order, order: .reverse)]

  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject var em: EM
  @Query(sort: \Chat.createdAt) private var chats: [Chat]
  @Query private var providers: [Provider]

  @Binding var navigationPath: NavigationPath
  @Binding var selectedChat: Chat?

  @State private var isSettingPresented = false
  @State private var isAddProviderPresented = false
  @State private var isProviderListPresented = false
  @State private var isPromptListPresented = false

  @State var isDeleteConfirmPresented: Bool = false
  @State var isMultiDeleteConfirmPresented: Bool = false
  @State var isClearMessageConfirmPresented: Bool = false
  @State var chatToClearMessages: Chat?
  @State var chatToDelete: Chat?

  @State var editMode: EditMode = .inactive

  init(_ searchString: String, navigationPath: Binding<NavigationPath>, selectedChat: Binding<Chat?>) {
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
    _selectedChat = selectedChat
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
          .presentationSizing(.page)
          .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $isAddProviderPresented) {
        let provider = Provider(type: .openAI)
        ProviderView(provider: provider, mode: .Add)
          .preferredColorScheme(colorScheme)
          .presentationSizing(.page)
      }
      .sheet(isPresented: $isProviderListPresented) {
        NavigationStack {
          ProviderListView()
        }
        .preferredColorScheme(colorScheme)
        .presentationSizing(.page)
        .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $isPromptListPresented) {
        NavigationStack {
          PromptListView()
        }
        .preferredColorScheme(colorScheme)
        .presentationSizing(.page)
        .presentationDragIndicator(.visible)
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
          .listRowBackground(selectedChat?.persistentModelID == chat.persistentModelID ? Color.accentColor.opacity(0.15) : nil)
          .contentShape(Rectangle())
          .onTapGesture {
            if editMode != .active {
              selectedChat = chat
            }
          }
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
          if selectedChat?.persistentModelID == c.persistentModelID {
            selectedChat = nil
          }
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
        if let currentChat = selectedChat, selectedChatIDs.contains(currentChat.persistentModelID) {
          selectedChat = nil
        }
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
          Button("Providers", systemImage: "bolt.fill") {
            isProviderListPresented.toggle()
          }
          Button("Prompts", systemImage: "lightbulb.fill") {
            isPromptListPresented.toggle()
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
          selectedChat = chat
        }
      }
    } catch {
      AppLogger.logError(
        .from(
          error: error,
          operation: "Save new chat",
          component: "ChatListView_iPad",
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
          component: "ChatListView_iPad",
          userMessage: "Failed to create chat"
        ))
    }
  }
}

#Preview {
  @Previewable @State var navigationPath = NavigationPath()
  @Previewable @State var selectedChat: Chat?
  
  LovelyPreview {
    NavigationStack {
      ChatListView_iPad("", navigationPath: $navigationPath, selectedChat: $selectedChat)
    }
  }
}
