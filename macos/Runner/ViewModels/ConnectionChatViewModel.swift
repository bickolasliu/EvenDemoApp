//
//  ConnectionChatViewModel.swift
//  Runner
//
//  ViewModel for legacy Q&A chat mode
//

import SwiftUI
import Combine

@MainActor
class ConnectionChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentQuestion: String = ""
    @Published var currentAnswer: String = ""
    @Published var isProcessing: Bool = false
    @Published var isRecording: Bool = false

    private var openAIService = OpenAIService()

    init() {
        // Set up callback for speech recognition from glasses (button-triggered mode)
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] recognizedText in
            print("🎤 Recognized text from glasses: \(recognizedText)")
            Task { @MainActor in
                if !recognizedText.isEmpty {
                    await self?.sendQuestion(recognizedText)
                }
            }
        }
    }

    // MARK: - Q&A Mode

    func sendQuestion(_ question: String) async {
        guard !question.isEmpty else { return }

        isProcessing = true
        currentQuestion = question
        currentAnswer = "Processing..."

        do {
            // Use GPT-5 with web search for better, factual responses
            let answer = try await openAIService.sendChatRequest(question: question, enableWebSearch: true)
            currentAnswer = answer

            // Add to history
            let message = ChatMessage(question: question, answer: answer, timestamp: Date())
            messages.insert(message, at: 0)

            // Send to glasses if connected
            if BluetoothManager.shared.isConnected {
                await sendToGlasses(answer)
            }

        } catch {
            currentAnswer = "Error: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func startVoiceRecording() {
        isRecording = true
        SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")

        // Set up a listener for speech recognition results
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] text in
            Task { @MainActor in
                self?.currentQuestion = text
            }
        }
    }

    func stopVoiceRecording() async {
        isRecording = false
        SpeechStreamRecognizer.shared.stopRecognition()

        // Send the recognized text
        if !currentQuestion.isEmpty {
            await sendQuestion(currentQuestion)
        }
    }

    private func sendToGlasses(_ text: String) async {
        print("🔧 Sending text to glasses (TextService mode - 0x71)")

        // Truncate and format text exactly like Flutter TextService
        let truncatedText = String(text.prefix(100))

        // Add leading newlines (Flutter adds \n\n for short text)
        let formattedText = "\n\n\(truncatedText)"

        print("📝 Formatted text: '\(formattedText)'")

        // Send with 0x70 status (0x71 after OR with 0x01)
        // This is for TEXT DISPLAY (not EvenAI voice mode!)
        print("📤 Sending text with 0x71 (text display mode)")
        await BluetoothManager.shared.sendEvenAIData(
            text: formattedText,
            newScreen: 0x71, // 0x01 | 0x70 (text display status)
            pos: 0,
            currentPage: 1,
            maxPage: 1
        )
    }

    func clearCurrent() {
        currentQuestion = ""
        currentAnswer = ""
    }
}

