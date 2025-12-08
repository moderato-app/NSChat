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
          let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
    else { return }

    let keyboardHeight = keyboardFrame.height
    inputContainerBottomConstraint?.constant = -keyboardHeight + view.safeAreaInsets.bottom

    UIView.animate(withDuration: duration) {
      self.view.layoutIfNeeded()
    }
  }

  @objc func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

    inputContainerBottomConstraint?.constant = 0

    UIView.animate(withDuration: duration) {
      self.view.layoutIfNeeded()
    }
  }
}
