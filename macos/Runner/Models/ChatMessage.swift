//
//  ChatMessage.swift
//  Runner
//
//  Data model for chat messages
//

import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let timestamp: Date
}

