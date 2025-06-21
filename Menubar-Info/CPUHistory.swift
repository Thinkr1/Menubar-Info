//
//  CPUHistory.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 04/05/2025.
//

import SwiftUI
import Foundation
import Charts

struct CPUDataPoint: Codable {
    let value: Double
    let timestamp: Date
    
    init(value: Double, timestamp: Date = Date()) {
        self.value = value.isFinite ? value : 0.0
        self.timestamp = timestamp
    }
}

@available(macOS 14.0, *)
class CPUHistory {
    static let shared = CPUHistory()
    private let maxPoints = 2880 // 24h * 60min * 2 (30s)
    private let saveInterval = 30.0
    
    private var dataPoints: [CPUDataPoint] = []
    private var timer: Timer?
    
    init() {
        loadHistory()
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            self?.saveCurrentCPUUsage()
        }
    }
    
    func saveCurrentCPUUsage() {
        guard let cpuValue = Double(AppDelegate.shared.CPUUsage), cpuValue.isFinite else {
            return
        }
        
        let newPoint = CPUDataPoint(value: cpuValue)
        dataPoints.append(newPoint)
        if dataPoints.count > maxPoints {
            dataPoints.removeFirst(dataPoints.count - maxPoints)
        }
        
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(dataPoints) {
            UserDefaults.standard.set(encoded, forKey: "cpuHistory")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "cpuHistory"),
           let decoded = try? JSONDecoder().decode([CPUDataPoint].self, from: data) {
            dataPoints = decoded
        }
    }
    
    func getHistory() -> [CPUDataPoint] {
        return dataPoints
    }
    
    func getLast24Hours() -> [CPUDataPoint] {
        let now = Date()
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 60 * 60)
        return dataPoints.filter { $0.timestamp >= twentyFourHoursAgo }
    }

    func getLast6Hours() -> [CPUDataPoint] {
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6 * 60 * 60)
        return dataPoints.filter { $0.timestamp >= sixHoursAgo }
    }
    
    func getLast30Minutes() -> [CPUDataPoint] {
        let now = Date()
        let thirtyMinutesAgo = now.addingTimeInterval(-1800)
        return dataPoints.filter { $0.timestamp >= thirtyMinutesAgo }
    }
    
    func getLast30MinutesValues() -> [Double] {
        let now = Date()
        let thirtyMinutesAgo = now.addingTimeInterval(-1800)
        return dataPoints
            .filter { $0.timestamp >= thirtyMinutesAgo }
            .map { $0.value }
    }
    
    func getLastHourValues() -> [Double] {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        return dataPoints
            .filter { $0.timestamp >= oneHourAgo }
            .map { $0.value }
    }
    
    func currentMaxValue() -> Double {
        if let pctMode = UserDefaults.standard.value(forKey: "CPUPctMode") as? Int {
            return pctMode == 0 ? 800.0 : 100.0
        }
        return 800.0
    }
    
    func getNormalizedValues(for points: [CPUDataPoint], is800PercentMode: Bool) -> [CPUDataPoint] {
        if is800PercentMode {
            return points.map { CPUDataPoint(value: $0.value / 8.0, timestamp: $0.timestamp) }
        }
        return points
    }

    func getLast30Minutes(is800PercentMode: Bool) -> [CPUDataPoint] {
        let now = Date()
        let thirtyMinutesAgo = now.addingTimeInterval(-1800)
        let filtered = dataPoints.filter { $0.timestamp >= thirtyMinutesAgo }
        return getNormalizedValues(for: filtered, is800PercentMode: is800PercentMode)
    }

    func getLast6Hours(is800PercentMode: Bool) -> [CPUDataPoint] {
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6 * 60 * 60)
        let filtered = dataPoints.filter { $0.timestamp >= sixHoursAgo }
        return getNormalizedValues(for: filtered, is800PercentMode: is800PercentMode)
    }
}
