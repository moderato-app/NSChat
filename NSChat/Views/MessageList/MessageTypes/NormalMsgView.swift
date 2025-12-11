import MarkdownUI
import SwiftData
import SwiftUI
import Translation

struct NormalMsgView: View {
  @EnvironmentObject var em: EM
  @EnvironmentObject var pref: Pref
  @Environment(\.modelContext) private var modelContext

  var msg: Message

  @State private var showingSelectTextPopover: Bool = false
  @State var isDeleteConfirmPresented: Bool = false
  @State private var translationVisible = false
  @State private var isInfoPresented = false
  @State private var softHaptics = false
  @State private var safariURL: String?

  private let deleteCallback: () -> Void
  init(msg: Message, deleteCallback: @escaping () -> Void) {
    self.msg = msg
    self.deleteCallback = deleteCallback
  }

  var body: some View {
//    let _ = Self.printChagesWhenDebug()
    HStack(spacing: 0) {
      if msg.role == .user {
        Spacer()
      }

      if msg.status == .thinking {
        ThinkingView()
          .contextMenu {
            Button(role: .destructive, action: {
              removeMsg(msg: msg)
            }) {
              Label("Delete", systemImage: "trash")
            }
          }
      } else {
        textView()
      }

      if msg.role == .assistant {
        Spacer()
      }
    }
    .softFeedback(isInfoPresented, softHaptics)
    .sheet(isPresented: $showingSelectTextPopover) {
      SelectTextView(msg.message)
        .presentationDetents(detents())
    }
    .sheet(isPresented: $isInfoPresented) {
      Form {
        MessageMetaView(message: msg)
      }
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
    .confirmationDialog(
      confirmDeleteTitle(),
      isPresented: $isDeleteConfirmPresented,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        removeMsg(msg: msg)
        deleteCallback()
        HapticsService.shared.shake(.success)
      }
    } message: {
      Text("This message will be permanently deleted.")
    }
    .sheet(item: $safariURL) { urlString in
      SafariView(url: URL(string: urlString)!)
        .presentationDetents([.large])
    }
  }

  @ViewBuilder
  func textView() -> some View {
    VStack(alignment: .trailing) {
      if !msg.message.isEmpty {
        Group {
          if msg.role == .assistant {
            // don't highlight code on typing for better performance
            if msg.status == .received || msg.status == .error {
              Markdown(msg.message)
                .markdownBlockStyle(\.codeBlock) {
                  codeBlock($0)
                }
                .environment(\.openURL, OpenURLAction { url in
                  handleLinkClick(url: url)
                })
            } else {
              Markdown(msg.message)
                .environment(\.openURL, OpenURLAction { url in
                  handleLinkClick(url: url)
                })
            }
          } else {
            Text(msg.message)
          }
        }
        .translationPresentation(isPresented: $translationVisible, text: msg.message) { trans in
          msg.message = trans
        }
        .weakFeedback(msg.message)
      }
      if msg.status == .error {
        ErrorView(msg.errorInfo, msg.errorType, provider: msg.chat?.option.model?.provider)
          .translationPresentation(isPresented: $translationVisible, text: msg.errorInfo) { trans in
            msg.errorInfo = trans
          }
      }
      StateView(msg: msg)
        .padding(.trailing, 2)
    }
    .padding(EdgeInsets(top: 10, leading: 10, bottom: 2, trailing: 10))
    .modifier(MessageRowModifier(msg.role))
    .background(.background) // prevent quinary opacity in context menu
    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 15).inset(by: 1))
    // preserve corner in context menu, use inset(by: 1) to remove the unhappy tiny white edge line
    .contextMenu {
      Button(action: {
        UIPasteboard.general.string = targetText()
      }) {
        Label("Copy", systemImage: "doc.on.doc")
      }
      Button(action: {
        showingSelectTextPopover.toggle()
      }) {
        Label("Select Text", systemImage: "selection.pin.in.out")
      }
      Button(action: {
        em.reUseTextEvent.send(targetText())
      }) {
        Label("Reuse", systemImage: "highlighter")
      }
      Button(action: {
        translationVisible.toggle()
      }) {
        Label("Translate", systemImage: "translate")
      }
      Button(action: {
        isInfoPresented.toggle()
      }) {
        Label("Info", systemImage: "info.square")
      }
      Section {
        Button(role: .destructive, action: {
          isDeleteConfirmPresented.toggle()
        }) {
          Label("Delete", systemImage: "trash")
        }
      }
    }
    .if(msg.status != .typing) {
      $0
        .if(pref.doubleTapAction != .none) {
          $0.onTapGesture(count: 2) {
            switchAction(pref.doubleTapAction)
          }
        }.if(pref.tripleTapAction != .none) {
          $0.onTapGesture(count: 3) {
            switchAction(pref.tripleTapAction)
          }
        }
    }
  }

  func switchAction(_ action: DoubleTapAction) {
    switch action {
    case .none:
      break
    case .reuse:
      softHaptics.toggle()
      em.reUseTextEvent.send(targetText())
    case .copy:
      softHaptics.toggle()
      UIPasteboard.general.string = targetText()
    case .showInfo:
      isInfoPresented.toggle()
    }
  }

  func detents() -> Set<PresentationDetent> {
    if msg.message.count <= 200 && (msg.message.split(separator: "\n").count < 10) {
      return PresentationDetent.mediumDetents
    } else {
      return PresentationDetent.largeDetents
    }
  }

  private func targetText() -> String {
    return msg.message.isMeaningful ? msg.message : msg.errorInfo.meaningfulString
  }

  func confirmDeleteTitle() -> String {
    let text = targetText()
    return text.count > 50 ? String(text.prefix(50 - 3)) + "..." : text
  }

  private func removeMsg(msg: Message) {
    modelContext.delete(msg)
  }

  private func handleLinkClick(url: URL) -> OpenURLAction.Result {
    switch pref.linkOpenMode {
    case .inApp:
      safariURL = url.absoluteString
      return .handled
    case .system:
      return .systemAction
    }
  }
}

#Preview {
  LovelyPreview {
    NavigationStack {
      NormalMsgView(msg: ChatSample.manyMessages.messages.last!, deleteCallback: {})
    }
  }
}
