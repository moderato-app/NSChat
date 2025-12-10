import UIKit

// MARK: - UICollectionViewDelegateFlowLayout

extension ChatDetailVC: UICollectionViewDelegateFlowLayout {
  
  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    guard indexPath.item < messages.count else {
      return CGSize(width: collectionView.bounds.width, height: MessageLayoutConstants.minMessageHeight)
    }
    
    let message = messages[indexPath.item]
    let width = collectionView.bounds.width
    let height = MessageCellSizing.calculateHeight(for: message, maxWidth: width)
    
    return CGSize(width: width, height: height)
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    minimumLineSpacingForSectionAt section: Int
  ) -> CGFloat {
    MessageLayoutConstants.messageSpacing
  }
  
  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    insetForSectionAt section: Int
  ) -> UIEdgeInsets {
    UIEdgeInsets(
      top: MessageLayoutConstants.collectionViewTopInset,
      left: 0,
      bottom: MessageLayoutConstants.collectionViewBottomInset,
      right: 0
    )
  }
}
