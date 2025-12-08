import UIKit

// MARK: - Scrolling

extension ChatDetailVC {
  func scrollToBottom(animated: Bool) {
    guard !messages.isEmpty else { return }
    let lastIndex = IndexPath(item: messages.count - 1, section: 0)
    collectionView.scrollToItem(at: lastIndex, at: .bottom, animated: animated)
  }

  @objc func scrollToBottomTapped() {
    scrollToBottom(animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      HapticsService.shared.shake(.light)
    }
  }

  func updateShowToBottomButton() {
    let contentHeight = collectionView.contentSize.height
    let containerHeight = collectionView.bounds.height
    let contentOffsetY = collectionView.contentOffset.y

    let distanceToBottom = contentHeight - (contentOffsetY + containerHeight)
    let threshold = containerHeight * 1.5
    let shouldShow = distanceToBottom >= threshold

    if shouldShow != showToBottomButton {
      showToBottomButton = shouldShow
    }
  }
}
