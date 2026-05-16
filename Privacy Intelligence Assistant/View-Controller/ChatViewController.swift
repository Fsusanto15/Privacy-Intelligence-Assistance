//
//  ChatViewController.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 16/5/2026.
//

import UIKit
import UniformTypeIdentifiers

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate {
    
    private let tableView = UITableView()
    private let inputContainerView = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let attachButton = UIButton(type: .system)
    
    private var messages: [ChatMessage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Local RAG Chat"
        
        // Initialize AI Core
        AIManager.shared.initializeEngine()
        
        setupTableView()
        setupInputBar()
        setupConstraints()
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
            sendButton.widthAnchor.constraint(equalToConstant: 34)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func didTapAttach() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let pickedURL = urls.first else { return }
        
        // Ingest the local file securely using our service
        KnowledgeService.shared.loadPDF(at: pickedURL)
        
        // Show a temporary visual system confirmation in the message timeline
        let confirmationMessage = ChatMessage(text: "📚 Ready! Ingested document: \(pickedURL.lastPathComponent)", sender: .ai(sourceContext: nil))
        messages.append(confirmationMessage)
        tableView.reloadData()
    }
    
    @objc private func didTapSend() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        textField.text = ""
        
        // 1. Add User query straight into the message stream
        let userMessage = ChatMessage(text: text, sender: .user)
        messages.append(userMessage)
        
        let targetIndexPath = IndexPath(row: self.messages.count - 1, section: 0)
        tableView.reloadData()
        tableView.scrollToRow(at: targetIndexPath, at: .bottom, animated: true)
        
        // 2. Fetch the Ranked Context Snippet concurrently
        let contextSnippet = KnowledgeService.shared.getContext(for: text)
        
        // 3. Dispatch Background AI Inference safely
        Task {
            do {
                if let aiEngine = AIManager.shared.engine {
                    let aiOutput = try await aiEngine.generateResponse(prompt: text, context: contextSnippet)
                    
                    // Add AI reply paired to the source metadata to prove the output is grounded
                    let aiMessage = ChatMessage(text: aiOutput, sender: .ai(sourceContext: contextSnippet))
                    self.messages.append(aiMessage)
                    
                    self.tableView.reloadData()
                    let newIndex = IndexPath(row: self.messages.count - 1, section: 0)
                    self.tableView.scrollToRow(at: newIndex, at: .bottom, animated: true)
                }
            } catch {
                print("Inference handling failure: \(error)")
            }
        }
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
