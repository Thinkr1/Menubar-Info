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
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q")
            }
        } label: {
            Text(cpuUsage)
            Image(systemName: "gauge")
            .labelStyle(.titleAndIcon)
        }

        WindowGroup("Settings", id: "settings") { // settings window
            SettingsView(refreshRate: $refreshRate, isEditingRefreshRate: $isEditingRefreshRate)
        }
    }
    private func updateCPUUsage() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {print s \"%\"}'"] // using ps command to get cpu %, rendering with awk
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

    var body: some View {
        VStack {
            Text("Settings")
                .font(.headline)
                .padding()
            
            Slider(value: $refreshRate, in: 1...60, step: 1) {
                Text("Refresh Rate: \(refreshRate, specifier: "%.2f") seconds")
            }.padding()
            
        }
    }
}
