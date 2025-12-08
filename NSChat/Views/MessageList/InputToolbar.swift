import Combine
import os
import SwiftData
import UIKit

// MARK: - InputToolbar

final class InputToolbar: UIView {
  // MARK: - Properties

  var chatOption: ChatOption
  var modelContext: ModelContext?
  var cancellables = Set<AnyCancellable>()

  weak var em: EM?

  var cachedModels: [ModelEntity] = []
  var cachedProviders: [Provider] = []
  var cachedIsWebSearchEnabled = false
  var cachedIsWebSearchAvailable = false

  var onInputTextChanged: ((String) -> Void)?
  var currentInputText: String = ""

  // MARK: - UI Components

  private lazy var stackView: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 8
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }()

  lazy var clearButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "xmark.circle.fill")
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .light)
    config.baseForegroundColor = .tertiaryLabel

    let button = UIButton(configuration: config)
    button.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
    button.isHidden = true
    return button
  }()

  lazy var modelButton: UIButton = {
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

  lazy var historyButton: UIButton = {
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

  lazy var webSearchButton: UIButton = {
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
}
