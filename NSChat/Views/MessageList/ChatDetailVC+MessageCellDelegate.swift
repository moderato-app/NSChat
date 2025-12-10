import SwiftUI
import UIKit

// MARK: - MessageCellDelegate

extension ChatDetailVC: MessageCellDelegate {
  
  func messageCell(_ cell: MessageCell, didRequestDelete message: Message) {
    let alertController = UIAlertController(
      title: confirmDeleteTitle(for: message),
      message: "This message will be deleted.",
      preferredStyle: .actionSheet
    )
    
    let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      guard let self = self else { return }
      self.deleteMessage(message)
      HapticsService.shared.shake(.success)
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    
    alertController.addAction(deleteAction)
    alertController.addAction(cancelAction)
    
    // For iPad
    if let popoverController = alertController.popoverPresentationController {
      popoverController.sourceView = cell.bubbleView
      popoverController.sourceRect = cell.bubbleView.bounds
    }
    
    present(alertController, animated: true)
  }
  
  func messageCell(_ cell: MessageCell, didRequestCopy text: String) {
    HapticsService.shared.shake(.light)
  }
  
  func messageCell(_ cell: MessageCell, didRequestReuse text: String) {
    em?.reUseTextEvent.send(text)
    HapticsService.shared.shake(.light)
  }
  
  func messageCell(_ cell: MessageCell, didRequestShowInfo message: Message) {
    let infoView = Form {
      MessageMetaView(message: message)
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    
    let hostingController = UIHostingController(rootView: infoView)
    if let sheet = hostingController.sheetPresentationController {
      sheet.detents = [.medium()]
      sheet.prefersGrabberVisible = true
    }
    
    present(hostingController, animated: true)
    HapticsService.shared.shake(.light)
  }
  
  func messageCell(_ cell: MessageCell, didRequestSelectText text: String) {
    let selectTextView = SelectTextView(text)
      .presentationDetents(detentsForText(text))
    
    let hostingController = UIHostingController(rootView: selectTextView)
    if let sheet = hostingController.sheetPresentationController {
      if text.count <= 200 && text.split(separator: "\n").count < 10 {
        sheet.detents = [.medium()]
      } else {
        sheet.detents = [.large()]
      }
      sheet.prefersGrabberVisible = true
    }
    
    present(hostingController, animated: true)
  }
  
  func messageCell(_ cell: MessageCell, didDoubleTap message: Message) {
    guard let pref = pref else { return }
    
    let action = pref.doubleTapAction
    let text = cell.targetText()
    
    switch action {
    case .none:
      break
    case .reuse:
      em?.reUseTextEvent.send(text)
      HapticsService.shared.shake(.light)
    case .copy:
      UIPasteboard.general.string = text
      HapticsService.shared.shake(.light)
    case .showInfo:
      messageCell(cell, didRequestShowInfo: message)
    }
  }
  
  // MARK: - Helpers
  
  private func confirmDeleteTitle(for message: Message) -> String {
    let text = message.message.isEmpty ? message.errorInfo : message.message
    return text.count > 50 ? String(text.prefix(47)) + "..." : text
  }
  
  private func deleteMessage(_ message: Message) {
    modelContext?.delete(message)
    onMsgCountChange()
  }
  
  private func detentsForText(_ text: String) -> Set<PresentationDetent> {
    if text.count <= 200 && text.split(separator: "\n").count < 10 {
      return [.medium]
    } else {
      return [.large]
    }
  }
}
