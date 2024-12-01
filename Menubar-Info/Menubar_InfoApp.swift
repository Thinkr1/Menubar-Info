//
//  CPU_MenubarApp.swift
//  CPU-Menubar
//
//  Created by [REDACTED] on 01/11/2024.
//

import SwiftUI
import Combine
import Network

@main
struct CPU_MenubarApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var cpuUsage: String = "0%" // default cpu usage value
    @State private var cpuUsageFormatted: String = ""
    @State private var refreshRate: TimeInterval = 5 // default
    @State private var iconName: String = "cpu" // default icon system name
    @State private var cpuPctMode: Int = 0 // 0 for 800% (normal Unix), 1 for 100% (%/8)
    @State private var ip: String = ""
    @State private var ipLoc: String = ""
    @State private var isConnected: Bool? = nil
    private var cpuTimer: Publishers.Autoconnect<Timer.TimerPublisher> { // using Combine to deliver elements to subscribers (get refresh rate)
        Timer.publish(every: refreshRate, on:.main, in: .common).autoconnect() // refresh rate
    }
    
    var body: some Scene {
        MenuBarExtra {
            VStack {
                Text("CPU Usage: \(cpuUsage)")
                    .padding()
                    .onReceive(cpuTimer) { _ in
                        updateCPUUsage()
                    }
                Button("Refresh") {
                    updateCPUUsage()
                }.keyboardShortcut("r")
                Divider()
                Button("Settings") {
                    openWindow(id:"settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }.keyboardShortcut(",")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    updateCPUUsage()
                    updateIPAndLoc()
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
            HStack {
                Image(systemName: iconName)
                Text(cpuUsage)
            }
        }
        
        MenuBarExtra {
            VStack {
                Text("IP: \(ip) (\(ipLoc))")
                    .padding()
                Text("Connected? \(isConnected==true ? "Yes" : isConnected==nil ? "..." : "No")")
                    .padding()
                Button("Refresh") {
                    updateIPAndLoc()
                    checkInternet { isConnected in
                        if isConnected {
                            self.isConnected = true
                        } else {
                            self.isConnected = false
                        }
                    }
                }.keyboardShortcut("r", modifiers:[.command, .shift])
                Divider()
                Button("Settings") {
                    openWindow(id:"settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }.keyboardShortcut(",")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    updateCPUUsage()
                    updateIPAndLoc()
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
            } else {
                Image(systemName: "camera.metering.none")
            }
        }

        WindowGroup("Settings", id: "settings") { // settings window
            SettingsView(refreshRate: $refreshRate, iconName: $iconName, cpuPctMode: $cpuPctMode)
        }

        .defaultSize(width: 500, height: 300)
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
    
    private func updateCPUUsage() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        if cpuPctMode==0 {
            process.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {print s \"%\"}'"] // using ps command to get cpu % -- alternative: `sudo powermetrics -s tasks -n 1 | grep ALL_TASKS | awk '{print $4"%"}'` (takes longer) -- alternative: `top -l 1 | awk '/CPU usage/ {print $3}'
        } else {
            process.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {printf \"%.1f%%\\n\", s/8}'"] // same as before, just divide sum by 8
        }

        process.standardOutput = pipe
        
        do {
            try process.run()
            
        } catch {
            print("Failed to run command: \(error)")
            return
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let output = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                cpuUsage = output.trimmingCharacters(in: .whitespacesAndNewlines) // get output correctly
            }
        }
    }
    
    private func checkInternet(completion: @escaping (Bool) -> Void) {
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
}

struct SettingsView: View {
    // bind vars to app struct vars
    @Binding var refreshRate: TimeInterval
    @Binding var iconName: String
    @Binding var cpuPctMode: Int
    var iconChoices = [("cpu", "CPU"), ("gauge.with.dots.needle.bottom.50percent", "Gauge"), ("chart.xyaxis.line", "Line Chart"), ("chart.bar.xaxis", "Bar Chart"), ("thermometer.medium", "Thermometer")]
    
    private var cpuPctModeBinding: Binding<Bool> {
        Binding(get: {self.cpuPctMode == 1}, set: {newVal in self.cpuPctMode = newVal ? 1 : 0})
    }

    var body: some View {
        VStack {
            Text("Settings")
                .font(.headline)
                .padding()
            
            Slider(value: $refreshRate, in: 1...60, step: 1) {
                Text("Refresh Rate: \(refreshRate, specifier: "%.2f") seconds")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("60")
            }.padding()
            
            HStack {
                Text("CPU Percentage Mode: 800%")
                Toggle("", isOn: cpuPctModeBinding)
                    .toggleStyle(.switch)
                Text("100%")
            }.padding()
            
            Picker("Select Icon", selection: $iconName) {
                ForEach(iconChoices, id: \.0) { choice in
                    HStack {
                        Image(systemName: choice.0)
                        Text(choice.1)
                    }.tag(choice.0)
                }
            }.padding()
            
        }
    }
}
