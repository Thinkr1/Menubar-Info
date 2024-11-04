//
//  CPU_MenubarApp.swift
//  CPU-Menubar
//
//  Created by [REDACTED] on 01/11/2024.
//

import SwiftUI
import Combine

@main
struct CPU_MenubarApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var cpuUsage: String = "0%" // default cpu usage value
    @State private var refreshRate: TimeInterval = 5 // default
    @State private var iconName: String = "cpu" // default icon system name
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> { // using Combine to deliver elements to subscribers (get refresh rate)
        Timer.publish(every: refreshRate, on:.main, in: .common).autoconnect() // refresh rate
    }
    var body: some Scene {
        MenuBarExtra() {
            VStack {
                Text("CPU Usage: \(cpuUsage)")
                    .padding()
                    .onReceive(timer) { _ in
                        updateCPUUsage()
                    }
                Button("Refresh") {
                    updateCPUUsage()
                }.keyboardShortcut("r")
                Divider()
                Button("Settings") {
                    openWindow(id:"settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q")
            }
        } label: {
            Text(cpuUsage)
            Image(systemName: iconName)
            .labelStyle(.titleAndIcon)
        }

        WindowGroup("Settings", id: "settings") { // settings window
            SettingsView(refreshRate: $refreshRate, iconName: $iconName)
        }
        .defaultSize(width: 500, height: 300)
    }
    
    private func updateCPUUsage() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {print s \"%\"}'"] // using ps command to get cpu % -- alternative: `sudo powermetrics -s tasks -n 1 | grep ALL_TASKS | awk '{print $4"%"}'` (takes longer) -- alternative: `top -l 1 | awk '/CPU usage/ {print $3}'
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
                cpuUsage = output.trimmingCharacters(in: .whitespacesAndNewlines) // render output correctly
            }
        }
    }
}

struct SettingsView: View {
    // bind vars to app struct vars
    @Binding var refreshRate: TimeInterval
    @Binding var iconName: String
    var iconChoices = [("cpu", "CPU"), ("gauge.with.dots.needle.bottom.50percent", "Gauge"), ("chart.xyaxis.line", "Line Chart"), ("chart.bar.xaxis", "Bar Chart"), ("thermometer.medium", "Thermometer")]

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
            
            Picker("Select Icon", selection: $iconName) {
                ForEach(iconChoices, id: \.1) { choice in
                    HStack {
                        Image(systemName: choice.0)
                        Text(choice.1)
                    }.tag(choice.0)
                }
            }.padding()
            
        }
    }
}
