import SwiftData
import UIKit

// MARK: - Input Actions

extension ChatDetailVC {
  @objc func textFieldDidChange() {
    let text = inputTextField.text ?? ""
    updateSendButton()
    inputToolbar.updateInputText(text)
    inputTextDebounceSubject.send(text)
  }

  func updateSendButton() {
    let hasText = !(inputTextField.text ?? "").isEmpty
    let hasModel = chat.option.model != nil

    UIView.animate(withDuration: 0.2) {
      self.sendButton.isHidden = !hasText
      self.sendButton.isEnabled = hasModel
    }
  }

  func updateSendMenuIfNeeded() {
    let currentCount = chat.messages.count
    guard currentCount != lastMessageCount else { return }
    lastMessageCount = currentCount
    sendButton.menu = buildSendMenu()
  }

  @objc func sendTapped() {
    send(chat.option.contextLength)
  }

  func send(_ contextLength: Int) {
    guard let model = chat.option.model,
          let text = inputTextField.text,
          !text.isEmpty,
          let modelContext = modelContext,
          let em = em
    else { return }

    inputTextField.text = ""
    updateSendButton()
    inputToolbar.updateInputText("")
    inputTextField.resignFirstResponder()

    ChatSendService.shared.sendMessage(
      text: text,
      chat: chat,
      contextLength: contextLength,
      model: model,
      modelContext: modelContext,
      em: em
    )
  }

  func buildSendMenu() -> UIMenu {
    let count = chat.messages.count
    var actions: [UIAction] = []

    if count >= 20 {
      for i in [0, 1, 2, 3, 4, 6, 8, 10].reversed() {
        actions.append(UIAction(title: "\(i)") { [weak self] _ in
          self?.send(i)
        })
      }
      actions.append(UIAction(title: "20") { [weak self] _ in self?.send(20) })
      if count >= 50 {
        actions.append(UIAction(title: "50") { [weak self] _ in self?.send(50) })
      }
      actions.append(UIAction(title: "(all) \(count)") { [weak self] _ in self?.send(count) })
    } else {
      for i in (0 ... min(count, 10)).reversed() {
        let title = i == count ? "(all) \(i)" : "\(i)"
        actions.append(UIAction(title: title) { [weak self] _ in self?.send(i) })
      }
      if count > 10 {
        actions.insert(UIAction(title: "(all) \(count)") { [weak self] _ in self?.send(count) }, at: 0)
      }
    }

    return UIMenu(title: "History Messages", children: actions)
  }

  @objc func dismissKeyboard() {
    view.endEditing(true)
  }
}
