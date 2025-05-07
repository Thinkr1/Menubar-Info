//
//  NetworkMonitor.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 04/05/2025.
//

import Foundation
import Network
import Observation
import Combine
import Charts

@available(macOS 14.0, *)
@Observable class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor.queue")
    private var pathStatus: NWPath.Status = .unsatisfied
    
    var isReachable: Bool {pathStatus == .satisfied}
    
    var status: Bool {
        switch pathStatus {
        case .satisfied:
            return true
        default:
            return false
        }
    }
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor [weak self] in
                self?.pathStatus = path.status
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
}
