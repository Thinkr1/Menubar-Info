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

extension Binding where Value == String {
    init<T: LosslessStringConvertible>(_ source: Binding<T>) {
        self.init(
            get: { source.wrappedValue.description },
            set: { if let value = T($0) { source.wrappedValue = value } }
        )
    }
}

struct CustomMenuItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var command: String
    var refreshInterval: TimeInterval?
    var outputFormat: String?
    var showInMenuBar: Bool
}

struct CustomMenuButton: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [CustomMenuItem]
    var isVisible: Bool
}

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
    @State private var decodedCustomMenuButtons: [CustomMenuButton] = []
    @State private var showingAddButtonSheet = false
    @State private var newButtonTitle = ""
    @State private var selectedButtonId: UUID?
    @State private var showingAddItemSheet = false
    @State private var newItemTitle = ""
    @State private var newItemCommand = ""
    @State private var newItemRefreshInterval: TimeInterval = 5
    @State private var newItemOutputFormat = ""
    @State private var newItemShowInMenuBar = false
    
    private var customMenuButtonsBinding: Binding<[CustomMenuButton]> {
        Binding(
            get: { decodedCustomMenuButtons },
            set: {
                decodedCustomMenuButtons = $0
                if let encoded = try? JSONEncoder().encode($0) {
                    customMenuButtons.wrappedValue = encoded
                }
            }
        )
    }

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
    private let customMenuButtons: Binding<Data>
    
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
         batteryMenuTitleOption: Binding<String>,
         customMenuButtons: Binding<Data>) {
        
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
        self.customMenuButtons = customMenuButtons
        
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
        
        let data = customMenuButtons.wrappedValue
        if let decoded = try? JSONDecoder().decode([CustomMenuButton].self, from: data) {
            _decodedCustomMenuButtons = State(initialValue: decoded)
        } else {
            _decodedCustomMenuButtons = State(initialValue: [])
        }
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
            
            customButtonSettings()
            
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
    
    @ViewBuilder
    private func customButtonSettings() -> some View {
        Section(header: Text("Custom Menu Bar Buttons").font(.headline)) {
            List {
                ForEach(customMenuButtonsBinding) { $button in
                    DisclosureGroup(isExpanded: Binding(
                        get: { selectedButtonId == button.id },
                        set: { if $0 { selectedButtonId = button.id } else { selectedButtonId = nil } }
                    )) {
                        ForEach($button.items) { $item in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Text(item.command)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    if item.showInMenuBar {
                                        Image(systemName: "menubar.arrow.up.rectangle")
                                    }
                                }
                            }
                            .contextMenu {
                                Button("Edit") { editItem(item) }
                                Button("Delete") { deleteItem(item, from: button) }
                            }
                        }
                        
                        Button("Add Item") {
                            newItemTitle = ""
                            newItemCommand = ""
                            newItemRefreshInterval = 5
                            newItemOutputFormat = ""
                            newItemShowInMenuBar = false
                            selectedButtonId = button.id
                            showingAddItemSheet = true
                        }
                    } label: {
                        HStack {
                            Toggle("", isOn: $button.isVisible)
                            TextField("Button Title", text: $button.title)
                        }
                    }
                    .contextMenu {
                        Button("Delete") { deleteButton(button) }
                    }
                }
            }
            .frame(height: 200)
            
            Button("Add New Button") {
                newButtonTitle = ""
                showingAddButtonSheet = true
            }
        }
        .sheet(isPresented: $showingAddButtonSheet) {
            VStack {
                Text("Add New Menu Bar Button").font(.headline)
                TextField("Button Title", text: $newButtonTitle)
                HStack {
                    Button("Cancel") { showingAddButtonSheet = false }
                    Button("Add") {
                        let newButton = CustomMenuButton(
                            title: newButtonTitle,
                            items: [],
                            isVisible: true
                        )
                        decodedCustomMenuButtons.append(newButton)
                        saveCustomButtons()
                        showingAddButtonSheet = false
                    }
                }
            }
            .padding()
            .frame(width: 300)
        }
        .sheet(isPresented: $showingAddItemSheet) {
            VStack {
                Text("Add New Menu Item").font(.headline)
                TextField("Item Title", text: $newItemTitle)
                TextField("Command", text: $newItemCommand)
                HStack {
                    Text("Refresh Interval (seconds):")
                    TextField("", value: $newItemRefreshInterval, formatter: NumberFormatter())
                        .frame(width: 50)
                }
                TextField("Output Format (use {output})", text: $newItemOutputFormat)
                Toggle("Show in Menu Bar", isOn: $newItemShowInMenuBar)
                HStack {
                    Button("Cancel") { showingAddItemSheet = false }
                    Button("Add") {
                        guard let selectedId = selectedButtonId else { return }
                        
                        if let buttonIndex = decodedCustomMenuButtons.firstIndex(where: { $0.id == selectedId }) {
                            let newItem = CustomMenuItem(
                                title: newItemTitle,
                                command: newItemCommand,
                                refreshInterval: newItemRefreshInterval > 0 ? newItemRefreshInterval : nil,
                                outputFormat: newItemOutputFormat.isEmpty ? nil : newItemOutputFormat,
                                showInMenuBar: newItemShowInMenuBar
                            )
                            decodedCustomMenuButtons[buttonIndex].items.append(newItem)
                            saveCustomButtons()
                        }
                        showingAddItemSheet = false
                    }
                }
            }
            .padding()
            .frame(width: 400)
        }
    }
    
    private func editItem(_ item: CustomMenuItem) {
        for (_, button) in decodedCustomMenuButtons.enumerated() {
            if let itemIndex = button.items.firstIndex(where: { $0.id == item.id }) {
                let currentItem = button.items[itemIndex]
                newItemTitle = currentItem.title
                newItemCommand = currentItem.command
                newItemRefreshInterval = currentItem.refreshInterval ?? 0
                newItemOutputFormat = currentItem.outputFormat ?? ""
                newItemShowInMenuBar = currentItem.showInMenuBar
                selectedButtonId = button.id
                showingAddItemSheet = true
                return
            }
        }
    }

    private func deleteItem(_ item: CustomMenuItem, from button: CustomMenuButton) {
        if let buttonIndex = decodedCustomMenuButtons.firstIndex(where: { $0.id == button.id }) {
            if let itemIndex = decodedCustomMenuButtons[buttonIndex].items.firstIndex(where: { $0.id == item.id }) {
                decodedCustomMenuButtons[buttonIndex].items.remove(at: itemIndex)
                saveCustomButtons()
            }
        }
    }

    private func deleteButton(_ button: CustomMenuButton) {
        if let index = decodedCustomMenuButtons.firstIndex(where: { $0.id == button.id }) {
            decodedCustomMenuButtons.remove(at: index)
            saveCustomButtons()
        }
    }

    private func saveCustomButtons() {
        if let encoded = try? JSONEncoder().encode(decodedCustomMenuButtons) {
            customMenuButtons.wrappedValue = encoded
            AppDelegate.shared?.setupCustomMenuButtons()
        }
    }
}
