//
//  ConversationAssistantViewModel.swift
//  Runner
//
//  ViewModel for real-time conversation assistant mode
//

import SwiftUI
import Combine

@MainActor
class ConversationAssistantViewModel: ObservableObject {
    @Published var isListening: Bool = false
    @Published var liveTranscript: String = ""
    @Published var suggestions: [ConversationSuggestion] = []
    @Published var analysisInterval: Double = 3.0 // seconds

    private var conversationAssistant = ConversationAssistant.shared

    init() {
        setupConversationAssistant()
        
        // Set the initial analysis interval
        conversationAssistant.setAnalysisInterval(analysisInterval)

        // Real-time transcript updates (partial - continuous listening mode)
        SpeechStreamRecognizer.shared.onPartialTranscript = { [weak self] transcript in
            Task { @MainActor in
                self?.liveTranscript = transcript
                self?.conversationAssistant.updateTranscript(transcript)
            }
        }

        // Complete transcript updates (final - for button-triggered mode)
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] transcript in
            guard let self = self else { return }
            Task { @MainActor in
                self.liveTranscript = transcript
                print("📝 Final transcript: \(self.liveTranscript)")
                self.conversationAssistant.updateTranscript(self.liveTranscript)
            }
        }
    }

    private func setupConversationAssistant() {
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
        
        // Format with initial spacing and minimal newlines
        // Keep only the \n\n at the beginning and single \n between items
        let truncatedText = String(text.prefix(200))
        let formattedText = "\n\n\(truncatedText)"
        
        print("📝 Formatted text (\(formattedText.count) chars): '\(formattedText)'")

        let result = await BluetoothManager.shared.sendEvenAIData(
            text: formattedText,
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
}

