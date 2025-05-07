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
