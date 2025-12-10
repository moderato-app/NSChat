import UIKit
import SwiftyMarkdown

// MARK: - MessageLayoutConstants

enum MessageLayoutConstants {
  // MARK: - Cell margins
  
  /// Horizontal margin from screen edge to bubble
  static let horizontalMargin: CGFloat = 10
  
  /// Vertical margin between cells
  static let verticalMargin: CGFloat = 4
  
  // MARK: - Bubble padding
  
  /// Vertical padding inside bubble
  static let bubbleVerticalPadding: CGFloat = 10
  
  /// Horizontal padding inside bubble
  static let bubbleHorizontalPadding: CGFloat = 10
  
  /// Bottom padding for state view
  static let stateBottomPadding: CGFloat = 2
  
  // MARK: - Bubble style
  
  /// Bubble corner radius
  static let bubbleCornerRadius: CGFloat = 15
  
  // MARK: - Computed properties
  
  /// Total vertical padding (top + bottom padding + state view height)
  static var totalVerticalPadding: CGFloat {
    bubbleVerticalPadding + stateBottomPadding + stateViewHeight
  }
  
  /// Total horizontal padding (margins + bubble padding)
  static var totalHorizontalPadding: CGFloat {
    (horizontalMargin * 2) + (bubbleHorizontalPadding * 2)
  }
  
  /// Minimum message cell height
  static let minMessageHeight: CGFloat = 50
  
  /// State view height (timestamp + status icon)
  static let stateViewHeight: CGFloat = 18
  
  /// Thinking view height
  static let thinkingViewHeight: CGFloat = 44
  
  // MARK: - Collection View
  
  /// Spacing between messages
  static let messageSpacing: CGFloat = 17
  
  /// Collection view top inset
  static let collectionViewTopInset: CGFloat = 20
  
  /// Collection view bottom inset
  static let collectionViewBottomInset: CGFloat = 20
}

// MARK: - MessageSizeCache

final class MessageSizeCache {
  static let shared = MessageSizeCache()
  
  private var cache: [String: CGSize] = [:]
  private let lock = NSLock()
  
  private init() {}
  
  func cacheKey(for messageId: String, content: String, width: CGFloat) -> String {
    "\(messageId)_\(content.hashValue)_\(Int(width))"
  }
  
  func size(for messageId: String, content: String, width: CGFloat) -> CGSize? {
    lock.lock()
    defer { lock.unlock() }
    return cache[cacheKey(for: messageId, content: content, width: width)]
  }
  
  func setSize(_ size: CGSize, for messageId: String, content: String, width: CGFloat) {
    lock.lock()
    defer { lock.unlock() }
    cache[cacheKey(for: messageId, content: content, width: width)] = size
  }
  
  func invalidate(for messageId: String) {
    lock.lock()
    defer { lock.unlock() }
    cache = cache.filter { !$0.key.hasPrefix(messageId) }
  }
  
  func invalidateAll() {
    lock.lock()
    defer { lock.unlock() }
    cache.removeAll()
  }
}

// MARK: - MessageCellSizing

final class MessageCellSizing {
  
  /// Calculate cell height for a message
  /// - Parameters:
  ///   - message: The message to calculate height for
  ///   - maxWidth: Maximum available width for the cell
  /// - Returns: Calculated height
  static func calculateHeight(for message: Message, maxWidth: CGFloat) -> CGFloat {
    // Handle thinking state
    if message.status == .thinking {
      return MessageLayoutConstants.thinkingViewHeight +
             MessageLayoutConstants.verticalMargin * 2
    }
    
    // Calculate text width (subtract horizontal padding)
    let textWidth = maxWidth - MessageLayoutConstants.totalHorizontalPadding
    
    // Check cache first
    let messageId = message.id.hashValue.description
    if let cachedSize = MessageSizeCache.shared.size(
      for: messageId,
      content: message.message,
      width: textWidth
    ) {
      return max(
        cachedSize.height + MessageLayoutConstants.totalVerticalPadding,
        MessageLayoutConstants.minMessageHeight
      )
    }
    
    // Calculate text size based on role
    let textSize: CGSize
    if message.role == .assistant {
      textSize = calculateMarkdownTextSize(message.message, maxWidth: textWidth)
    } else {
      textSize = calculatePlainTextSize(message.message, maxWidth: textWidth)
    }
    
    // Add error info height if needed
    var totalHeight = textSize.height
    if message.status == .error && !message.errorInfo.isEmpty {
      let errorSize = calculatePlainTextSize(message.errorInfo, maxWidth: textWidth)
      totalHeight += errorSize.height + 8 // 8pt spacing
    }
    
    // Cache the result
    MessageSizeCache.shared.setSize(
      CGSize(width: textWidth, height: totalHeight),
      for: messageId,
      content: message.message,
      width: textWidth
    )
    
    // Return final height with padding
    let finalHeight = totalHeight + MessageLayoutConstants.totalVerticalPadding
    return max(finalHeight, MessageLayoutConstants.minMessageHeight)
  }
  
  /// Calculate size for markdown text using SwiftyMarkdown
  private static func calculateMarkdownTextSize(_ text: String, maxWidth: CGFloat) -> CGSize {
    guard !text.isEmpty else { return .zero }
    
    let md = SwiftyMarkdown(string: text)
    configureMarkdownStyles(md)
    
    let attributedString = md.attributedString()
    return calculateAttributedStringSize(attributedString, maxWidth: maxWidth)
  }
  
  /// Calculate size for plain text
  private static func calculatePlainTextSize(_ text: String, maxWidth: CGFloat) -> CGSize {
    guard !text.isEmpty else { return .zero }
    
    let font = UIFont.preferredFont(forTextStyle: .body)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    
    let boundingRect = (text as NSString).boundingRect(
      with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )
    
    return CGSize(width: ceil(boundingRect.width), height: ceil(boundingRect.height))
  }
  
  /// Calculate size for attributed string
  private static func calculateAttributedStringSize(
    _ attributedString: NSAttributedString,
    maxWidth: CGFloat
  ) -> CGSize {
    let boundingRect = attributedString.boundingRect(
      with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil
    )
    
    return CGSize(width: ceil(boundingRect.width), height: ceil(boundingRect.height))
  }
  
  /// Configure SwiftyMarkdown styles to match the app theme
  static func configureMarkdownStyles(_ md: SwiftyMarkdown) {
    let bodyFont = UIFont.preferredFont(forTextStyle: .body)
    let codeFont = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize * 0.9, weight: .regular)
    
    md.setFontColorForAllStyles(with: .label)
    md.setFontSizeForAllStyles(with: bodyFont.pointSize)
    
    // Headers
    md.h1.fontSize = bodyFont.pointSize * 1.5
    md.h1.fontStyle = .bold
    md.h2.fontSize = bodyFont.pointSize * 1.3
    md.h2.fontStyle = .bold
    md.h3.fontSize = bodyFont.pointSize * 1.15
    md.h3.fontStyle = .bold
    
    // Code
    md.code.fontName = codeFont.fontName
    md.code.fontSize = codeFont.pointSize
    md.code.color = .secondaryLabel
    
    // Links
    md.link.color = .systemBlue
    md.underlineLinks = true
    
    // Bold and italic
    md.bold.fontStyle = .bold
    md.italic.fontStyle = .italic
    
    // Blockquotes
    md.blockquotes.color = .secondaryLabel
    
    // Strikethrough
    md.strikethrough.color = .secondaryLabel
  }
  
  /// Create attributed string for a message
  static func attributedString(for message: Message) -> NSAttributedString {
    if message.role == .assistant {
      let md = SwiftyMarkdown(string: message.message)
      configureMarkdownStyles(md)
      return md.attributedString()
    } else {
      let font = UIFont.preferredFont(forTextStyle: .body)
      return NSAttributedString(
        string: message.message,
        attributes: [
          .font: font,
          .foregroundColor: UIColor.white
        ]
      )
    }
  }
}
