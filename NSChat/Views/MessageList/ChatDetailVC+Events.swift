import Combine
import Foundation
import UIKit

// MARK: - Events

extension ChatDetailVC {
  func subscribeToEvents() {
    guard let em = em else { return }

    em.messageEvent
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        self?.handleMessageEvent(event)
      }
      .store(in: &cancellables)

    em.reUseTextEvent
      .receive(on: DispatchQueue.main)
      .sink { [weak self] text in
        self?.handleReuseText(text)
      }
      .store(in: &cancellables)
  }

  private func handleMessageEvent(_ event: MessageEventType) {
    switch event {
    case .new:
      onMsgCountChange()
      scrollToBottom(animated: true)
      HapticsService.shared.shake(.light)
    case .countChanged:
      onMsgCountChange()
    case .eof:
      streamingMessageId = nil
      Task {
        await sleepFor(0.2)
        HapticsService.shared.shake(.success)
      }
    case .err:
      streamingMessageId = nil
      Task {
        await sleepFor(0.2)
        HapticsService.shared.shake(.error)
      }
    }
  }

  private func handleReuseText(_ text: String) {
    guard !text.isEmpty else { return }

    var currentText = inputTextField.text ?? ""

    if currentText.hasSuffix(text + " ") {
      currentText.removeLast((text + " ").count)
    } else if currentText.hasSuffix(text) {
      currentText.removeLast(text.count)
    } else {
      if !currentText.isEmpty, let last = currentText.last, !["\n", " ", "\t"].contains(last) {
        currentText += " "
      }
      currentText += text
    }

    inputTextField.text = currentText
    updateSendButton()
    inputToolbar.onTextChanged(isEmpty: currentText.isEmpty)
  }
}
