//
//  ConnectionManagementView.swift
//  Runner
//
//  Main container for connection management and chat interface
//

import SwiftUI

struct ConnectionManagementView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var chatViewModel: ConnectionChatViewModel
    @State private var questionText: String = ""
    @State private var isScanning: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with connection status
            ConnectionStatusView()

            Divider()

            // Main content area
            if !bluetoothManager.isConnected {
                // Show scanning/pairing UI
                ScanningView(isScanning: $isScanning)
            } else {
                // Show chat interface
                ChatInterfaceView(questionText: $questionText)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    ConnectionManagementView()
        .environmentObject(BluetoothManager.shared)
        .environmentObject(ConnectionChatViewModel())
        .frame(width: 600, height: 700)
}

