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
import QuartzCore
//import IOKit

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

private extension AppDelegate {
    var cpuStatusItemWidth: CGFloat {
        switch cpuDisplayStyle {
        case 0: return 50
        case 1: return 45
        case 2: return 95
        default: return 95
        }
    }
    
    var chartWidth: CGFloat { 45 }
    var percentageWidth: CGFloat { 50 }
}

@available(macOS 14.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    enum BatteryMenuTitleOption: String, CaseIterable {
        case batteryPercentage = "Battery Percentage"
        case timeRemaining = "Time Remaining"
        case temperature = "Temperature"
        case cycleCount = "Cycle Count"
        case currentCapacity = "Current Capacity"
    }
    
    @ObservedObject private var networkMonitorWrapper = NetworkMonitorWrapper()
    @AppStorage("CPURefreshRate") var CPURefreshRate: TimeInterval = 5
    @AppStorage("memoryRefreshRate") var memoryRefreshRate: TimeInterval = 5
    @AppStorage("CPUPctMode") var CPUPctMode: Int = 0 // 0: 800, 1: 100
    @AppStorage("CPUMBESelect") var CPUMBESelect: Bool = true
    @AppStorage("IPMBESelect") var IPMBESelect: Bool = true
    @AppStorage("batteryMBESelect") var batteryMBESelect: Bool = true
    @AppStorage("memoryMBESelect") var memoryMBESelect: Bool = true
    @AppStorage("portsMBESelect") var portsMBESelect: Bool = true
    @AppStorage("cpuDisplayStyle") var cpuDisplayStyle: Int = 2 // 0: only %, 1: only chart, 2: both
    @AppStorage("memoryDisplayMode") var memoryDisplayMode: Int = 0
    @AppStorage("batteryMenuTitleOption") var batteryMenuTitleOptionRawValue: String = BatteryMenuTitleOption.batteryPercentage.rawValue
    @AppStorage("customMenuButtons") var customMenuButtonsData: Data = Data()
    @Published var customMenuButtons: [CustomMenuButton] = []
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
    @Published var batteryTemperature: Double = 0.0
    @Published var batteryCellVoltage: String = "?"
    @Published var networkSSID: String = ""
    @Published var networkDeviceCount: Int = 0
    @Published var cpuBrand: String = "Unknown"
    @Published var cpuCores: String = "?"
    @Published var cpuThreads: String = "?"
    @Published var cpuFrequency: String = "?"
    @Published var cpuCacheL1: String = "?"
    @Published var cpuCacheL2: String = "?"
    @Published var cpuPctUser: String = "?"
    @Published var cpuPctSys: String = "?"
    @Published var cpuPctIdle: String = "?"
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
    @Published var networkDevices: [(ip: String, mac: String/*, name: String*/)] = []
//    @Published var smcCategories: [SensorCategory] = []
//    @Published var smcAccessGranted: Bool = false
//    private var smcTimer: Timer?
//    private let smcReader = SMCReader()
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
    private var customStatusItems: [UUID: NSStatusItem] = [:]
    private var customTimers: [UUID: Timer] = [:]
    static var shared: AppDelegate!
    let portManagerData = PortManagerData()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared=self
        CPUHistory.shared.saveCurrentCPUUsage()
        setupStatusItems()
        setupObservers()
        initialDataLoad()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            AppUpdater.shared.checkForUpdates()
//        }
        if let decoded = try? JSONDecoder().decode([CustomMenuButton].self, from: customMenuButtonsData) {
            customMenuButtons = decoded
        } else {
            customMenuButtons = []
        }
        setupCustomMenuButtons()
//        checkSMCAccess()
//        setupSMCMonitoring()
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
            updateCPUStatusItem()
            
        let button = cpuStatusItem?.button
        button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        button?.widthAnchor.constraint(equalToConstant: cpuStatusItemWidth).isActive = true
//        let button = cpuStatusItem?.button
//        let width: CGFloat
//        switch cpuDisplayStyle {
//        case 0: width = 50
//        case 1: width = 45
//        case 2: width = 95
//        default: width = 95
//        }
//        button?.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
//        button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "CPU Usage")
//        button?.imagePosition = .imageLeading
//        button?.title = "\(CPUUsage)%"
        
        let menu = NSMenu()
        
        let usageItem = NSMenuItem(title: "CPU Usage: \(CPUUsage)%", action: nil, keyEquivalent: "")
        usageItem.isEnabled = false
        
        let userItem = NSMenuItem(title: "    User: \(cpuPctUser)%", action: nil, keyEquivalent: "")
        userItem.isEnabled = false
        
        let sysItem = NSMenuItem(title: "    System: \(cpuPctSys)%", action: nil, keyEquivalent: "")
        sysItem.isEnabled = false
        
        let idleItem = NSMenuItem(title: "    Idle: \(cpuPctIdle)%", action: nil, keyEquivalent: "")
        idleItem.isEnabled = false
        
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
        menu.addItem(userItem)
        menu.addItem(sysItem)
        menu.addItem(idleItem)
        menu.addItem(NSMenuItem.separator())
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
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
//        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
//        updateItem.target = self
//        menu.addItem(updateItem)
        menu.addItem(quitItem)
        cpuStatusItem?.menu = menu
    }
    
    private func setupMemoryStatusItem() {
        memoryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let button = memoryStatusItem?.button
        button?.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Usage")
        button?.imagePosition = .imageLeading
        button?.title = "\(memoryFreePercentage)"
        button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        
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
//        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
//        updateItem.target = self
//        menu.addItem(updateItem)
        menu.addItem(quitItem)
        
        memoryStatusItem?.menu = menu
    }
    
    private func setupPortsStatusItem() {
        portsStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let button = portsStatusItem?.button
        button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Open Ports")
        button?.imagePosition = .imageLeading
        button?.title = "\(openPorts.count)"
        button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        
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
                portItem.isEnabled = true
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
        
//        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
//        updateItem.target = self
//        menu.addItem(updateItem)
        
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
        
        let ipItem = NSMenuItem(title: "Public IP: \(ip) (\(ipLoc))", action: nil, keyEquivalent: "")
        ipItem.isEnabled = false
        
        let networkItem = NSMenuItem(title: "Network SSID: \(networkSSID.isEmpty ? "Unknown" : networkSSID)", action: nil, keyEquivalent: "")
        networkItem.isEnabled = false
        
        let statusItem = NSMenuItem(title: "Connected? \(networkMonitorWrapper.isReachable ? "Yes" : "No")", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        
        let devicesHeader = NSMenuItem(title: "Connected Devices: \(networkDeviceCount)", action: nil, keyEquivalent: "")
        devicesHeader.isEnabled = false
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshIP), keyEquivalent: "r")
        refreshItem.target = self
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        
        menu.addItem(ipItem)
        menu.addItem(networkItem)
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(devicesHeader)
        for device in networkDevices {
            let deviceItem = NSMenuItem(title: "    \(device.ip) (\(device.mac))", action: nil, keyEquivalent: "")
            deviceItem.isEnabled = false
            menu.addItem(deviceItem)
        }
        menu.addItem(NSMenuItem.separator())
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
        
        let temperatureItem = NSMenuItem(title: "Temperature: \(batteryTemperature) °C", action: nil, keyEquivalent: "")
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
//        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
//        updateItem.target = self
//        menu.addItem(updateItem)
        menu.addItem(quitItem)
        
        batteryStatusItem?.menu = menu
    }
    
    func setupCustomMenuButtons() {
        for(_, item) in customStatusItems {
            NSStatusBar.system.removeStatusItem(item)
        }
        customStatusItems.removeAll()
        customTimers.values.forEach { $0.invalidate() }
        customTimers.removeAll()
        let decoded: [CustomMenuButton]
        if let d = try? JSONDecoder().decode([CustomMenuButton].self, from: customMenuButtonsData) {
            decoded = d
        } else {
            decoded = []
        }
        customMenuButtons = decoded

        for button in decoded {
            if button.isVisible, button.items.contains(where: {$0.showInMenuBar}) {
                setupCustomMenuButton(button)
            }
        }
    }
    
//    private func checkSMCAccess() {
//        smcAccessGranted = smcReader.isConnected
//        if !smcAccessGranted {
//            showSMCAccessDeniedAlert()
//        }
//    }
//    
//    private func setupSMCMonitoring() {
//        fetchSMCData()
//        smcTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
//            self?.fetchSMCData()
//        }
//    }

    private func setupCustomMenuButton(_ button: CustomMenuButton) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        customStatusItems[button.id] = statusItem
        guard let menuBarItem = button.items.first(where: { $0.showInMenuBar }) else { return }
        statusItem.button?.title = menuBarItem.title

        let menu = NSMenu()
        for item in button.items where item.showInMenuBar {
            let menuItem = NSMenuItem(title: item.title, action: #selector(executeCustomCommand(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = (item, button.id)
            menu.addItem(menuItem)
        }
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        
        if let mainItem = button.items.first(where: { $0.showInMenuBar }) {
            updateCustomButtonTitle(buttonId: button.id, item: mainItem)
            
            if let interval = mainItem.refreshInterval {
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    self.executeCustomCommand(item: mainItem, buttonId: button.id)
                }
                customTimers[button.id] = timer
            }
        } else {
            statusItem.button?.title = button.title
        }
    }
    
//    private func fetchSMCData() {
//        guard smcAccessGranted else {
//            updateSMCMenuWithError()
//            return
//        }
//
//        DispatchQueue.global(qos: .userInitiated).async {
//            var newCategories: [SensorCategory] = []
//            
//            guard self.smcReader.readKey("TC0P") != nil else {
//                DispatchQueue.main.async {
//                    self.smcAccessGranted = false
//                    self.updateSMCMenuWithError()
//                }
//                return
//            }
//            
//            let categories: [(name: String, keys: [(key: String, description: String, unit: String?)])] = [
//                 ("Battery", [
//                     ("BNum", "Battery Count", nil),
//                     ("BSIn", "Battery Info", nil),
//                     ("BATP", "Battery Power", nil)
//                 ]),
//                 ("Current", [
//                     ("IPBR", "Charger BMON", "A"),
//                     ("ibuck5", "PMU2 ibuck5", "A"),
//                     ("ibuck8", "PMU2 ibuck8", "A"),
//                     ("ildo4", "PMU2 ildo4", "A"),
//                     ("ibuck0", "PMU ibuck0", "A"),
//                     ("ibuck1", "PMU ibuck1", "A"),
//                     ("ibuck2", "PMU ibuck2", "A"),
//                     ("ibuck4", "PMU ibuck4", "A"),
//                     ("ibuck7", "PMU ibuck7", "A"),
//                     ("ibuck9", "PMU ibuck9", "A"),
//                     ("ibuck11", "PMU ibuck11", "A"),
//                     ("ildo2", "PMU ildo2", "A"),
//                     ("ildo7", "PMU ildo7", "A"),
//                     ("ildo8", "PMU ildo8", "A"),
//                     ("ildo9", "PMU ildo9", "A")
//                 ]),
//                 ("Fans", [
//                     ("FNum", "Fan Count", nil)
//                 ]),
//                 ("Power", [
//                     ("PPBR", "Battery", "W"),
//                     ("PHPC", "Heatpipe", "W"),
//                     ("PSTR", "System Total", "W")
//                 ]),
//                 ("Temperature", [
//                     ("Ts1P", "Actuator", "°C"),
//                     ("TW0P", "Airport", "°C"),
//                     ("TB1T", "Battery 1", "°C"),
//                     ("TB2T", "Battery 2", "°C"),
//                     ("Te05", "CPU Efficiency Core 1", "°C"),
//                     ("Tp01", "CPU Performance Core 1", "°C"),
//                     ("Tp05", "CPU Performance Core 2", "°C"),
//                     ("Tp09", "CPU Performance Core 3", "°C"),
//                     ("Tp0D", "CPU Performance Core 4", "°C"),
//                     ("Tp0b", "CPU Performance Core 6", "°C"),
//                     ("Tp0f", "CPU Performance Core 7", "°C"),
//                     ("Tp0j", "CPU Performance Core 8", "°C"),
//                     ("TH0x", "Drive 0 OOBv3 Max", "°C"),
//                     ("Tg0f", "GPU 1", "°C"),
//                     ("TG0H", "GPU Heatsink 1", "°C"),
//                     ("Th0H", "Heatpipe 1", "°C"),
//                     ("Ts0S", "Memory Proximity", "°C"),
//                     ("temp", "NAND CH0 temp", "°C"),
//                     ("tcal", "PMU2 tcal", "°C"),
//                     ("tdev1", "PMU2 tdev1", "°C"),
//                     ("tdev2", "PMU2 tdev2", "°C"),
//                     ("tdev3", "PMU2 tdev3", "°C"),
//                     ("tdev4", "PMU2 tdev4", "°C"),
//                     ("tdev5", "PMU2 tdev5", "°C"),
//                     ("tdev6", "PMU2 tdev6", "°C"),
//                     ("tdev7", "PMU2 tdev7", "°C"),
//                     ("tdev8", "PMU2 tdev8", "°C"),
//                     ("tdie1", "PMU2 tdie1", "°C"),
//                     ("tdie2", "PMU2 tdie2", "°C"),
//                     ("tdie3", "PMU2 tdie3", "°C"),
//                     ("tdie4", "PMU2 tdie4", "°C"),
//                     ("tdie5", "PMU2 tdie5", "°C"),
//                     ("tdie6", "PMU2 tdie6", "°C"),
//                     ("tdie7", "PMU2 tdie7", "°C"),
//                     ("tdie8", "PMU2 tdie8", "°C"),
//                     ("Ts0P", "Palm Rest", "°C"),
//                     ("Tp0C", "Power Supply 1 Alt", "°C"),
//                     ("battery", "gas gauge battery", "°C")
//                 ]),
//                 ("Voltage", [
//                     ("VP0R", "12V Rail", "V"),
//                     ("VD0R", "DC In", "V"),
//                     ("vbuck5", "PMU2 vbuck5", "V"),
//                     ("vbuck6", "PMU2 vbuck6", "V"),
//                     ("vbuck8", "PMU2 vbuck8", "V"),
//                     ("vbuck10", "PMU2 vbuck10", "V"),
//                     ("vbuck12", "PMU2 vbuck12", "V"),
//                     ("vbuck14", "PMU2 vbuck14", "V"),
//                     ("vldo4", "PMU2 vldo4", "V"),
//                     ("vbuck0", "PMU vbuck0", "V"),
//                     ("vbuck1", "PMU vbuck1", "V"),
//                     ("vbuck2", "PMU vbuck2", "V"),
//                     ("vbuck3", "PMU vbuck3", "V"),
//                     ("vbuck4", "PMU vbuck4", "V"),
//                     ("vbuck7", "PMU vbuck7", "V"),
//                     ("vbuck9", "PMU vbuck9", "V"),
//                     ("vbuck11", "PMU vbuck11", "V"),
//                     ("vbuck13", "PMU vbuck13", "V"),
//                     ("vldo2", "PMU vldo2", "V"),
//                     ("vldo7", "PMU vldo7", "V"),
//                     ("vldo8", "PMU vldo8", "V"),
//                     ("vldo9", "PMU vldo9", "V")
//                 ])
//            ]
//            
//            for category in categories {
//                var sensors: [SensorData] = []
//                
//                for keyInfo in category.keys {
//                    if let (value, type) = self.smcReader.readKey(keyInfo.key) {
//                        let formattedValue: String
//                        if let unit = keyInfo.unit {
//                            formattedValue = String(format: "%.1f %@", value, unit)
//                        } else {
//                            formattedValue = String(format: "%.0f", value)
//                        }
//                        
//                        let sensor = SensorData(
//                            description: keyInfo.description,
//                            key: keyInfo.key,
//                            value: formattedValue,
//                            type: SensorType(rawValue: type)
//                        )
//                        sensors.append(sensor)
//                    }
//                }
//                
//                if !sensors.isEmpty {
//                    newCategories.append(SensorCategory(
//                        name: category.name,
//                        sensors: sensors
//                    ))
//                }
//            }
//            
//            DispatchQueue.main.async {
//                if newCategories.isEmpty {
//                    self.smcAccessGranted = false
//                    self.updateSMCMenuWithError()
//                } else {
//                    self.smcCategories = newCategories
//                    self.updateSMCMenuItems()
//                }
//            }
//        }
//    }
    
    private func updateCustomButtonTitle(buttonId: UUID, item: CustomMenuItem) {
        guard let statusItem = customStatusItems[buttonId] else { return }
        
        if statusItem.button?.title.isEmpty ?? true {
            statusItem.button?.title = item.title
        }
        
        runCommand(item.command) { output in
            DispatchQueue.main.async { [weak statusItem] in
                guard let statusItem = statusItem else { return }
                let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedOutput.isEmpty {
                    if let format = item.outputFormat {
                        let formatted = format.replacingOccurrences(of: "{output}", with: trimmedOutput)
                        statusItem.button?.title = formatted
                    } else {
                        statusItem.button?.title = trimmedOutput
                    }
                } else {
                    statusItem.button?.title = item.title
                }
            }
        }
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
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
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
            
//            menu.addItem(NSMenuItem.separator())
//            let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
//            updateItem.target = self
//            menu.addItem(updateItem)
            
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
        guard let button = batteryStatusItem?.button else { return }
        
        let selectedOption = BatteryMenuTitleOption(rawValue: batteryMenuTitleOptionRawValue) ?? .batteryPercentage
        
        switch selectedOption {
        case .batteryPercentage:
            button.title = batteryPct
        case .timeRemaining:
            button.title = batteryTime
        case .temperature:
            button.title = "\(Int(round(Double(batteryTemperature)))) °C"
        case .cycleCount:
            button.title = batteryCycleCount
        case .currentCapacity:
            button.title = "\(batteryCurrentCapacity) mAh"
        }
        
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    }
    
    private func updateCPUStatusItem() {
        guard let button = cpuStatusItem?.button else { return }
        
        button.subviews.forEach { $0.removeFromSuperview() }
        button.constraints.forEach { button.removeConstraint($0) }
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: cpuStatusItemWidth, height: 22))
        
        if cpuDisplayStyle == 1 || cpuDisplayStyle == 2 {
            let chartView = MiniChartView(frame: NSRect(
                x: 0,
                y: 4,
                width: chartWidth,
                height: 14
            ))
            chartView.setValues(CPUHistory.shared.getLast30Minutes().map { $0.value }, is800PercentMode: CPUPctMode == 1)
            chartView.color = .controlAccentColor
            containerView.addSubview(chartView)
        }
        
        if cpuDisplayStyle == 0 || cpuDisplayStyle == 2 {
            let xPosition = cpuDisplayStyle == 2 ? chartWidth + 1 : 0
            let textField = NSTextField(frame: NSRect(
                x: xPosition,
                y: 3,
                width: percentageWidth,
                height: 16
            ))
            textField.stringValue = "\(CPUUsage)%"
            textField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            textField.isBezeled = false
            textField.isEditable = false
            textField.isSelectable = false
            textField.drawsBackground = false
            textField.textColor = .labelColor
            containerView.addSubview(textField)
        }
        
        button.addSubview(containerView)
        
        button.widthAnchor.constraint(equalToConstant: cpuStatusItemWidth).isActive = true
        
        updateMenuItems()
    }
    
    private var memoryUsedPercentage: String {
        if let freePct = Double(memoryFreePercentage.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) {
            let usedPct = 100.0 - freePct
            return String(format: "%.0f%%", usedPct)
        }
        return "..."
    }

    private func updateMemoryStatusItem() {
        switch memoryDisplayMode {
        case 0:
            memoryStatusItem?.button?.title = memoryFreePercentage
        case 1:
            memoryStatusItem?.button?.title = memoryUsedPercentage
        default:
            memoryStatusItem?.button?.title = memoryFreePercentage
        }
        memoryStatusItem?.button?.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory Usage")
        memoryStatusItem?.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    }
    
//    private func updateSMCMenuItems() {
//        guard let mainMenu = NSApp.mainMenu else { return }
//        
//        var smcMenuItem: NSMenuItem!
//        
//        if let existingItem = mainMenu.item(withTitle: "Sensors") {
//            smcMenuItem = existingItem
//        } else {
//            smcMenuItem = NSMenuItem(title: "Sensors", action: nil, keyEquivalent: "")
//            mainMenu.insertItem(smcMenuItem, at: mainMenu.items.count - 1)
//        }
//        
//        let submenu = NSMenu(title: "System Sensors")
//        
//        for category in smcCategories {
//            let categoryItem = NSMenuItem(title: category.name, action: nil, keyEquivalent: "")
//            let categoryMenu = NSMenu(title: category.name)
//            
//            for sensor in category.sensors {
//                let item = NSMenuItem(
//                    title: "\(sensor.description): \(sensor.value)",
//                    action: nil,
//                    keyEquivalent: ""
//                )
//                item.isEnabled = false
//                
//                if sensor.value.contains("°C"), let temp = Double(sensor.value.replacingOccurrences(of: " °C", with: "")) {
//                    if temp > 80 {
//                        item.attributedTitle = NSAttributedString(
//                            string: item.title,
//                            attributes: [.foregroundColor: NSColor.systemRed]
//                        )
//                    } else if temp > 70 {
//                        item.attributedTitle = NSAttributedString(
//                            string: item.title,
//                            attributes: [.foregroundColor: NSColor.systemOrange]
//                        )
//                    }
//                }
//                
//                categoryMenu.addItem(item)
//            }
//            
//            categoryItem.submenu = categoryMenu
//            submenu.addItem(categoryItem)
//        }
//        
//        submenu.addItem(NSMenuItem.separator())
//        
//        let refreshItem = NSMenuItem(
//            title: "Refresh",
//            action: #selector(refreshSMCData),
//            keyEquivalent: "r"
//        )
//        refreshItem.target = self
//        submenu.addItem(refreshItem)
//        
//        let helpItem = NSMenuItem(
//            title: "Troubleshooting...",
//            action: #selector(showSMCAccessHelp),
//            keyEquivalent: ""
//        )
//        helpItem.target = self
//        submenu.addItem(helpItem)
//        
//        smcMenuItem.submenu = submenu
//    }
//    
//    private func updateSMCMenuWithError() {
//        guard let mainMenu = NSApp.mainMenu else { return }
//        
//        var smcMenuItem: NSMenuItem!
//        
//        if let existingItem = mainMenu.item(withTitle: "Sensors") {
//            smcMenuItem = existingItem
//        } else {
//            smcMenuItem = NSMenuItem(title: "Sensors", action: nil, keyEquivalent: "")
//            mainMenu.insertItem(smcMenuItem, at: mainMenu.items.count - 1)
//        }
//        
//        let submenu = NSMenu(title: "System Sensors")
//        
//        let errorItem = NSMenuItem(
//            title: "Sensor Access Denied",
//            action: nil,
//            keyEquivalent: ""
//        )
//        errorItem.isEnabled = false
//        submenu.addItem(errorItem)
//        
//        let helpItem = NSMenuItem(
//            title: "How to Fix...",
//            action: #selector(showSMCAccessHelp),
//            keyEquivalent: ""
//        )
//        helpItem.target = self
//        submenu.addItem(helpItem)
//        
//        smcMenuItem.submenu = submenu
//    }
//
//    @objc private func showSMCAccessHelp() {
//        let alert = NSAlert()
//        alert.messageText = "Sensor Access Required"
//        alert.addButton(withTitle: "Open System Preferences")
//        alert.addButton(withTitle: "OK")
//        
//        let response = alert.runModal()
//        if response == .alertFirstButtonReturn {
//            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
//        }
//    }
//
//    private func showSMCAccessDeniedAlert() {
//        let alert = NSAlert()
//        alert.messageText = "Sensor Access Not Available"
//        alert.informativeText = "This app can't access system sensors. Some features will be limited."
//        alert.runModal()
//    }
    
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
        
        let cpuPctDetailCommand = "top -l 1 -n 0 -F | grep 'CPU usage'"
        runCommand(cpuPctDetailCommand) { [weak self] result in
            DispatchQueue.main.async {
                let output = result
                let pattern = "CPU usage: (\\d+\\.\\d+)% user, (\\d+\\.\\d+)% sys, (\\d+\\.\\d+)% idle"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.count)) {
                    
                    if let userRange = Range(match.range(at: 1), in: output),
                       let sysRange = Range(match.range(at: 2), in: output),
                       let idleRange = Range(match.range(at: 3), in: output) {
                        
                        self?.cpuPctUser = "\((Double(output[userRange]) ?? 0.0)*(self?.CPUPctMode == 0 ? 8 : 1))%"
                        self?.cpuPctSys = "\((Double(output[sysRange]) ?? 0.0)*(self?.CPUPctMode == 0 ? 8 : 1))%"
                        self?.cpuPctIdle = "\((Double(output[idleRange]) ?? 0.0)*(self?.CPUPctMode == 0 ? 8 : 1))%"
                    }
                }
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
        
        let arpCommand = """
        arp -a | while read -r line; do
            ip=$(echo "$line" | awk -F '[()]' '{print $2}')
            mac=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2}/) print $i}')
            name=$(echo "$line" | awk '{print $1}')
            # If name is "?", try reverse DNS, else use as is
            if [[ "$name" == "?" ]]; then
            revname=$(dig +short -x $ip 2>/dev/null | sed 's/\\.$//')
            if [[ -z "$revname" ]]; then
                revname="Unknown"
            fi
            name="$revname"
            fi
            # If MAC is "(incomplete)", set as empty string
            if [[ "$mac" == "(incomplete)" ]]; then
            mac="Unknown"
            fi
            if [[ -n "$ip" ]]; then
            echo "$ip|$mac|$name"
            fi
        done
        """
        
        runCommand(arpCommand) { [weak self] res in
            DispatchQueue.main.async {
                let devices = res.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .compactMap { line -> (ip: String, mac: String, name: String)? in
                        let components = line.components(separatedBy: "|")
                        if components.count >= 3 {
                            let name = components[2].trimmingCharacters(in: .whitespaces)
                            return (
                                ip: components[0],
                                mac: components[1],
                                name: name == "" ? "Unknown" : name
                            )
                        }
                        return nil
                    }
                self?.networkDevices = devices.map { ($0.ip, $0.mac) }
                self?.networkDeviceCount = devices.count
                self?.updateIPMenuItem(with: devices)
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
                    self.updateCPUStatusItem()
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
                        self.batteryTemperature = Double(String(format: "%.2f", celsius)) ?? 0.0
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
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCPUStatusItem()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBatteryStatusItem()
            }
            .store(in: &cancellables)
        
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateIPAndLoc()
            self?.updateNetworkDetails()
        }
        
//        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
//            AppUpdater.shared.checkForUpdates()
//        }
        
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
        
        if CPUMBESelect {
            if cpuStatusItem == nil {
                setupCPUStatusItem()
            } else {
                updateCPUStatusItem()
            }
        }
        
        if let cpuButton = cpuStatusItem?.button {
            cpuButton.constraints.forEach { cpuButton.removeConstraint($0) }
            cpuButton.subviews.forEach { $0.removeFromSuperview() }
            updateCPUStatusItem()
            let width: CGFloat
            switch cpuDisplayStyle {
            case 0: width = 50
            case 1: width = 45
            case 2: width = 95
            default: width = 95
            }
            cpuButton.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
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
                } else if item.title.starts(with: "    User") {
                    item.title = "    User: \(cpuPctUser)"
                } else if item.title.starts(with: "    System") {
                    item.title = "    System: \(cpuPctSys)"
                } else if item.title.starts(with: "    Idle") {
                    item.title = "    Idle: \(cpuPctIdle)"
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
        
        if let ipMenu = ipStatusItem?.menu {
            for item in ipMenu.items {
                if item.title.starts(with: "Public IP") {
                    item.title = "Public IP: \(ip) (\(ipLoc))"
                } else if item.title.starts(with: "Network SSID") {
                    item.title = "Network SSID: \(networkSSID.isEmpty ? "Unknown" : networkSSID)"
                } else if item.title.starts(with: "Connected?") {
                    item.title = "Connected? \(networkMonitorWrapper.isReachable ? "Yes" : "No")"
                } else if item.title.starts(with: "Connected Devices") {
                    item.title = "Connected Devices: \(networkDeviceCount)"
                }
            }
            
            ipMenu.items.removeAll { $0.title.hasPrefix("    ") }
            
            if let devicesHeaderIndex = ipMenu.items.firstIndex(where: { $0.title.starts(with: "Connected Devices") }) {
                for device in networkDevices {
                    let deviceItem = NSMenuItem(title: "    \(device.ip) (\(device.mac))", action: nil, keyEquivalent: "")
                    deviceItem.isEnabled = false
                    ipMenu.insertItem(deviceItem, at: devicesHeaderIndex + 1)
                }
                
                if devicesHeaderIndex + networkDevices.count + 1 < ipMenu.items.count &&
                   !ipMenu.items[devicesHeaderIndex + networkDevices.count + 1].isSeparatorItem {
                    ipMenu.insertItem(NSMenuItem.separator(), at: devicesHeaderIndex + networkDevices.count + 1)
                }
            }
        }
        
        if let batteryMenu = batteryStatusItem?.menu, batteryMenu.items.count > 5 {
            batteryMenu.item(at: 0)?.title = "Battery: \(batteryPct)"
            batteryMenu.item(at: 1)?.title = "Time remaining: \(batteryTime)"
            batteryMenu.item(at: 2)?.title = "Temperature: \(batteryTemperature) °C"
            batteryMenu.item(at: 6)?.title = "    Design: \(batteryDesignCapacity) mAh"
        }
    }
    
    private func updateIPMenuItem(with devices: [(ip: String, mac: String, name: String)]) {
        guard let menu = ipStatusItem?.menu else { return }
        
        let nonDeviceItems = menu.items.filter { item in
            !item.title.hasPrefix("    ")
        }
        
        menu.removeAllItems()
        
        for item in nonDeviceItems {
            if item.title.contains("Connected Devices") {
                item.title = "Connected Devices: \(devices.count)"
            }
            menu.addItem(item)
            
            if item.title.contains("Connected Devices") {
                for device in devices {
                    let deviceName = device.name.hasSuffix(".") ? "Unknown" : device.name
                    let displayName = deviceName == "Unknown" ? "" : " (\(deviceName))"
                    let deviceItem = NSMenuItem(title: "    \(device.ip) - \(device.mac)\(displayName)", action: nil, keyEquivalent: "")
                    deviceItem.isEnabled = false
                    menu.addItem(deviceItem)
                }
            }
        }
    }
    
    private func updateMemoryMenuItems() {
        if let memoryMenu = memoryStatusItem?.menu {
            for item in memoryMenu.items {
                if item.title.starts(with: "Memory Free") || item.title.starts(with: "Memory Used") {
                    switch memoryDisplayMode {
                    case 0:
                        item.title = "Memory Free: \(memoryFreePercentage)"
                    case 1:
                        item.title = "Memory Used: \(memoryUsedPercentage)"
                    default:
                        item.title = "Memory Free: \(memoryFreePercentage)"
                    }
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

    private struct PortData {
        var pid: Int?
        var port: Int?
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
    
//    @objc private func refreshSMCData() {
//        fetchSMCData()
//    }
    
//    @objc private func checkForUpdates() {
//        AppUpdater.shared.checkForUpdates(force: true) {updateAvailable in
//            if !updateAvailable {
//                let alert = NSAlert()
//                alert.messageText = "You're up to date!"
//                alert.informativeText = "No updates available for Menubar-Info."
//                alert.runModal()
//            }
//        }
//    }
    
    @objc private func openSettings() {
        let settingsPanel = createSettingsPanel()
        settingsPanel.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func openCustomButtonSettings() {
        let settingsPanel = createSettingsPanel()
        settingsPanel.makeKeyAndOrderFront(nil)
    }
    
    @objc private func executeCustomCommand(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? CustomMenuItem else { return }
        executeCustomCommand(item: item)
    }
    
    private func executeCustomCommand(item: CustomMenuItem, buttonId: UUID? = nil) {
        if let buttonId = buttonId, let statusItem = customStatusItems[buttonId] {
            let currentTitle = statusItem.button?.title ?? item.title
            
            runCommand(item.command) { output in
                DispatchQueue.main.async {
                    let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOutput.isEmpty {
                        if let format = item.outputFormat {
                            let formatted = format.replacingOccurrences(of: "{output}", with: trimmedOutput)
                            statusItem.button?.title = formatted
                        } else {
                            statusItem.button?.title = trimmedOutput
                        }
                    } else {
                        statusItem.button?.title = currentTitle
                    }
                }
            }
        } else {
            runCommand(item.command) { output in
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Command Output"
                    alert.informativeText = output
                    alert.runModal()
                }
            }
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
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
            CPUPctMode: $CPUPctMode,
            CPUMBESelect: $CPUMBESelect,
            IPMBESelect: $IPMBESelect,
            batteryMBESelect: $batteryMBESelect,
            memoryMBESelect: $memoryMBESelect,
            portsMBESelect: $portsMBESelect,
            cpuDisplayStyle: $cpuDisplayStyle,
            memoryDisplayMode: $memoryDisplayMode,
            batteryMenuTitleOption: $batteryMenuTitleOptionRawValue,
            customMenuButtons: $customMenuButtonsData
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
        process.standardError = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                completion(output.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion("No output")
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
