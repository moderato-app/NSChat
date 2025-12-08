import Combine
import os
import SwiftData
import UIKit

// MARK: - InputToolbar

final class InputToolbar: UIView {
  // MARK: - Properties

  private var chatOption: ChatOption
  private var modelContext: ModelContext?
  private var cancellables = Set<AnyCancellable>()

  weak var em: EM?

  private var cachedModels: [ModelEntity] = []
  private var cachedProviders: [Provider] = []
  private var cachedIsWebSearchEnabled = false
  private var cachedIsWebSearchAvailable = false

  var onInputTextChanged: ((String) -> Void)?
  private var currentInputText: String = ""

  // MARK: - UI Components

  private lazy var stackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 8
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  private lazy var clearButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "xmark.circle.fill")
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .light)
    config.baseForegroundColor = .tertiaryLabel

    let button = UIButton(configuration: config)
    button.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
    button.isHidden = true
    return button
  }()

  private lazy var modelButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var outgoing = incoming
      outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
      return outgoing
    }
    config.baseForegroundColor = .label
    config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)

    let button = UIButton(configuration: config)
    button.showsMenuAsPrimaryAction = true
    button.changesSelectionAsPrimaryAction = false
    return button
  }()

  private lazy var historyButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var outgoing = incoming
      outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
      return outgoing
    }
    config.baseForegroundColor = .label
    config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)

    let button = UIButton(configuration: config)
    button.showsMenuAsPrimaryAction = true
    button.changesSelectionAsPrimaryAction = false
    return button
  }()

  private lazy var webSearchButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "globe")
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
    config.baseForegroundColor = .secondaryLabel

    let button = UIButton(configuration: config)
    button.addTarget(self, action: #selector(webSearchTapped), for: .touchUpInside)
    button.isHidden = true
    return button
  }()

  private lazy var spacerView: UIView = {
    let view = UIView()
    view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return view
  }()

  // MARK: - Init

  init(chatOption: ChatOption) {
    self.chatOption = chatOption
    super.init(frame: .zero)
    setupUI()
    reloadData()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setupUI() {
    addSubview(stackView)

    stackView.addArrangedSubview(clearButton)
    stackView.addArrangedSubview(modelButton)
    stackView.addArrangedSubview(historyButton)
    stackView.addArrangedSubview(webSearchButton)
    stackView.addArrangedSubview(spacerView)

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    updateModelButton()
    updateHistoryButton()
  }

  func configure(modelContext: ModelContext, em: EM) {
    self.modelContext = modelContext
    self.em = em

    em.chatOptionChanged
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        self?.reloadData()
      }
      .store(in: &cancellables)

    reloadData()
  }

  // MARK: - Data Loading

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

  // MARK: - Update UI

  func updateInputText(_ text: String) {
    currentInputText = text
    UIView.animate(withDuration: 0.2) {
      self.clearButton.isHidden = text.isEmpty
    }
  }

  private func updateModelButton() {
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

  private func updateHistoryButton() {
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

  private func updateWebSearchButton() {
    webSearchButton.isHidden = !cachedIsWebSearchAvailable

    var config = webSearchButton.configuration
    config?.baseForegroundColor = cachedIsWebSearchEnabled ? .tintColor : .secondaryLabel
    webSearchButton.configuration = config
  }

  // MARK: - Menus

  private func buildModelMenu() -> UIMenu {
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

  private func buildHistoryMenu() -> UIMenu {
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

  // MARK: - Actions

  @objc private func clearTapped() {
    HapticsService.shared.shake(.light)
    onInputTextChanged?("")
  }

  @objc private func webSearchTapped() {
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

  private func selectModel(_ model: ModelEntity) {
    chatOption.model = model
    em?.chatOptionChanged.send()
    updateModelButton()
  }

  private func selectContextLength(_ length: Int) {
    chatOption.contextLength = length
    updateHistoryButton()
  }
}

