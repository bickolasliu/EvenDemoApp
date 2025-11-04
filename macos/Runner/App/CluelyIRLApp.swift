//
//  CluelyIRLApp.swift
//  Runner
//
//  Main application entry point
//

import SwiftUI

@main
struct CluelyIRLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @StateObject private var conversationAssistantViewModel = ConversationAssistantViewModel()
    @StateObject private var connectionChatViewModel = ConnectionChatViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(bluetoothManager)
                .environmentObject(conversationAssistantViewModel)
                .environmentObject(connectionChatViewModel)
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

