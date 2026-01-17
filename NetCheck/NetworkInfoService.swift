import Foundation
import Network
import Combine // Required for ObservableObject in some configurations

// Reference: https://developer.apple.com/documentation/combine/observableobject
class NetworkInfoService: ObservableObject {
    
    // @Published allows SwiftUI to watch these variables for changes
    @Published var isVPNActive: Bool = false
    @Published var localIP: String = "Loading..."
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            // All updates to @Published properties must happen on the main thread
            DispatchQueue.main.async {
                self?.isVPNActive = self?.checkVPNInterfaces() ?? false
                self?.localIP = self?.calculateLocalIP() ?? "Disconnected"
            }
        }
        monitor.start(queue: queue)
    }
    
    // Scans network interfaces for 'utun' (VPN tunnels)
    private func checkVPNInterfaces() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return false }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            if let interface = ptr?.pointee {
                let name = String(cString: interface.ifa_name)
                let flags = Int32(interface.ifa_flags)
                if name.contains("utun") && (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0 {
                    return true
                }
            }
            ptr = ptr?.pointee.ifa_next
        }
        return false
    }
    
    // Finds the active IPv4 address
    private func calculateLocalIP() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "Unknown" }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: ifaddr!, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addr = interface.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                let flags = Int32(interface.ifa_flags)
                if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        return address ?? "Disconnected"
    }
    
    func getPublicIP(completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let ip = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { completion(ip) }
            } else {
                DispatchQueue.main.async { completion("Offline") }
            }
        }.resume()
    }
}
