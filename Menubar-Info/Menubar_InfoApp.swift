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
import Charts

@available(macOS 14.0, *)
@main
struct Menubar_InfoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
//
//struct CustomMenuItem: Identifiable, Codable {
//    let id: UUID
//    var title: String
//    var command: String
//    var refreshInterval: TimeInterval?
//    var outputFormat: String?
//    var showInMenuBar: Bool
//    
//    init(id: UUID = UUID(),
//         title: String,
//         command: String,
//         refreshInterval: TimeInterval? = nil,
//         outputFormat: String? = nil,
//         showInMenuBar: Bool = false) {
//        self.id = id
//        self.title = title
//        self.command = command
//        self.refreshInterval = refreshInterval
//        self.outputFormat = outputFormat
//        self.showInMenuBar = showInMenuBar
//    }
//}
//
//struct CustomMenuButton: Identifiable, Codable {
//    let id: UUID
//    var title: String
//    var items: [CustomMenuItem]
//    var isVisible: Bool
//    
//    init(id: UUID = UUID(),
//         title: String,
//         items: [CustomMenuItem] = [],
//         isVisible: Bool = true) {
//        self.id = id
//        self.title = title
//        self.items = items
//        self.isVisible = isVisible
//    }
//}

extension NSColor {
    static var memoryUsageColor: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.controlAccentColor
        } else {
            return NSColor.systemBlue
        }
    }
    
    static var cpuUserColor: NSColor {
        return NSColor(red: 0.20, green: 0.60, blue: 0.86, alpha: 1.00) // light blue
    }
    
    static var cpuSystemColor: NSColor {
        return NSColor(red: 0.99, green: 0.40, blue: 0.40, alpha: 1.00) // light red
    }
    
    static var cpuIdleColor: NSColor {
        return NSColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1.00) // light grey
    }
    
    static var batteryColor: NSColor {
        return NSColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 1.00) // light green
    }
}
