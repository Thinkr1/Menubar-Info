//
//  NetworkMonitorWrapper.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 04/05/2025.
//

import Foundation
import Combine
import Observation
import Charts

@available(macOS 14.0, *)
class NetworkMonitorWrapper: ObservableObject {
    @Published var isReachable: Bool = false
    
    private var networkMonitor = NetworkMonitor()
    private var cancellable: AnyCancellable?
    
    init() {
        cancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isReachable != self.networkMonitor.isReachable {
                    self.isReachable = self.networkMonitor.isReachable
                }
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}
