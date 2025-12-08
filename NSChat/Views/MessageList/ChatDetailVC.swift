import Combine
import os
import SwiftData
import SwiftUI
import UIKit

// MARK: - ChatDetailVC

final class ChatDetailVC: UIViewController {
  // MARK: - Properties

  private(set) var chat: Chat
  private var messages: [Message] = []
  private var total = 10
  private var cancellables = Set<AnyCancellable>()
  private var inputTextDebounceSubject = PassthroughSubject<String, Never>()

  weak var em: EM?
  weak var pref: Pref?
  var modelContext: ModelContext?

  var onPresentInfo: (() -> Void)?
  var onPresentPrompt: (() -> Void)?

  // MARK: - UI Components

  private lazy var collectionView: UICollectionView = {
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

  private lazy var toBottomButton: UIButton = {
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

  private var showToBottomButton = false {
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
    let blurEffect = UIBlurEffect(style: .systemThinMaterial)
    let view = UIVisualEffectView(effect: blurEffect)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var inputToolbar: InputToolbar = {
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
    view.layer.cornerRadius = 15
    view.layer.borderWidth = 0.5
    view.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.5).cgColor
    return view
  }()

  private lazy var inputTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "Message"
    textField.font = .preferredFont(forTextStyle: .body)
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.delegate = self
    textField.returnKeyType = .send
    textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    return textField
  }()

  private lazy var sendButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "arrow.up.circle.fill")
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
    config.baseForegroundColor = .tintColor

    let button = UIButton(configuration: config)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    button.isHidden = true

    // Add context menu for history selection
    button.showsMenuAsPrimaryAction = false
    button.menu = buildSendMenu()

    return button
  }()

  private var inputContainerBottomConstraint: NSLayoutConstraint?
  private var toBottomButtonBottomConstraint: NSLayoutConstraint?

  // MARK: - Data Source

  private var dataSource: UICollectionViewDiffableDataSource<Section, Message.ID>!

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

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    inputWrapperView.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.5).cgColor
  }

  // MARK: - Setup

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Add collection view
    view.addSubview(collectionView)
    view.addSubview(toBottomButton)

    // Add input container
    view.addSubview(inputContainerView)
    inputContainerView.addSubview(blurEffectView)
    inputContainerView.addSubview(inputToolbar)
    inputContainerView.addSubview(inputWrapperView)
    inputWrapperView.addSubview(inputTextField)
    inputWrapperView.addSubview(sendButton)

    inputContainerBottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    toBottomButtonBottomConstraint = toBottomButton.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -15)

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),

      toBottomButton.widthAnchor.constraint(equalToConstant: 40),
      toBottomButton.heightAnchor.constraint(equalToConstant: 40),
      toBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
      toBottomButtonBottomConstraint!,

      inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      inputContainerBottomConstraint!,

      blurEffectView.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
      blurEffectView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
      blurEffectView.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
      blurEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      inputToolbar.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
      inputToolbar.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 18),
      inputToolbar.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -18),
      inputToolbar.heightAnchor.constraint(equalToConstant: 32),

      inputWrapperView.topAnchor.constraint(equalTo: inputToolbar.bottomAnchor, constant: 6),
      inputWrapperView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 8),
      inputWrapperView.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -8),
      inputWrapperView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

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

    // Tap gesture to dismiss keyboard
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGesture.cancelsTouchesInView = false
    collectionView.addGestureRecognizer(tapGesture)
  }

  private func setupNavigationBar() {
    navigationItem.largeTitleDisplayMode = .never

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
    section.interGroupSpacing = 0
    section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

    return UICollectionViewCompositionalLayout(section: section)
  }

  private func setupDataSource() {
    let cellRegistration = UICollectionView.CellRegistration<MessageCell, Message.ID> { [weak self] cell, _, messageID in
      guard let self = self,
            let message = self.messages.first(where: { $0.id == messageID }),
            let em = self.em,
            let pref = self.pref
      else { return }

      cell.configure(with: message, em: em, pref: pref) { [weak self] in
        self?.onMsgCountChange()
      }
    }

    dataSource = UICollectionViewDiffableDataSource<Section, Message.ID>(collectionView: collectionView) {
      collectionView, indexPath, identifier in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
    }
  }

  private func setupKeyboardObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  private func setupInputDebounce() {
    inputTextDebounceSubject
      .debounce(for: .seconds(1), scheduler: RunLoop.main)
      .sink { [weak self] value in
        self?.chat.input = value
      }
      .store(in: &cancellables)
  }
}

// MARK: - Data Loading

extension ChatDetailVC {
  private func loadMessages() {
    messages = chat.messages
      .sorted { $0.createdAt > $1.createdAt }
      .prefix(total)
      .reversed()

    applySnapshot(animatingDifferences: false)
  }

  func reloadMessages(animated: Bool = true) {
    total = 10
    loadMessages()
    if animated {
      applySnapshot(animatingDifferences: true)
    }
  }

  private func applySnapshot(animatingDifferences: Bool) {
    var snapshot = NSDiffableDataSourceSnapshot<Section, Message.ID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(messages.map { $0.id }, toSection: .main)
    dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
  }

  private func onMsgCountChange() {
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

  private func loadInputText() {
    inputTextField.text = chat.input
    updateSendButton()
    inputToolbar.updateInputText(chat.input)
  }

  private func saveInputText() {
    chat.input = inputTextField.text ?? ""
  }
}

// MARK: - Events

extension ChatDetailVC {
  private func subscribeToEvents() {
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
      var snapshot = dataSource.snapshot()
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
      dataSource.apply(snapshot, animatingDifferences: false)
      Task {
        await sleepFor(0.2)
        HapticsService.shared.shake(.success)
      }
    case .err:
      var snapshot = dataSource.snapshot()
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
      dataSource.apply(snapshot, animatingDifferences: false)
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
    inputToolbar.updateInputText(currentText)
  }
}

// MARK: - Scrolling

extension ChatDetailVC {
  func scrollToBottom(animated: Bool) {
    guard !messages.isEmpty else { return }
    let lastIndex = IndexPath(item: messages.count - 1, section: 0)
    collectionView.scrollToItem(at: lastIndex, at: .bottom, animated: animated)
  }

  @objc private func scrollToBottomTapped() {
    scrollToBottom(animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      HapticsService.shared.shake(.light)
    }
  }

  private func updateShowToBottomButton() {
    let contentHeight = collectionView.contentSize.height
    let containerHeight = collectionView.bounds.height
    let contentOffsetY = collectionView.contentOffset.y

    let distanceToBottom = contentHeight - (contentOffsetY + containerHeight)
    let threshold = containerHeight * 1.5
    let shouldShow = distanceToBottom >= threshold

    if shouldShow != showToBottomButton {
      showToBottomButton = shouldShow
    }
  }
}

// MARK: - Magic Scroll

extension ChatDetailVC {
  private func applyMagicScrollEffects() {
    guard pref?.magicScrolling == true else {
      resetAllCellTransforms()
      return
    }

    let screenHeight = UIScreen.main.bounds.height

    for cell in collectionView.visibleCells {
      guard let messageCell = cell as? MessageCell else { continue }

      let cellFrame = cell.frame
      let frameInView = collectionView.convert(cellFrame, to: view)
      let minY = frameInView.minY

      messageCell.applyMagicScrollEffect(
        minY: minY,
        cellHeight: cellFrame.height,
        screenHeight: screenHeight
      )
    }
  }

  private func resetAllCellTransforms() {
    for cell in collectionView.visibleCells {
      (cell as? MessageCell)?.resetTransform()
    }
  }
}

// MARK: - Input Actions

extension ChatDetailVC {
  @objc private func textFieldDidChange() {
    let text = inputTextField.text ?? ""
    updateSendButton()
    inputToolbar.updateInputText(text)
    inputTextDebounceSubject.send(text)
  }

  private func updateSendButton() {
    let hasText = !(inputTextField.text ?? "").isEmpty
    let hasModel = chat.option.model != nil

    UIView.animate(withDuration: 0.2) {
      self.sendButton.isHidden = !hasText
      self.sendButton.isEnabled = hasModel
    }

    sendButton.menu = buildSendMenu()
  }

  @objc private func sendTapped() {
    send(chat.option.contextLength)
  }

  private func send(_ contextLength: Int) {
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

  private func buildSendMenu() -> UIMenu {
    let count = chat.messages.count
    var actions: [UIAction] = []

    if count >= 20 {
      // Show limited options for large message counts
      for i in [0, 1, 2, 3, 4, 6, 8, 10].reversed() {
        actions.append(UIAction(title: "\(i)") { [weak self] _ in
          self?.send(i)
        })
      }
      actions.append(UIAction(title: "20") { [weak self] _ in self?.send(20) })
      if count >= 50 {
        actions.append(UIAction(title: "50") { [weak self] _ in self?.send(50) })
      }
      actions.append(UIAction(title: "\(count) (all)") { [weak self] _ in self?.send(count) })
    } else {
      for i in (0 ... min(count, 10)).reversed() {
        let title = i == count ? "\(i) (all)" : "\(i)"
        actions.append(UIAction(title: title) { [weak self] _ in self?.send(i) })
      }
      if count > 10 {
        actions.insert(UIAction(title: "\(count) (all)") { [weak self] _ in self?.send(count) }, at: 0)
      }
    }

    return UIMenu(title: "History Messages", children: actions)
  }

  @objc private func dismissKeyboard() {
    view.endEditing(true)
  }
}

// MARK: - Navigation Actions

extension ChatDetailVC {
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

// MARK: - Keyboard Handling

extension ChatDetailVC {
  @objc private func keyboardWillShow(_ notification: Notification) {
    guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
          let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
    else { return }

    let keyboardHeight = keyboardFrame.height
    inputContainerBottomConstraint?.constant = -keyboardHeight + view.safeAreaInsets.bottom

    UIView.animate(withDuration: duration) {
      self.view.layoutIfNeeded()
    }
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

    inputContainerBottomConstraint?.constant = 0

    UIView.animate(withDuration: duration) {
      self.view.layoutIfNeeded()
    }
  }
}

// MARK: - UICollectionViewDelegate

extension ChatDetailVC: UICollectionViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    updateShowToBottomButton()
    applyMagicScrollEffects()
  }
}

// MARK: - UITextFieldDelegate

extension ChatDetailVC: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    send(chat.option.contextLength)
    return true
  }
}

