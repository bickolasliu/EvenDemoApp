//
//  GlassesDeviceRow.swift
//  Runner
//
//  Individual glasses device row in scanning list
//

import SwiftUI

struct GlassesDeviceRow: View {
    let glasses: PairedGlasses
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var isHovering = false

    var body: some View {
        Button(action: { connectToGlasses() }) {
            HStack(spacing: 12) {
                // Glasses icon
                Image(systemName: "eyeglasses")
                    .font(.system(size: 32))
                    .foregroundColor(isHovering ? .accentColor : .secondary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pair: \(glasses.channelNumber)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "l.square.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(glasses.leftDeviceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "r.square.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(glasses.rightDeviceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .opacity(isHovering ? 1.0 : 0.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering ? Color.accentColor.opacity(0.05) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: isHovering ? Color.black.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Click to connect to these glasses")
    }

    private func connectToGlasses() {
        bluetoothManager.connectToDevice(deviceName: "Pair_\(glasses.channelNumber)") { _ in }
    }
}

