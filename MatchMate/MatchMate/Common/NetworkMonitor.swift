//
//  NetworkMonitor.swift
//  MatchMate
//
//  Publishes live connectivity so views can show an offline banner and the
//  repository can decide whether to attempt a network fetch.
//

import Foundation
import Network

/// Abstraction so ViewModels can be tested without the real network stack.
protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
}

@Observable
final class NetworkMonitor: NetworkMonitoring {
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.matchmate.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
