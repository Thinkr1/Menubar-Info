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
