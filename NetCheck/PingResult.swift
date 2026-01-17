//
//  PingResult.swift
//  NetCheck
//
//  Created by HOCC on 1/17/26.
//


import Foundation

struct PingResult: Identifiable {
    let id = UUID()
    let address: String
    var isOnline: Bool? // nil = pending, true = success, false = fail
}

class PingService {
    // Reference: https://developer.apple.com/documentation/foundation/process
    func ping(address: String, completion: @escaping (Bool) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        // -c 1: send 1 packet, -t 2: timeout after 2 seconds
        process.arguments = ["-c", "1", "-t", "2", address]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { p in
            completion(p.terminationStatus == 0)
        }
        
        do {
            try process.run()
        } catch {
            completion(false)
        }
    }
}