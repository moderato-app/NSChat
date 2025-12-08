import UIKit

// MARK: - UICollectionViewDelegate

extension ChatDetailVC: UICollectionViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    updateShowToBottomButton()
  }
}

// MARK: - UITextFieldDelegate

extension ChatDetailVC: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    send(chat.option.contextLength)
    return true
  }
}
