import MarkdownUI
import SwiftData
import SwiftUI
import Translation

// MARK: - MessageCellContent

struct MessageCellContent: View {
  @EnvironmentObject var em: EM
  @EnvironmentObject var pref: Pref
  @Environment(\.modelContext) private var modelContext

  var msg: Message

  @State private var showingSelectTextPopover: Bool = false
  @State var isDeleteConfirmPresented: Bool = false
  @State private var translationVisible = false
  @State private var isInfoPresented = false
  @State private var softHaptics = false

  private let deleteCallback: () -> Void

  init(msg: Message, deleteCallback: @escaping () -> Void) {
    self.msg = msg
    self.deleteCallback = deleteCallback
  }

  var body: some View {
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
      Text("This message will be deleted.")
    }
  }

  // MARK: - Views

  @ViewBuilder
  func textView() -> some View {
    VStack(alignment: .trailing) {
      if !msg.message.isEmpty {
        Group {
          if msg.role == .assistant {
            if msg.status == .received || msg.status == .error {
              Markdown(msg.message)
                .markdownBlockStyle(\.codeBlock) {
                  codeBlock($0)
                }
            } else {
              Markdown(msg.message)
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
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 15).inset(by: 1))
    .contextMenu {
      contextMenuContent()
    }
    .modifier(TapGestureModifier(
      msg: msg,
      pref: pref,
      switchAction: switchAction
    ))
  }

  @ViewBuilder
  func contextMenuContent() -> some View {
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

  @ViewBuilder
  func codeBlock(_ configuration: CodeBlockConfiguration) -> some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Text((configuration.language == nil || configuration.language == "") ? "plain text" : configuration.language!)
          .fontDesign(.monospaced)
          .font(.callout)
          .fontWeight(.semibold)
          .foregroundStyle(Color(red: 0.098, green: 0.976, blue: 0.847))
          .padding(.vertical, 4)
          .padding(.horizontal, 8)
          .background(Color.black.opacity(0.3).background(.ultraThinMaterial))
          .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 10, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous))
      }

      ScrollView(.horizontal) {
        configuration.label
          .relativeLineSpacing(.em(0.25))
          .markdownTextStyle {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
          }
          .padding()
      }
    }
    .background {
      Color(Color(red: 0.165, green: 0.173, blue: 0.173))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .markdownMargin(top: .zero, bottom: .em(0.8))
  }

  // MARK: - Helper Methods

  func detents() -> Set<PresentationDetent> {
    if msg.message.count <= 200 && (msg.message.split(separator: "\n").count < 10) {
      return PresentationDetent.mediumDetents
    } else {
      return PresentationDetent.largeDetents
    }
  }

  func confirmDeleteTitle() -> String {
    let text = targetText()
    return text.count > 50 ? String(text.prefix(50 - 3)) + "..." : text
  }

  private func removeMsg(msg: Message) {
    modelContext.delete(msg)
  }

  private func targetText() -> String {
    return msg.message.isMeaningful ? msg.message : msg.errorInfo.meaningfulString
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
}
