import Foundation

extension Message {
  /// Returns the first N characters of the message content
  /// - Parameter count: Maximum number of characters to return (default: 100)
  /// - Returns: A preview string with up to `count` characters
  var preview: String {
    preview(count: 100)
  }
  
  /// Returns the first N characters of the message content
  /// - Parameter count: Maximum number of characters to return
  /// - Returns: A preview string with up to `count` characters
  func preview(count: Int) -> String {
    return String(message.prefix(count))
  }
}
