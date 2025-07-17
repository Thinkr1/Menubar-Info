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

private struct RefreshIntervals {
    static let cpuUsage: TimeInterval = 5
    static let cpuDetails: TimeInterval = 3600
    static let battery: TimeInterval = 30
    static let memory: TimeInterval = 10
    static let network: TimeInterval = 60
    static let ipLocation: TimeInterval = 900
}

extension UserDefaults {
    enum CacheKeys: String {
        case cpuBrand
        case cpuCores
        case cpuThreads
        case osVersion
        case kernelVersion
    }
    
    func cache<T>(_ value: T, forKey key: CacheKeys) where T: Codable {
        if let encoded = try? JSONEncoder().encode(value) {
            set(encoded, forKey: key.rawValue)
        }
    }
    
    func cached<T>(forKey key: CacheKeys) -> T? where T: Codable {
        if let data = data(forKey: key.rawValue) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        return nil
    }
}

extension Bundle {
    public var appName: String { getInfo("CFBundleName")  }
    public var copyright: String { getInfo("NSHumanReadableCopyright") }
    
    public var appBuild: String { getInfo("CFBundleVersion") }
    public var appVersionLong: String { getInfo("CFBundleShortVersionString") }
    //public var appVersionShort: String { getInfo("CFBundleShortVersion") }
    
    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "" }
}

private extension AppDelegate {
    var progressViewHorizontalPadding: CGFloat { 12 }
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
    @Published var CPUUsage: String = "..." {
        didSet {
            if oldValue != CPUUsage {
                updateCPUStatusItem()
            }
        }
    }
    @Published var ip: String = "" {
        didSet {
            if oldValue != ip {
                updateIPStatusItem()
            }
        }
    }
    @Published var ipLoc: String = "" {
        didSet {
            if oldValue != ipLoc {
                updateIPAndLoc()
            }
        }
    }
    @Published var batteryPct: String = "..." {
        didSet {
            if oldValue != batteryPct {
                updateBatteryStatusItem()
                updateBatteryProgressView()
            }
        }
    }
    @Published var batteryTime: String = "" {
        didSet {
            if oldValue != batteryPct {
                updateBatteryStatusItem()
            }
        }
    }
    @Published var batteryCycleCount: String = "?" {
        didSet {
            if oldValue != batteryCycleCount {
                updateBatteryStatusItem()
            }
        }
    }
    @Published var batteryDesignCapacity: String = "?" {
        didSet {
            if oldValue != batteryDesignCapacity {
                updateBatteryStatusItem()
            }
        }
    }
    @Published var batteryCurrentCapacity: String = "?" {
        didSet {
            if oldValue != batteryCurrentCapacity {
                updateBatteryStatusItem()
            }
        }
    }
    //    @Published var batteryMaxCapacity: String = "?"
    //    @Published var batteryHealth: String = "?"
    //    @Published var batteryIsCharging: Bool = false
    @Published var batteryTemperature: Double = 0.0 {
        didSet {
            if oldValue != batteryTemperature {
                updateBatteryStatusItem()
            }
        }
    }
    @Published var batteryCellVoltage: String = "?" {
        didSet {
            if oldValue != batteryCellVoltage {
                updateBatteryStatusItem()
            }
        }
    }
    @Published var networkSSID: String = "" {
        didSet {
            if oldValue != networkSSID {
                updateNetworkDetails()
            }
        }
    }
    @Published var networkDeviceCount: Int = 0 {
        didSet {
            if oldValue != networkDeviceCount {
                updateNetworkDetails()
            }
        }
    }
    @Published var cpuBrand: String = "Unknown" {
        didSet {
            if oldValue != cpuBrand {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuCores: String = "?" {
        didSet {
            if oldValue != cpuCores {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuThreads: String = "?" {
        didSet {
            if oldValue != cpuThreads {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuFrequency: String = "?" {
        didSet {
            if oldValue != cpuFrequency {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuCacheL1: String = "?" {
        didSet {
            if oldValue != cpuCacheL1 {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuCacheL2: String = "?" {
        didSet {
            if oldValue != cpuCacheL2 {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuPctUser: String = "?" {
        didSet {
            if oldValue != cpuPctUser {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuPctSys: String = "?" {
        didSet {
            if oldValue != cpuPctSys {
                updateCPUStatusItem()
            }
        }
    }
    @Published var cpuPctIdle: String = "?" {
        didSet {
            if oldValue != cpuPctIdle {
                updateCPUStatusItem()
            }
        }
    }
    @Published var memoryTotal: String = "?" {
        didSet {
            if oldValue != memoryTotal {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryFreePercentage: String = "...%" {
        didSet {
            if oldValue != memoryFreePercentage {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryPagesFree: String = "?" {
        didSet {
            if oldValue != memoryPagesFree {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryPagesPurgeable: String = "?" {
        didSet {
            if oldValue != memoryPagesPurgeable {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryPagesActive: String = "?" {
        didSet {
            if oldValue != memoryPagesActive {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryPagesInactive: String = "?" {
        didSet {
            if oldValue != memoryPagesInactive {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryPagesCompressed: String = "?" {
        didSet {
            if oldValue != memoryPagesCompressed {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memoryPageSize: Int = 0 {
        didSet {
            if oldValue != memoryPageSize {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memorySwapIns: String = "?" {
        didSet {
            if oldValue != memorySwapIns {
                updateMemoryStatusItem()
            }
        }
    }
    @Published var memorySwapOuts: String = "?" {
        didSet {
            if oldValue != memorySwapOuts {
                updateMemoryStatusItem()
            }
        }
    }
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
    private var cpuDetailsTimer: Timer?
    private var networkTimer: Timer?
    private var ipLocationTimer: Timer?
    private var cpuGraphPopover: NSPopover?
    private var customStatusItems: [UUID: NSStatusItem] = [:]
    private var customTimers: [UUID: Timer] = [:]
    private var aboutBoxWindowController: NSWindowController?
    static var shared: AppDelegate!
    let portManagerData = PortManagerData()
    
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    
    private var lastCPUUpdateTime: Date = .distantPast
    private var lastBatteryUpdateTime: Date = .distantPast
    private var lastMemoryUpdateTime: Date = .distantPast
    
    @objc func showAboutWindow() {
        if aboutBoxWindowController == nil {
            let styleMask: NSWindow.StyleMask = [.closable, .miniaturizable,/* .resizable,*/ .titled]
            let window = NSWindow()
            window.styleMask = styleMask
            window.title = "About \(Bundle.main.appName)"
            window.contentView = NSHostingView(rootView: AboutView())
            window.center()
            aboutBoxWindowController = NSWindowController(window: window)
        }
        
        aboutBoxWindowController?.showWindow(aboutBoxWindowController?.window)
    }
    
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
        cpuDetailsTimer?.invalidate()
        networkTimer?.invalidate()
        ipLocationTimer?.invalidate()
    }
    
    private func addCommonMenuItems(to menu: NSMenu) {
        if !menu.items.isEmpty && !menu.items.last!.isSeparatorItem {
            menu.addItem(NSMenuItem.separator())
        }
        
        let aboutItem = NSMenuItem(title: "About...", action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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
    
    @objc private func doNothing() {}
    
    private func styledMenuItemText(label: String, value: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        attributedString.append(NSAttributedString(string: label, attributes: labelAttributes))
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor
        ]
        attributedString.append(NSAttributedString(string: value, attributes: valueAttributes))
        
        return attributedString
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
        
        let usageItem = NSMenuItem(title: "CPU Usage: \(CPUUsage)%", action: #selector(doNothing), keyEquivalent: "")
        usageItem.isEnabled = true
        
        let userItem = NSMenuItem(title: "    User: \(cpuPctUser)%", action: #selector(doNothing), keyEquivalent: "")
        userItem.isEnabled = true
        
        let sysItem = NSMenuItem(title: "    System: \(cpuPctSys)%", action: #selector(doNothing), keyEquivalent: "")
        sysItem.isEnabled = true
        
        let idleItem = NSMenuItem(title: "    Idle: \(cpuPctIdle)%", action: #selector(doNothing), keyEquivalent: "")
        idleItem.isEnabled = true
        
        let cpuProgressItem = NSMenuItem()
        let cpuProgressView = createProgressContainerView()
        
        let cpuProgressBar = NSView()
        cpuProgressBar.translatesAutoresizingMaskIntoConstraints = false
        cpuProgressBar.wantsLayer = true
        cpuProgressBar.layer?.cornerRadius = 4
        cpuProgressBar.layer?.masksToBounds = true
        cpuProgressBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        cpuProgressView.addSubview(cpuProgressBar)
        
        NSLayoutConstraint.activate([
            cpuProgressBar.leadingAnchor.constraint(equalTo: cpuProgressView.leadingAnchor, constant: progressViewHorizontalPadding),
            cpuProgressBar.trailingAnchor.constraint(equalTo: cpuProgressView.trailingAnchor, constant: -progressViewHorizontalPadding),
            cpuProgressBar.centerYAnchor.constraint(equalTo: cpuProgressView.centerYAnchor),
            cpuProgressBar.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        // init segments
        let userView = NSView()
        userView.translatesAutoresizingMaskIntoConstraints = false
        userView.wantsLayer = true
        userView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        
        let sysView = NSView()
        sysView.translatesAutoresizingMaskIntoConstraints = false
        sysView.wantsLayer = true
        sysView.layer?.backgroundColor = NSColor.systemOrange.cgColor
        
        let idleView = NSView()
        idleView.translatesAutoresizingMaskIntoConstraints = false
        idleView.wantsLayer = true
        idleView.layer?.backgroundColor = NSColor.systemGray.cgColor
        
        cpuProgressBar.addSubview(userView)
        cpuProgressBar.addSubview(sysView)
        cpuProgressBar.addSubview(idleView)
        
        // position segments
        NSLayoutConstraint.activate([
            userView.leadingAnchor.constraint(equalTo: cpuProgressBar.leadingAnchor),
            userView.topAnchor.constraint(equalTo: cpuProgressBar.topAnchor),
            userView.bottomAnchor.constraint(equalTo: cpuProgressBar.bottomAnchor),
            
            sysView.leadingAnchor.constraint(equalTo: userView.trailingAnchor),
            sysView.topAnchor.constraint(equalTo: cpuProgressBar.topAnchor),
            sysView.bottomAnchor.constraint(equalTo: cpuProgressBar.bottomAnchor),
            
            idleView.leadingAnchor.constraint(equalTo: sysView.trailingAnchor),
            idleView.trailingAnchor.constraint(equalTo: cpuProgressBar.trailingAnchor),
            idleView.topAnchor.constraint(equalTo: cpuProgressBar.topAnchor),
            idleView.bottomAnchor.constraint(equalTo: cpuProgressBar.bottomAnchor)
        ])
        
        cpuProgressItem.view = cpuProgressView
        
        let brandItem = NSMenuItem(title: "Brand: \(cpuBrand)", action: #selector(doNothing), keyEquivalent: "")
        brandItem.target=self
        
        let coresItem = NSMenuItem(title: "    Cores: \(cpuCores)", action: #selector(doNothing), keyEquivalent: "")
        coresItem.target=self
        
        let threadsItem = NSMenuItem(title: "    Threads: \(cpuThreads)", action: #selector(doNothing), keyEquivalent: "")
        threadsItem.target=self
        
        let cacheL1Item = NSMenuItem(title: "    Cache L1: \(cpuCacheL1)", action: #selector(doNothing), keyEquivalent: "")
        cacheL1Item.target=self
        
        let cacheL2Item = NSMenuItem(title: "    Cache L2: \(cpuCacheL2)", action: #selector(doNothing), keyEquivalent: "")
        cacheL2Item.target=self
        
        let osVersionItem = NSMenuItem(title: "OS Version: \(osVersion)", action: #selector(doNothing), keyEquivalent: "")
        osVersionItem.target=self
        
        let kernelVersionItem = NSMenuItem(title: "Kernel Version: \(kernelVersion)", action: #selector(doNothing), keyEquivalent: "")
        kernelVersionItem.target=self
        
        let showGraphItem = NSMenuItem(title: "Show CPU Usage Graph", action: #selector(showCPUHistoryGraph), keyEquivalent: "g")
        showGraphItem.target = self
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshCPU), keyEquivalent: "r")
        refreshItem.target = self
        
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
        
        menu.addItem(usageItem)
        menu.addItem(userItem)
        menu.addItem(sysItem)
        menu.addItem(idleItem)
        menu.addItem(cpuProgressItem)
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
//        menu.addItem(NSMenuItem.separator())
//        menu.addItem(settingsItem)
        //        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        //        updateItem.target = self
        //        menu.addItem(updateItem)
//        menu.addItem(quitItem)
        addCommonMenuItems(to: menu)
        updateCPUProgressView()
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
        
        let freePctItem = NSMenuItem(title: "Memory Free: \(memoryFreePercentage)", action: #selector(doNothing), keyEquivalent: "")
        freePctItem.isEnabled = true
        
        let memoryProgressItem = NSMenuItem()
        let memoryProgressView = createProgressContainerView()
        
        let memoryProgressBar = ProgressBarView(frame: NSRect(x: 0, y: 8, width: 180, height: 8))
        memoryProgressBar.translatesAutoresizingMaskIntoConstraints = false
        memoryProgressBar.value = Double(memoryUsedPercentage.replacingOccurrences(of: "%", with: "")) ?? 0
        memoryProgressBar.fillColor = NSColor.systemBlue
        memoryProgressView.addSubview(memoryProgressBar)
        
        NSLayoutConstraint.activate([
            memoryProgressBar.leadingAnchor.constraint(equalTo: memoryProgressView.leadingAnchor, constant: progressViewHorizontalPadding),
            memoryProgressBar.trailingAnchor.constraint(equalTo: memoryProgressView.trailingAnchor, constant: -progressViewHorizontalPadding),
            memoryProgressBar.centerYAnchor.constraint(equalTo: memoryProgressView.centerYAnchor),
            memoryProgressBar.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        memoryProgressItem.view = memoryProgressView
        
        let totalMemoryItem = NSMenuItem(title: "Total Memory: \(memoryTotal)", action: #selector(doNothing), keyEquivalent: "")
        totalMemoryItem.isEnabled = true
        
        let pagesSection = NSMenuItem(title: "Pages", action: #selector(doNothing), keyEquivalent: "")
        pagesSection.isEnabled = true
        
        let freeItem = NSMenuItem(title: "    Free: \(memoryPagesFree)", action: #selector(doNothing), keyEquivalent: "")
        freeItem.isEnabled = true
        
        let purgeableItem = NSMenuItem(title: "    Purgeable: \(memoryPagesPurgeable)", action: #selector(doNothing), keyEquivalent: "")
        purgeableItem.isEnabled = true
        
        let activeItem = NSMenuItem(title: "    Active: \(memoryPagesActive)", action: #selector(doNothing), keyEquivalent: "")
        activeItem.isEnabled = true
        
        let inactiveItem = NSMenuItem(title: "    Inactive: \(memoryPagesInactive)", action: #selector(doNothing), keyEquivalent: "")
        inactiveItem.isEnabled = true
        
        let compressedItem = NSMenuItem(title: "    Compressed: \(memoryPagesCompressed)", action: #selector(doNothing), keyEquivalent: "")
        compressedItem.isEnabled = true
        
        let swapSection = NSMenuItem(title: "Swap", action: #selector(doNothing), keyEquivalent: "")
        swapSection.isEnabled = true
        
        let swapInsItem = NSMenuItem(title: "    Swap Ins: \(memorySwapIns)", action: #selector(doNothing), keyEquivalent: "")
        swapInsItem.isEnabled = true
        
        let swapOutsItem = NSMenuItem(title: "    Swap Outs: \(memorySwapOuts)", action: #selector(doNothing), keyEquivalent: "")
        swapOutsItem.isEnabled = true
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMemory), keyEquivalent: "r")
        refreshItem.target = self
        
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
        
        menu.addItem(freePctItem)
        menu.addItem(memoryProgressItem)
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
//        menu.addItem(NSMenuItem.separator())
//        menu.addItem(settingsItem)
        //        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        //        updateItem.target = self
        //        menu.addItem(updateItem)
//        menu.addItem(quitItem)
        addCommonMenuItems(to: menu)
        updateMemoryProgressView()
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
        
        let titleItem = NSMenuItem(title: "Open Ports: \(openPorts.count)", action: #selector(doNothing), keyEquivalent: "")
        titleItem.isEnabled = true
        
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        if openPorts.isEmpty {
            let noPortsItem = NSMenuItem(title: "No open ports detected", action: #selector(doNothing), keyEquivalent: "")
            noPortsItem.isEnabled = true
            menu.addItem(noPortsItem)
        } else {
            for port in openPorts {
                let portItem = NSMenuItem(title: port, action: #selector(doNothing), keyEquivalent: "")
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
        
//        menu.addItem(NSMenuItem.separator())
        
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        menu.addItem(settingsItem)
        
        //        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        //        updateItem.target = self
        //        menu.addItem(updateItem)
        
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
//        menu.addItem(quitItem)
        
        addCommonMenuItems(to: menu)
        
        portsStatusItem?.menu = menu
        updatePortsMenu()
    }
    
    private func setupIPStatusItem() {
        ipStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateIPStatusItem()
        
        let menu = NSMenu()
        
        let ipItem = NSMenuItem(title: "Public IP: \(ip) (\(ipLoc))", action: #selector(doNothing), keyEquivalent: "")
        ipItem.isEnabled = true
        
        let networkItem = NSMenuItem(title: "Network SSID: \(networkSSID.isEmpty ? "Unknown" : networkSSID)", action: #selector(doNothing), keyEquivalent: "")
        networkItem.isEnabled = true
        
        let statusItem = NSMenuItem(title: "Connected? \(networkMonitorWrapper.isReachable ? "Yes" : "No")", action: #selector(doNothing), keyEquivalent: "")
        statusItem.isEnabled = true
        
        let devicesHeader = NSMenuItem(title: "Connected Devices: \(networkDeviceCount)", action: #selector(doNothing), keyEquivalent: "")
        devicesHeader.isEnabled = true
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshIP), keyEquivalent: "r")
        refreshItem.target = self
        
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
        
        menu.addItem(ipItem)
        menu.addItem(networkItem)
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(devicesHeader)
        for device in networkDevices {
            let deviceItem = NSMenuItem(title: "    \(device.ip) (\(device.mac))", action: #selector(doNothing), keyEquivalent: "")
            deviceItem.isEnabled = true
            menu.addItem(deviceItem)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(refreshItem)
//        menu.addItem(NSMenuItem.separator())
//        menu.addItem(settingsItem)
//        menu.addItem(quitItem)
        addCommonMenuItems(to: menu)
        ipStatusItem?.menu = menu
    }
    
    private func setupBatteryStatusItem() {
        batteryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateBatteryStatusItem()
        
        let menu = NSMenu()
        
        let batteryItem = NSMenuItem(title: "Battery: \(batteryPct)", action: #selector(doNothing), keyEquivalent: "")
        batteryItem.isEnabled = true
        
        let batteryProgressItem = NSMenuItem()
        let batteryProgressView = createProgressContainerView()
        
        let batteryProgressBar = ProgressBarView()
        batteryProgressBar.translatesAutoresizingMaskIntoConstraints = false
        batteryProgressBar.value = Double(batteryPct.replacingOccurrences(of: "%", with: "")) ?? 0
        batteryProgressBar.fillColor = NSColor.systemGreen
        batteryProgressView.addSubview(batteryProgressBar)
        
        NSLayoutConstraint.activate([
            batteryProgressBar.leadingAnchor.constraint(equalTo: batteryProgressView.leadingAnchor, constant: progressViewHorizontalPadding),
            batteryProgressBar.trailingAnchor.constraint(equalTo: batteryProgressView.trailingAnchor, constant: -progressViewHorizontalPadding),
            batteryProgressBar.centerYAnchor.constraint(equalTo: batteryProgressView.centerYAnchor),
            batteryProgressBar.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        batteryProgressItem.view = batteryProgressView
        
        //        let batteryStatusMenuItem = NSMenuItem(title: "Status: \(batteryIsCharging ? "Charging" : "Discharging")", action: #selector(doNothing), keyEquivalent: "")
        //        batteryStatusMenuItem.isEnabled = true
        
        let timeItem = NSMenuItem(title: "Time remaining: \(batteryTime)", action: #selector(doNothing), keyEquivalent: "")
        timeItem.isEnabled = true
        
        let temperatureItem = NSMenuItem(title: "Temperature: \(batteryTemperature) °C", action: #selector(doNothing), keyEquivalent: "")
        temperatureItem.isEnabled = true
        
        //        let healthItem = NSMenuItem(title: "Health: \(batteryHealth)", action: #selector(doNothing), keyEquivalent: "")
        //        healthItem.isEnabled = true
        
        let cycleCountItem = NSMenuItem(title: "Cycle count: \(batteryCycleCount)", action: #selector(doNothing), keyEquivalent: "")
        cycleCountItem.isEnabled = true
        
        let capacitySection = NSMenuItem(title: "Capacity", action: #selector(doNothing), keyEquivalent: "")
        capacitySection.isEnabled = true
        
        let designCapacityItem = NSMenuItem(title: "    Design: \(batteryDesignCapacity) mAh", action: #selector(doNothing), keyEquivalent: "")
        designCapacityItem.isEnabled = true
        
        //        let maxCapacityItem = NSMenuItem(title: "    Maximum: \(batteryMaxCapacity) mAh", action: #selector(doNothing), keyEquivalent: "")
        //        maxCapacityItem.isEnabled = true
        
        let currentCapacityItem = NSMenuItem(title: "    Current: \(batteryCurrentCapacity) mAh", action: #selector(doNothing), keyEquivalent: "")
        currentCapacityItem.isEnabled = true
        
        let voltageItem = NSMenuItem(title: "Cell voltage: \(batteryCellVoltage)", action: #selector(doNothing), keyEquivalent: "")
        voltageItem.isEnabled = true
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshBattery), keyEquivalent: "r")
        refreshItem.target = self
        
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
        
        menu.addItem(batteryItem)
        menu.addItem(batteryProgressItem)
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
//        menu.addItem(NSMenuItem.separator())
//        menu.addItem(settingsItem)
        //        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        //        updateItem.target = self
        //        menu.addItem(updateItem)
//        menu.addItem(quitItem)
        addCommonMenuItems(to: menu)
        updateBatteryProgressView()
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
//        menu.addItem(NSMenuItem.separator())
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        menu.addItem(settingsItem)
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
//        menu.addItem(quitItem)
        
        addCommonMenuItems(to: menu)
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
            
            let titleItem = NSMenuItem()
            titleItem.attributedTitle = styledMenuItemText(label: "Open Ports: ", value: "\(openPorts.count)")
            titleItem.action = #selector(doNothing)
            titleItem.isEnabled = true
            menu.addItem(titleItem)
            menu.addItem(NSMenuItem.separator())
            
            if openPorts.isEmpty {
                let noPortsItem = NSMenuItem(title: "No open ports detected", action: #selector(doNothing), keyEquivalent: "")
                noPortsItem.isEnabled = true
                menu.addItem(noPortsItem)
            } else {
                for portInfo in openPorts {
                    let portData = extractPortData(from: portInfo)
                    let portItem = NSMenuItem(title: portInfo, action: #selector(doNothing), keyEquivalent: "")
                    
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
            
            if !standardItems.contains(where: { $0.action == #selector(showAboutWindow) }) {
                let aboutItem = NSMenuItem(title: "About...", action: #selector(showAboutWindow), keyEquivalent: "")
                aboutItem.target = self
                menu.addItem(aboutItem)
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
            chartView.setValues(CPUHistory.shared.getLast30MinutesValues(is800PercentMode: CPUPctMode == 0), is800PercentMode: CPUPctMode == 0)
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
    //            smcMenuItem = NSMenuItem(title: "Sensors", action: #selector(doNothing), keyEquivalent: "")
    //            mainMenu.insertItem(smcMenuItem, at: mainMenu.items.count - 1)
    //        }
    //
    //        let submenu = NSMenu(title: "System Sensors")
    //
    //        for category in smcCategories {
    //            let categoryItem = NSMenuItem(title: category.name, action: #selector(doNothing), keyEquivalent: "")
    //            let categoryMenu = NSMenu(title: category.name)
    //
    //            for sensor in category.sensors {
    //                let item = NSMenuItem(
    //                    title: "\(sensor.description): \(sensor.value)",
    //                    action: #selector(doNothing),
    //                    keyEquivalent: ""
    //                )
    //                item.isEnabled = true
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
    //            smcMenuItem = NSMenuItem(title: "Sensors", action: #selector(doNothing), keyEquivalent: "")
    //            mainMenu.insertItem(smcMenuItem, at: mainMenu.items.count - 1)
    //        }
    //
    //        let submenu = NSMenu(title: "System Sensors")
    //
    //        let errorItem = NSMenuItem(
    //            title: "Sensor Access Denied",
    //            action: #selector(doNothing),
    //            keyEquivalent: ""
    //        )
    //        errorItem.isEnabled = true
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
        if let cachedBrand: String = UserDefaults.standard.cached(forKey: .cpuBrand) {
            self.cpuBrand = cachedBrand
        } else {
            let brandCommand = "sysctl -n machdep.cpu.brand_string"
            runCommand(brandCommand) { [weak self] result in
                let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self?.cpuBrand = cleaned.isEmpty ? "Unknown" : cleaned
                    UserDefaults.standard.cache(self?.cpuBrand ?? "Unknown", forKey: .cpuBrand)
                }
            }
        }
        
        if let cachedCores: String = UserDefaults.standard.cached(forKey: .cpuCores) {
            self.cpuBrand = cachedCores
        } else {
            let coresCommand = "sysctl -n hw.perflevel0.physicalcpu"
            runCommand(coresCommand) { [weak self] result in
                DispatchQueue.main.async {
                    self?.cpuCores = result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        if let cachedThreads: String = UserDefaults.standard.cached(forKey: .cpuThreads) {
            self.cpuBrand = cachedThreads
        } else {
            let threadsCommand = "sysctl -n hw.logicalcpu"
            runCommand(threadsCommand) { [weak self] result in
                DispatchQueue.main.async {
                    self?.cpuThreads = result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
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
        
        if let cachedOS: String = UserDefaults.standard.cached(forKey: .osVersion) {
            self.cpuBrand = cachedOS
        } else {
            let osVersionCommand = "sw_vers -productVersion"
            runCommand(osVersionCommand) { [weak self] result in
                DispatchQueue.main.async {
                    self?.osVersion = result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        if let cachedKernel: String = UserDefaults.standard.cached(forKey: .kernelVersion) {
            self.cpuBrand = cachedKernel
        } else {
            let kernelCommand = "sysctl -n kern.version"
            runCommand(kernelCommand) { [weak self] result in
                DispatchQueue.main.async {
                    self?.kernelVersion = result.trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: ";").first?
                        .trimmingCharacters(in: .whitespaces) ?? "Unknown"
                }
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
        updateCPUProgressView()
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
            updateMemoryProgressView()
            DispatchQueue.main.async {
                self.updateMemoryMenuItems()
            }
        }
    }
    
    private func updateMemoryProgressView() {
        DispatchQueue.main.async {
            guard let menu = self.memoryStatusItem?.menu,
                  menu.numberOfItems > 1,
                  let progressItem = menu.item(at: 1),
                  let progressView = progressItem.view,
                  let progressBar = progressView.subviews.first as? ProgressBarView else { return }
            progressBar.value = Double(self.memoryUsedPercentage.replacingOccurrences(of: "%", with: "")) ?? 0
        }
    }
    
    private func updateCPUProgressView() {
        guard let menu = cpuStatusItem?.menu,
              menu.numberOfItems > 4,
              let progressItem = menu.item(at: 4),
              let cpuProgressView = progressItem.view,
              let cpuProgressBar = cpuProgressView.subviews.first,
              cpuProgressBar.subviews.count >= 3 else {
            return
        }
        
        let userPct = Double(cpuPctUser.replacingOccurrences(of: "%", with: "")) ?? 0
        let sysPct = Double(cpuPctSys.replacingOccurrences(of: "%", with: "")) ?? 0
        
        let scaleFactor = CPUPctMode == 0 ? 8.0 : 1.0
        
        let normalizedUserPct = userPct / scaleFactor
        let normalizedSysPct = sysPct / scaleFactor
        
        let userView = cpuProgressBar.subviews[0]
        let sysView = cpuProgressBar.subviews[1]
        let idleView = cpuProgressBar.subviews[2]
        
        let totalWidth = cpuProgressBar.bounds.width
        
        userView.constraints.forEach { userView.removeConstraint($0) }
        sysView.constraints.forEach { sysView.removeConstraint($0) }
        idleView.constraints.forEach { idleView.removeConstraint($0) }
        
        let userWidth = abs(totalWidth * CGFloat(normalizedUserPct / 100) - (2*progressViewHorizontalPadding))
        let sysWidth = abs(totalWidth * CGFloat(normalizedSysPct / 100) - (2*progressViewHorizontalPadding))
        
        userView.widthAnchor.constraint(equalToConstant: userWidth).isActive = true
        sysView.widthAnchor.constraint(equalToConstant: sysWidth).isActive = true
        
        NSLayoutConstraint.activate([
            userView.leadingAnchor.constraint(equalTo: cpuProgressBar.leadingAnchor),
            sysView.leadingAnchor.constraint(equalTo: userView.trailingAnchor),
            idleView.leadingAnchor.constraint(equalTo: sysView.trailingAnchor),
            idleView.trailingAnchor.constraint(equalTo: cpuProgressBar.trailingAnchor)
        ])
        
        cpuProgressView.needsLayout = true
    }
    
    private func updateBatteryProgressView() {
        guard let menu = batteryStatusItem?.menu,
              menu.numberOfItems > 1,
              let progressItem = menu.item(at: 1),
              let progressView = progressItem.view,
              let progressBar = progressView.subviews.first as? ProgressBarView else {
            return
        }
        progressBar.value = Double(batteryPct.replacingOccurrences(of: "%", with: "")) ?? 0
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
            mac="N/A"
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
        guard networkMonitorWrapper.isReachable else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.updateIPAndLoc()
            }
            return
        }
        
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + \" \" + .countryCode'"]
        process.standardOutput = pipe
        
        var retryCount = 0
        let maxRetries = 3
        
        func attempt() {
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                
                if let output = String(data: data, encoding: .utf8) {
                    let res = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
                    if res.count == 2 {
                        DispatchQueue.main.async {
                            self.ip = String(res[0])
                            self.ipLoc = String(res[1])
                        }
                        return
                    }
                }
                
                if retryCount < maxRetries {
                    retryCount += 1
                    let delay = pow(2.0, Double(retryCount)) // Exponential backoff
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                }
            } catch {
                if retryCount < maxRetries {
                    retryCount += 1
                    let delay = pow(2.0, Double(retryCount))
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                }
            }
        }
        
        attempt()
    }
    
    private func updateCPUUsage() {
        let now = Date()
        guard now.timeIntervalSince(lastCPUUpdateTime) >= RefreshIntervals.cpuUsage else { return }
        lastCPUUpdateTime = now
        
        let operation = BlockOperation { [weak self] in
            let command = self?.CPUPctMode == 0 ? "ps -A -o %cpu | awk '{s+=$1} END {print s}'" : "ps -A -o %cpu | awk '{s+=$1} END {printf \"%.1f\", s/8}'"
            self?.runCommand(command) { res in
                let cleanedResult = res.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value = Double(cleanedResult), value.isFinite {
                    DispatchQueue.main.async {
                        self?.CPUUsage = cleanedResult
                        CPUHistory.shared.saveCurrentCPUUsage()
                    }
                }
            }
        }
        operation.queuePriority = .high
        operationQueue.addOperation(operation)
    }
    
    private func updateBatteryStatus() {
        let now = Date()
        guard now.timeIntervalSince(lastBatteryUpdateTime) >= RefreshIntervals.battery else { return }
        lastBatteryUpdateTime = now
        
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
        updateBatteryProgressView()
    }
    
    private func setupObservers() {
        setupCPUTimer()
        setupCPUDetailsTimer()
        setupMemoryTimer()
        setupNetworkTimer()
        setupIPLocationTimer()
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
        
        //        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
        //            self?.updateIPAndLoc()
        //            self?.updateNetworkDetails()
        //        }
        
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
    
    private func setupCPUDetailsTimer() {
        cpuDetailsTimer?.invalidate()
        cpuDetailsTimer = Timer.scheduledTimer(
            withTimeInterval: RefreshIntervals.cpuDetails,
            repeats: true
        ) { [weak self] _ in
            self?.updateCPUDetails()
        }
    }
    
    private func setupMemoryTimer() {
        memoryTimer?.invalidate()
        memoryTimer = Timer.scheduledTimer(withTimeInterval: memoryRefreshRate, repeats: true) { [weak self] _ in
            self?.updateMemoryDetails()
        }
    }
    
    private func setupNetworkTimer() {
        networkTimer?.invalidate()
        networkTimer = Timer.scheduledTimer(
            withTimeInterval: RefreshIntervals.network,
            repeats: true
        ) { [weak self] _ in
            self?.updateNetworkDetails()
        }
    }
    
    private func setupIPLocationTimer() {
        ipLocationTimer?.invalidate()
        ipLocationTimer = Timer.scheduledTimer(
            withTimeInterval: RefreshIntervals.ipLocation,
            repeats: true
        ) { [weak self] _ in
            self?.updateIPAndLoc()
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
        setupCPUDetailsTimer()
        setupNetworkTimer()
        setupIPLocationTimer()
    }
    
    private func updateMenuItems() {
        if let cpuMenu = cpuStatusItem?.menu {
            for item in cpuMenu.items {
                if item.title.starts(with: "CPU Usage") {
                    item.attributedTitle = styledMenuItemText(label: "CPU Usage: ", value: "\(CPUUsage)%")
                } else if item.title.starts(with: "Brand") {
                    item.attributedTitle = styledMenuItemText(label: "Brand: ", value: cpuBrand)
                } else if item.title.starts(with: "    User") {
                    item.attributedTitle = styledMenuItemText(label: "    User: ", value: cpuPctUser)
                } else if item.title.starts(with: "    System") {
                    item.attributedTitle = styledMenuItemText(label: "    System: ", value: cpuPctSys)
                } else if item.title.starts(with: "    Idle") {
                    item.attributedTitle = styledMenuItemText(label: "    Idle: ", value: cpuPctIdle)
                } else if item.title.starts(with: "    Cores") {
                    item.attributedTitle = styledMenuItemText(label: "    Cores: ", value: cpuCores)
                } else if item.title.starts(with: "    Threads") {
                    item.attributedTitle = styledMenuItemText(label: "    Threads: ", value: cpuThreads)
                } else if item.title.starts(with: "    Cache L1") {
                    item.attributedTitle = styledMenuItemText(label: "    Cache L1: ", value: cpuCacheL1)
                } else if item.title.starts(with: "    Cache L2") {
                    item.attributedTitle = styledMenuItemText(label: "    Cache L2: ", value: cpuCacheL2)
                } else if item.title.starts(with: "OS Version") {
                    item.attributedTitle = styledMenuItemText(label: "OS Version: ", value: osVersion)
                } else if item.title.starts(with: "Kernel Version") {
                    item.attributedTitle = styledMenuItemText(label: "Kernel Version: ", value: kernelVersion)
                }
            }
        }
        
        if let ipMenu = ipStatusItem?.menu {
            for item in ipMenu.items {
                if item.title.starts(with: "Public IP") {
                    item.attributedTitle = styledMenuItemText(label: "Public IP: ", value: "\(ip) (\(ipLoc))")
                } else if item.title.starts(with: "Network SSID") {
                    item.attributedTitle = styledMenuItemText(label: "Network SSID: ", value: networkSSID.isEmpty ? "Unknown" : networkSSID)
                } else if item.title.starts(with: "Connected?") {
                    item.attributedTitle = styledMenuItemText(label: "Connected? ", value: networkMonitorWrapper.isReachable ? "Yes" : "No")
                } else if item.title.starts(with: "Connected Devices") {
                    item.attributedTitle = styledMenuItemText(label: "Connected Devices: ", value: "\(networkDeviceCount)")
                }
            }
            
            ipMenu.items.removeAll { $0.title.hasPrefix("    ") }
            
            if let devicesHeaderIndex = ipMenu.items.firstIndex(where: { $0.title.starts(with: "Connected Devices") }) {
                for device in networkDevices {
                    let deviceItem = NSMenuItem(title: "    \(device.ip) (\(device.mac))", action: #selector(doNothing), keyEquivalent: "")
                    deviceItem.isEnabled = true
                    ipMenu.insertItem(deviceItem, at: devicesHeaderIndex + 1)
                }
                
                if devicesHeaderIndex + networkDevices.count + 1 < ipMenu.items.count &&
                    !ipMenu.items[devicesHeaderIndex + networkDevices.count + 1].isSeparatorItem {
                    ipMenu.insertItem(NSMenuItem.separator(), at: devicesHeaderIndex + networkDevices.count + 1)
                }
            }
        }
        
        if let batteryMenu = batteryStatusItem?.menu, batteryMenu.items.count > 5 {
            batteryMenu.item(at: 0)?.attributedTitle = styledMenuItemText(label: "Battery: ", value: batteryPct)
            batteryMenu.item(at: 2)?.attributedTitle = styledMenuItemText(label: "Time remaining: ", value: batteryTime)
            batteryMenu.item(at: 3)?.attributedTitle = styledMenuItemText(label: "Temperature: ", value: "\(batteryTemperature) °C")
            batteryMenu.item(at: 4)?.attributedTitle = styledMenuItemText(label: "Cycle count: ", value: batteryCycleCount)
            batteryMenu.item(at: 7)?.attributedTitle = styledMenuItemText(label: "    Design: ", value: "\(batteryDesignCapacity) mAh")
            batteryMenu.item(at: 8)?.attributedTitle = styledMenuItemText(label: "    Current: ", value: "\(batteryCurrentCapacity) mAh")
            batteryMenu.item(at: 10)?.attributedTitle = styledMenuItemText(label: "Cell voltage: ", value: batteryCellVoltage)
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
                item.attributedTitle = styledMenuItemText(label: "Connected Devices: ", value: "\(devices.count)")
            }
            menu.addItem(item)
            
            if item.title.contains("Connected Devices") {
                for device in devices {
                    let deviceName = device.name.hasSuffix(".") ? "Unknown" : device.name
                    let displayName = deviceName == "Unknown" ? "" : " (\(deviceName))"
                    let deviceItem = NSMenuItem(title: "    \(device.ip) - \(device.mac)\(displayName)", action: #selector(doNothing), keyEquivalent: "")
                    deviceItem.isEnabled = true
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
                        item.attributedTitle = styledMenuItemText(label: "Memory Free: ", value: memoryFreePercentage)
                    case 1:
                        item.attributedTitle = styledMenuItemText(label: "Memory Used: ", value: memoryUsedPercentage)
                    default:
                        item.attributedTitle = styledMenuItemText(label: "Memory Free: ", value: memoryFreePercentage)
                    }
                } else if item.title.starts(with: "Total Memory") {
                    item.attributedTitle = styledMenuItemText(label: "Total Memory: ", value: memoryTotal)
                } else if item.title.starts(with: "    Free:") {
                    item.attributedTitle = styledMenuItemText(label: "    Free: ", value: memoryPagesFree)
                } else if item.title.starts(with: "    Purgeable:") {
                    item.attributedTitle = styledMenuItemText(label: "    Purgeable: ", value: memoryPagesPurgeable)
                } else if item.title.starts(with: "    Active:") {
                    item.attributedTitle = styledMenuItemText(label: "    Active: ", value: memoryPagesActive)
                } else if item.title.starts(with: "    Inactive:") {
                    item.attributedTitle = styledMenuItemText(label: "    Inactive: ", value: memoryPagesInactive)
                } else if item.title.starts(with: "    Compressed:") {
                    item.attributedTitle = styledMenuItemText(label: "    Compressed: ", value: memoryPagesCompressed)
                } else if item.title.starts(with: "    Swap Ins:") {
                    item.attributedTitle = styledMenuItemText(label: "    Swap Ins: ", value: memorySwapIns)
                } else if item.title.starts(with: "    Swap Outs:") {
                    item.attributedTitle = styledMenuItemText(label: "    Swap Outs: ", value: memorySwapOuts)
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
        
        //        let titleItem = NSMenuItem(title: "Open Ports: \(openPorts.count)", action: #selector(doNothing), keyEquivalent: "")
        let titleItem = NSMenuItem()
        titleItem.attributedTitle = styledMenuItemText(label: "Open Ports: ", value: "\(openPorts.count)")
        titleItem.action = #selector(doNothing)
        titleItem.isEnabled = true
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        if openPorts.isEmpty {
            let noPortsItem = NSMenuItem(title: "No open ports detected", action: #selector(doNothing), keyEquivalent: "")
            noPortsItem.isEnabled = true
            menu.addItem(noPortsItem)
        } else {
            for portInfo in openPorts {
                let portData = extractPortData(from: portInfo)
                let portItem = NSMenuItem(title: portInfo, action: #selector(doNothing), keyEquivalent: "")
                
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
        
//        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
//        settingsItem.target = self
//        menu.addItem(settingsItem)
//        
//        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
//        quitItem.target = self
//        menu.addItem(quitItem)
        
        addCommonMenuItems(to: menu)
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
        let operation = BlockOperation {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe
            
            let outHandle = pipe.fileHandleForReading
            outHandle.waitForDataInBackgroundAndNotify()
            
            var output = ""
            var observer: NSObjectProtocol?
            
            func removeObserverIfNeeded() {
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                    observer = nil
                }
            }
            
            observer = NotificationCenter.default.addObserver(
                forName: .NSFileHandleDataAvailable,
                object: outHandle,
                queue: nil
            ) { _ in
                let data = outHandle.availableData
                if data.count > 0 {
                    if let str = String(data: data, encoding: .utf8) {
                        output += str
                    }
                    outHandle.waitForDataInBackgroundAndNotify()
                } else {
                    removeObserverIfNeeded()
                    completion(output)
                }
            }
            
            process.terminationHandler = { _ in
                removeObserverIfNeeded()
                if output.isEmpty {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    output = String(data: data, encoding: .utf8) ?? "No output"
                }
                completion(output)
            }
            
            do {
                try process.run()
            } catch {
                completion("Command failed: \(error.localizedDescription)")
            }
        }
        operationQueue.addOperation(operation)
    }

    @objc private func showCPUHistoryGraph() {
        guard let button = cpuStatusItem?.button else { return }
            
        if cpuGraphPopover == nil {
            let popover = NSPopover()
            let history = CPUHistory.shared.getLast6Hours(is800PercentMode: CPUPctMode == 0)
            let graphView = CPUHistoryGraph(history: history, maxValue: 100) // always use 100 as max
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
    
    private func createProgressContainerView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return container
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

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSImage(named: "AppIcon")!)
            
            Text("\(Bundle.main.appName)")
                .font(.system(size: 20, weight: .bold))
                .textSelection(.enabled)
            
            Text("\(Bundle.main.appVersionLong) (\(Bundle.main.appBuild)) ")
                .textSelection(.enabled)
            
            Text(Bundle.main.copyright)
                .font(.system(size: 10, weight: .thin))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(minWidth: 350, minHeight: 300)
        .background(.regularMaterial)
    }
}
