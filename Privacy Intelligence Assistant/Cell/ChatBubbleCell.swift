//
//  ChatBubbleCell.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 16/5/2026.
//

import UIKit

class ChatBubbleCell: UITableViewCell {
    static let identifier = "ChatBubbleCell"
    
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let sourceLabel = UILabel() // To show retrieved RAG source
    
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubviews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
        
        sourceLabel.numberOfLines = 2
        sourceLabel.font = .italicSystemFont(ofSize: 12)
        sourceLabel.textColor = .secondaryLabel
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sourceLabel)
        
        // Setup base constraints
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            
            sourceLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            sourceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sourceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            sourceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.text
        
        switch message.sender {
        case .user:
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            sourceLabel.text = nil
            sourceLabel.isHidden = true
            bubbleTrailingConstraint.isActive = true
            bubbleLeadingConstraint.isActive = false
            
        case .ai(let sourceContext):
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label
            bubbleTrailingConstraint.isActive = false
            bubbleLeadingConstraint.isActive = true
            
            if let source = sourceContext, !source.isEmpty {
                sourceLabel.text = "📚 Source retrieved: \"\(source)\""
                sourceLabel.isHidden = false
            } else {
                sourceLabel.text = nil
                sourceLabel.isHidden = true
            }
        }
    }
}
