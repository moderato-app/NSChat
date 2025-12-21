import Foundation

func formatAgo(from date: Date) -> String {
  let now = Date()
  let timeInterval = now.timeIntervalSince(date)

  // Return localized "now" if less than 1 minute
  if timeInterval < 60 {
    return "now"
  }

  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .abbreviated
  formatter.locale = Locale.current
  return formatter.localizedString(for: date, relativeTo: now)
}

func getAppVersion() -> String {
  if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
     let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
  {
    return "\(version) Build \(build)"
  }
  return ""
}
