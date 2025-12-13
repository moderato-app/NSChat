import SwiftUI

struct WheelPickerView: View {
  @EnvironmentObject var pref: Pref

  let name: String
  @Binding var value: Double
  let start: Int
  let end: Int
  let defaultValue: Int
  let systemImage: String
  let spacing: CGFloat

  @State private var realTimeValue: Double
  @State private var rippleTrigger = 0
  @State private var debounceTask: Task<Void, Never>?
  @State var resetTrigger: Int = 0

  init(
    name: String,
    value: Binding<Double>,
    start: Int,
    end: Int,
    defaultValue: Int,
    systemImage: String,
    spacing: CGFloat = 13
  ) {
    self.name = name
    self.realTimeValue = value.wrappedValue
    self._value = value
    self.start = start
    self.end = end
    self.defaultValue = defaultValue
    self.systemImage = systemImage
    self.spacing = spacing
  }

  var numberType: NumberType {
    if doubleEqual(Double(defaultValue), realTimeValue) {
      return .dft("\(defaultValue)")
    } else if realTimeValue < Double(defaultValue) {
      return .smaller(String(format: "%.1f", realTimeValue))
    } else {
      return .bigger(String(format: "%.1f", realTimeValue))
    }
  }

  enum NumberType: Equatable {
    case smaller(String), bigger(String), dft(String)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Label(name, systemImage: systemImage)
          .foregroundStyle(.primary)
          .modifier(RippleEffect(at: .zero, trigger: rippleTrigger))

        Spacer()
        HStack(alignment: .lastTextBaseline, spacing: 5) {
          Group {
            switch numberType {
            case let .bigger(str):
              Text(str)
                .foregroundStyle(.blue)
            case let .smaller(str):
              Text(str)
                .foregroundStyle(.orange)
            case let .dft(str):
              Text(str) + Text(".1").foregroundStyle(.clear)
            }
          }
          .foregroundStyle(.secondary)
          .fontWeight(.semibold)
          .contentTransition(.numericText(value: realTimeValue))
          .animation(.snappy(duration: 0.1), value: realTimeValue)
        }
      }
      .background(Rectangle().fill(.gray.opacity(0.0001)))

      wheelPicker.frame(height: 50)
    }
    .onTapGesture(count: 2) {
      resetTrigger += 1
    }
    .grayscale(doubleEqual(Double(defaultValue), realTimeValue) ? 1 : 0)
    .opacity(doubleEqual(Double(defaultValue), realTimeValue) ? 0.35 : 1)
    .onChange(of: realTimeValue) { _, newValue in
      // Debounce: cancel previous task and schedule new one
      debounceTask?.cancel()
      debounceTask = Task {
        do {
          try await Task.sleep(for: .milliseconds(250))
          guard !Task.isCancelled else { return }

          // Update external binding only after delay
          await MainActor.run {
            if !doubleEqual(value, newValue) {
              withAnimation {
                value = newValue
              }
              AppLogger.ui.debug("WheelPicker: Updated external value to \(String(format: "%.2f", newValue))")
            }
          }
        } catch {
          // Task was cancelled, ignore
        }
      }
    }
    .onDisappear {
      // Flush any pending changes when view disappears
      debounceTask?.cancel()
      if !doubleEqual(value, realTimeValue) {
        value = realTimeValue
      }
    }
  }

  @ViewBuilder
  private var wheelPicker: some View {
    WheelPicker(
      value: $realTimeValue,
      resetTrigger: $resetTrigger,
      start: start,
      end: end,
      defaultValue: defaultValue,
      spacing: spacing,
      haptic: pref.haptics
    )
    .frame(height: 50)
  }
}

#Preview {
  @Previewable @State var value = 0.3
  Form {
    WheelPickerView(
      name: "Temperature",
      value: $value,
      start: -1,
      end: 1,
      defaultValue: 0,
      systemImage: "thermometer.medium"
    )
  }
}
