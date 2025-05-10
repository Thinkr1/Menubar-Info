//
//  SettingsView.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 04/05/2025.
//

import SwiftUI
import AppKit
import Combine
import Network
import Charts

struct SettingsView: View {
    enum BatteryMenuTitleOption: String, CaseIterable, Identifiable {
        case batteryPercentage = "Battery Percentage"
        case timeRemaining = "Time Remaining"
        case temperature = "Temperature"
        case cycleCount = "Cycle Count"
        case currentCapacity = "Current Capacity"
        
        var id: String { self.rawValue }
    }
    
    @State private var localCPURefreshRate: TimeInterval
    @State private var localMemoryRefreshRate: TimeInterval
    @State private var localCPUPctMode: Int
    @State private var localCPUMBESelect: Bool
    @State private var localIPMBESelect: Bool
    @State private var localBatteryMBESelect: Bool
    @State private var localMemoryMBESelect: Bool
    @State private var localPortsMBESelect: Bool
    @State private var localCPUDisplayStyle: Int
    @State private var localMemoryDisplayMode: Int
    @State private var localBatteryMenuTitleOption: BatteryMenuTitleOption

    private let CPURefreshRateBinding: Binding<TimeInterval>
    private let memoryRefreshRateBinding: Binding<TimeInterval>
    private let cpupctModeBinding: Binding<Int>
    private let cpuMBESelectBinding: Binding<Bool>
    private let ipMBESelectBinding: Binding<Bool>
    private let batteryMBESelectBinding: Binding<Bool>
    private let memoryMBESelectBinding: Binding<Bool>
    private let portsMBESelectBinding: Binding<Bool>
    private let cpuDisplayStyle: Binding<Int>
    private let memoryDisplayModeBinding: Binding<Int>
    private let batteryMenuTitleOptionBinding: Binding<String>
    
    init(CPURefreshRate: Binding<TimeInterval>,
         memoryRefreshRate: Binding<TimeInterval>,
         CPUPctMode: Binding<Int>,
         CPUMBESelect: Binding<Bool>,
         IPMBESelect: Binding<Bool>,
         batteryMBESelect: Binding<Bool>,
         memoryMBESelect: Binding<Bool>,
         portsMBESelect: Binding<Bool>,
         cpuDisplayStyle: Binding<Int>,
         memoryDisplayMode: Binding<Int>,
         batteryMenuTitleOption: Binding<String>) {
        
        self.CPURefreshRateBinding = CPURefreshRate
        self.memoryRefreshRateBinding = memoryRefreshRate
        self.cpupctModeBinding = CPUPctMode
        self.cpuMBESelectBinding = CPUMBESelect
        self.ipMBESelectBinding = IPMBESelect
        self.batteryMBESelectBinding = batteryMBESelect
        self.memoryMBESelectBinding = memoryMBESelect
        self.portsMBESelectBinding = portsMBESelect
        self.cpuDisplayStyle = cpuDisplayStyle
        self.memoryDisplayModeBinding = memoryDisplayMode
        self.batteryMenuTitleOptionBinding = batteryMenuTitleOption
        
        _localCPURefreshRate = State(initialValue: CPURefreshRate.wrappedValue)
        _localMemoryRefreshRate = State(initialValue: memoryRefreshRate.wrappedValue)
        _localCPUPctMode = State(initialValue: CPUPctMode.wrappedValue)
        _localCPUMBESelect = State(initialValue: CPUMBESelect.wrappedValue)
        _localIPMBESelect = State(initialValue: IPMBESelect.wrappedValue)
        _localBatteryMBESelect = State(initialValue: batteryMBESelect.wrappedValue)
        _localMemoryMBESelect = State(initialValue: memoryMBESelect.wrappedValue)
        _localPortsMBESelect = State(initialValue: portsMBESelect.wrappedValue)
        _localCPUDisplayStyle = State(initialValue: cpuDisplayStyle.wrappedValue)
        _localMemoryDisplayMode = State(initialValue: memoryDisplayMode.wrappedValue)
        _localBatteryMenuTitleOption = State(initialValue: BatteryMenuTitleOption(rawValue: batteryMenuTitleOption.wrappedValue) ?? .batteryPercentage)
    }
    
    private var CPUPctModeBinding: Binding<Bool> {
        Binding(
            get: { self.localCPUPctMode == 1 },
            set: { newValue in
                self.localCPUPctMode = newValue ? 1 : 0
                self.cpupctModeBinding.wrappedValue = self.localCPUPctMode
                UserDefaults.standard.synchronize()
            }
        )
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Show in Menu Bar: ")
                    .padding()
                if #available(macOS 14.0, *) {
                    Toggle("CPU", isOn: Binding(
                        get: { self.localCPUMBESelect },
                        set: { newValue in
                            self.localCPUMBESelect = newValue
                            self.cpuMBESelectBinding.wrappedValue = newValue
                            UserDefaults.standard.synchronize()
                            if !self.localIPMBESelect && !newValue && !self.localBatteryMBESelect && !localMemoryMBESelect && !localPortsMBESelect {
                                self.localCPUMBESelect = true
                                self.cpuMBESelectBinding.wrappedValue = true
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    Toggle("IP", isOn: Binding(
                        get: { self.localIPMBESelect },
                        set: { newValue in
                            self.localIPMBESelect = newValue
                            self.ipMBESelectBinding.wrappedValue = newValue
                            UserDefaults.standard.synchronize()
                            if !self.localCPUMBESelect && !newValue && !self.localBatteryMBESelect && !localMemoryMBESelect && !localPortsMBESelect {
                                self.localIPMBESelect = true
                                self.ipMBESelectBinding.wrappedValue = true
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    Toggle("Battery", isOn: Binding(
                        get: { self.localBatteryMBESelect },
                        set: { newValue in
                            self.localBatteryMBESelect = newValue
                            self.batteryMBESelectBinding.wrappedValue = newValue
                            UserDefaults.standard.synchronize()
                            if !self.localIPMBESelect && !newValue && !self.localCPUMBESelect && !localMemoryMBESelect && !localPortsMBESelect {
                                self.localBatteryMBESelect = true
                                self.batteryMBESelectBinding.wrappedValue = true
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    Toggle("Memory", isOn: Binding(
                        get: { self.localMemoryMBESelect },
                        set: { newValue in
                            self.localMemoryMBESelect = newValue
                            self.memoryMBESelectBinding.wrappedValue = newValue
                            UserDefaults.standard.synchronize()
                            if !self.localIPMBESelect && !newValue && !self.localCPUMBESelect && !localBatteryMBESelect && !localPortsMBESelect {
                                self.localMemoryMBESelect = true
                                self.memoryMBESelectBinding.wrappedValue = true
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    Toggle("Ports", isOn: Binding(
                        get: { self.localPortsMBESelect },
                        set: { newValue in
                            self.localPortsMBESelect = newValue
                            self.portsMBESelectBinding.wrappedValue = newValue
                            UserDefaults.standard.synchronize()
                            if !self.localIPMBESelect && !newValue && !self.localCPUMBESelect && !localBatteryMBESelect && !localMemoryMBESelect {
                                self.localPortsMBESelect = true
                                self.portsMBESelectBinding.wrappedValue = true
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }.accessibilityIdentifier("ShowInMenuBarToggle").padding()
            
            Slider(value: Binding(
                get: { self.localCPURefreshRate },
                set: { newValue in
                    self.localCPURefreshRate = newValue
                    self.CPURefreshRateBinding.wrappedValue = newValue
                    UserDefaults.standard.synchronize()
                }
            ), in: 1...60, step: 1) {
                Text("CPU Refresh Rate: \(Int(localCPURefreshRate)) seconds")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("60")
            }
            .padding()
            
            Slider(value: Binding(
                get: { self.localMemoryRefreshRate },
                set: { newValue in
                    self.localMemoryRefreshRate = newValue
                    self.memoryRefreshRateBinding.wrappedValue = newValue
                    UserDefaults.standard.synchronize()
                }
            ), in: 1...60, step: 1) {
                Text("Memory Refresh Rate: \(Int(localMemoryRefreshRate)) seconds")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("60")
            }
            .padding()
            
            Picker(selection: Binding(
                get: { self.localCPUDisplayStyle },
                set: { newValue in
                    self.localCPUDisplayStyle = newValue
                    self.cpuDisplayStyle.wrappedValue = newValue
                    UserDefaults.standard.synchronize()
                }
            ), label: Text("CPU Menu Item Display Mode")) {
                Text("CPU Usage Only").tag(0)
                Text("CPU Usage Graph Only").tag(1)
                Text("Both").tag(2)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            
            Picker(selection: Binding(
                get: { self.localMemoryDisplayMode },
                set: { newValue in
                    self.localMemoryDisplayMode = newValue
                    self.memoryDisplayModeBinding.wrappedValue = newValue
                    UserDefaults.standard.synchronize()
                }
            ), label: Text("Memory Display Mode")) {
                Text("Memory Free").tag(0)
                Text("Memory Used").tag(1)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .padding()
            
            Picker(selection: Binding(
                get: { self.localBatteryMenuTitleOption },
                set: { newValue in
                    self.localBatteryMenuTitleOption = newValue
                    self.batteryMenuTitleOptionBinding.wrappedValue = newValue.rawValue
                    UserDefaults.standard.synchronize()
                }
            ), label: Text("Battery Menu Item Title")) {
                ForEach(BatteryMenuTitleOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding()
            
            HStack {
                Text("CPU Percentage Mode: 800%")
                Toggle("", isOn: CPUPctModeBinding)
                    .toggleStyle(.switch)
                Text("100%")
            }.accessibilityIdentifier("CPUPctModeToggle").padding()
            
            Button("Close") {
                NSApplication.shared.keyWindow?.orderOut(nil)
            }.accessibilityIdentifier("CloseSettingsButton").padding()
        }
        .onAppear {
            self.localCPURefreshRate = self.CPURefreshRateBinding.wrappedValue
            self.localCPUPctMode = self.cpupctModeBinding.wrappedValue
            self.localCPUMBESelect = self.cpuMBESelectBinding.wrappedValue
            self.localIPMBESelect = self.ipMBESelectBinding.wrappedValue
            self.localBatteryMBESelect = self.batteryMBESelectBinding.wrappedValue
            self.localMemoryMBESelect = self.memoryMBESelectBinding.wrappedValue
            self.localPortsMBESelect = self.portsMBESelectBinding.wrappedValue
            self.localCPUDisplayStyle = self.cpuDisplayStyle.wrappedValue
            self.localMemoryDisplayMode = self.memoryDisplayModeBinding.wrappedValue
            self.localBatteryMenuTitleOption = BatteryMenuTitleOption(rawValue: self.batteryMenuTitleOptionBinding.wrappedValue) ?? .batteryPercentage
        }
    }
}
