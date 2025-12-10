import SwiftData
import SwiftUI

struct PromptListView: View {
  @State var searchString = ""
  var chatOption: ChatOption?
  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    ListPrompt(chatOption: chatOption, searchString: searchString)
      .searchable(text: $searchString)
//      .searchable(text: $searchString, placement: .navigationBarDrawer(displayMode: .always))
      .animation(.easeInOut, value: searchString)
  }
}

private struct ListPrompt: View {
  private static let sortOrder = [SortDescriptor(\Prompt.order, order: .reverse)]

  var chatOption: ChatOption?
  @Query(sort: \Prompt.order, order: .reverse) private var prompts: [Prompt]

  init(chatOption: ChatOption? = nil, searchString: String) {
    self.chatOption = chatOption
    _prompts = Query(filter: #Predicate {
      searchString.isMeaningless || $0.name.localizedStandardContains(searchString.meaningfulString)
    }, sort: Self.sortOrder)
  }

  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    ListPromptNoQuery(chatOption: chatOption, prompts: prompts)
      .navigationBarTitle("Prompts")
  }
}

private struct ListPromptNoQuery: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var em: EM

  @State var promptToDelete: Prompt?
  @State var isDeleteConfirmPresented: Bool = false
  @State var isCreatePromptPresented = false
  @State var hapticsTrigger = false

  var chatOption: ChatOption?
  private var myPrompts: [Prompt]
  private var presets: [Prompt]

  init(chatOption: ChatOption? = nil, prompts: [Prompt]) {
    self.chatOption = chatOption
    self.myPrompts = prompts.filter { !$0.preset }
    self.presets = prompts.filter { $0.preset }
  }

  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    List {
      if !myPrompts.isEmpty {
        Section {
          list(prompts: myPrompts)
        } header: {
          Text(myPrompts.count > 5 ? "My Prompts (\(myPrompts.count))" : "My Prompts")
            .foregroundStyle(.tint)
        }
      }

      if !presets.isEmpty {
        Section {
          list(prompts: presets)
        } header: {
          Text(presets.count > 5 ? "Presets (\(presets.count))" : "Presets")
            .foregroundStyle(.tint)
        }
      }
    }
    .listStyle(.plain)
    .modifier(JustScrollView(chatOption?.prompt?.persistentModelID))
    .animation(.spring, value: myPrompts.count)
    .animation(.spring, value: presets.count)
    .toolbar {
      Button {
        isCreatePromptPresented.toggle()
      } label: {
        PlusIcon()
      }
    }
    .softFeedback(isCreatePromptPresented, hapticsTrigger)
    .sheet(isPresented: $isCreatePromptPresented) {
      NavigationStack {
        PromptCreateView { _ in }
      }
    }
    .confirmationDialog(
      promptToDelete?.name ?? "",
      isPresented: $isDeleteConfirmPresented,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        if let prompt = promptToDelete {
          modelContext.delete(prompt)
          if let co = chatOption, co.prompt == prompt {
            co.prompt = nil
          }
        }
      }
    } message: {
      Text("This prompt will be permanently deleted.")
    }
    .onReceive(em.chatOptionPromptChangeEvent) { id in
      if let co = chatOption {
        hapticsTrigger.toggle()
        withAnimation(.bouncy(duration: 0.2)) {
          if let id = id {
            co.prompt = modelContext.findPromptById(promptId: id)
          } else {
            co.prompt = nil
          }
        }
      }
    }
  }

  @ViewBuilder
  func list(prompts: [Prompt]) -> some View {
    ForEach(prompts, id: \.persistentModelID) { prompt in
      PromptRowView(prompt: prompt, showCircle: chatOption != nil, id: chatOption?.prompt?.persistentModelID)
        .background(
          NavigationLink(value: prompt) {}.opacity(0)
        )
        .modifier(
          SwitchableListRowInsets(chatOption != nil, EdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 10))
        )
        .swipeActions {
          DeleteButton {
            promptToDelete = prompt
            isDeleteConfirmPresented = true
          }
          DupButton {
            let p = prompt.copy(order: prompts.count)
            modelContext.insert(p)
          }
        }
    }
    .onMove {
      onMove(prompts: prompts, from: $0, to: $1)
    }
  }


  func onMove(prompts: [Prompt], from source: IndexSet, to destination: Int) {
    var updatedItems = prompts
    updatedItems.move(fromOffsets: source, toOffset: destination)
    updatedItems.reIndex()
  }
}

#Preview("PromptListView") {
  ModelContainerPreview(ModelContainer.preview) {
    NavigationStack {
      PromptListView()
    }
  }
}
