//
//  ScanningView.swift
//  Runner
//
//  Bluetooth scanning and device list UI
//

import SwiftUI

struct ScanningView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var isScanning: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Even Realities G1 Glasses")
                .font(.title2)
                .fontWeight(.semibold)

            if isScanning {
                ProgressView("Scanning for glasses...")
                    .padding()
            } else {
                Button(action: startScan) {
                    Label("Scan for Glasses", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }

            if !bluetoothManager.pairedGlasses.isEmpty {
                Divider()
                    .padding(.vertical)

                Text("Available Glasses")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(bluetoothManager.pairedGlasses, id: \.channelNumber) { glasses in
                            GlassesDeviceRow(glasses: glasses)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func startScan() {
        isScanning = true
        bluetoothManager.startScan { _ in
            // Auto-stop after 15 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                isScanning = false
                bluetoothManager.stopScan { _ in }
            }
        }
    }
}

