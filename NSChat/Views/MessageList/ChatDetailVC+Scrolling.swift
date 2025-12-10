import UIKit

// MARK: - Scrolling

extension ChatDetailVC {
  func scrollToBottom(animated: Bool) {
    guard !messages.isEmpty else { return }
    
    let lastIndex = IndexPath(item: messages.count - 1, section: 0)
    
    // First scroll to last item to trigger cell loading
    collectionView.scrollToItem(at: lastIndex, at: .bottom, animated: animated)
    
    // Then scroll visible rect to true bottom with accurate contentSize
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let contentHeight = self.collectionView.contentSize.height
      let boundsHeight = self.collectionView.bounds.height
      let contentInset = self.collectionView.adjustedContentInset
      
      let bottomOffset = contentHeight + contentInset.bottom - boundsHeight
      
      guard bottomOffset > -contentInset.top else { return }
      
      let targetOffset = CGPoint(x: 0, y: max(bottomOffset, -contentInset.top))
      self.collectionView.setContentOffset(targetOffset, animated: animated)
    }
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
