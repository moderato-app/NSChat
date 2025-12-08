import UIKit

// MARK: - Actions

extension InputToolbar {
  @objc func clearTapped() {
    HapticsService.shared.shake(.light)
    onInputTextChanged?("")
  }

  @objc func webSearchTapped() {
    if let wso = chatOption.webSearchOption {
      wso.enabled.toggle()
    } else {
      let wso = WebSearch()
      wso.enabled = !cachedIsWebSearchEnabled
      chatOption.webSearchOption = wso
    }

    cachedIsWebSearchEnabled = chatOption.webSearchOption?.enabled ?? false
    updateWebSearchButton()

    HapticsService.shared.shake(.light)
  }

  func selectModel(_ model: ModelEntity) {
    chatOption.model = model
    em?.chatOptionChanged.send()
    updateModelButton()
  }

  func selectContextLength(_ length: Int) {
    chatOption.contextLength = length
    updateHistoryButton()
  }
}
