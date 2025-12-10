import SwiftData
import SwiftUI
import TinyConstraints
import UIKit

// MARK: - MessageCellDelegate

protocol MessageCellDelegate: AnyObject {
  func messageCell(_ cell: MessageCell, didRequestDelete message: Message)
  func messageCell(_ cell: MessageCell, didRequestCopy text: String)
  func messageCell(_ cell: MessageCell, didRequestReuse text: String)
  func messageCell(_ cell: MessageCell, didRequestShowInfo message: Message)
  func messageCell(_ cell: MessageCell, didRequestSelectText text: String)
  func messageCell(_ cell: MessageCell, didDoubleTap message: Message)
}

// MARK: - MessageCell

final class MessageCell: UICollectionViewCell {
  static let reuseIdentifier = "MessageCell"
  
  // MARK: - Properties
  
  weak var delegate: MessageCellDelegate?
  private(set) var message: Message?
  private var displayLink: CADisplayLink?
  private var thinkingDotCount = 0
  
  // MARK: - UI Components
  
  let bubbleView: UIView = {
    let view = UIView()
    view.layer.cornerRadius = MessageLayoutConstants.bubbleCornerRadius
    view.layer.cornerCurve = .continuous
    view.clipsToBounds = true
    return view
  }()
  
  private let contentLabel: UITextView = {
    let textView = UITextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.font = .preferredFont(forTextStyle: .body)
    textView.dataDetectorTypes = [.link]
    return textView
  }()
  
  private let stateStackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 2
    stack.alignment = .center
    return stack
  }()
  
  private let timestampLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .footnote)
    return label
  }()
  
  private let statusImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
      font: .preferredFont(forTextStyle: .footnote),
      scale: .small
    )
    return imageView
  }()
  
  private let thinkingLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .largeTitle)
    label.textColor = .secondaryLabel
    label.textAlignment = .center
    return label
  }()
  
  private let errorLabel: UILabel = {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .footnote)
    label.textColor = .systemRed
    label.numberOfLines = 0
    return label
  }()
  
  // MARK: - Constraints
  
  private var bubbleLeadingConstraint: NSLayoutConstraint?
  private var bubbleTrailingConstraint: NSLayoutConstraint?
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
    setupConstraints()
  }
  
  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Setup
  
  private func setupViews() {
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    
    contentView.addSubview(bubbleView)
    bubbleView.addSubview(contentLabel)
    bubbleView.addSubview(errorLabel)
    bubbleView.addSubview(stateStackView)
    bubbleView.addSubview(thinkingLabel)
    
    stateStackView.addArrangedSubview(timestampLabel)
    stateStackView.addArrangedSubview(statusImageView)
    
    // Initially hide error and thinking
    errorLabel.isHidden = true
    thinkingLabel.isHidden = true
    
    // Setup interactions
    setupContextMenu()
    setupDoubleTapGesture()
  }
  
  private func setupConstraints() {
    bubbleView.translatesAutoresizingMaskIntoConstraints = false
    contentLabel.translatesAutoresizingMaskIntoConstraints = false
    stateStackView.translatesAutoresizingMaskIntoConstraints = false
    errorLabel.translatesAutoresizingMaskIntoConstraints = false
    thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
    
    // Bubble constraints (will be updated based on role)
    bubbleView.top(to: contentView, offset: MessageLayoutConstants.verticalMargin)
    bubbleView.bottom(to: contentView, offset: -MessageLayoutConstants.verticalMargin)
    
    // Store leading/trailing constraints to modify later
    bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(
      equalTo: contentView.leadingAnchor,
      constant: MessageLayoutConstants.horizontalMargin
    )
    bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(
      equalTo: contentView.trailingAnchor,
      constant: -MessageLayoutConstants.horizontalMargin
    )
    
    // Content label constraints
    contentLabel.top(to: bubbleView, offset: MessageLayoutConstants.bubbleVerticalPadding)
    contentLabel.leading(to: bubbleView, offset: MessageLayoutConstants.bubbleHorizontalPadding)
    contentLabel.trailing(to: bubbleView, offset: -MessageLayoutConstants.bubbleHorizontalPadding)
    
    // Error label constraints
    errorLabel.topToBottom(of: contentLabel, offset: 4)
    errorLabel.leading(to: bubbleView, offset: MessageLayoutConstants.bubbleHorizontalPadding)
    errorLabel.trailing(to: bubbleView, offset: -MessageLayoutConstants.bubbleHorizontalPadding)
    
    // State stack constraints
    stateStackView.topToBottom(of: errorLabel, offset: 2, priority: .defaultLow)
    stateStackView.trailing(to: bubbleView, offset: -MessageLayoutConstants.bubbleHorizontalPadding)
    stateStackView.bottom(to: bubbleView, offset: -MessageLayoutConstants.stateBottomPadding)
    
    // Make error-to-state constraint lower priority when error is hidden
    let contentToStateConstraint = stateStackView.topAnchor.constraint(
      equalTo: contentLabel.bottomAnchor,
      constant: 2
    )
    contentToStateConstraint.priority = .defaultHigh
    contentToStateConstraint.isActive = true
    
    // Thinking label constraints
    thinkingLabel.edges(to: bubbleView, insets: .uniform(10))
    
    // Status image size
    statusImageView.size(CGSize(width: 14, height: 14))
  }
  
  // MARK: - Configuration
  
  func configure(with message: Message) {
    self.message = message
    
    // Update colors based on role
    updateAppearance(for: message.role)
    
    // Update alignment
    updateAlignment(for: message.role)
    
    // Handle thinking state
    if message.status == .thinking {
      showThinkingState()
      return
    }
    
    hideThinkingState()
    
    // Update content
    if message.role == .assistant {
      contentLabel.attributedText = MessageCellSizing.attributedString(for: message)
      contentLabel.textColor = assistantTextColor
    } else {
      contentLabel.text = message.message
      contentLabel.textColor = .white
    }
    
    // Update error state
    if message.status == .error && !message.errorInfo.isEmpty {
      errorLabel.text = message.errorInfo
      errorLabel.isHidden = false
    } else {
      errorLabel.isHidden = true
    }
    
    // Update timestamp
    timestampLabel.text = formatAgo(from: message.createdAt)
    
    // Update status icon
    updateStatusIcon(for: message.status)
  }
  
  private func updateAppearance(for role: Message.MessageRole) {
    let isDark = traitCollection.userInterfaceStyle == .dark
    
    if role == .assistant {
      bubbleView.backgroundColor = isDark
        ? UIColor(hex: "3b3b3b")
        : UIColor(hex: "e9e9e9")
      timestampLabel.textColor = .secondaryLabel
      statusImageView.tintColor = .secondaryLabel
    } else {
      bubbleView.backgroundColor = UIColor(hex: "3f61e6")
      timestampLabel.textColor = UIColor(hex: "e5e5e5")
      statusImageView.tintColor = UIColor(hex: "e5e5e5")
    }
  }
  
  private var assistantTextColor: UIColor {
    traitCollection.userInterfaceStyle == .dark
      ? UIColor(hex: "e9e9e9")
      : UIColor(hex: "000000")
  }
  
  private func updateAlignment(for role: Message.MessageRole) {
    bubbleLeadingConstraint?.isActive = false
    bubbleTrailingConstraint?.isActive = false
    
    if role == .user {
      // User messages: right aligned with min leading margin
      bubbleTrailingConstraint?.isActive = true
      bubbleView.leadingAnchor.constraint(
        greaterThanOrEqualTo: contentView.leadingAnchor,
        constant: 60
      ).isActive = true
    } else {
      // Assistant messages: left aligned with min trailing margin
      bubbleLeadingConstraint?.isActive = true
      bubbleView.trailingAnchor.constraint(
        lessThanOrEqualTo: contentView.trailingAnchor,
        constant: -60
      ).isActive = true
    }
  }
  
  private func updateStatusIcon(for status: Message.MessageStatus) {
    switch status {
    case .sending:
      statusImageView.image = UIImage(systemName: "circle.dotted")
      statusImageView.isHidden = false
      startSendingAnimation()
    case .sent, .received:
      statusImageView.image = UIImage(systemName: "checkmark.circle.fill")
      statusImageView.isHidden = false
      stopSendingAnimation()
    default:
      statusImageView.isHidden = true
      stopSendingAnimation()
    }
  }
  
  private func showThinkingState() {
    contentLabel.isHidden = true
    errorLabel.isHidden = true
    stateStackView.isHidden = true
    thinkingLabel.isHidden = false
    
    thinkingDotCount = 1
    updateThinkingDots()
    startThinkingAnimation()
  }
  
  private func hideThinkingState() {
    contentLabel.isHidden = false
    stateStackView.isHidden = false
    thinkingLabel.isHidden = true
    stopThinkingAnimation()
  }
  
  // MARK: - Animations
  
  private func startSendingAnimation() {
    guard statusImageView.layer.animation(forKey: "rotation") == nil else { return }
    
    let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
    rotation.toValue = NSNumber(value: Double.pi * 2)
    rotation.duration = 4
    rotation.repeatCount = .infinity
    statusImageView.layer.add(rotation, forKey: "rotation")
  }
  
  private func stopSendingAnimation() {
    statusImageView.layer.removeAnimation(forKey: "rotation")
  }
  
  private func startThinkingAnimation() {
    displayLink?.invalidate()
    displayLink = CADisplayLink(target: self, selector: #selector(updateThinkingAnimation))
    displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 3, maximum: 3)
    displayLink?.add(to: .main, forMode: .common)
  }
  
  private func stopThinkingAnimation() {
    displayLink?.invalidate()
    displayLink = nil
  }
  
  @objc private func updateThinkingAnimation() {
    thinkingDotCount = (thinkingDotCount % 3) + 1
    updateThinkingDots()
  }
  
  private func updateThinkingDots() {
    let config = UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .largeTitle))
    let variableValue = Double(thinkingDotCount) / 3.0
    thinkingLabel.text = nil
    
    if let image = UIImage(
      systemName: "ellipsis",
      variableValue: variableValue,
      configuration: config
    ) {
      let attachment = NSTextAttachment()
      attachment.image = image.withTintColor(.secondaryLabel)
      thinkingLabel.attributedText = NSAttributedString(attachment: attachment)
    }
  }
  
  // MARK: - Magic Scroll Effect
  
  func applyMagicScrollEffect(minY: CGFloat, cellHeight: CGFloat, screenHeight: CGFloat) {
    guard cellHeight <= screenHeight / 4 else {
      resetTransform()
      return
    }
    
    let distance = min(0, minY)
    var scale = 1 + distance / 700
    if scale < 0 { scale = 0 }
    
    let y = scale < 0 ? 0 : -distance / 1.25
    let blurRadius = -distance / 50
    
    contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
      .translatedBy(x: 0, y: y / scale)
    
    applyBlur(radius: blurRadius)
  }
  
  func resetTransform() {
    contentView.transform = .identity
    removeBlur()
  }
  
  private func applyBlur(radius: CGFloat) {
    if radius > 0.5 {
      if let existingBlur = contentView.layer.filters,
         let gaussianBlur = existingBlur.first as? NSObject,
         gaussianBlur.responds(to: NSSelectorFromString("inputRadius"))
      {
        gaussianBlur.setValue(radius, forKey: "inputRadius")
      } else {
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(radius, forKey: "inputRadius")
        contentView.layer.filters = [blurFilter as Any]
      }
    } else {
      removeBlur()
    }
  }
  
  private func removeBlur() {
    contentView.layer.filters = nil
  }
  
  // MARK: - Lifecycle
  
  override func prepareForReuse() {
    super.prepareForReuse()
    message = nil
    delegate = nil
    contentLabel.text = nil
    contentLabel.attributedText = nil
    errorLabel.text = nil
    errorLabel.isHidden = true
    thinkingLabel.isHidden = true
    contentLabel.isHidden = false
    stateStackView.isHidden = false
    resetTransform()
    stopSendingAnimation()
    stopThinkingAnimation()
    
    // Remove any dynamic constraints
    bubbleView.constraints.forEach { constraint in
      if constraint.firstAttribute == .leading && constraint.relation == .greaterThanOrEqual {
        bubbleView.removeConstraint(constraint)
      }
      if constraint.firstAttribute == .trailing && constraint.relation == .lessThanOrEqual {
        bubbleView.removeConstraint(constraint)
      }
    }
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if let message = message {
      updateAppearance(for: message.role)
      if message.role == .assistant {
        contentLabel.textColor = assistantTextColor
      }
    }
  }
  
  // MARK: - Helper
  
  func targetText() -> String {
    guard let message = message else { return "" }
    return message.message.isEmpty ? message.errorInfo : message.message
  }
}

// MARK: - UIColor Hex Extension

extension UIColor {
  convenience init(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    
    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)
    
    let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
    let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
    let blue = CGFloat(rgb & 0x0000FF) / 255.0
    
    self.init(red: red, green: green, blue: blue, alpha: 1.0)
  }
}
