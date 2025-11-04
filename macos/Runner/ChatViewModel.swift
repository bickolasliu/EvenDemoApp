import SwiftUI
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let timestamp: Date
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentQuestion: String = ""
    @Published var currentAnswer: String = ""
    @Published var isProcessing: Bool = false
    @Published var isRecording: Bool = false

    // Conversation Assistant Mode
    @Published var isListening: Bool = false
    @Published var liveTranscript: String = ""
    @Published var suggestions: [ConversationSuggestion] = []
    @Published var analysisInterval: Double = 3.0 // seconds

    private var openAIService = OpenAIService()
    private var conversationAssistant = ConversationAssistant.shared

    init() {
        setupConversationAssistant()
        
        // Set the initial analysis interval
        conversationAssistant.setAnalysisInterval(analysisInterval)

        // Legacy: Set up callback for speech recognition from glasses
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] recognizedText in
            print("🎤 Recognized text from glasses: \(recognizedText)")
            Task { @MainActor in
                if !recognizedText.isEmpty {
                    await self?.sendQuestion(recognizedText)
                }
            }
        }
    }

    private func setupConversationAssistant() {
        // Real-time transcript updates (partial - continuous listening mode)
        // This provides live updates as speech is recognized
        SpeechStreamRecognizer.shared.onPartialTranscript = { [weak self] transcript in
            Task { @MainActor in
                self?.liveTranscript = transcript
                // Update conversation assistant with live transcript
                self?.conversationAssistant.updateTranscript(transcript)
            }
        }

        // Complete transcript updates (final - for button-triggered mode)
        // Also used when speech recognition completes a segment
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] transcript in
            guard let self = self else { return }
            Task { @MainActor in
                // In continuous mode, just update the transcript
                self.liveTranscript = transcript

                print("📝 Final transcript: \(self.liveTranscript)")

                // Update conversation assistant with final transcript
                self.conversationAssistant.updateTranscript(self.liveTranscript)
            }
        }

        // Suggestions updates
        conversationAssistant.onSuggestionsUpdated = { [weak self] newSuggestions in
            Task { @MainActor in
                self?.suggestions = newSuggestions
            }
        }

        // Glasses display
        conversationAssistant.onGlassesSuggestions = { [weak self] glassesText in
            Task { @MainActor in
                await self?.sendSuggestionsToGlasses(glassesText)
            }
        }
    }

    // MARK: - Conversation Assistant Controls

    func startListening() {
        print("▶️ Starting conversation assistant with continuous glasses mic...")
        isListening = true

        guard BluetoothManager.shared.isConnected else {
            print("⚠️ Glasses not connected - cannot start listening")
            isListening = false
            return
        }

        // Start continuous glasses microphone listening
        startContinuousGlassesMic()

        // Start LLM analysis (will analyze transcript as it comes in)
        conversationAssistant.startAnalysis()

        print("🎧 Glasses microphone is now continuously listening")
    }

    func stopListening() {
        print("⏹️ Stopping conversation assistant...")
        isListening = false

        // Stop glasses microphone
        stopContinuousGlassesMic()

        // Stop analysis
        conversationAssistant.stopAnalysis()

        // Keep the transcript - user can manually clear with Clear button
        print("💾 Transcript preserved: \(liveTranscript.count) chars")
    }

    private func startContinuousGlassesMic() {
        print("🎤 Activating continuous glasses microphone...")

        // Start speech recognition first
        SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")

        // Small delay to ensure recognition is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Send command to activate glasses microphone (0x0E 0x01)
            let micOnCommand = Data([0x0E, 0x01])
            let success = BluetoothManager.shared.sendData(data: micOnCommand, lr: "R")

            if success {
                print("✅ Glasses microphone activated (continuous mode)")
            } else {
                print("❌ Failed to activate glasses microphone")
            }
        }
    }

    private func stopContinuousGlassesMic() {
        print("🎤 Deactivating continuous glasses microphone...")

        // Send command to deactivate glasses microphone (0x0E 0x00)
        let micOffCommand = Data([0x0E, 0x00])
        BluetoothManager.shared.sendData(data: micOffCommand, lr: "R")

        // Stop speech recognition
        SpeechStreamRecognizer.shared.stopRecognition()

        print("✅ Glasses microphone deactivated")
    }

    func updateAnalysisInterval(_ interval: Double) {
        analysisInterval = interval
        conversationAssistant.setAnalysisInterval(interval)
    }

    func clearTranscript() {
        liveTranscript = ""
        suggestions = []
        conversationAssistant.clearTranscript()
        SpeechStreamRecognizer.shared.clearTranscript()
    }

    private func sendSuggestionsToGlasses(_ text: String) async {
        guard BluetoothManager.shared.isConnected else {
            print("⚠️ Glasses not connected, skipping display")
            return
        }

        print("👓 Sending suggestions to glasses")
        print("📝 Text to send: \(text)")

        let result = await BluetoothManager.shared.sendEvenAIData(
            text: text,
            newScreen: 0x71, // Text display mode
            pos: 0,
            currentPage: 1,
            maxPage: 1
        )

        if result {
            print("✅ Successfully sent to glasses")
        } else {
            print("❌ Failed to send to glasses")
        }
    }

    func testGlassesDisplay() async {
        print("🧪 TESTING GLASSES DISPLAY")

        let testText = """
Timeline?
Budget?
ROI data
Risks
Next steps
"""

        print("📝 Test text (5 ultra-short keywords):")
        print(testText)

        guard BluetoothManager.shared.isConnected else {
            print("❌ Glasses not connected!")
            return
        }

        print("✅ Glasses connected, sending test...")

        let result = await BluetoothManager.shared.sendEvenAIData(
            text: testText,
            newScreen: 0x71,
            pos: 0,
            currentPage: 1,
            maxPage: 1
        )

        print(result ? "✅ Test sent successfully" : "❌ Test send failed")
    }

    // MARK: - Legacy Q&A Mode (kept for backward compatibility)

    func sendQuestion(_ question: String) async {
        guard !question.isEmpty else { return }

        isProcessing = true
        currentQuestion = question
        currentAnswer = "Processing..."

        do {
            let answer = try await openAIService.sendChatRequest(question: question)
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

    private func measureStringList(_ text: String) -> [String] {
        // Simple line splitting for now
        // In production, would measure actual width as Flutter code did
        let paragraphs = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        return paragraphs.filter { !$0.isEmpty }
    }

    func clearCurrent() {
        currentQuestion = ""
        currentAnswer = ""
    }
}
