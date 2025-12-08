import UIKit

// MARK: - Menu Building

extension InputToolbar {
  func buildModelMenu() -> UIMenu {
    var menuChildren: [UIMenuElement] = []

    // Favorites section
    let favoritedModels = cachedModels.filter { $0.favorited }
    let sortedFavorites = ModelEntity.smartSort(favoritedModels)

    if !sortedFavorites.isEmpty {
      let favoriteActions = sortedFavorites.map { model in
        UIAction(
          title: model.resolvedName,
          image: model.id == chatOption.model?.id ? UIImage(systemName: "checkmark") : nil
        ) { [weak self] _ in
          self?.selectModel(model)
        }
      }
      let favoritesMenu = UIMenu(title: "Favorites", image: UIImage(systemName: "star.fill"), children: favoriteActions)
      menuChildren.append(favoritesMenu)
    }

    // Provider groups
    let grouped = cachedModels.groupedByProvider().filter { $0.provider.enabled }
    let sortedGroups = grouped.sorted { $0.provider.displayName < $1.provider.displayName }

    if !sortedGroups.isEmpty {
      let providerMenus = sortedGroups.map { group -> UIMenu in
        let modelActions = group.models.map { model in
          UIAction(
            title: model.resolvedName,
            image: model.id == chatOption.model?.id ? UIImage(systemName: "checkmark") : nil
          ) { [weak self] _ in
            self?.selectModel(model)
          }
        }
        return UIMenu(title: group.provider.displayName, children: modelActions)
      }

      let providersMenu = UIMenu(title: "Providers", image: UIImage(systemName: "bolt.fill"), options: .displayInline, children: providerMenus)
      menuChildren.append(providersMenu)
    }

    return UIMenu(children: menuChildren)
  }

  func buildHistoryMenu() -> UIMenu {
    let choices = contextLengthChoices.reversed()
    let actions = choices.map { choice in
      UIAction(
        title: choice.lengthString,
        image: chatOption.contextLength == choice.length ? UIImage(systemName: "checkmark") : nil
      ) { [weak self] _ in
        self?.selectContextLength(choice.length)
      }
    }

    let header = UIAction(title: "History Messages", image: UIImage(systemName: "clock.fill"), attributes: .disabled) { _ in }
    return UIMenu(children: [header] + actions)
  }
}
