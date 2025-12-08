import Combine
import SwiftData
import SwiftUI
import UIKit

// MARK: - MessageCell

final class MessageCell: UICollectionViewCell {
  static let reuseIdentifier = "MessageCell"

  var message: Message?
  var deleteCallback: (() -> Void)?
  weak var em: EM?
  weak var pref: Pref?

  private var hostingConfiguration: UIHostingConfiguration<AnyView, EmptyView>?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(
    with message: Message,
    em: EM,
    pref: Pref,
    deleteCallback: @escaping () -> Void
  ) {
    self.message = message
    self.em = em
    self.pref = pref
    self.deleteCallback = deleteCallback

    updateContent()
  }

  private func updateContent() {
    guard let message = message,
          let em = em,
          let pref = pref,
          let deleteCallback = deleteCallback
    else { return }

    contentConfiguration = UIHostingConfiguration {
      AnyView(
        MessageCellContent(
          msg: message,
          deleteCallback: deleteCallback
        )
        .environmentObject(em)
        .environmentObject(pref)
      )
    }
    .margins(.all, 0)
  }

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
      if let existingBlur = contentView.layer.filters as? [Any],
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

  override func prepareForReuse() {
    super.prepareForReuse()
    message = nil
    deleteCallback = nil
    em = nil
    pref = nil
    resetTransform()
  }
}
