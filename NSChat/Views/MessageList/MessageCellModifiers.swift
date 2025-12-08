import SwiftUI

// MARK: - TapGestureModifier

struct TapGestureModifier: ViewModifier {
  let msg: Message
  let pref: Pref
  let switchAction: (DoubleTapAction) -> Void

  func body(content: Content) -> some View {
    if msg.status != .typing {
      applyGestures(to: content)
    } else {
      content
    }
  }

  @ViewBuilder
  private func applyGestures(to content: Content) -> some View {
    if pref.doubleTapAction != .none && pref.trippleTapAction != .none {
      content
        .onTapGesture(count: 2) { switchAction(pref.doubleTapAction) }
        .onTapGesture(count: 3) { switchAction(pref.trippleTapAction) }
    } else if pref.doubleTapAction != .none {
      content
        .onTapGesture(count: 2) { switchAction(pref.doubleTapAction) }
    } else if pref.trippleTapAction != .none {
      content
        .onTapGesture(count: 3) { switchAction(pref.trippleTapAction) }
    } else {
      content
    }
  }
}
