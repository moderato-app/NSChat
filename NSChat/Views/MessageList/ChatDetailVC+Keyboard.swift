import UIKit

// MARK: - Keyboard Handling

extension ChatDetailVC {
  func setupKeyboardObservers() {
    // Using keyboardLayoutGuide (iOS 15+) - constraints are handled automatically
    // The inputContainerView.bottomAnchor is constrained to view.keyboardLayoutGuide.topAnchor
    // which automatically animates with keyboard appearance/disappearance

    // Configure keyboard layout guide to use safe area when keyboard is hidden
    view.keyboardLayoutGuide.usesBottomSafeArea = true
  }
}
