import Combine
import Foundation
import os
import SwiftData
import SwiftUI
import Throttler
import VisualEffectView

struct SwitchableListRowInsets: ViewModifier {
  let apply: Bool
  let insets: EdgeInsets

  init(_ apply: Bool, _ insets: EdgeInsets) {
    self.apply = apply
    self.insets = insets
  }

  func body(content: Content) -> some View {
    if apply {
      content.listRowInsets(insets)
    } else {
      content
    }
  }
}

extension View {
  @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}

@ViewBuilder
func CondNavigationStack<Content: View>(_ condition: Bool, @ViewBuilder content: () -> Content) -> some View {
  if condition {
    NavigationStack {
      content()
    }
  } else {
    content()
  }
}

struct JustScrollView: ViewModifier {
  let id: PersistentIdentifier?

  init(_ id: PersistentIdentifier?) {
    self.id = id
  }

  func body(content: Content) -> some View {
    ScrollViewReader { proxy in
      content.onAppear {
        if let id = id {
          withAnimation {
            proxy.scrollTo(id, anchor: .center)
          }
        }
      }
    }
  }
}

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r = CGFloat((int & 0xFF0000) >> 16) / 255
    let g = CGFloat((int & 0x00FF00) >> 8) / 255
    let b = CGFloat(int & 0x0000FF) / 255

    self.init(
      .sRGB,
      red: r,
      green: g,
      blue: b,
      opacity: 1
    )
  }
}

// https://stackoverflow.com/a/72026504
// tap anywhere to lose focus
struct RemoveFocusOnTapModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
    #if os(iOS)
    .onTapGesture {
      UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #elseif os(macOS)
    .onTapGesture {
      DispatchQueue.main.async {
        NSApp.keyWindow?.makeFirstResponder(nil)
      }
    }
    #endif
  }
}

public extension View {
  func removeFocusOnTap() -> some View {
    modifier(RemoveFocusOnTapModifier())
  }
}

extension Spacer {
  static func widthPercent(_ percent: CGFloat) -> some View {
    return Spacer().containerRelativeFrame(.horizontal) { w, _ in w * percent }
  }
}

extension PresentationDetent {
  static let mediumDetents: Set<PresentationDetent> = Set([.medium])
  static let largeDetents: Set<PresentationDetent> = Set([.large])
}

struct TransNaviModifier: ViewModifier {
  @Environment(\.colorScheme) var colorScheme

  var visualTint: Color {
    colorScheme == .dark ? .black : .white
  }

  func body(content: Content) -> some View {
    content
      .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top, spacing: 0) {
        VisualEffect(colorTint: visualTint, colorTintAlpha: 0.1, blurRadius: 18, scale: 1)
          .ignoresSafeArea(edges: .top)
          .frame(height: 0)
      }
  }
}

public extension View {
  func transNavi() -> some View {
    modifier(TransNaviModifier())
  }
}
