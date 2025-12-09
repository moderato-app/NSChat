import UIKit

// MARK: - Keyboard Handling

extension ChatDetailVC {
  func setupKeyboardObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  @objc func keyboardWillShow(_ notification: Notification) {
    guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
          let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
          let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    let keyboardHeight = keyboardFrame.height
    inputContainerBottomConstraint?.constant = -keyboardHeight
    // When keyboard is shown, just need padding (keyboard replaces safe area)
    inputWrapperBottomConstraint?.constant = -12

    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: UIView.AnimationOptions(rawValue: curve << 16),
      animations: {
        self.view.layoutIfNeeded()
      }
    )
  }

  @objc func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
          let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
    else { return }

    inputContainerBottomConstraint?.constant = 0
    // When keyboard is hidden, need safe area padding + extra padding
    inputWrapperBottomConstraint?.constant = -(view.safeAreaInsets.bottom + 12)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: UIView.AnimationOptions(rawValue: curve << 16),
      animations: {
        self.view.layoutIfNeeded()
      }
    )
  }
}
