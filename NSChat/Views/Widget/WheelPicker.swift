import AVFoundation
import os
import SwiftUI

private let steps = 10

private enum Role {
  case primary, secondary, ordinary
}

struct WheelPicker: View {
  @Binding var value: Double
  @Binding var resetTrigger: Int

  let start: Int
  let end: Int
  let spacing: CGFloat
  let haptic: Bool

  private let defaultIndex: Int
  @State private var actualIndex: Int
  @State private var loaded: Bool
  @State private var indicatorX: CGFloat = .zero
  @State private var defaultIndexX: CGFloat = .zero

  init(
    value: Binding<Double>,
    resetTrigger: Binding<Int>,
    start: Int,
    end: Int,
    defaultValue: Int,
    spacing: CGFloat = 13,
    haptic: Bool = true,
  ) {
    self._value = value
    self._resetTrigger = resetTrigger
    self.start = start
    self.end = end
    self.spacing = spacing
    self.haptic = haptic

    self.defaultIndex = Int(round((Double(defaultValue) - Double(start)) * 10))
    let initialValue = value.wrappedValue
    self._actualIndex = State(initialValue: Int(round((initialValue - Double(start)) * Double(steps))))
    self._loaded = State(initialValue: false)
  }

  var body: some View {
    GeometryReader {
      let hPadding = $0.size.width / 2

      ScrollView(.horizontal) {
        HStack(spacing: spacing) {
          let totalSteps = steps * (end - start)

          ForEach(0 ... totalSteps, id: \.self) { i in
            let role = (i % steps == 0 ? Role.primary : (i % (steps / 2) == 0 ? Role.secondary : Role.ordinary))
            let color = (role == .primary ? Color.primary : Color.secondary)
            let height = (role == .primary ? 15 : (role == .secondary ? 10 : 5))

            Rectangle()
              .fill(color)
              .frame(width: 1, height: CGFloat(height), alignment: .center)
              .frame(maxHeight: 20, alignment: .bottom)
              .overlay {
                if role == .primary {
                  Text("\(i / steps + start)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textScale(.secondary)
                    .fixedSize()
                    .offset(y: 20)
                }
              }
              .overlay {
                if defaultIndex == i {
                  Circle()
                    .fill(actualIndex == i ? .clear : Color.primary)
                    .fontWeight(.semibold)
                    .frame(width: 6, height: 6)
                    .offset(y: -10)
                    .animation(.default, value: actualIndex)
                    .padding(3)
                    .onTapGesture { withAnimation { reset() }}
                    .onGeometryChange(for: CGFloat.self) { proxy in
                      proxy.frame(in: .global).midX
                    } action: {
                      defaultIndexX = $0
                    }
                }
              }
          }
        }
        .frame(height: 50)
        .scrollTargetLayout()
      }
      .scrollIndicators(.hidden)
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: .init(get: {
        let pos: Int? = loaded ? actualIndex : nil
        return pos
      }, set: { newValue in
        if let newValue {
          actualIndex = newValue
        }
      }))
      .onAppear {
        if !loaded { loaded = true }
      }
      .overlay(alignment: .center) {
        Rectangle()
          .fill(indicatorColor)
          .frame(width: 2, height: 25)
          .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).midX
          } action: {
            indicatorX = $0
          }
          .overlay(alignment: .trailing) {
            if status == .bigger && indicatorX > defaultIndexX {
              Rectangle()
                .fill(indicatorColor.opacity(0.2))
                .frame(width: indicatorX - defaultIndexX + 1.5, height: 25)
            }
          }
          .overlay(alignment: .leading) {
            if status == .smaller && defaultIndexX > indicatorX {
              Rectangle()
                .fill(indicatorColor.opacity(0.2))
                .frame(width: defaultIndexX - indicatorX + 1.5, height: 25)
            }
          }
          .padding(.bottom, 5)
          .allowsHitTesting(false)
      }
      .safeAreaPadding(.horizontal, hPadding)
    }
    .onChange(of: resetTrigger) { _, newTrigger in
      if newTrigger != 0 {
        withAnimation { reset() }
      }
    }
    .onChange(of: actualIndex) { _, newIndex in
      guard loaded else { return }

      // Update local value immediately for smooth UI
      let newValue = indexToValue(newIndex)

      if !doubleEqual(value, newValue) {
        withAnimation {
          value = newValue
        }
        AppLogger.ui.debug("WheelPicker: value changed to \(String(format: "%.2f", newValue))")
      }

      // Play haptic feedback
      if haptic {
        AudioServicesPlayAlertSound(SystemSoundID(1460))
      }
    }
  }

  var status: Status {
    let compareIndex = valueToIndex(value)
    if compareIndex == defaultIndex {
      return .equal
    } else if compareIndex < defaultIndex {
      return .smaller
    } else {
      return .bigger
    }
  }

  var indicatorColor: Color {
    switch status {
    case .bigger:
      Color.blue
    case .smaller:
      Color.orange
    case .equal:
      Color.secondary
    }
  }

  func reset() {
    actualIndex = defaultIndex
  }

  enum Status: Equatable {
    case smaller, bigger, equal
  }

  private func indexToValue(_ index: Int) -> Double {
    return Double(index) / Double(steps) + Double(start)
  }

  private func valueToIndex(_ value: Double) -> Int {
    return Int(round((value - Double(start)) * Double(steps)))
  }
}

#Preview("GPTWheelPicker") {
  @Previewable @State var value = 0.3
  @Previewable @State var resetTrigger = 1
  WheelPicker(value: $value, resetTrigger: $resetTrigger, start: -1, end: 1, defaultValue: 0)
}
