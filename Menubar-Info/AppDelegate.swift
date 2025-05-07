//
//  AppDelegate.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 04/05/2025.
//

import SwiftUI
import AppKit
import Combine
import Network

enum PortOpeningMethod: String, CaseIterable {
    case netcat = "Netcat (nc)"
    case python = "Python HTTP Server"
//    case node = "Node.js HTTP Server"
//    case socat = "Socat"
    
    var command: (Int) -> String {
        switch self {
        case .netcat:
            return { port in "nc -l -k \(port)" }
        case .python:
            return { port in "python3 -m http.server \(port)" }
//        case .node:
//            return { port in "npx http-server -p \(port)" }
//        case .socat:
//            return { port in "socat TCP-LISTEN:\(port),fork,reuseaddr SYSTEM:'echo HTTP/1.0 200 OK; echo Content-Type: text/plain; echo; echo Port \(port) is open'" }
        }
    }
}

@available(macOS 14.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    @ObservedObject private var networkMonitorWrapper = NetworkMonitorWrapper()
    @AppStorage("CPURefreshRate") var CPURefreshRate: TimeInterval = 5
    @AppStorage("memoryRefreshRate") var memoryRefreshRate: TimeInterval = 5
    @AppStorage("iconName") var iconName: String = "cpu"
    @AppStorage("CPUPctMode") var CPUPctMode: Int = 0
    @AppStorage("CPUMBESelect") var CPUMBESelect: Bool = true
    @AppStorage("IPMBESelect") var IPMBESelect: Bool = true
    @AppStorage("batteryMBESelect") var batteryMBESelect: Bool = true
    @AppStorage("memoryMBESelect") var memoryMBESelect: Bool = true
    @AppStorage("portsMBESelect") var portsMBESelect: Bool = true
    @Published var CPUUsage: String = "..."
    @Published var ip: String = ""
    @Published var ipLoc: String = ""
    @Published var batteryPct: String = "..."
    @Published var batteryTime: String = ""
    @Published var batteryCycleCount: String = "?"
    @Published var batteryDesignCapacity: String = "?"
    @Published var batteryCurrentCapacity: String = "?"
//    @Published var batteryMaxCapacity: String = "?"
//    @Published var batteryHealth: String = "?"
//    @Published var batteryIsCharging: Bool = false
    @Published var batteryTemperature: String = "?"
    @Published var batteryCellVoltage: String = "?"
    @Published var networkSSID: String = ""
    @Published var cpuBrand: String = "Unknown"
    @Published var cpuCores: String = "?"
    @Published var cpuThreads: String = "?"
    @Published var cpuFrequency: String = "?"
    @Published var cpuCacheL1: String = "?"
    @Published var cpuCacheL2: String = "?"
    @Published var memoryTotal: String = "?"
    @Published var memoryFreePercentage: String = "...%"
    @Published var memoryPagesFree: String = "?"
    @Published var memoryPagesPurgeable: String = "?"
    @Published var memoryPagesActive: String = "?"
    @Published var memoryPagesInactive: String = "?"
    @Published var memoryPagesCompressed: String = "?"
    @Published var memoryPageSize: Int = 0
    @Published var memorySwapIns: String = "?"
    @Published var memorySwapOuts: String = "?"
    @Published var osVersion: String = "?"
    @Published var kernelVersion: String = "?"
    @Published var openPorts: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var settingsPanel: NSPanel?
    private var cpuStatusItem: NSStatusItem?
    private var ipStatusItem: NSStatusItem?
    private var batteryStatusItem: NSStatusItem?
    private var memoryStatusItem: NSStatusItem?
    private var portsStatusItem: NSStatusItem?
    private var cpuTimer: Timer?
    private var memoryTimer: Timer?
    private var cpuGraphPopover: NSPopover?
    static var shared: AppDelegate!
    let portManagerData = PortManagerData()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared=self
        CPUHistory.shared.saveCurrentCPUUsage()
        setupStatusItems()
        setupObservers()
        initialDataLoad()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cpuTimer?.invalidate()
        memoryTimer?.invalidate()
    }
    
    private func setupStatusItems() {
        if CPUMBESelect {
            setupCPUStatusItem()
        }
        if IPMBESelect {
            setupIPStatusItem()
        }
        if batteryMBESelect {
            setupBatteryStatusItem()
        }
        if memoryMBESelect {
            setupMemoryStatusItem()
        }
    }
    
    private func setupCPUStatusItem() {
        cpuStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let button = cpuStatusItem?.button
        button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "CPU Usage")
        button?.imagePosition = .imageLeading
        button?.title = "\(CPUUsage)%"
        
        let menu = NSMenu()
        
        let usageItem = NSMenuItem(title: "CPU Usage: \(CPUUsage)%", action: nil, keyEquivalent: "")
        usageItem.isEnabled = false
        
        let brandItem = NSMenuItem(title: "Brand: \(cpuBrand)", action: nil, keyEquivalent: "")
        brandItem.target=self
        
        let coresItem = NSMenuItem(title: "    Cores: \(cpuCores)", action: nil, keyEquivalent: "")
        coresItem.target=self
        
        let threadsItem = NSMenuItem(title: "    Threads: \(cpuThreads)", action: nil, keyEquivalent: "")
        threadsItem.target=self
        
        let cacheL1Item = NSMenuItem(title: "    Cache L1: \(cpuCacheL1)", action: nil, keyEquivalent: "")
        cacheL1Item.target=self
        
        let cacheL2Item = NSMenuItem(title: "    Cache L2: \(cpuCacheL2)", action: nil, keyEquivalent: "")
        cacheL2Item.target=self
        
        let osVersionItem = NSMenuItem(title: "OS Version: \(osVersion)", action: nil, keyEquivalent: "")
        osVersionItem.target=self
        
        let kernelVersionItem = NSMenuItem(title: "Kernel Version: \(kernelVersion)", action: nil, keyEquivalent: "")
        kernelVersionItem.target=self
        
        let showGraphItem = NSMenuItem(title: "Show CPU Usage Graph", action: #selector(showCPUHistoryGraph), keyEquivalent: "g")
        showGraphItem.target = self
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshCPU), keyEquivalent: "r")
        refreshItem.target = self
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        
        menu.addItem(usageItem)
        menu.addItem(brandItem)
        menu.addItem(coresItem)
        menu.addItem(threadsItem)
        menu.addItem(cacheL1Item)
        menu.addItem(cacheL2Item)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(osVersionItem)
        menu.addItem(kernelVersionItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(refreshItem)
        menu.addItem(showGraphItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
        cpuStatusItem?.menu = menu
    }
    
    private func setupMemoryStatusItem() {
        memoryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let button = memoryStatusItem?.button
        button?.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Usage")
        button?.imagePosition = .imageLeading
        button?.title = "\(memoryFreePercentage)"
        
        updateMemoryStatusItem()
        
        let menu = NSMenu()
        
        let freePctItem = NSMenuItem(title: "Memory Free: \(memoryFreePercentage)", action: nil, keyEquivalent: "")
        freePctItem.isEnabled = false
        
        let totalMemoryItem = NSMenuItem(title: "Total Memory: \(memoryTotal)", action: nil, keyEquivalent: "")
        totalMemoryItem.isEnabled = false
        
        let pagesSection = NSMenuItem(title: "Pages", action: nil, keyEquivalent: "")
        pagesSection.isEnabled = false
        
        let freeItem = NSMenuItem(title: "    Free: \(memoryPagesFree)", action: nil, keyEquivalent: "")
        freeItem.isEnabled = false
        
        let purgeableItem = NSMenuItem(title: "    Purgeable: \(memoryPagesPurgeable)", action: nil, keyEquivalent: "")
        purgeableItem.isEnabled = false
        
        let activeItem = NSMenuItem(title: "    Active: \(memoryPagesActive)", action: nil, keyEquivalent: "")
        activeItem.isEnabled = false
        
        let inactiveItem = NSMenuItem(title: "    Inactive: \(memoryPagesInactive)", action: nil, keyEquivalent: "")
        inactiveItem.isEnabled = false
        
        let compressedItem = NSMenuItem(title: "    Compressed: \(memoryPagesCompressed)", action: nil, keyEquivalent: "")
        compressedItem.isEnabled = false
        
        let swapSection = NSMenuItem(title: "Swap", action: nil, keyEquivalent: "")
        swapSection.isEnabled = false
        
        let swapInsItem = NSMenuItem(title: "    Swap Ins: \(memorySwapIns)", action: nil, keyEquivalent: "")
        swapInsItem.isEnabled = false
        
        let swapOutsItem = NSMenuItem(title: "    Swap Outs: \(memorySwapOuts)", action: nil, keyEquivalent: "")
        swapOutsItem.isEnabled = false
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMemory), keyEquivalent: "r")
        refreshItem.target = self
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        
        menu.addItem(freePctItem)
        menu.addItem(totalMemoryItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pagesSection)
        menu.addItem(freeItem)
        menu.addItem(purgeableItem)
        menu.addItem(activeItem)
        menu.addItem(inactiveItem)
        menu.addItem(compressedItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(swapSection)
        menu.addItem(swapInsItem)
        menu.addItem(swapOutsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
        
        memoryStatusItem?.menu = menu
    }
    
    private func setupPortsStatusItem() {
        portsStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let button = portsStatusItem?.button
        button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Open Ports")
        button?.imagePosition = .imageLeading
        button?.title = "\(openPorts.count)"
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Open Ports: \(openPorts.count)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        if openPorts.isEmpty {
            let noPortsItem = NSMenuItem(title: "No open ports detected", action: nil, keyEquivalent: "")
            noPortsItem.isEnabled = false
            menu.addItem(noPortsItem)
        } else {
            for port in openPorts {
                let portItem = NSMenuItem(title: port, action: nil, keyEquivalent: "")
                portItem.isEnabled = false
                menu.addItem(portItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let openNewPortItem = NSMenuItem(title: "Open New Port...", action: #selector(showOpenPortDialog), keyEquivalent: "o")
        openNewPortItem.target = self
        menu.addItem(openNewPortItem)
        
        let portManagerItem = NSMenuItem(title: "Port Manager...", action: #selector(showPortManager), keyEquivalent: "m")
        portManagerItem.target = self
        menu.addItem(portManagerItem)
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshPorts), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        portsStatusItem?.menu = menu
        updatePortsMenu()
    }
    
    private func setupIPStatusItem() {
        ipStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateIPStatusItem()
        
        let menu = NSMenu()
        
        let ipItem = NSMenuItem(title: "IP: \(ip) (\(ipLoc))", action: nil, keyEquivalent: "")
        ipItem.isEnabled = false
        
        let networkItem = NSMenuItem(title: "Network: \(networkSSID.isEmpty ? "Unknown" : networkSSID)", action: nil, keyEquivalent: "")
        networkItem.isEnabled = false
        
        let statusItem = NSMenuItem(title: "Connected? \(networkMonitorWrapper.isReachable ? "Yes" : "...")", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshIP), keyEquivalent: "r")
        refreshItem.target = self
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        
        menu.addItem(ipItem)
        menu.addItem(networkItem)
        menu.addItem(statusItem)
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
        
        ipStatusItem?.menu = menu
    }
    
    private func setupBatteryStatusItem() {
        batteryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateBatteryStatusItem()
        
        let menu = NSMenu()
        
        let batteryItem = NSMenuItem(title: "Battery: \(batteryPct)", action: nil, keyEquivalent: "")
        batteryItem.isEnabled = false
        
//        let batteryStatusMenuItem = NSMenuItem(title: "Status: \(batteryIsCharging ? "Charging" : "Discharging")", action: nil, keyEquivalent: "")
//        batteryStatusMenuItem.isEnabled = false
        
        let timeItem = NSMenuItem(title: "Time remaining: \(batteryTime)", action: nil, keyEquivalent: "")
        timeItem.isEnabled = false
        
        let temperatureItem = NSMenuItem(title: "Temperature: \(batteryTemperature)", action: nil, keyEquivalent: "")
        temperatureItem.isEnabled = false
        
//        let healthItem = NSMenuItem(title: "Health: \(batteryHealth)", action: nil, keyEquivalent: "")
//        healthItem.isEnabled = false
        
        let cycleCountItem = NSMenuItem(title: "Cycle count: \(batteryCycleCount)", action: nil, keyEquivalent: "")
        cycleCountItem.isEnabled = false
        
        let capacitySection = NSMenuItem(title: "Capacity", action: nil, keyEquivalent: "")
        capacitySection.isEnabled = false
        
        let designCapacityItem = NSMenuItem(title: "    Design: \(batteryDesignCapacity) mAh", action: nil, keyEquivalent: "")
        designCapacityItem.isEnabled = false
        
//        let maxCapacityItem = NSMenuItem(title: "    Maximum: \(batteryMaxCapacity) mAh", action: nil, keyEquivalent: "")
//        maxCapacityItem.isEnabled = false
        
        let currentCapacityItem = NSMenuItem(title: "    Current: \(batteryCurrentCapacity) mAh", action: nil, keyEquivalent: "")
        currentCapacityItem.isEnabled = false
        
        let voltageItem = NSMenuItem(title: "Cell voltage: \(batteryCellVoltage)", action: nil, keyEquivalent: "")
        voltageItem.isEnabled = false
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshBattery), keyEquivalent: "r")
        refreshItem.target = self
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        
        menu.addItem(batteryItem)
//        menu.addItem(batteryStatusMenuItem)
        menu.addItem(timeItem)
        menu.addItem(temperatureItem)
//        menu.addItem(healthItem)
        menu.addItem(cycleCountItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(capacitySection)
        menu.addItem(designCapacityItem)
//        menu.addItem(maxCapacityItem)
        menu.addItem(currentCapacityItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(voltageItem)
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
        
        batteryStatusItem?.menu = menu
    }
    
    private func updateIPStatusItem() {
        guard let button = ipStatusItem?.button else { return }
        
        if networkMonitorWrapper.isReachable {
            if !ipLoc.isEmpty {
                let url = URL(string: "https://flagcdn.com/w20/\(ipLoc.lowercased()).png")!
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            image.size = NSSize(width: 20, height: 13)
                            button.image = image
                        }
                    }
                }.resume()
            }
        } else {
            let noConnectionImage = NSImage(systemSymbolName: "camera.metering.none", accessibilityDescription: "No Connection")
            noConnectionImage?.size = NSSize(width: 20, height: 13)
            button.image = noConnectionImage
        }
    }
    
    func updateOpenPorts() {
        let portsCommand = "lsof -i -P | grep LISTEN"
        runCommand(portsCommand) { [weak self] result in
            let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                self?.openPorts = lines.map { line in
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if components.count >= 9 {
                        let process = components[0]
                        let pidInfo = components[1]
                        let portInfo = components[8]
                        return "\(process) (PID \(pidInfo)): \(portInfo)" // "ProcessName (PID 12345): 127.0.0.1:8080"/"ProcessName (PID 12345): :8080"
                    }
                    return line
                }
                self?.portManagerData.openPorts = lines.map { line in
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if components.count >= 9 {
                        let process = components[0]
                        let pidInfo = components[1]
                        let portInfo = components[8]
                        return "\(process) (PID \(pidInfo)): \(portInfo)" // "ProcessName (PID 12345): 127.0.0.1:8080"/"ProcessName (PID 12345): :8080"
                    }
                    return line
                }
                self?.updatePortsStatusItem()
            }
        }
    }
    
    private func updatePortsStatusItem() {
        guard let item = portsStatusItem else { return }
        
        item.button?.title = "\(openPorts.count)"
        updatePortsMenu()
        if let menu = item.menu {
            let standardItems = menu.items.filter { item in
                item.action == #selector(showOpenPortDialog) ||
                item.action == #selector(showPortManager) ||
                item.action == #selector(refreshPorts) ||
                item.action == #selector(openSettings) ||
                item.action == #selector(quitApp)
            }
            
            menu.removeAllItems()
            
            let titleItem = NSMenuItem(title: "Open Ports: \(openPorts.count)", action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)
            menu.addItem(NSMenuItem.separator())
            
            if openPorts.isEmpty {
                let noPortsItem = NSMenuItem(title: "No open ports detected", action: nil, keyEquivalent: "")
                noPortsItem.isEnabled = false
                menu.addItem(noPortsItem)
            } else {
                for port in openPorts {
                    let portItem = NSMenuItem(title: port, action: nil, keyEquivalent: "")
                    portItem.isEnabled = false
                    menu.addItem(portItem)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
            
            for item in standardItems {
                if item.action == #selector(showOpenPortDialog) {
                    menu.addItem(item)
                }
            }
            
            for item in standardItems {
                if item.action == #selector(showPortManager) {
                    menu.addItem(item)
                }
            }
            
            for item in standardItems {
                if item.action == #selector(refreshPorts) {
                    menu.addItem(item)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
            
            for item in standardItems {
                if item.action == #selector(openSettings) {
                    menu.addItem(item)
                }
            }
            
            for item in standardItems {
                if item.action == #selector(quitApp) {
                    menu.addItem(item)
                }
            }
            
            if !standardItems.contains(where: { $0.action == #selector(showOpenPortDialog) }) {
                let openNewPortItem = NSMenuItem(title: "Open New Port...", action: #selector(showOpenPortDialog), keyEquivalent: "o")
                openNewPortItem.target = self
                menu.addItem(openNewPortItem)
            }
            
            if !standardItems.contains(where: { $0.action == #selector(showPortManager) }) {
                let portManagerItem = NSMenuItem(title: "Port Manager...", action: #selector(showPortManager), keyEquivalent: "m")
                portManagerItem.target = self
                menu.addItem(portManagerItem)
            }
            
            if !standardItems.contains(where: { $0.action == #selector(refreshPorts) }) {
                let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshPorts), keyEquivalent: "r")
                refreshItem.target = self
                menu.addItem(refreshItem)
            }
            
            if !standardItems.contains(where: { $0.action == #selector(openSettings) }) {
                let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
                settingsItem.target = self
                menu.addItem(settingsItem)
            }
            
            if !standardItems.contains(where: { $0.action == #selector(quitApp) }) {
                let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
                quitItem.target = self
                menu.addItem(quitItem)
            }
        }
    }
    
    private func updateBatteryStatusItem() {
        batteryStatusItem?.button?.title = batteryTime
    }
    
    private func updateCPUStatusItem() {
        cpuStatusItem?.button?.title = "\(CPUUsage)%"
        cpuStatusItem?.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "CPU Usage")
    }
    
    private func updateMemoryStatusItem() {
        memoryStatusItem?.button?.title = memoryFreePercentage
        memoryStatusItem?.button?.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Usage")
    }
    
    private func updateCPUDetails() {
        let brandCommand = "sysctl -n machdep.cpu.brand_string"
        runCommand(brandCommand) { [weak self] result in
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self?.cpuBrand = cleaned.isEmpty ? "Unknown" : cleaned
            }
        }

        let coresCommand = "sysctl -n hw.perflevel0.physicalcpu"
        runCommand(coresCommand) { [weak self] result in
            DispatchQueue.main.async {
                self?.cpuCores = result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let threadsCommand = "sysctl -n hw.logicalcpu"
        runCommand(threadsCommand) { [weak self] result in
            DispatchQueue.main.async {
                self?.cpuThreads = result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let l1CacheCommand = "sysctl -n hw.l1dcachesize"
        runCommand(l1CacheCommand) { [weak self] result in
            if let size = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) {
                DispatchQueue.main.async {
                    self?.cpuCacheL1 = "\(size/1024) KB"
                }
            }
        }
        
        let l2CacheCommand = "sysctl -n hw.l2cachesize"
        runCommand(l2CacheCommand) { [weak self] result in
            if let size = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) {
                DispatchQueue.main.async {
                    self?.cpuCacheL2 = "\(size/1024/1024) MB"
                }
            }
        }
        
        let osVersionCommand = "sw_vers -productVersion"
        runCommand(osVersionCommand) { [weak self] result in
            DispatchQueue.main.async {
                self?.osVersion = result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let kernelCommand = "sysctl -n kern.version"
        runCommand(kernelCommand) { [weak self] result in
            DispatchQueue.main.async {
                self?.kernelVersion = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: ";").first?
                    .trimmingCharacters(in: .whitespaces) ?? "Unknown"
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()+1) { [weak self] in
            self?.updateMenuItems()
        }
    }
    
    private func updateMemoryDetails() {
        let memoryPressureCommand = "memory_pressure"
        runCommand(memoryPressureCommand) { [weak self] result in
            guard let self = self else { return }
            
            if let totalMemoryMatch = result.range(of: "The system has (\\d+)", options: .regularExpression) {
                let totalMemoryString = String(result[totalMemoryMatch])
                if let totalMemoryBytes = Int(totalMemoryString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    DispatchQueue.main.async {
                        self.memoryTotal = "\(totalMemoryBytes/1024/1024/1024) GB"
                    }
                }
            }
            
            if let pageSizeMatch = result.range(of: "page size of (\\d+)", options: .regularExpression) {
                let pageSizeString = String(result[pageSizeMatch])
                if let pageSize = Int(pageSizeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    DispatchQueue.main.async {
                        self.memoryPageSize = pageSize
                    }
                }
            }
            
            if let freePercentageMatch = result.range(of: "System-wide memory free percentage: (\\d+)%", options: .regularExpression) {
                let freePercentageString = String(result[freePercentageMatch])
                let percentage = freePercentageString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memoryFreePercentage = "\(percentage)%"
                }
            }
            
            if let pagesFreeMatch = result.range(of: "Pages free: (\\d+)", options: .regularExpression) {
                let pagesFreeString = String(result[pagesFreeMatch])
                let pagesFree = pagesFreeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memoryPagesFree = pagesFree
                }
            }
            
            if let pagesPurgeableMatch = result.range(of: "Pages purgeable: (\\d+)", options: .regularExpression) {
                let pagesPurgeableString = String(result[pagesPurgeableMatch])
                let pagesPurgeable = pagesPurgeableString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memoryPagesPurgeable = pagesPurgeable
                }
            }
            
            if let pagesActiveMatch = result.range(of: "Pages active: (\\d+)", options: .regularExpression) {
                let pagesActiveString = String(result[pagesActiveMatch])
                let pagesActive = pagesActiveString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memoryPagesActive = pagesActive
                }
            }
            
            if let pagesInactiveMatch = result.range(of: "Pages inactive: (\\d+)", options: .regularExpression) {
                let pagesInactiveString = String(result[pagesInactiveMatch])
                let pagesInactive = pagesInactiveString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memoryPagesInactive = pagesInactive
                }
            }
            
            if let pagesCompressedMatch = result.range(of: "Pages used by compressor: (\\d+)", options: .regularExpression) {
                let pagesCompressedString = String(result[pagesCompressedMatch])
                let pagesCompressed = pagesCompressedString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memoryPagesCompressed = pagesCompressed
                }
            }
            
            if let swapInsMatch = result.range(of: "Swapins: (\\d+)", options: .regularExpression) {
                let swapInsString = String(result[swapInsMatch])
                let swapIns = swapInsString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memorySwapIns = swapIns
                }
            }
            
            if let swapOutsMatch = result.range(of: "Swapouts: (\\d+)", options: .regularExpression) {
                let swapOutsString = String(result[swapOutsMatch])
                let swapOuts = swapOutsString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                DispatchQueue.main.async {
                    self.memorySwapOuts = swapOuts
                }
            }
            
            DispatchQueue.main.async {
                self.updateMemoryMenuItems()
            }
        }
    }
    
    private func updateNetworkDetails() {
        let ssidCommand = """
        for i in ${(o)$(ifconfig -lX "en[0-9]")};
        do 
            ipconfig getsummary ${i} | awk '/ SSID/ {print $NF}'
        done 2> /dev/null
        """
        
        runCommand(ssidCommand) { [weak self] result in
            DispatchQueue.main.async {
                self?.networkSSID = result.trimmingCharacters(in: .whitespacesAndNewlines)
                self?.updateMenuItems()
            }
        }
    }
    
    private func updateIPAndLoc() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + \" \" + .countryCode'"]
        process.standardOutput = pipe
        
        do {
            try process.run()
        } catch {
            print("Failed to run command: \(error)")
            return
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let output = String(data: data, encoding: .utf8) {
            let res = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
            if res.count == 2 {
                DispatchQueue.main.async {
                    self.ip = String(res[0])
                    self.ipLoc = String(res[1])
                }
            }
        }
    }
    
    private func updateCPUUsage() {
        let command = CPUPctMode == 0 ? "ps -A -o %cpu | awk '{s+=$1} END {print s}'" : "ps -A -o %cpu | awk '{s+=$1} END {printf \"%.1f\", s/8}'"
        runCommand(command) { res in
            let cleanedResult = res.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Double(cleanedResult), value.isFinite {
                DispatchQueue.main.async {
                    self.CPUUsage = cleanedResult
                    CPUHistory.shared.saveCurrentCPUUsage()
                }
            } else {
                print("Invalid CPU value received: \(res)")
            }
        }
    }
    
    private func updateBatteryStatus() {
        let batteryCommand = "ioreg -rn AppleSmartBattery"
        
        runCommand(batteryCommand) { [weak self] result in
            guard let self = self else { return }
            
            if let percentMatch = result.range(of: "\"CurrentCapacity\" = (\\d+)", options: .regularExpression) {
                let percentString = String(result[percentMatch])
                if let percent = Int(percentString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    DispatchQueue.main.async {
                        self.batteryPct = "\(percent)%"
                    }
                }
            }
            
            if let designCapacityMatch = result.range(of: "\"DesignCapacity\" = (\\d+)", options: .regularExpression) {
                let capacityString = String(result[designCapacityMatch])
                if let capacity = Int(capacityString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    DispatchQueue.main.async {
                        self.batteryDesignCapacity = "\(capacity)"
                    }
                }
            }
            
            if let currentCapacityMatch = result.range(of: "\"AppleRawCurrentCapacity\" = (\\d+)", options: .regularExpression) {
                let currentCapacityString = String(result[currentCapacityMatch])
                if let currentCapacity = Int(currentCapacityString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    DispatchQueue.main.async {
                        self.batteryCurrentCapacity = "\(currentCapacity)"
                    }
                }
            }
            
            if let cycleCountMatch = result.range(of: "\"CycleCount\" = (\\d+)", options: .regularExpression) {
                let cycleCountString = String(result[cycleCountMatch])
                if let cycleCount = Int(cycleCountString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    DispatchQueue.main.async {
                        self.batteryCycleCount = "\(cycleCount)"
                    }
                }
            }
            
            if let voltageMatch = result.range(of: "\"Voltage\" = (\\d+)", options: .regularExpression) {
                let voltageString = String(result[voltageMatch])
                if let voltage = Int(voltageString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    let volts = Double(voltage) / 1000.0
                    DispatchQueue.main.async {
                        self.batteryCellVoltage = String(format: "%.2f V", volts)
                    }
                }
            }
            
            if let temperatureMatch = result.range(of: "\"VirtualTemperature\" = (\\d+)", options: .regularExpression) {
                let temperatureString = String(result[temperatureMatch])
                if let temp = Int(temperatureString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    let celsius = Double(temp)/100.0
                    DispatchQueue.main.async {
                        self.batteryTemperature = String(format: "%.2f °C", celsius)
                    }
                }
            }
        }
        
        let batteryTimeCommand = "pmset -g batt | grep -o '[0-9]\\+:[0-9]\\+'"
        runCommand(batteryTimeCommand) { [weak self] result in
            let timeRemaining = result.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self?.batteryTime = timeRemaining.isEmpty ? "..." : timeRemaining
            }
        }
    }
    
    private func setupObservers() {
        setupCPUTimer()
        setupMemoryTimer()
        $CPUUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCPUStatusItem()
                self?.updateMenuItems()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest($ip, $ipLoc)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIPStatusItem()
                self?.updateMenuItems()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest($batteryPct, $batteryTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBatteryStatusItem()
                self?.updateMenuItems()
            }
            .store(in: &cancellables)
        
        $memoryFreePercentage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMemoryStatusItem()
                self?.updateMemoryMenuItems()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handlePreferenceChanges()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.handlePreferenceChanges()
                    self?.setupCPUTimer()
                    self?.setupMemoryTimer()
                }
                .store(in: &cancellables)
        
        handlePreferenceChanges()
    }
    
    private func setupCPUTimer() {
        cpuTimer?.invalidate()
        cpuTimer = Timer.scheduledTimer(
            withTimeInterval: CPURefreshRate,
            repeats: true
        ) { [weak self] _ in
            self?.updateCPUUsage()
        }
    }
    
    private func setupMemoryTimer() {
        memoryTimer?.invalidate()
        memoryTimer = Timer.scheduledTimer(withTimeInterval: memoryRefreshRate, repeats: true) { [weak self] _ in
            self?.updateMemoryDetails()
        }
    }
    
    private func handlePreferenceChanges() {
        if CPUMBESelect && cpuStatusItem == nil {
            setupCPUStatusItem()
        } else if !CPUMBESelect && cpuStatusItem != nil {
            NSStatusBar.system.removeStatusItem(cpuStatusItem!)
            cpuStatusItem = nil
        }
        
        if IPMBESelect && ipStatusItem == nil {
            setupIPStatusItem()
        } else if !IPMBESelect && ipStatusItem != nil {
            NSStatusBar.system.removeStatusItem(ipStatusItem!)
            ipStatusItem = nil
        }
        
        if batteryMBESelect && batteryStatusItem == nil {
            setupBatteryStatusItem()
        } else if !batteryMBESelect && batteryStatusItem != nil {
            NSStatusBar.system.removeStatusItem(batteryStatusItem!)
            batteryStatusItem = nil
        }
        
        if memoryMBESelect && memoryStatusItem == nil {
            setupMemoryStatusItem()
        } else if !memoryMBESelect && memoryStatusItem != nil {
            NSStatusBar.system.removeStatusItem(memoryStatusItem!)
            memoryStatusItem = nil
        }
        
        if portsMBESelect && portsStatusItem == nil {
            setupPortsStatusItem()
        } else if !portsMBESelect && portsStatusItem != nil {
            NSStatusBar.system.removeStatusItem(portsStatusItem!)
            portsStatusItem = nil
        }
        
        updateCPUStatusItem()
        updateMemoryStatusItem()
    }
    
    private func updateMenuItems() {
        if let cpuMenu = cpuStatusItem?.menu {
            for item in cpuMenu.items {
                if item.title.starts(with: "CPU Usage") {
                    item.title = "CPU Usage: \(CPUUsage)%"
                } else if item.title.starts(with: "Brand") {
                    item.title = "Brand: \(cpuBrand)"
                } else if item.title.starts(with: "    Cores") {
                    item.title = "    Cores: \(cpuCores)"
                } else if item.title.starts(with: "    Threads") {
                    item.title = "    Threads: \(cpuThreads)"
                } else if item.title.starts(with: "    Cache L1") {
                    item.title = "    Cache L1: \(cpuCacheL1)"
                } else if item.title.starts(with: "    Cache L2") {
                    item.title = "    Cache L2: \(cpuCacheL2)"
                } else if item.title.starts(with: "OS Version") {
                    item.title = "OS Version: \(osVersion)"
                } else if item.title.starts(with: "Kernel Version") {
                    item.title = "Kernel Version: \(kernelVersion)"
                }
            }
        }
        
        if let ipMenu = ipStatusItem?.menu, ipMenu.items.count > 2 {
            ipMenu.item(at: 0)?.title = "Public IP: \(ip) (\(ipLoc))"
            ipMenu.item(at: 1)?.title = "Network SSID: \(networkSSID.isEmpty ? "Unknown" : networkSSID)"
            ipMenu.item(at: 2)?.title = "Connected? \(networkMonitorWrapper.isReachable ? "Yes" : "...")"
        }
        
        if let batteryMenu = batteryStatusItem?.menu, batteryMenu.items.count > 1 {
            batteryMenu.item(at: 0)?.title = "Battery: \(batteryPct)"
            batteryMenu.item(at: 1)?.title = "Time remaining: \(batteryTime)"
        }
        
        if let batteryMenu = batteryStatusItem?.menu, batteryMenu.items.count > 5 {
            batteryMenu.item(at: 0)?.title = "Battery: \(batteryPct)"
//            batteryMenu.item(at: 1)?.title = "Status: \(batteryIsCharging ? "Charging" : "Discharging")"
            batteryMenu.item(at: 1)?.title = "Time remaining: \(batteryTime)"
            batteryMenu.item(at: 2)?.title = "Temperature: \(batteryTemperature)"
//            batteryMenu.item(at: 3)?.title = "Health: \(batteryHealth)"
            batteryMenu.item(at: 3)?.title = "Cycle count: \(batteryCycleCount)"
            batteryMenu.item(at: 6)?.title = "    Design: \(batteryDesignCapacity) mAh"
//            batteryMenu.item(at: 7)?.title = "    Maximum: \(batteryMaxCapacity) mAh"
            batteryMenu.item(at: 7)?.title = "    Current: \(batteryCurrentCapacity) mAh"
            batteryMenu.item(at: 9)?.title = "Cell voltage: \(batteryCellVoltage)"
        }
    }
    
    private func updateMemoryMenuItems() {
        if let memoryMenu = memoryStatusItem?.menu {
            for item in memoryMenu.items {
                if item.title.starts(with: "Memory Free") {
                    item.title = "Memory Free: \(memoryFreePercentage)"
                } else if item.title.starts(with: "Total Memory") {
                    item.title = "Total Memory: \(memoryTotal)"
                } else if item.title.starts(with: "    Free:") {
                    item.title = "    Free: \(memoryPagesFree)"
                } else if item.title.starts(with: "    Purgeable:") {
                    item.title = "    Purgeable: \(memoryPagesPurgeable)"
                } else if item.title.starts(with: "    Active:") {
                    item.title = "    Active: \(memoryPagesActive)"
                } else if item.title.starts(with: "    Inactive:") {
                    item.title = "    Inactive: \(memoryPagesInactive)"
                } else if item.title.starts(with: "    Compressed:") {
                    item.title = "    Compressed: \(memoryPagesCompressed)"
                } else if item.title.starts(with: "    Swap Ins:") {
                    item.title = "    Swap Ins: \(memorySwapIns)"
                } else if item.title.starts(with: "    Swap Outs:") {
                    item.title = "    Swap Outs: \(memorySwapOuts)"
                }
            }
        }
    }
    
    private func updatePortsMenu() {
        guard let menu = portsStatusItem?.menu else {
            portsStatusItem?.menu = NSMenu()
            updatePortsMenu()
            return
        }
        
        menu.removeAllItems()
        
        let titleItem = NSMenuItem(title: "Open Ports: \(openPorts.count)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        if openPorts.isEmpty {
            let noPortsItem = NSMenuItem(title: "No open ports detected", action: nil, keyEquivalent: "")
            noPortsItem.isEnabled = false
            menu.addItem(noPortsItem)
        } else {
            for portInfo in openPorts {
                let portData = extractPortData(from: portInfo)
                let portItem = NSMenuItem(title: portInfo, action: nil, keyEquivalent: "")
                
                let submenu = NSMenu()
                
                if let pid = portData.pid {
                    let killItem = NSMenuItem(title: "Kill Process", action: #selector(killPortProcess(_:)), keyEquivalent: "")
                    killItem.target = self
                    killItem.representedObject = pid
                    killItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Kill")
                    submenu.addItem(killItem)
                }
                
                if let port = portData.port {
                    let copyItem = NSMenuItem(title: "Copy URL", action: #selector(copyPortURL(_:)), keyEquivalent: "")
                    copyItem.target = self
                    copyItem.representedObject = port
                    copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
                    submenu.addItem(copyItem)
                    if isLocalhostPort(portInfo) {
                        let openItem = NSMenuItem(title: "Open in Browser", action: #selector(openPortInBrowser(_:)), keyEquivalent: "")
                        openItem.target = self
                        openItem.representedObject = port
                        openItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: "Open")
                        submenu.addItem(openItem)
                    }
                }
                
                portItem.submenu = submenu
                menu.addItem(portItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let openNewPortItem = NSMenuItem(title: "Open New Port...", action: #selector(showOpenPortDialog), keyEquivalent: "o")
        openNewPortItem.target = self
        menu.addItem(openNewPortItem)
        
        let portManagerItem = NSMenuItem(title: "Port Manager...", action: #selector(showPortManager), keyEquivalent: "m")
        portManagerItem.target = self
        menu.addItem(portManagerItem)
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshPorts), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func extractPortData(from portInfo: String) -> PortData {
        var result = PortData()
        
        // "process (PID 12345): portinfo"
        if let pidRange = portInfo.range(of: "\\(PID \\d+\\)", options: .regularExpression) {
            let pidString = portInfo[pidRange]
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "PID", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            result.pid = Int(pidString)
        }
        
        // ":8080" or "127.0.0.1:8080"
        if let portRange = portInfo.range(of: ":\\d+", options: .regularExpression) {
            let portString = String(portInfo[portRange].dropFirst())
            result.port = Int(portString)
        }
        
        return result
    }

    private func isLocalhostPort(_ portInfo: String) -> Bool {
        return portInfo.contains("127.0.0.1") ||
               portInfo.contains("localhost") ||
               (portInfo.contains(":") && !portInfo.contains("."))
    }
    
    private func initialDataLoad() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateCPUUsage()
            self.updateIPAndLoc()
            self.updateBatteryStatus()
            self.updateNetworkDetails()
            self.updateCPUDetails()
            self.updateMemoryDetails()
            self.updateOpenPorts()
        }
    }
    
    @objc private func showOpenPortDialog() {
        let alert = NSAlert()
        alert.messageText = "Open New Port"
        alert.informativeText = "Enter the port number and select a method:"
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 30, width: 300, height: 24))
        textField.placeholderString = "Port number (e.g. 8080)"
        accessoryView.addSubview(textField)
        
        let dropdown = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        for method in PortOpeningMethod.allCases {
            dropdown.addItem(withTitle: method.rawValue)
        }
        accessoryView.addSubview(dropdown)
        
        alert.accessoryView = accessoryView
        
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let portString = textField.stringValue
            if portString.isEmpty || Int(portString) == nil {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Port"
                errorAlert.informativeText = "Please enter a valid port number."
                errorAlert.runModal()
                return
            }
            
            let port = Int(portString)!
            let selectedMethod = PortOpeningMethod.allCases[dropdown.indexOfSelectedItem]
            openPort(port, method: selectedMethod)
        }
    }
    
    @objc private func showPortManager() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.title = "Port Manager"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        
        let portManagerView = PortManagerView(
            portData: portManagerData,
            refreshAction: { [weak self] in
                self?.updateOpenPorts()
            },
            openPortAction: { [weak self] port, method in
                self?.openPort(port, method: method)
            }
        )
        
        panel.contentView = NSHostingView(rootView: portManagerView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
    
    @objc private func killPortProcess(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? Int else { return }
        
        let alert = NSAlert()
        alert.messageText = "Kill Process?"
        alert.informativeText = "Are you sure you want to kill process with PID \(pid)?"
        alert.addButton(withTitle: "Kill")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            ProcessManager.shared.killProcessByPID(pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateOpenPorts()
            }
        }
    }

    @objc private func copyPortURL(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? Int else { return }
        let url = "http://localhost:\(port)"
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
        
        let alert = NSAlert()
        alert.messageText = "Copied to Clipboard"
        alert.informativeText = "URL copied: \(url)"
        alert.runModal()
    }

    @objc private func openPortInBrowser(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? Int else { return }
        let url = URL(string: "http://localhost:\(port)")!
        NSWorkspace.shared.open(url)
    }
    
    @objc private func refreshCPU() {
        updateCPUUsage()
        updateCPUDetails()
    }
    
    @objc private func refreshIP() {
        updateIPAndLoc()
        updateNetworkDetails()
    }
    
    @objc private func refreshBattery() {
        updateBatteryStatus()
    }
    
    @objc private func refreshMemory() {
        updateMemoryDetails()
    }
    
    @objc private func refreshPorts() {
        updateOpenPorts()
    }
    
    @objc private func openSettings() {
        let settingsPanel = createSettingsPanel()
        settingsPanel.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func openPort(_ port: Int, method: PortOpeningMethod) {
        let command = method.command(port)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        var outputData = Data()
        var errorData = Data()
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
            }
        }
        
        process.terminationHandler = { _ in
            DispatchQueue.main.async { [weak self] in
                if let errorOutput = String(data: errorData, encoding: .utf8),
                   errorOutput.contains("command not found") {
                    let toolName = self?.getToolName(for: method) ?? "the required tool"
                    let alert = NSAlert()
                    alert.messageText = "Tool Not Found"
                    alert.informativeText = "Failed to open port \(port): \(errorOutput)\n\nPlease install \(toolName)."
                    alert.runModal()
                }
                
                self?.updateOpenPorts()
            }
        }
        
        ProcessManager.shared.registerProcess(process, forPort: port)
        
        do {
            try process.run()
            DispatchQueue.main.async { [weak self] in
                self?.updateOpenPorts()
                
                let alert = NSAlert()
                alert.messageText = "Port Opening Started"
                alert.informativeText = "Started listening on port \(port) using \(method.rawValue).\n\nCommand: \(command)\n\nThe port will remain open until you close the application or kill the process."
                alert.runModal()
            }
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Opening Port"
                alert.informativeText = "Failed to execute command: \(error.localizedDescription)"
                alert.runModal()
            }
        }
    }

    private func getToolName(for method: PortOpeningMethod) -> String {
        switch method {
        case .netcat:
            return "netcat (nc)"
        case .python:
            return "Python 3"
//        case .node:
//            return "Node.js (npx)"
//        case .socat:
//            return "socat"
        }
    }
    
    private func createSettingsPanel() -> NSPanel {
        if let panel = settingsPanel {
            panel.makeKeyAndOrderFront(nil)
            return panel
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.title = "Settings"
        
        let settingsView = SettingsView(
            CPURefreshRate: $CPURefreshRate,
            memoryRefreshRate: $memoryRefreshRate,
            iconName: $iconName,
            CPUPctMode: $CPUPctMode,
            CPUMBESelect: $CPUMBESelect,
            IPMBESelect: $IPMBESelect,
            batteryMBESelect: $batteryMBESelect,
            memoryMBESelect: $memoryMBESelect,
            portsMBESelect: $portsMBESelect
        )
        
        panel.contentView = NSHostingView(rootView: settingsView)
        panel.center()
        
        settingsPanel = panel
        return panel
    }
    
    private func runCommand(_ command: String, completion: @escaping (String) -> Void) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                completion(output)
            }
        } catch {
            print("Command failed: \(error)")
        }
    }
    
    @objc private func showCPUHistoryGraph() {
        guard let button = cpuStatusItem?.button else { return }
        
        if cpuGraphPopover == nil {
            let popover = NSPopover()
            let history = CPUHistory.shared.getLast6Hours()
            let maxValue = CPUHistory.shared.currentMaxValue()
            let graphView = CPUHistoryGraph(history: history, maxValue: maxValue)
            popover.contentSize = NSSize(width: 320, height: 180)
            popover.behavior = .transient
            popover.contentViewController = NSViewController()
            popover.contentViewController?.view = NSHostingView(rootView: graphView)
            cpuGraphPopover = popover
        }
        
        if let popover = cpuGraphPopover, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            cpuGraphPopover?.performClose(nil)
        }
    }
}


class ProcessManager {
    static let shared = ProcessManager()
    
    private var runningProcesses: [Int: Process] = [:]
    private let processLock = NSLock()
    
    func registerProcess(_ process: Process, forPort port: Int) {
        processLock.lock()
        defer { processLock.unlock() }
        
        if let existingProcess = runningProcesses[port], existingProcess.isRunning {
            existingProcess.terminate()
        }
        
        runningProcesses[port] = process
        
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.cleanupProcess(forPort: port)
                AppDelegate.shared.updateOpenPorts()
            }
        }
    }
    
    func killProcessByPID(_ pid: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "kill -9 \(pid)"]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to kill process \(pid): \(error)")
        }
    }
    
    private func cleanupProcess(forPort port: Int) {
        processLock.lock()
        defer { processLock.unlock() }
        
        runningProcesses.removeValue(forKey: port)
    }
}

class PortManagerData: ObservableObject {
    @Published var openPorts: [String] = []
}
