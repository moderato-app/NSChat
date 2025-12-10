import Combine
import os
import SwiftData
import SwiftUI
import Then
import TinyConstraints
import UIKit

// MARK: - ChatDetailVC

final class ChatDetailVC: UIViewController {
  // MARK: - Properties

  private(set) var chat: Chat
  var messages: [Message] = []
  var total = 10
  var cancellables = Set<AnyCancellable>()
  var inputTextDebounceSubject = PassthroughSubject<String, Never>()
  var lastMessageCount = 0

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
    let button = ToBottomButton()
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)
    button.alpha = 0
    button.transform = CGAffineTransform(scaleX: 0, y: 0)
    return button
  }()

  var showToBottomButton = false {
    didSet {
      guard showToBottomButton != oldValue else { return }
      animateToBottomButtonVisibility(showToBottomButton)
    }
  }

  private func animateToBottomButtonVisibility(_ show: Bool) {
    toBottomButton.layer.removeAllAnimations()
    UIView.animate(
      withDuration: 0.25,
      delay: 0,
      options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
    ) {
      self.toBottomButton.alpha = show ? 1 : 0
      self.toBottomButton.transform = show ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
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
    textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    return textField
  }()

  lazy var sendButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "arrow.up.circle.fill")
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
      pointSize: 24, weight: .bold
    )
    config.baseForegroundColor = .tintColor

    let button = UIButton(configuration: config)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    button.isHidden = true

    button.showsMenuAsPrimaryAction = false

    return button
  }()

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
    setupInputDebounce()
    setupTraitObservers()
    loadMessages()
    loadInputText()
    subscribeToEvents()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureNavigationBarAppearance()
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

    // Constraints
    collectionView.edges(to: view, excluding: .bottom)
    collectionView.bottomToTop(of: inputContainerView)

    inputContainerView.leading(to: view)
    inputContainerView.trailing(to: view)
    inputContainerView.bottom(to: view, view.keyboardLayoutGuide.topAnchor)

    toBottomButton.size(.init(width: 40, height: 40))
    toBottomButton.bottomToTop(of: inputContainerView, offset: -15)
    toBottomButton.trailing(to: view, offset: -15)

    // Blur effect fills the input container and extends to bottom of screen
    blurEffectView.edges(to: inputContainerView, excluding: .bottom)
    blurEffectView.bottom(to: view)

    // Top separator line
    topSeparatorView.edges(to: inputContainerView, excluding: .bottom)
    topSeparatorView.height(1.0 / UIScreen.main.scale)

    inputToolbar.top(to: inputContainerView, offset: 6)
    inputToolbar.leading(to: inputContainerView, offset: 6)
    inputToolbar.trailing(to: inputContainerView, offset: -6)
    inputToolbar.height(32)

    inputWrapperView.topToBottom(of: inputToolbar, offset: 6)
    inputWrapperView.edges(to: inputContainerView, excluding: .top, insets: .uniform(6))

    inputTextField.height(24, relation: .equalOrGreater)
    inputTextField.edges(to: inputWrapperView, excluding: .trailing, insets: .uniform(6))
    inputTextField.trailingToLeading(of: sendButton, offset: -4)

    sendButton.size(.init(width: 32, height: 32))
    sendButton.centerX(to: inputWrapperView)
    sendButton.trailing(to: inputWrapperView, offset: -4)

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGesture.cancelsTouchesInView = false
    collectionView.addGestureRecognizer(tapGesture)
  }

  private func setupNavigationBar() {
    navigationItem.largeTitleDisplayMode = .never

    // Setup right bar button
    let infoButton = UIBarButtonItem(
      image: UIImage(systemName: "ellipsis.circle"),
      style: .plain,
      target: self,
      action: #selector(infoTapped)
    )
    navigationItem.rightBarButtonItem = infoButton

    guard let navigationBar = navigationController?.navigationBar else { return }
    navigationBar.topItem?.setRightBarButtonItems([infoButton], animated: false)
  }

  private func configureNavigationBarAppearance() {
    guard let navigationBar = navigationController?.navigationBar else { return }

    // Setup navigation bar with blur effect
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

    navigationBar.standardAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
    navigationBar.compactAppearance = appearance
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
    section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10)

    return UICollectionViewCompositionalLayout(section: section)
  }

  private func setupDataSource() {
    let cellRegistration = UICollectionView.CellRegistration<MessageCell, PersistentIdentifier> {
      [weak self] cell, _, messageID in
      guard let self = self,
            let message = self.messages.first(where: { $0.id == messageID }),
            let em = self.em,
            let pref = self.pref
      else { return }

      cell.configure(with: message, em: em, pref: pref) { [weak self] in
        self?.onMsgCountChange()
      }
    }

    dataSource = UICollectionViewDiffableDataSource<Section, PersistentIdentifier>(
      collectionView: collectionView
    ) {
      collectionView, indexPath, identifier in
      collectionView.dequeueConfiguredReusableCell(
        using: cellRegistration, for: indexPath, item: identifier
      )
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
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: Self, _) in
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
    loadMessages(resetTotal: true, animated: false)
    scrollToBottom(animated: false)
    loadInputText()
    inputToolbar.reloadData()
  }
}
