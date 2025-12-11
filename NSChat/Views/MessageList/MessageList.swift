import os
import SwiftData
import SwiftUI
import VisualEffectView

private struct ScrollState: Equatable {
  let contentHeight: CGFloat
  let containerHeight: CGFloat
  let contentOffsetY: CGFloat
}

struct MessageList: View {
  @EnvironmentObject private var em: EM
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var pref: Pref
  @State private var triggerHaptic: Bool = false

  @State private var showToBottomButton = false
  @State private var position = ScrollPosition()
  @State private var messages: [Message] = []
  @State private var total = 10
  @State private var inputText = ""

  let chat: Chat

  init(chat: Chat) {
    self.chat = chat
  }

  func initMessageList() {
    messages = chat.messages
      .sorted(by: { a, b in a.createdAt > b.createdAt })
      .prefix(total)
      .reversed()
  }

  func onMsgCountChange() {
    // Skip animation if there are too many history messages to avoid clutter
    let anim = total <= 20
    total = 10
    Task.detached {
      try await Task.sleep(for: .seconds(0.05))
      Task { @MainActor in
        withAnimation(anim ? .easeInOut : .none) {
          initMessageList()
        }
      }
      try await Task.sleep(for: .seconds(1))
      Task { @MainActor in
        withAnimation(anim ? .easeInOut : .none) {
          initMessageList()
        }
      }
    }
  }

  @State var scrollIndicatorPresented = false

  var body: some View {
//    let _ = Self.printChagesWhenDebug()
    ScrollView {
      VStack(alignment: .leading) {
        ForEach(messages, id: \.self) { msg in
//          let _ = Self.printChagesWhenDebug()
          NormalMsgView(msg: msg, deleteCallback: onMsgCountChange)
            .id(msg.id)
            .if(pref.magicScrolling) { c in
              c.visualEffect { content, proxy in
                let frame = proxy.frame(in: .scrollView(axis: .vertical))
                let distance = min(0, frame.height > UIScreen.main.bounds.height / 4 ? 0 : frame.minY)
                var scale = (1 + distance / 700)
                if scale < 0 {
                  scale = 0
                }
                let y = scale < 0 ? 0 : -distance / 1.25
                return content
                  .scaleEffect(scale)
                  .offset(y: y)
                  .blur(radius: -distance / 50)
              }
            }
        }
        .padding(10)
      }
      .background {
        GeometryReader { proxy in
          Color.clear
            .onChange(of: proxy.size.height, initial: true) { _, newValue in
              // Use debouncing to avoid frequent updates
              let shouldPresent = newValue > UIScreen.main.bounds.height
              if scrollIndicatorPresented != shouldPresent {
                scrollIndicatorPresented = shouldPresent
              }
            }
        }
      }
      .scrollTargetLayout()
    }
    .background(Rectangle().fill(.gray.opacity(0.0001)).containerRelativeFrame(.horizontal) { v, _ in v })
    .defaultScrollAnchor(.bottom, for: .initialOffset)
    .defaultScrollAnchor(.bottom, for: .sizeChanges)
    .defaultScrollAnchor(.top, for: .alignment)
    .scrollPosition($position, anchor: .bottom)
    .scrollDismissesKeyboard(.interactively)
    .removeFocusOnTap()
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 0) {
        InputToolbarView(chatOption: chat.option, inputText: $inputText)
          .padding(.horizontal, 18)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        InputAreaView(chat: chat, inputText: $inputText)
      }
      .background(
        VisualEffect(colorTint: visualTint, colorTintAlpha: 0.5, blurRadius: 18, scale: 1)
          .ignoresSafeArea(edges: .bottom))
      .overlay(alignment: .topTrailing) {
        // Place offset on outer layer to avoid position changes being animated
        Button {
          withAnimation {
            position.scrollTo(edge: .bottom)
          }
          Task.detached {
            try await Task.sleep(for: .seconds(0.2))
            Task { @MainActor in
              triggerHaptic.toggle()
            }
          }
        } label: {
          ToBottomIcon()
        }
        .scaleEffect(showToBottomButton ? 1 : 0)
        .opacity(showToBottomButton ? 1 : 0)
        .animation(.default, value: showToBottomButton)
        .offset(y: -60)
        .offset(x: -15)
      }
    }
    .onScrollGeometryChange(for: ScrollState.self) { geometry in
      ScrollState(
        contentHeight: geometry.contentSize.height,
        containerHeight: geometry.containerSize.height,
        contentOffsetY: geometry.contentOffset.y
      )
    } action: { _, newValue in
      updateShowToBottomButton(newValue)
    }
    .softFeedback(triggerHaptic)
    .onAppear {
      initMessageList()
      Task {
        position.scrollTo(edge: .bottom)
      }
    }
    .onReceive(em.messageEvent) { event in
      if event == .new {
        withAnimation {
          onMsgCountChange()
          position.scrollTo(edge: .bottom)
        }
      } else if event == .countChanged {
        withAnimation {
          onMsgCountChange()
        }
      }
    }
    .refreshable {
      if messages.count == total {
        total += 20
        withAnimation {
          initMessageList()
        }
      } else {
        HapticsService.shared.shake(.error)
      }
    }
  }

  var visualTint: Color {
    colorScheme == .dark ? .black : .white
  }

  fileprivate func updateShowToBottomButton(_ scrollState: ScrollState) {
    let contentHeight = scrollState.contentHeight
    let containerHeight = scrollState.containerHeight
    let contentOffsetY = scrollState.contentOffsetY

    // Calculate distance from current position to bottom
    // Distance = total content height - (current offset + visible height)
    let distanceToBottom = contentHeight - (contentOffsetY + containerHeight)

    // Show button if distance is greater than 1.5 container heights
    // Using containerHeight directly ensures proper response to screen rotation
    let threshold = containerHeight * 1.5
    let shouldShow = distanceToBottom >= threshold

    if shouldShow != showToBottomButton {
      showToBottomButton = shouldShow
    }

//    AppLogger.ui.debug("Scroll position - contentHeight: \(contentHeight), containerHeight: \(containerHeight), offset: \(contentOffsetY), distanceToBottom: \(distanceToBottom), threshold: \(threshold), showButton: \(shouldShow)")
  }
}

#Preview {
  LovelyPreview {
    MessageList(chat: ChatSample.manyMessages)
  }
}
