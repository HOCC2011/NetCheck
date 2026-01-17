//
//  ContentView.swift
//  NetCheck
//
//  Created by HOCC on 1/17/26.
//

import SwiftUI

struct ContentView: View {
    @State private var results: [PingResult] = [
        PingResult(address: "8.8.8.8"),
        PingResult(address: "google.com"),
        PingResult(address: "github.com"),
        PingResult(address: "apple.com"),
        PingResult(address: "info.cern.ch")
    ]
    
    // Change to StateObject to observe live changes
    @StateObject private var infoService = NetworkInfoService()
    @State private var publicIP: String = "Loading..."
    @State private var isPinging = false
    private let pingService = PingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Network Information").font(.headline)
                    Spacer()
                    
                    // VPN Status updates automatically via infoService
                    HStack(spacing: 4) {
                        Circle()
                            .fill(infoService.isVPNActive ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(infoService.isVPNActive ? "VPN ACTIVE" : "NO VPN")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(infoService.isVPNActive ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Local IP:").font(.caption).foregroundColor(.secondary)
                        Text(infoService.localIP).bold() // Observed property
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Public IPv4:").font(.caption).foregroundColor(.secondary)
                        Text(publicIP).bold()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // --- Ping Section (unchanged) ---
            VStack(alignment: .leading) {
                Text("Server Status").font(.headline)
                ForEach(results) { result in
                    HStack {
                        Circle()
                            .fill(statusColor(result.isOnline))
                            .frame(width: 10, height: 10)
                        Text(result.address)
                            .font(.system(.body, design: .monospaced))
                        if result.isOnline == nil && isPinging {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button(action: startPinging) {
                Text(isPinging ? "Pinging..." : "Ping Servers")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPinging)
        }
        .padding(48)
        .frame(minWidth: 400)
        .onAppear {
            fetchPublicIP()
        }
        // Refresh Public IP if network changes (e.g. VPN connects)
        .onChange(of: infoService.isVPNActive) { _ in
            fetchPublicIP()
        }
    }

    private func fetchPublicIP() {
        infoService.getPublicIP { ip in
            self.publicIP = ip
        }
    }

    private func startPinging() {
        isPinging = true
        for i in results.indices { results[i].isOnline = nil }
        
        let group = DispatchGroup()
        for i in results.indices {
            group.enter()
            pingService.ping(address: results[i].address) { success in
                DispatchQueue.main.async {
                    results[i].isOnline = success
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { isPinging = false }
    }

    private func statusColor(_ isOnline: Bool?) -> Color {
        guard let online = isOnline else { return .gray }
        return online ? .green : .red
    }
}

#Preview {
    ContentView()
}
