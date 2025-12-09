import SwiftUI
import Then
import TinyConstraints
import UIKit

final class ToBottomButton: UIButton {
  let baseConfig = UIImage.SymbolConfiguration(textStyle: .title1)

  private lazy var lightImage: UIImage? = {
    let paletteConfig = UIImage.SymbolConfiguration(paletteColors: [.secondaryLabel, .white])
    let finalConfig = baseConfig.applying(paletteConfig)
    let image = UIImage(systemName: "arrow.down.circle.fill", withConfiguration: finalConfig)
    return image
  }()

  private lazy var darkImage: UIImage? = {
    let paletteConfig = UIImage.SymbolConfiguration(paletteColors: [.white, .darkGray])
    let finalConfig = baseConfig.applying(paletteConfig)
    let image = UIImage(systemName: "arrow.down.circle.fill", withConfiguration: finalConfig)
    return image
  }()

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.shadowOffset = CGSizeMake(0, 1.0)
    layer.shadowOpacity = 0.22
    layer.shadowRadius = 8

    updateStyle()
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
      (_: ToBottomButton, _: UITraitCollection) in
      self.updateStyle()
    }
  }

  // MARK: - Style Updates

  private func updateStyle() {
    let isDarkMode = traitCollection.userInterfaceStyle == .dark

      if isDarkMode {
        layer.shadowColor = UIColor.lightGray.cgColor
        setImage(darkImage, for: .normal)
      } else {
        layer.shadowColor = UIColor.black.cgColor
        setImage(lightImage, for: .normal)
    }
  }
}

#Preview {
  ToBottomButton()
}
