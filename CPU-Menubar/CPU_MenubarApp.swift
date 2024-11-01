//
//  CPU_MenubarApp.swift
//  CPU-Menubar
//
//  Created by [REDACTED] on 01/11/2024.
//

import SwiftUI

@main
struct CPU_MenubarApp: App {
    @State private var cpuUsage: String = "0%"
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
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
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q")
            }
        } label: {
            Text(cpuUsage)
            Image(systemName: "gauge")
            .labelStyle(.titleAndIcon)
        }
    }
    private func updateCPUUsage() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {print s \"%\"}'"]
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
                cpuUsage = output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
