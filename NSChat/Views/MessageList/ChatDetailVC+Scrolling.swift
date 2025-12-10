import UIKit

// MARK: - Scrolling

extension ChatDetailVC {
  
  /// Maximum content offset Y (scrolled to bottom position)
  var maxContentOffsetY: CGFloat {
    let contentHeight = collectionView.contentSize.height
    let adjustedContentInset = collectionView.adjustedContentInset
    let rawValue = contentHeight + adjustedContentInset.bottom - collectionView.bounds.height
    // Handle case where there isn't enough content to fill the collection view
    let minValue = -adjustedContentInset.top
    return max(minValue, rawValue)
  }
  
  /// Scrolls to the bottom of the message list
  ///
  /// Using UICollectionViewFlowLayout with sizeForItemAt delegate method,
  /// cell heights are calculated before rendering, ensuring contentSize is accurate.
  /// This allows for a single, smooth scroll operation (like Signal-iOS).
  func scrollToBottom(animated: Bool) {
    guard !messages.isEmpty else { return }
    
    // Ensure layout is up-to-date
    collectionView.layoutIfNeeded()
    
    // Calculate and scroll to the bottom in one step
    let targetOffset = CGPoint(x: 0, y: maxContentOffsetY)
    collectionView.setContentOffset(targetOffset, animated: animated)
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
  
  /// Check if scrolled to bottom
  var isScrolledToBottom: Bool {
    isScrolledToBottom(tolerancePoints: 5)
  }
  
  func isScrolledToBottom(tolerancePoints: CGFloat) -> Bool {
    maxContentOffsetY - collectionView.contentOffset.y <= tolerancePoints
  }
}
