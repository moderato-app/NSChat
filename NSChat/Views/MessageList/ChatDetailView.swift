import SwiftUI
import VisualEffectView

struct ChatDetailView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isSettingPresented = false

  let chat: Chat

  var visualTint: Color {
    colorScheme == .dark ? .black : .white
  }

  var body: some View {
    //    let _ = Self.printChagesWhenDebug()
    ChatDetail(chat: chat)
      .toolbarBackground(.hidden, for: .automatic)
      .safeAreaInset(edge: .top, spacing: 0) {
        VisualEffect(colorTint: visualTint, colorTintAlpha: 0.5, blurRadius: 18, scale: 1)
          .ignoresSafeArea(edges: .top)
          .frame(height: 0)
      }
      .toolbar {
        ToolbarTitleMenu {
          Section {
            Button {
              isSettingPresented.toggle()
            } label: {
              HStack {
                Text("Settings")
                Image(systemName: "gear")
              }
            }
          }
        }
      }
      .sheet(isPresented: $isSettingPresented) {
        SettingView()
          .preferredColorScheme(colorScheme)
          .presentationDetents([.large])
      }
      .browserLinkHandler()
  }
}

private struct ChatDetail: View {
  let chat: Chat

  @EnvironmentObject var em: EM
  @State private var isInfoPresented = false
  @State private var isPromptPresented = false

  init(chat: Chat) {
    self.chat = chat
  }

  var body: some View {
    //    let _ = Self._printChanges()
    MessageList(chat: chat)
      .softFeedback(isPromptPresented, isInfoPresented)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          HStack(spacing: 0) {
            Button {
              self.isPromptPresented.toggle()
            } label: {
              PromptIcon(chatOption: chat.option)
                .tint(.secondary)
            }
            .sheet(isPresented: $isPromptPresented) {
              NavigationStack {
                if let p = chat.option.prompt {
                  PromptEditorView(p)
                    .toolbar { Button("OK") { isPromptPresented.toggle() } }
                } else {
                  PromptCreateView { p in
                    chat.option.prompt = p
                  }
                }
              }
              .presentationDetents([.large])
            }.hidden()

            Button("", systemImage: "ellipsis.circle") {
              self.isInfoPresented.toggle()
            }
            .sheet(isPresented: $isInfoPresented) {
              ChatInfoView(chat: chat)
                .presentationDetents([.large])
            }
          }
        }
      }
      .onReceive(em.messageEvent) { event in
        switch event {
        case .new:
          HapticsService.shared.shake(.light)
        case .eof:
          Task {
            await sleepFor(0.2)
            HapticsService.shared.shake(.success)
          }
        case .err:
          Task {
            await sleepFor(0.2)
            HapticsService.shared.shake(.error)
          }
        case .countChanged:
          break
        }
      }
  }
}

#Preview {
  LovelyPreview {
    NavigationStack {
      ChatDetailView(chat: ChatSample.manyMessages)
    }
  }
}
