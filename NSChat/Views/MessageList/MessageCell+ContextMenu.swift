import UIKit

// MARK: - Context Menu

extension MessageCell: UIContextMenuInteractionDelegate {
  
  func setupContextMenu() {
    let interaction = UIContextMenuInteraction(delegate: self)
    bubbleView.addInteraction(interaction)
  }
  
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let message = message else { return nil }
    
    return UIContextMenuConfiguration(
      identifier: nil,
      previewProvider: nil
    ) { [weak self] _ in
      self?.createContextMenu(for: message)
    }
  }
  
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    
    let path = UIBezierPath(
      roundedRect: bubbleView.bounds,
      cornerRadius: MessageLayoutConstants.bubbleCornerRadius
    )
    parameters.visiblePath = path
    
    return UITargetedPreview(view: bubbleView, parameters: parameters)
  }
  
  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {
    contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration)
  }
  
  private func createContextMenu(for message: Message) -> UIMenu {
    var actions: [UIAction] = []
    
    // Copy action
    let copyAction = UIAction(
      title: "Copy",
      image: UIImage(systemName: "doc.on.doc")
    ) { [weak self] _ in
      guard let self = self else { return }
      let text = self.targetText()
      UIPasteboard.general.string = text
      self.delegate?.messageCell(self, didRequestCopy: text)
    }
    actions.append(copyAction)
    
    // Select Text action
    let selectTextAction = UIAction(
      title: "Select Text",
      image: UIImage(systemName: "selection.pin.in.out")
    ) { [weak self] _ in
      guard let self = self else { return }
      self.delegate?.messageCell(self, didRequestSelectText: self.targetText())
    }
    actions.append(selectTextAction)
    
    // Reuse action
    let reuseAction = UIAction(
      title: "Reuse",
      image: UIImage(systemName: "highlighter")
    ) { [weak self] _ in
      guard let self = self else { return }
      self.delegate?.messageCell(self, didRequestReuse: self.targetText())
    }
    actions.append(reuseAction)
    
    // Translate action (iOS 17.4+)
    if #available(iOS 17.4, *) {
      let translateAction = UIAction(
        title: "Translate",
        image: UIImage(systemName: "translate")
      ) { [weak self] _ in
        // Translation will be handled by the delegate
        guard let self = self, let message = self.message else { return }
        self.delegate?.messageCell(self, didRequestShowInfo: message)
      }
      actions.append(translateAction)
    }
    
    // Info action
    let infoAction = UIAction(
      title: "Info",
      image: UIImage(systemName: "info.square")
    ) { [weak self] _ in
      guard let self = self, let message = self.message else { return }
      self.delegate?.messageCell(self, didRequestShowInfo: message)
    }
    actions.append(infoAction)
    
    // Delete action (destructive, in separate section)
    let deleteAction = UIAction(
      title: "Delete",
      image: UIImage(systemName: "trash"),
      attributes: .destructive
    ) { [weak self] _ in
      guard let self = self, let message = self.message else { return }
      self.delegate?.messageCell(self, didRequestDelete: message)
    }
    
    let mainMenu = UIMenu(title: "", options: .displayInline, children: actions)
    let deleteMenu = UIMenu(title: "", options: .displayInline, children: [deleteAction])
    
    return UIMenu(title: "", children: [mainMenu, deleteMenu])
  }
}

// MARK: - Double Tap Gesture

extension MessageCell {
  
  func setupDoubleTapGesture() {
    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
    doubleTap.numberOfTapsRequired = 2
    bubbleView.addGestureRecognizer(doubleTap)
  }
  
  @objc private func handleDoubleTap() {
    guard let message = message else { return }
    delegate?.messageCell(self, didDoubleTap: message)
  }
}

// MARK: - Make bubbleView accessible

extension MessageCell {
  
  func addInteractionToBubble(_ interaction: UIInteraction) {
    bubbleView.addInteraction(interaction)
  }
}
