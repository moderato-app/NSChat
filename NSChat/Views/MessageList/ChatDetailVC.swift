import Combine
import os
import SwiftData
import SwiftUI
import UIKit
import TinyConstraints

// MARK: - ChatDetailVC

final class ChatDetailVC: UIViewController {
  // MARK: - Properties

  private(set) var chat: Chat
  var messages: [Message] = []
  var total = 10
  var cancellables = Set<AnyCancellable>()
  var inputTextDebounceSubject = PassthroughSubject<String, Never>()

  weak var em: EM?
  weak var pref: Pref?
  var modelContext: ModelContext?

  var onPresentInfo: (() -> Void)?
  var onPresentPrompt: (() -> Void)?

  // MARK: - UI Components

  lazy var collectionView: UICollectionView = {
    let layout = createLayout()
    let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
    cv.backgroundColor = .clear
    cv.translatesAutoresizingMaskIntoConstraints = false
    cv.delegate = self
    cv.keyboardDismissMode = .interactive
    cv.contentInsetAdjustmentBehavior = .automatic
    cv.alwaysBounceVertical = true
    return cv
  }()

  lazy var toBottomButton: UIButton = {
    let button = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
    let image = UIImage(systemName: "chevron.down.circle.fill", withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = .systemGray
    button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
    button.layer.cornerRadius = 20
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOffset = CGSize(width: 0, height: 2)
    button.layer.shadowRadius = 4
    button.layer.shadowOpacity = 0.15
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)
    button.alpha = 0
    button.transform = CGAffineTransform(scaleX: 0, y: 0)
    return button
  }()

  var showToBottomButton = false {
    didSet {
      guard showToBottomButton != oldValue else { return }
      UIView.animate(withDuration: 0.25) {
        self.toBottomButton.alpha = self.showToBottomButton ? 1 : 0
        self.toBottomButton.transform = self.showToBottomButton
          ? .identity
          : CGAffineTransform(scaleX: 0, y: 0)
      }
    }
  }

  // Input Area
  private lazy var inputContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var blurEffectView: UIVisualEffectView = {
    let blurEffect = UIBlurEffect(style: .systemMaterial)
    let view = UIVisualEffectView(effect: blurEffect)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var topSeparatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .separator
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  lazy var inputToolbar: InputToolbar = {
    let toolbar = InputToolbar(chatOption: chat.option)
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    toolbar.onInputTextChanged = { [weak self] text in
      self?.inputTextField.text = text
      self?.updateSendButton()
    }
    return toolbar
  }()

  private lazy var inputWrapperView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .secondarySystemBackground
    view.layer.cornerRadius = 18
    view.layer.borderWidth = 0.5
    view.layer.borderColor = UIColor.separator.cgColor
    return view
  }()

  lazy var inputTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "Message"
    textField.font = .preferredFont(forTextStyle: .body)
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.delegate = self
    textField.returnKeyType = .send
    textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    return textField
  }()

  lazy var sendButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "arrow.up.circle.fill")
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
    config.baseForegroundColor = .tintColor

    let button = UIButton(configuration: config)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    button.isHidden = true

    button.showsMenuAsPrimaryAction = false
    button.menu = buildSendMenu()

    return button
  }()

  var toBottomButtonBottomConstraint: NSLayoutConstraint?

  // MARK: - Data Source

  var dataSource: UICollectionViewDiffableDataSource<Section, PersistentIdentifier>!

  enum Section {
    case main
  }

  // MARK: - Init

  init(chat: Chat) {
    self.chat = chat
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    setupNavigationBar()
    setupDataSource()
    setupKeyboardObservers()
    setupInputDebounce()
    setupTraitObservers()
    loadMessages()
    loadInputText()
    subscribeToEvents()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    scrollToBottom(animated: false)
  }


  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    saveInputText()
  }

  // MARK: - Setup

  private func setupUI() {
    view.backgroundColor = .systemBackground

    view.addSubview(collectionView)
    view.addSubview(inputContainerView)
    view.addSubview(toBottomButton)
    inputContainerView.addSubview(blurEffectView)
    inputContainerView.addSubview(topSeparatorView)
    inputContainerView.addSubview(inputToolbar)
    inputContainerView.addSubview(inputWrapperView)
    inputWrapperView.addSubview(inputTextField)
    inputWrapperView.addSubview(sendButton)

    toBottomButtonBottomConstraint = toBottomButton.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -15)

    // Use keyboardLayoutGuide for proper keyboard handling (iOS 15+)
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),

      toBottomButton.widthAnchor.constraint(equalToConstant: 40),
      toBottomButton.heightAnchor.constraint(equalToConstant: 40),
      toBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
      toBottomButtonBottomConstraint!,

      // Input container uses keyboardLayoutGuide for keyboard-aware positioning
      inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      inputContainerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

      // Blur effect fills the input container and extends to bottom of screen
      blurEffectView.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
      blurEffectView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
      blurEffectView.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
      blurEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      // Top separator line
      topSeparatorView.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
      topSeparatorView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
      topSeparatorView.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
      topSeparatorView.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

      inputToolbar.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 6),
      inputToolbar.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 18),
      inputToolbar.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -18),
      inputToolbar.heightAnchor.constraint(equalToConstant: 32),

      inputWrapperView.topAnchor.constraint(equalTo: inputToolbar.bottomAnchor, constant: 6),
      inputWrapperView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 8),
      inputWrapperView.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -8),
      inputWrapperView.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -12),

      inputTextField.topAnchor.constraint(equalTo: inputWrapperView.topAnchor, constant: 8),
      inputTextField.leadingAnchor.constraint(equalTo: inputWrapperView.leadingAnchor, constant: 12),
      inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -4),
      inputTextField.bottomAnchor.constraint(equalTo: inputWrapperView.bottomAnchor, constant: -8),
      inputTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),

      sendButton.trailingAnchor.constraint(equalTo: inputWrapperView.trailingAnchor, constant: -4),
      sendButton.centerYAnchor.constraint(equalTo: inputWrapperView.centerYAnchor),
      sendButton.widthAnchor.constraint(equalToConstant: 32),
      sendButton.heightAnchor.constraint(equalToConstant: 32),
    ])

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGesture.cancelsTouchesInView = false
    collectionView.addGestureRecognizer(tapGesture)
  }

  private func setupNavigationBar() {
    navigationItem.largeTitleDisplayMode = .never

    // Setup navigation bar with blur effect
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
    appearance.backgroundColor = .clear

    navigationController?.navigationBar.standardAppearance = appearance
    navigationController?.navigationBar.scrollEdgeAppearance = appearance
    navigationController?.navigationBar.compactAppearance = appearance

    let infoButton = UIBarButtonItem(
      image: UIImage(systemName: "ellipsis.circle"),
      style: .plain,
      target: self,
      action: #selector(infoTapped)
    )
    navigationItem.rightBarButtonItem = infoButton
  }

  func configure(em: EM, pref: Pref, modelContext: ModelContext) {
    self.em = em
    self.pref = pref
    self.modelContext = modelContext
    inputToolbar.configure(modelContext: modelContext, em: em)
  }

  private func createLayout() -> UICollectionViewCompositionalLayout {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(60)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(60)
    )
    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 17
    section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

    return UICollectionViewCompositionalLayout(section: section)
  }

  private func setupDataSource() {
    let cellRegistration = UICollectionView.CellRegistration<MessageCell, PersistentIdentifier> { [weak self] cell, _, messageID in
      guard let self = self,
            let message = self.messages.first(where: { $0.id == messageID }),
            let em = self.em,
            let pref = self.pref
      else { return }

      cell.configure(with: message, em: em, pref: pref) { [weak self] in
        self?.onMsgCountChange()
      }
    }

    dataSource = UICollectionViewDiffableDataSource<Section, PersistentIdentifier>(collectionView: collectionView) {
      collectionView, indexPath, identifier in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
    }
  }

  private func setupInputDebounce() {
    inputTextDebounceSubject
      .debounce(for: .seconds(1), scheduler: RunLoop.main)
      .sink { [weak self] value in
        self?.chat.input = value
      }
      .store(in: &cancellables)
  }

  private func setupTraitObservers() {
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (viewController: Self, _) in
      self?.inputWrapperView.layer.borderColor = UIColor.separator.cgColor
    }
  }

  // MARK: - Navigation Actions

  @objc private func infoTapped() {
    onPresentInfo?()
    HapticsService.shared.shake(.light)
  }

  func updateChat(_ chat: Chat) {
    self.chat = chat
    reloadMessages(animated: false)
    scrollToBottom(animated: false)
    loadInputText()
    inputToolbar.reloadData()
  }
}
