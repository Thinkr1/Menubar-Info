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
    @State private var localCPURefreshRate: TimeInterval
    @State private var localMemoryRefreshRate: TimeInterval
    @State private var localIconName: String
    @State private var localCPUPctMode: Int
    @State private var localCPUMBESelect: Bool
    @State private var localIPMBESelect: Bool
    @State private var localBatteryMBESelect: Bool
    @State private var localMemoryMBESelect: Bool
    @State private var localPortsMBESelect: Bool
    private let CPURefreshRateBinding: Binding<TimeInterval>
    private let memoryRefreshRateBinding: Binding<TimeInterval>
    private let iconNameBinding: Binding<String>
    private let cpupctModeBinding: Binding<Int>
    private let cpuMBESelectBinding: Binding<Bool>
    private let ipMBESelectBinding: Binding<Bool>
    private let batteryMBESelectBinding: Binding<Bool>
    private let memoryMBESelectBinding: Binding<Bool>
    private let portsMBESelectBinding: Binding<Bool>
    
    init(CPURefreshRate: Binding<TimeInterval>,
         memoryRefreshRate: Binding<TimeInterval>,
         iconName: Binding<String>,
         CPUPctMode: Binding<Int>,
         CPUMBESelect: Binding<Bool>,
         IPMBESelect: Binding<Bool>,
         batteryMBESelect: Binding<Bool>,
         memoryMBESelect: Binding<Bool>,
         portsMBESelect: Binding<Bool>) {
        
        self.CPURefreshRateBinding = CPURefreshRate
        self.memoryRefreshRateBinding = memoryRefreshRate
        self.iconNameBinding = iconName
        self.cpupctModeBinding = CPUPctMode
        self.cpuMBESelectBinding = CPUMBESelect
        self.ipMBESelectBinding = IPMBESelect
        self.batteryMBESelectBinding = batteryMBESelect
        self.memoryMBESelectBinding = memoryMBESelect
        self.portsMBESelectBinding = portsMBESelect
        
        _localCPURefreshRate = State(initialValue: CPURefreshRate.wrappedValue)
        _localMemoryRefreshRate = State(initialValue: memoryRefreshRate.wrappedValue)
        _localIconName = State(initialValue: iconName.wrappedValue)
        _localCPUPctMode = State(initialValue: CPUPctMode.wrappedValue)
        _localCPUMBESelect = State(initialValue: CPUMBESelect.wrappedValue)
        _localIPMBESelect = State(initialValue: IPMBESelect.wrappedValue)
        _localBatteryMBESelect = State(initialValue: batteryMBESelect.wrappedValue)
        _localMemoryMBESelect = State(initialValue: memoryMBESelect.wrappedValue)
        _localPortsMBESelect = State(initialValue: portsMBESelect.wrappedValue)
    }
    
    var iconChoices = [("cpu", "CPU"), ("gauge.with.dots.needle.bottom.50percent", "Gauge"),
                      ("chart.xyaxis.line", "Line Chart"), ("chart.bar.xaxis", "Bar Chart"),
                      ("thermometer.medium", "Thermometer")]
    
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
                } /*else {*/
//                    Toggle("CPU", isOn: $CPUMBESelect)
//                        .toggleStyle(.checkbox)
//                        .onChange(of: CPUMBESelect) { _ in
//                            if !IPMBESelect && !CPUMBESelect && !batteryMBESelect {
//                                CPUMBESelect=true
//                            }
//                        }
//                    Toggle("IP", isOn: $IPMBESelect)
//                        .toggleStyle(.checkbox)
//                        .onChange(of: IPMBESelect) { _ in
//                            if !CPUMBESelect && !IPMBESelect && !batteryMBESelect {
//                                IPMBESelect=true
//                            }
//                        }
//                    Toggle("Battery", isOn: $batteryMBESelect)
//                        .toggleStyle(.checkbox)
//                        .onChange(of: batteryMBESelect) { _ in
//                            if !CPUMBESelect && !IPMBESelect && !batteryMBESelect {
//                                batteryMBESelect=true
//                            }
//                        }
//                }
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
            
            HStack {
                Text("CPU Percentage Mode: 800%")
                Toggle("", isOn: CPUPctModeBinding)
                    .toggleStyle(.switch)
                Text("100%")
            }.accessibilityIdentifier("CPUPctModeToggle").padding()
            
            Picker("Select Icon", selection: $localIconName) {
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
        .onAppear {
            self.localCPURefreshRate = self.CPURefreshRateBinding.wrappedValue
            self.localIconName = self.iconNameBinding.wrappedValue
            self.localCPUPctMode = self.cpupctModeBinding.wrappedValue
            self.localCPUMBESelect = self.cpuMBESelectBinding.wrappedValue
            self.localIPMBESelect = self.ipMBESelectBinding.wrappedValue
            self.localBatteryMBESelect = self.batteryMBESelectBinding.wrappedValue
        }
    }
}
