//
//  ConnectionStatusView.swift
//  Runner
//
//  Connection status header
//

import SwiftUI

struct ConnectionStatusView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        HStack {
            Image(systemName: bluetoothManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .foregroundColor(bluetoothManager.isConnected ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Status")
                    .font(.headline)
                Text(bluetoothManager.connectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

