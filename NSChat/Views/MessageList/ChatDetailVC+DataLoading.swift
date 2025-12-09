import Foundation
import SwiftData
import UIKit

// MARK: - Data Loading

extension ChatDetailVC {
  func loadMessages() {
    messages = chat.messages
      .sorted { $0.createdAt > $1.createdAt }
      .prefix(total)
      .reversed()

    applySnapshot(animatingDifferences: false)
    updateSendMenuIfNeeded()
  }

  func reloadMessages(animated: Bool = true) {
    total = 10
    loadMessages()
    if animated {
      applySnapshot(animatingDifferences: true)
    }
  }

  func applySnapshot(animatingDifferences: Bool) {
    var snapshot = NSDiffableDataSourceSnapshot<ChatDetailVC.Section, PersistentIdentifier>()
    snapshot.appendSections([.main])
    snapshot.appendItems(messages.map { $0.id }, toSection: .main)
    dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
  }

  func onMsgCountChange() {
    let animated = total <= 20
    total = 10

    Task { @MainActor in
      try? await Task.sleep(for: .seconds(0.05))
      self.loadMessages()
      self.applySnapshot(animatingDifferences: animated)

      try? await Task.sleep(for: .seconds(1))
      self.loadMessages()
      self.applySnapshot(animatingDifferences: animated)
    }
  }

  func loadInputText() {
    inputTextField.text = chat.input
    updateSendButton()
    inputToolbar.updateInputText(chat.input)
  }

  func saveInputText() {
    chat.input = inputTextField.text ?? ""
  }
}
