//
//  ChatInterfaceView.swift
//  Runner
//
//  Chat interface for Q&A with glasses
//

import SwiftUI

struct ChatInterfaceView: View {
    @EnvironmentObject var viewModel: ConnectionChatViewModel
    @Binding var questionText: String
    @State private var isHoldingVoiceButton: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Current response display
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isProcessing {
                        HStack {
                            ProgressView()
                            Text("Processing...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    } else if !viewModel.currentAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if !viewModel.currentQuestion.isEmpty {
                                Text("Q: \(viewModel.currentQuestion)")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .padding(.bottom, 4)
                            }

                            Text(viewModel.currentAnswer)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("Press and hold the voice button or type a question")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }

                    // Chat history
                    if !viewModel.messages.isEmpty {
                        Divider()
                            .padding(.vertical)

                        Text("History")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.messages) { message in
                            ChatHistoryRow(message: message)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Input area
            HStack(spacing: 12) {
                // Voice input button
                Button(action: {}) {
                    Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(viewModel.isRecording ? .red : .primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(
                    Circle()
                        .fill(viewModel.isRecording ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHoldingVoiceButton {
                                isHoldingVoiceButton = true
                                viewModel.startVoiceRecording()
                            }
                        }
                        .onEnded { _ in
                            isHoldingVoiceButton = false
                            Task {
                                await viewModel.stopVoiceRecording()
                            }
                        }
                )
                .help("Hold to speak")

                // Text input
                TextField("Type a question...", text: $questionText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendQuestion()
                    }
                    .disabled(viewModel.isProcessing)

                // Send button
                Button(action: sendQuestion) {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .disabled(questionText.isEmpty || viewModel.isProcessing)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func sendQuestion() {
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        questionText = ""
        Task {
            await viewModel.sendQuestion(question)
        }
    }
}

