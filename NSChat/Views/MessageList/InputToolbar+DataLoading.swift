import os
import SwiftData
import UIKit

// MARK: - Data Loading & UI Updates

extension InputToolbar {
  func reloadData() {
    cachedIsWebSearchAvailable = chatOption.model?.provider.type.isWebSearchAvailable ?? false
    cachedIsWebSearchEnabled = chatOption.webSearchOption?.enabled ?? false

    guard let modelContext = modelContext else { return }

    do {
      let providerDescriptor = FetchDescriptor<Provider>(
        predicate: #Predicate<Provider> { $0.enabled }
      )
      cachedProviders = try modelContext.fetch(providerDescriptor)

      let modelDescriptor = FetchDescriptor<ModelEntity>()
      cachedModels = try modelContext.fetch(modelDescriptor)
    } catch {
      AppLogger.error.error("Failed to fetch toolbar data: \(error.localizedDescription)")
    }

    updateModelButton()
    updateHistoryButton()
    updateWebSearchButton()
  }

  func onTextChanged(isEmpty: Bool) {
    if isEmpty, !self.clearButton.isHidden {
      UIView.animate(withDuration: 0.2) {
        self.clearButton.isHidden = true
      }
    } else if self.clearButton.isHidden {
      UIView.animate(withDuration: 0.2) {
        self.clearButton.isHidden = false
      }
    }
  }

  func updateModelButton() {
    let title: String
    if let model = chatOption.model {
      title = model.resolvedName
    } else {
      title = "Select Model"
    }

    var config = modelButton.configuration
    config?.title = title

    let chevron = UIImage(systemName: "chevron.up.chevron.down")?
      .withConfiguration(UIImage.SymbolConfiguration(pointSize: 8, weight: .regular))
    config?.image = chevron
    config?.imagePlacement = .trailing
    config?.imagePadding = 4
    config?.baseForegroundColor = chatOption.model == nil ? .secondaryLabel : .label

    modelButton.configuration = config
    modelButton.menu = buildModelMenu()
  }

  func updateHistoryButton() {
    let length = chatOption.contextLength
    let title = length == Int.max ? "∞" : "\(length)"

    var config = historyButton.configuration
    config?.title = title

    let chevron = UIImage(systemName: "chevron.up.chevron.down")?
      .withConfiguration(UIImage.SymbolConfiguration(pointSize: 8, weight: .regular))
    config?.image = chevron
    config?.imagePlacement = .trailing
    config?.imagePadding = 4

    if length == 0 {
      config?.baseForegroundColor = .secondaryLabel
    } else if length == Int.max {
      config?.baseForegroundColor = .systemOrange
    } else {
      config?.baseForegroundColor = .label
    }

    historyButton.configuration = config
    historyButton.menu = buildHistoryMenu()
  }

  func updateWebSearchButton() {
    webSearchButton.isHidden = !cachedIsWebSearchAvailable

    var config = webSearchButton.configuration
    config?.baseForegroundColor = cachedIsWebSearchEnabled ? .tintColor : .secondaryLabel
    webSearchButton.configuration = config
  }
}
