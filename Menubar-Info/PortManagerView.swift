//
//  PortManagerView.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 06/05/2025.
//

import SwiftUI

struct PortData {
    var pid: Int?
    var port: Int?
}

struct PortManagerView: View {
    @State private var portNumber: String = ""
    @State private var selectedMethod: PortOpeningMethod = .netcat
    @ObservedObject var portData: PortManagerData
    var refreshAction: () -> Void
    var openPortAction: (Int, PortOpeningMethod) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Active Ports")
                .font(.headline)
            
            if portData.openPorts.isEmpty {
                Text("No open ports detected")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(Array(portData.openPorts.enumerated()), id: \.offset) { index, portInfo in
                        let portData = extractPortData(from: portInfo)
                        
                        Text(portInfo)
                            .contextMenu {
                                if let pid = portData.pid {
                                    Button(action: {
                                        showKillConfirmation(for: pid)
                                    }) {
                                        Text("Kill Process")
                                        Image(systemName: "xmark.circle")
                                    }
                                }
                                
                                if let port = portData.port {
                                    Button(action: {
                                        let url = "http://localhost:\(port)"
                                        copyToClipboard(url)
                                    }) {
                                        Text("Copy URL")
                                        Image(systemName: "doc.on.doc")
                                    }
                                    
                                    if isLocalhostPort(portInfo) {
                                        Button(action: {
                                            let url = "http://localhost:\(port)"
                                            NSWorkspace.shared.open(URL(string: url)!)
                                        }) {
                                            Text("Open in Browser")
                                            Image(systemName: "safari")
                                        }
                                    }
                                }
                            }
                    }
                }
                .frame(height: 200)
            }
            
            Divider()
            
            HStack {
                TextField("Port Number", text: $portNumber)
                    .frame(width: 100)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Method", selection: $selectedMethod) {
                    ForEach(PortOpeningMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 180)
                
                Button("Open Port") {
                    guard let port = Int(portNumber), port > 0 && port < 65536 else {
                        let alert = NSAlert()
                        alert.messageText = "Invalid Port"
                        alert.informativeText = "Please enter a valid port number (1-65535)."
                        alert.runModal()
                        return
                    }
                    
                    openPortAction(port, selectedMethod)
                }
                .disabled(portNumber.isEmpty || Int(portNumber) == nil)
            }
            .padding(.vertical)
            
            HStack {
                Button("Refresh") {
                    refreshAction()
                }
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 350)
    }
    
    private func extractPortData(from portInfo: String) -> PortData {
        var result = PortData()
        
        if let pidRange = portInfo.range(of: "\\(PID \\d+\\)", options: .regularExpression) {
            let pidString = portInfo[pidRange]
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "PID", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            result.pid = Int(pidString)
        }
        
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
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        let alert = NSAlert()
        alert.messageText = "Copied to Clipboard"
        alert.informativeText = "URL copied: \(text)"
        alert.runModal()
    }
    
    private func showKillConfirmation(for pid: Int) {
        let alert = NSAlert()
        alert.messageText = "Kill Process?"
        alert.informativeText = "Are you sure you want to kill process with PID \(pid)?"
        alert.addButton(withTitle: "Kill")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            ProcessManager.shared.killProcessByPID(pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshAction()
            }
        }
    }
}
