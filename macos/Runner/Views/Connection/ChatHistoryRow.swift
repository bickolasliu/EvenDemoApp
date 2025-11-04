//
//  ChatHistoryRow.swift
//  Runner
//
//  Individual chat message in history
//

import SwiftUI

struct ChatHistoryRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text("Q: \(message.question)")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(message.answer)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

