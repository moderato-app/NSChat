import SwiftUI

struct MessageMetaView: View {
  @Environment(\.colorScheme) var colorScheme
  let message: Message

  var body: some View {
    VStack(spacing: 12) {
      if let meta = message.meta {
        HStack(alignment: .firstTextBaseline) {
          Text("Provider").foregroundStyle(.secondary)
          Spacer()
          Text(meta.provider).fontWeight(.light)
        }

        HStack(alignment: .firstTextBaseline) {
          Text("Model").foregroundStyle(.secondary)
          Spacer()
          Text(meta.model).fontWeight(.light)
        }

        if let promptName = meta.promptName {
          HStack(alignment: .firstTextBaseline) {
            Text("Prompt Name").foregroundStyle(.secondary)
            Spacer()
            Text(promptName).fontWeight(.light)
          }
        }

        HStack(alignment: .firstTextBaseline) {
          Text("History Messages").foregroundStyle(.secondary)
          Spacer()
          Text("\(meta.actual_contextLength)").fontWeight(.light)
        }

        if let maybeTemperature = meta.maybeTemperature {
          HStack(alignment: .firstTextBaseline) {
            Text("Temperature [0,2]").foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f", maybeTemperature)).fontWeight(.light)
          }
        }

        if let maybePresencePenalty = meta.maybePresencePenalty {
          HStack(alignment: .firstTextBaseline) {
            Text("Presence Penalty [-2,2]").foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f", maybePresencePenalty)).fontWeight(.light)
          }
        }

        if let maybeFrequencyPenalty = meta.maybeFrequencyPenalty {
          HStack(alignment: .firstTextBaseline) {
            Text("Frequency Penalty [-2,2]").foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f", maybeFrequencyPenalty)).fontWeight(.light)
          }
        }

        if let promptTokens = meta.promptTokens {
          HStack(alignment: .firstTextBaseline) {
            Text("Prompt Tokens").foregroundStyle(.secondary)
            Spacer()
            Text("\(promptTokens)").fontWeight(.light)
          }
        }

        if let completionTokens = meta.completionTokens {
          HStack(alignment: .firstTextBaseline) {
            Text("Completion Tokens").foregroundStyle(.secondary)
            Spacer()
            Text("\(completionTokens)").fontWeight(.light)
          }
        }

        if let s = meta.startedAt, let e = meta.endedAt {
          let duration = e.timeIntervalSince(s)
          HStack(alignment: .firstTextBaseline) {
            Text("Duration")
              .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 2) {
              Text(String(format: "%.1f", duration)).fontWeight(.light)
              Text("s").fontWeight(.light).foregroundStyle(.secondary)
            }
          }
        }

        if let startedAt = meta.startedAt {
          HStack(alignment: .firstTextBaseline) {
            Text("Start")
              .foregroundStyle(.secondary)
            Spacer()
            Text(startedAt, format: Date.FormatStyle(date: .long, time: .omitted))
              .fontWeight(.light)
              .foregroundStyle(.secondary)
            Text(startedAt, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
              .fontWeight(.light)
          }
        }

        if let endedAt = meta.endedAt {
          HStack(alignment: .firstTextBaseline) {
            Text("End")
              .foregroundStyle(.secondary)
            Spacer()
            Text(endedAt, format: Date.FormatStyle(date: .long, time: .omitted))
              .fontWeight(.light)
              .foregroundStyle(.secondary)
            Text(endedAt, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
              .fontWeight(.light)
          }
        }
      }
    }
  }
}
