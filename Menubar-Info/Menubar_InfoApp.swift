//
//  Menubar_InfoApp.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 01/11/2024.
//

import SwiftUI
import AppKit
import Combine
import Network

@main
struct Menubar_InfoApp: App {
    @Environment(\.openWindow) private var openWindow
    
    //@State var CPUUsagePerCore: [Double] = [] // per core
    @State var CPUUsage: String = "0"
    @State var ip: String = ""
    @State var ipLoc: String = ""
    @State var isConnected: Bool? = nil
    @State var batteryPct: String = "0%"
    @State var batteryPctBar: Double = 0
    @State var batteryTime: String = ""
    @State var isSettingsVisible: Bool = false
    @State private var settingsPanel: NSPanel? = nil
    
    @AppStorage("refreshRate") var refreshRate: TimeInterval = 5 // default 5s
    @AppStorage("iconName") var iconName: String = "cpu" // default icon system name
    @AppStorage("CPUPctMode") var CPUPctMode: Int = 0 // 0 for 800% (normal Unix), 1 for 100% (%/8)
    @AppStorage("CPUMBESelect") var CPUMBESelect: Bool = true // shown by default
    @AppStorage("IPMBESelect") var IPMBESelect: Bool = true // shown by default
    @AppStorage("batteryMBESelect") var batteryMBESelect: Bool = true // shown by default
    
    var CPUTimer: Publishers.Autoconnect<Timer.TimerPublisher> { // using Combine to deliver elements to subscribers (get refresh rate)
        Timer.publish(every: refreshRate, on:.main, in: .common).autoconnect()
    }
    
    var BatteryTimer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 180, on:.main, in: .common).autoconnect()
    }
    
    var IPTimer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 300, on:.main, in: .common).autoconnect()
    }
    
    var body: some Scene {
        CPUMenuBarExtra()
        IPMenuBarExtra()
        BatteryMenuBarExtra()
    }
    
    @SceneBuilder
    func CPUMenuBarExtra() -> some Scene {
        MenuBarExtra(isInserted: $CPUMBESelect) {
            VStack {
                //Text("CPU Usage: \(CPUUsage.map {String(format: "%.2f%%", $0)}.joined(separator: ", "))")
                Text("CPU Usage: \(CPUUsage)%")
                    .padding()
                    .onReceive(CPUTimer) { _ in
                        DispatchQueue.global(qos: .background).async {
                            updateCPUUsage()
                        }
                    }.accessibilityIdentifier("CPUUsageText")
                Button("Refresh") {
                    updateCPUUsage()
                }.accessibilityIdentifier("RefreshCPUButton").keyboardShortcut("r")
                Divider()
                Button("Settings") {
                    let settingsPanel = createSettingsPanel(refreshRate: $refreshRate, iconName: $iconName, CPUPctMode: $CPUPctMode, CPUMBESelect: $CPUMBESelect, IPMBESelect: $IPMBESelect, batteryMBESelect: $batteryMBESelect)
                    settingsPanel.makeKeyAndOrderFront(nil)
                }.accessibilityIdentifier("SettingsButton").keyboardShortcut(",")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.accessibilityIdentifier("QuitButton").keyboardShortcut("q")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    updateCPUUsage()
                    updateIPAndLoc()
                    updateBatteryStatus()
                    checkInternet { isConnected in
                        if isConnected {
                            self.isConnected = true
                        } else {
                            self.isConnected = false
                        }
                    }
                }
            }
        } label: {
            HStack { // IN PROGRESS
//                Canvas { context, size in
//                    let barWidth: CGFloat = size.width/CGFloat(CPUUsage.count)
//                    let maxHeight: CGFloat = size.height
//
//                    for (i, pct) in CPUUsagePerCore.enumerated() {
//                        let height = maxHeight * CGFloat(pct/100)
//                        let rect = CGRect(x: CGFloat(i)*barWidth, y: maxHeight - height, width: barWidth*0.8, height: height)
//                        context.fill(Path(rect), with: .color(.white))
//                    }
//                }
//                .frame(width: 40, height: 20)
//                .accessibilityIdentifier("CPUUsageGraph")
                Text("\(CPUUsage)%")
                Image(systemName: iconName)
                //Text(CPUUsage.map {String(format: "%.2f%%", $0)}.joined(separator: ", "))
            }.accessibilityIdentifier("CPUUsage")
        }
    }
    
    @SceneBuilder
    func IPMenuBarExtra() -> some Scene {
        MenuBarExtra(isInserted: $IPMBESelect) {
            VStack {
                Text("IP: \(ip) (\(ipLoc))")
                    .padding()
                    .accessibilityIdentifier("IPText")
                Text("Connected? \(isConnected==true ? "Yes" : isConnected==nil ? "..." : "No")")
                    .padding()
                    .accessibilityIdentifier("ConnectionStatusText")
                Button("Refresh") {
                    updateIPAndLoc()
                    checkInternet { isConnected in
                        if isConnected {
                            self.isConnected = true
                        } else {
                            self.isConnected = false
                        }
                    }
                }.accessibilityIdentifier("IPRefreshButton").keyboardShortcut("r")
                Divider()
                Button("Settings") {
                    let settingsPanel = createSettingsPanel(refreshRate: $refreshRate, iconName: $iconName, CPUPctMode: $CPUPctMode, CPUMBESelect: $CPUMBESelect, IPMBESelect: $IPMBESelect, batteryMBESelect: $batteryMBESelect)
                    settingsPanel.makeKeyAndOrderFront(nil)
                }.accessibilityIdentifier("SettingsButton").keyboardShortcut(",")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.accessibilityIdentifier("QuitButton").keyboardShortcut("q")
            }
            .onReceive(IPTimer) { _ in
                DispatchQueue.global(qos: .background).async {
                    updateIPAndLoc()
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    updateCPUUsage()
                    updateIPAndLoc()
                    updateBatteryStatus()
                }
            }
        } label: {
            if isConnected==true {
                AsyncImage(url: URL(string: "https://flagcdn.com/w20/\(ipLoc.lowercased()).png")) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Text("...")
                }
                .accessibilityIdentifier("IPInfo")
            } else {
                Image(systemName: "camera.metering.none")
                    .accessibilityIdentifier("IPInfo")
            }
        }
    }
    
    @SceneBuilder
    func BatteryMenuBarExtra() -> some Scene {
        MenuBarExtra(isInserted: $batteryMBESelect) {
            VStack {
                HStack {
                    Text("Battery: \(batteryPct)")
                        .padding()
                        .accessibilityIdentifier("batteryPctText")
                    
//                    ProgressView(value: Double(batteryPct.dropLast(1)) ?? 0, total: 100)
//                        .progressViewStyle(LinearProgressViewStyle())
//                        .padding([.leading, .trailing])
//                        .frame(width: 100)
                    
                
                    Text("Time remaining: \(batteryTime)")
                        .padding()
                        .accessibilityIdentifier("batteryTimeText")
                }
                .onReceive(BatteryTimer) { _ in
                    DispatchQueue.global(qos: .background).async {
                        updateBatteryStatus()
                    }
                }
                Button("Refresh") {
                    updateBatteryStatus()
                }.accessibilityIdentifier("BatteryRefreshButton").keyboardShortcut("r")
                Divider()
                Button("Settings") {
                    let settingsPanel = createSettingsPanel(refreshRate: $refreshRate, iconName: $iconName, CPUPctMode: $CPUPctMode, CPUMBESelect: $CPUMBESelect, IPMBESelect: $IPMBESelect, batteryMBESelect: $batteryMBESelect)
                    settingsPanel.makeKeyAndOrderFront(nil)
                }.accessibilityIdentifier("SettingsButton").keyboardShortcut(",")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.accessibilityIdentifier("QuitButton").keyboardShortcut("q")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    updateCPUUsage()
                    updateIPAndLoc()
                    updateBatteryStatus()
                }
            }
            .frame(width: 200)
        } label: {
            Text("\(batteryTime)")
        }
    }
    
    private func updateIPAndLoc() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + \" \" + .countryCode'"] //curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + " " + .countryCode'
        
        process.standardOutput = pipe
        
        do {
            try process.run()
        } catch {
            print("Failed to run command: \(error)")
            return
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let output = String(data: data, encoding: .utf8){
            let res = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
            if res.count == 2 {
                DispatchQueue.main.async {
                    ip = String(res[0]) // Extract IP
                    ipLoc = String(res[1]) // Extract country code
                }
            }
        }
    }
    
    func updateCPUUsage() {
        //let commandPerCore = "ps -A -o %cpu | awk 'NR>1 {core[NR % 8] += $1} END {for (i = 1; i <= 8; i++) print core[i]}'" // To complete
        let command = CPUPctMode==0 ? "ps -A -o %cpu | awk '{s+=$1} END {print s}'" : "ps -A -o %cpu | awk '{s+=$1} END {printf \"%.1f\", s/8}'"
        runCommand(command) { res in
            DispatchQueue.main.async {
                self.CPUUsage = res.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    func checkInternet(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue.global(qos: .background) // quality of service: background, to run when system is idle (avoid using too much resources)
        
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                completion(true) // return true if connection can be established
            } else {
                completion(false) // return false otherwide
            }
            monitor.cancel()
        }
        monitor.start(queue: queue)
    }
    
    func updateBatteryStatus() {
        let batteryPctCommand = "pmset -g batt | awk '/[0-9]+%/ {gsub(/;/, \"\", $3); print $3}'"
        let batteryTimeCommand = "pmset -g batt | awk '/[0-9]+:[0-9]+/ {print $5}'"
        runCommand(batteryPctCommand) { res in
            DispatchQueue.main.async {
                self.batteryPct = res.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        runCommand(batteryTimeCommand) { res in
            DispatchQueue.main.async {
                self.batteryTime = res.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
    
    func createSettingsPanel(refreshRate: Binding<TimeInterval>, iconName: Binding<String>, CPUPctMode: Binding<Int>, CPUMBESelect: Binding<Bool>, IPMBESelect: Binding<Bool>, batteryMBESelect: Binding<Bool>) -> NSPanel {
        if settingsPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = true //make sure it can be reopened when closed
            panel.title = "Settings"
            panel.contentView = NSHostingView(rootView: SettingsView(refreshRate: refreshRate, iconName: iconName, CPUPctMode: CPUPctMode, CPUMBESelect: CPUMBESelect, IPMBESelect: IPMBESelect, batteryMBESelect: batteryMBESelect))
            panel.makeKeyAndOrderFront(nil)
            panel.center()
            
            settingsPanel=panel
            return panel
        } else {
            settingsPanel?.makeKeyAndOrderFront(nil)
            return settingsPanel!
        }
    }
    
    
    
    func runCommand(_ command: String, completion: @escaping (String) -> Void) {
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
}

struct SettingsView: View {
    // bind vars to app struct vars
    @Binding var refreshRate: TimeInterval
    @Binding var iconName: String
    @Binding var CPUPctMode: Int
    @Binding var CPUMBESelect: Bool
    @Binding var IPMBESelect: Bool
    @Binding var batteryMBESelect: Bool
    var iconChoices = [("cpu", "CPU"), ("gauge.with.dots.needle.bottom.50percent", "Gauge"), ("chart.xyaxis.line", "Line Chart"), ("chart.bar.xaxis", "Bar Chart"), ("thermometer.medium", "Thermometer")]
    
    private var CPUPctModeBinding: Binding<Bool> {
        Binding(get: {self.CPUPctMode == 1}, set: {newVal in self.CPUPctMode = newVal ? 1 : 0})
    }

    var body: some View {
        VStack {
            HStack {
                Text("Show in Menu Bar: ")
                    .padding()
                if #available(macOS 14.0, *) {
                    Toggle("CPU", isOn: $CPUMBESelect)
                        .toggleStyle(.checkbox)
                        .onChange(of: CPUMBESelect, initial: false) {
                            if !IPMBESelect && !CPUMBESelect && !batteryMBESelect {
                                CPUMBESelect=true
                            }
                        }
                    Toggle("IP", isOn: $IPMBESelect)
                        .toggleStyle(.checkbox)
                        .onChange(of: IPMBESelect, initial: false) {
                            if !CPUMBESelect && !IPMBESelect && !batteryMBESelect {
                                IPMBESelect=true
                            }
                        }
                    Toggle("Battery", isOn: $batteryMBESelect)
                        .toggleStyle(.checkbox)
                        .onChange(of: batteryMBESelect, initial: false) {
                            if !CPUMBESelect && !IPMBESelect && !batteryMBESelect {
                                batteryMBESelect=true
                            }
                        }
                } else {
                    Toggle("CPU", isOn: $CPUMBESelect)
                        .toggleStyle(.checkbox)
                        .onChange(of: CPUMBESelect) { _ in
                            if !IPMBESelect && !CPUMBESelect && !batteryMBESelect {
                                CPUMBESelect=true
                            }
                        }
                    Toggle("IP", isOn: $IPMBESelect)
                        .toggleStyle(.checkbox)
                        .onChange(of: IPMBESelect) { _ in
                            if !CPUMBESelect && !IPMBESelect && !batteryMBESelect {
                                IPMBESelect=true
                            }
                        }
                    Toggle("Battery", isOn: $batteryMBESelect)
                        .toggleStyle(.checkbox)
                        .onChange(of: batteryMBESelect) { _ in
                            if !CPUMBESelect && !IPMBESelect && !batteryMBESelect {
                                batteryMBESelect=true
                            }
                        }
                }
            }.accessibilityIdentifier("ShowInMenuBarToggle").padding()
            Slider(value: $refreshRate, in: 1...60, step: 1) {
                Text("CPU Refresh Rate: \(refreshRate, specifier: "%.2f") seconds")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("60")
            }.accessibilityIdentifier("RefreshRateSlider").padding()
            
            HStack {
                Text("CPU Percentage Mode: 800%")
                Toggle("", isOn: CPUPctModeBinding)
                    .toggleStyle(.switch)
                Text("100%")
            }.accessibilityIdentifier("CPUPctModeToggle").padding()
            
            Picker("Select Icon", selection: $iconName) {
                ForEach(iconChoices, id: \.0) { choice in
                    HStack {
                        Image(systemName: choice.0)
                        Text(choice.1)
                    }.tag(choice.0)
                }
            }.accessibilityIdentifier("IconPicker").padding()
            
            Button("Close") {
                NSApplication.shared.keyWindow?.orderOut(nil)
            }.accessibilityIdentifier("CloseSettingsButton").padding()
        }
    }
}
