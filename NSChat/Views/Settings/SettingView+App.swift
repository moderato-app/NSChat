import SwiftUI

extension SettingView {
  @ViewBuilder
  var appSection: some View {
    Section {
      HStack {
        Label("Haptic Feedback", systemImage: "iphone.gen2.radiowaves.left.and.right")
          .symbolRenderingMode(.multicolor)
          .modifier(RippleEffect(at: .zero, trigger: pref.haptics))
        Toggle("", isOn: $pref.haptics)
      }
      
      HStack {
        Label("Double Tap", systemImage: "hand.tap")
          .symbolRenderingMode(.multicolor)
        Spacer()
        Picker("Double Tap", selection: $pref.doubleTapAction.animation()) {
          ForEach(DoubleTapAction.allCases, id: \.self) { c in
            Text("\(c.rawValue)")
          }
        }
        .labelsHidden()
        .selectionFeedback(pref.doubleTapAction)
      }
      
      HStack {
        Label("Triple Tap", systemImage: "hand.tap")
          .symbolRenderingMode(.multicolor)
        Spacer()
        Picker("Triple Tap", selection: $pref.tripleTapAction.animation()) {
          ForEach(DoubleTapAction.allCases, id: \.self) { c in
            Text("\(c.rawValue)")
          }
        }
        .labelsHidden()
        .selectionFeedback(pref.tripleTapAction)
      }
    } header: {
      Text("App")
    } footer: {
      if pref.doubleTapAction == .reuse {
        Text("Double-tap a message to reuse it. Double-tap again to cancel reuse.")
      }
      if pref.tripleTapAction == .reuse {
        Text("Triple-tap a message to reuse it. Triple-tap again to cancel reuse.")
      }
    }
    .textCase(.none)
  }
}

