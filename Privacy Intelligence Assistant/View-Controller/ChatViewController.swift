//
//  ChatViewController.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 16/5/2026.
//

import UIKit
import UniformTypeIdentifiers
import SwiftData

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate {
    
    var modelContext: ModelContext?
    private let tableView = UITableView()
    private let inputContainerView = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let attachButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var messages: [ChatMessage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Local RAG Chat"
        
        AIManager.shared.initializeEngine()
        
        setupNavigationItems()
        setupTableView()
        setupInputBar()
        setupConstraints()
        loadSavedMessages()
    }
    
    private func setupNavigationItems() {
        let modelMenuButton = UIBarButtonItem(
            image: UIImage(systemName: "cpu"),
            style: .plain,
            target: self,
            action: #selector(didTapModelSelector)
        )
        navigationItem.leftBarButtonItem = modelMenuButton
        
        let newChatButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(didTapNewChat),
        )
        navigationItem.rightBarButtonItem = newChatButton
        updateNavigationTitle()
    }
    
    private func updateNavigationTitle() {
        let activeModelName = AIManager.shared.activeLocalStrategy == .qwenLite ? "Qwen 0.5B" : "Bonsai 4B"
        self.title = "\(activeModelName) Chat"
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        tableView.keyboardDismissMode = .interactive
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tapGesture)
    }
    
    private func setupInputBar() {
        inputContainerView.backgroundColor = .systemBackground
        inputContainerView.layer.borderWidth = 0.5
        inputContainerView.layer.borderColor = UIColor.separator.cgColor
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainerView)
        
        attachButton.setImage(UIImage(systemName: "doc.badge.plus"), for: .normal)
        attachButton.tintColor = .systemGray
        attachButton.addTarget(self, action: #selector(didTapAttach), for: .touchUpInside)
        attachButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(attachButton)
        
        textField.placeholder = "Ask your document..."
        textField.borderStyle = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(textField)
        
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = .systemBlue
        sendButton.imageView?.layer.transform = CATransform3DMakeScale(1.3, 1.3, 1)
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(sendButton)
        
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Table View Constraints
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),
            
            // Input Bar Container Constraints
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // CRITICAL: Anchored smoothly right on top of the system keyboard layout guide
            inputContainerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 60),
            
            // Elements Inside Input Bar
            attachButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 12),
            attachButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: 34),
            
            textField.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 36),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            
            loadingIndicator.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -12),
            loadingIndicator.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 34)
        ])
    }
    
    // MARK: - SwiftData Operations
    
    private func loadSavedMessages() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedMessage>(sortBy: [SortDescriptor(\.timestamp)])
        
        do {
            let saved = try context.fetch(descriptor)
            self.messages = saved.map { dbMessage in
                let sender: MessageSender = dbMessage.senderType == "user" ? .user : .ai(sourceContext: dbMessage.sourceContext)
                return ChatMessage(text: dbMessage.text, sender: sender)
            }
            tableView.reloadData()
            scrollToBottom(animated: false)
        } catch {
            print("Failed loading database history: \(error)")
        }
    }
    
    // MARK: - Actions
    
    @objc private func didTapModelSelector() {
        if AIManager.shared.isCurrentlyGenerating {
            let warningAlert = UIAlertController(
                title: "Engine Locked",
                message: "Please wait before changing settings.",
                preferredStyle: .alert
            )
            warningAlert.addAction(UIAlertAction(title: "OK", style: .default))
            present(warningAlert, animated: true)
            return
        }
        
        let actionSheet = UIAlertController(
            title: "Select Local Intelligence Core",
            message: "Choose which architecture model engine to load.",
            preferredStyle: .actionSheet
        )
        
        for strategy in LocalModelStrategy.allCases {
            let isCurrent = AIManager.shared.activeLocalStrategy == strategy
            let titleSuffix = isCurrent ? " (Active)" : ""
            
            let action = UIAlertAction(title: "\(strategy.rawValue)\(titleSuffix)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                
                // Execute runtime hot-swap migration pass safely
                let success = AIManager.shared.switchModel(to: strategy)
                if success {
                    self.updateNavigationTitle()
                }
            }
            
            action.isEnabled = !isCurrent
            actionSheet.addAction(action)
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad layout
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.leftBarButtonItem
        }
        
        present(actionSheet, animated: true)
    }
    
    @objc private func didTapNewChat() {
        let alert = UIAlertController(
            title: "Start New Chat?",
            message: "This will permanently wipe your current conversation text history and document index chunks.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset Everything", style: .destructive, handler: { [weak self] _ in
            self?.clearEntireSession()
        }))
        
        present(alert, animated: true)
    }
    
    private func clearEntireSession() {
        guard let context = modelContext else { return }
        
        try? context.delete(model: PersistedMessage.self)
        KnowledgeService.shared.clearAllChunks()
        try? context.save()
        
        messages.removeAll()
        tableView.reloadData()
    }
    
    @objc private func didTapAttach() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let pickedURL = urls.first else { return }
        
        setInterfaceProcessing(true)
        
        Task {
            await KnowledgeService.shared.loadPDF(at: pickedURL)
            
            await MainActor.run {
                self.setInterfaceProcessing(false)
                let msgText = "📚 Ready! Ingested document: \(pickedURL.lastPathComponent)"
                
                let confirmationMessage = ChatMessage(text: msgText, sender: .ai(sourceContext: nil))
                self.messages.append(confirmationMessage)
                
                let dbMsg = PersistedMessage(text: msgText, senderType: "ai")
                self.modelContext?.insert(dbMsg)
                try? self.modelContext?.save()
                
                self.tableView.reloadData()
                self.scrollToBottom(animated: true)
            }
        }
        
    }
    
    @objc private func didTapSend() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        textField.text = ""
        
        let userMessage = ChatMessage(text: text, sender: .user)
        messages.append(userMessage)
        
        let dbUserMsg = PersistedMessage(text: text, senderType: "user")
        modelContext?.insert(dbUserMsg)
        
        self.tableView.reloadData()
        self.scrollToBottom(animated: true)
        let contextSnippet = KnowledgeService.shared.getContext(for: text)
        setInterfaceProcessing(true)
        
        Task {
            do {
                // Automatically manages background processing state context flags internally
                let aiOutput = try await AIManager.shared.generateResponse(prompt: text, context: contextSnippet)
                
                await MainActor.run {
                    self.setInterfaceProcessing(false)
                    
                    let aiMessage = ChatMessage(text: aiOutput, sender: .ai(sourceContext: contextSnippet.isEmpty ? nil : contextSnippet))
                    self.messages.append(aiMessage)
                    
                    let dbAiMsg = PersistedMessage(text: aiOutput, senderType: "ai", sourceContext: contextSnippet.isEmpty ? nil : contextSnippet)
                    self.modelContext?.insert(dbAiMsg)
                    try? self.modelContext?.save()
                    
                    self.tableView.reloadData()
                    self.scrollToBottom(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.setInterfaceProcessing(false)
                    print("Engine pipeline exception log: \(error)")
                }
            }
        }
    }
    
    private func setInterfaceProcessing(_ isProcessing: Bool) {
        if isProcessing {
            sendButton.isHidden = true
            loadingIndicator.startAnimating()
            attachButton.isEnabled = false
            textField.placeholder = "AI is thinking..."
        } else {
            loadingIndicator.stopAnimating()
            sendButton.isHidden = false
            textField.isEnabled = true
            attachButton.isEnabled = true
            textField.placeholder = "Ask your document..."
        }
    }
    
    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let index = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: animated)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.identifier, for: indexPath) as? ChatBubbleCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}
