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
    @State private var selection: Pane = .general
    enum Pane: Hashable { case general, battery, custom }
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
        Group {
            if #available(macOS 14.0, *) {
                if #available(macOS 26.0, *) {
                    liquidGlassLayout
                } else {
                    legacyLayout
                }
            } else {
                legacyLayout
            }
        }
        .onAppear{syncFromBindings()}
    }

    @available(macOS 26.0, *)
    private var liquidGlassLayout: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selection {
                    case .general: generalPane
                    case .battery: batteryPane
                    case .custom: customPane
                    }
                }
                .padding(20)
            }
            .navigationTitle(titleFor(selection))
//            .toolbar {
//                ToolbarItem(placement: .automatic) {
//                    Button("Close") { NSApplication.shared.keyWindow?.orderOut(nil) }
//                        .keyboardShortcut(.cancelAction)
//                }
//            }
        }
        .frame(minWidth: 850, idealWidth: 880, minHeight: 520, idealHeight: 640)
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden)
    }

    @available(macOS 26.0, *)
    private var sidebar: some View {
        List(selection: $selection) {
            Section("Settings") {
                Label("General", systemImage: "slider.horizontal.3").tag(Pane.general)
                Label("Battery", systemImage: "battery.100").tag(Pane.battery)
                Label("Custom Buttons", systemImage: "rectangle.3.group").tag(Pane.custom)
            }
        }
        .listStyle(.sidebar)
    }

    @available(macOS 26.0, *)
    private func titleFor(_ pane: Pane) -> String {
        switch pane {
        case .general: return "General"
        case .battery: return "Battery"
        case .custom: return "Custom Buttons"
        }
    }

    @available(macOS 26.0, *)
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            glassSection(title: "Menu Bar Items") {
                HStack(spacing: 16) {
                    glassCheckbox(title: "CPU", isOn: Binding(get: { self.localCPUMBESelect }, set: { updateMenuToggle(&localCPUMBESelect, new: $0, binding: cpuMBESelectBinding) }))
                    glassCheckbox(title: "IP", isOn: Binding(get: { self.localIPMBESelect }, set: { updateMenuToggle(&localIPMBESelect, new: $0, binding: ipMBESelectBinding) }))
                    glassCheckbox(title: "Battery", isOn: Binding(get: { self.localBatteryMBESelect }, set: { updateMenuToggle(&localBatteryMBESelect, new: $0, binding: batteryMBESelectBinding) }))
                    glassCheckbox(title: "Memory", isOn: Binding(get: { self.localMemoryMBESelect }, set: { updateMenuToggle(&localMemoryMBESelect, new: $0, binding: memoryMBESelectBinding) }))
                    glassCheckbox(title: "Ports", isOn: Binding(get: { self.localPortsMBESelect }, set: { updateMenuToggle(&localPortsMBESelect, new: $0, binding: portsMBESelectBinding) }))
                }
            }

            glassSection(title: "Refresh Rates") {
                LabeledContent("CPU Refresh Rate") {
                    HStack(spacing: 10) {
                        Text("\(Int(localCPURefreshRate))s").monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: Binding(get: { self.localCPURefreshRate }, set: { self.localCPURefreshRate = $0; CPURefreshRateBinding.wrappedValue = $0; UserDefaults.standard.synchronize() }), in: 1...60, step: 1)
                    }
                }
                LabeledContent("Memory Refresh Rate") {
                    HStack(spacing: 10) {
                        Text("\(Int(localMemoryRefreshRate))s").monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: Binding(get: { self.localMemoryRefreshRate }, set: { self.localMemoryRefreshRate = $0; memoryRefreshRateBinding.wrappedValue = $0; UserDefaults.standard.synchronize() }), in: 1...60, step: 1)
                    }
                }
            }

            glassSection(title: "CPU Display") {
                Picker("Display Mode", selection: Binding(get: { self.localCPUDisplayStyle }, set: { self.localCPUDisplayStyle = $0; cpuDisplayStyle.wrappedValue = $0; UserDefaults.standard.synchronize() })) {
                    Text("CPU Usage Only").tag(0)
                    Text("CPU Usage Graph Only").tag(1)
                    Text("Both").tag(2)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("CPU Percentage Mode: 800%")
                    Toggle("", isOn: CPUPctModeBinding).toggleStyle(.switch)
                    Text("100%")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            glassSection(title: "Memory Display") {
                Picker("Mode", selection: Binding(get: { self.localMemoryDisplayMode }, set: { self.localMemoryDisplayMode = $0; memoryDisplayModeBinding.wrappedValue = $0; UserDefaults.standard.synchronize() })) {
                    Text("Memory Free").tag(0)
                    Text("Memory Used").tag(1)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @available(macOS 26.0, *)
    private var batteryPane: some View {
        glassSection(title: "Battery Menu Title") {
            Picker("Title", selection: Binding(get: { self.localBatteryMenuTitleOption }, set: { self.localBatteryMenuTitleOption = $0; batteryMenuTitleOptionBinding.wrappedValue = $0.rawValue; UserDefaults.standard.synchronize() })) {
                ForEach(BatteryMenuTitleOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @available(macOS 26.0, *)
    private var customPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            glassSection(title: "Custom Menu Bar Buttons") {
                List {
                    ForEach(customMenuButtonsBinding) { $button in
                        DisclosureGroup(isExpanded: Binding(get: { selectedButtonId == button.id }, set: { if $0 { selectedButtonId = button.id } else { selectedButtonId = nil } })) {
                            ForEach($button.items) { $item in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                        Text(item.command).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if item.showInMenuBar { Image(systemName: "menubar.arrow.up.rectangle") }
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
                            HStack(spacing: 10) {
                                Toggle("", isOn: $button.isVisible)
                                TextField("Button Title", text: $button.title)
                            }
                        }
                        .contextMenu { Button("Delete") { deleteButton(button) } }
                    }
                }
                .frame(minHeight: 220, idealHeight: 260)

                HStack {
                    Spacer()
                    Button {
                        newButtonTitle = ""
                        showingAddButtonSheet = true
                    } label: {
                        Label("Add New Button", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddButtonSheet) { addButtonSheet }
        .sheet(isPresented: $showingAddItemSheet) { addItemSheet }
    }

    @available(macOS 14.0, *)
    private func glassSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 12) { content() }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    @available(macOS 14.0, *)
    private func glassCheckbox(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    @available(macOS 14.0, *)
    private var addButtonSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add New Menu Bar Button").font(.headline)
            TextField("Button Title", text: $newButtonTitle)
            HStack {
                Spacer()
                Button("Cancel") { showingAddButtonSheet = false }
                Button("Add") {
                    let newButton = CustomMenuButton(title: newButtonTitle, items: [], isVisible: true)
                    decodedCustomMenuButtons.append(newButton)
                    saveCustomButtons()
                    showingAddButtonSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 340)
        .background(.thinMaterial)
    }

    @available(macOS 14.0, *)
    private var addItemSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add New Menu Item").font(.headline)
            TextField("Item Title", text: $newItemTitle)
            TextField("Command", text: $newItemCommand)
            HStack {
                Text("Refresh Interval (seconds):")
                TextField("", value: $newItemRefreshInterval, formatter: NumberFormatter())
                    .frame(width: 60)
            }
            TextField("Output Format (use {output})", text: $newItemOutputFormat)
            Toggle("Show in Menu Bar", isOn: $newItemShowInMenuBar)
            HStack {
                Spacer()
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
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
        .background(.thinMaterial)
    }

    private var legacyLayout: some View {
        VStack {
            HStack {
                Text("Show in Menu Bar: ")
                    .padding()
                if #available(macOS 14.0, *) {
                    Toggle("CPU", isOn: Binding(get: { self.localCPUMBESelect }, set: { updateMenuToggle(&localCPUMBESelect, new: $0, binding: cpuMBESelectBinding) }))
                        .toggleStyle(.checkbox)
                    Toggle("IP", isOn: Binding(get: { self.localIPMBESelect }, set: { updateMenuToggle(&localIPMBESelect, new: $0, binding: ipMBESelectBinding) }))
                        .toggleStyle(.checkbox)
                    Toggle("Battery", isOn: Binding(get: { self.localBatteryMBESelect }, set: { updateMenuToggle(&localBatteryMBESelect, new: $0, binding: batteryMBESelectBinding) }))
                        .toggleStyle(.checkbox)
                    Toggle("Memory", isOn: Binding(get: { self.localMemoryMBESelect }, set: { updateMenuToggle(&localMemoryMBESelect, new: $0, binding: memoryMBESelectBinding) }))
                        .toggleStyle(.checkbox)
                    Toggle("Ports", isOn: Binding(get: { self.localPortsMBESelect }, set: { updateMenuToggle(&localPortsMBESelect, new: $0, binding: portsMBESelectBinding) }))
                        .toggleStyle(.checkbox)
                }
            }.accessibilityIdentifier("ShowInMenuBarToggle").padding()

            Slider(value: Binding(get: { self.localCPURefreshRate }, set: { self.localCPURefreshRate = $0; CPURefreshRateBinding.wrappedValue = $0; UserDefaults.standard.synchronize() }), in: 1...60, step: 1) {
                Text("CPU Refresh Rate: \(Int(localCPURefreshRate)) seconds")
            } minimumValueLabel: { Text("1") } maximumValueLabel: { Text("60") }
            .padding()

            Slider(value: Binding(get: { self.localMemoryRefreshRate }, set: { self.localMemoryRefreshRate = $0; memoryRefreshRateBinding.wrappedValue = $0; UserDefaults.standard.synchronize() }), in: 1...60, step: 1) {
                Text("Memory Refresh Rate: \(Int(localMemoryRefreshRate)) seconds")
            } minimumValueLabel: { Text("1") } maximumValueLabel: { Text("60") }
            .padding()

            Picker(selection: Binding(get: { self.localCPUDisplayStyle }, set: { self.localCPUDisplayStyle = $0; cpuDisplayStyle.wrappedValue = $0; UserDefaults.standard.synchronize() }), label: Text("CPU Menu Item Display Mode")) {
                Text("CPU Usage Only").tag(0)
                Text("CPU Usage Graph Only").tag(1)
                Text("Both").tag(2)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()

            Picker(selection: Binding(get: { self.localMemoryDisplayMode }, set: { self.localMemoryDisplayMode = $0; memoryDisplayModeBinding.wrappedValue = $0; UserDefaults.standard.synchronize() }), label: Text("Memory Display Mode")) {
                Text("Memory Free").tag(0)
                Text("Memory Used").tag(1)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .padding()

            Picker(selection: Binding(get: { self.localBatteryMenuTitleOption }, set: { self.localBatteryMenuTitleOption = $0; batteryMenuTitleOptionBinding.wrappedValue = $0.rawValue; UserDefaults.standard.synchronize() }), label: Text("Battery Menu Item Title")) {
                ForEach(BatteryMenuTitleOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding()

            HStack {
                Text("CPU Percentage Mode: 800%")
                Toggle("", isOn: CPUPctModeBinding).toggleStyle(.switch)
                Text("100%")
            }.accessibilityIdentifier("CPUPctModeToggle").padding()

            legacyCustomButtonSettings()

//            Button("Close") { NSApplication.shared.keyWindow?.orderOut(nil) }
//                .accessibilityIdentifier("CloseSettingsButton").padding()
        }
    }

    @ViewBuilder
    private func legacyCustomButtonSettings() -> some View {
        Section(header: Text("Custom Menu Bar Buttons").font(.headline)) {
            List {
                ForEach(customMenuButtonsBinding) { $button in
                    DisclosureGroup(isExpanded: Binding(get: { selectedButtonId == button.id }, set: { if $0 { selectedButtonId = button.id } else { selectedButtonId = nil } })) {
                        ForEach($button.items) { $item in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Text(item.command).font(.caption).foregroundColor(.gray)
                                    if item.showInMenuBar { Image(systemName: "menubar.arrow.up.rectangle") }
                                }
                            }
                            .contextMenu {
                                Button("Edit") { editItem(item) }
                                Button("Delete") { deleteItem(item, from: button) }
                            }
                        }
                        Button("Add Item") {
                            newItemTitle = ""; newItemCommand = ""; newItemRefreshInterval = 5; newItemOutputFormat = ""; newItemShowInMenuBar = false
                            selectedButtonId = button.id
                            showingAddItemSheet = true
                        }
                    } label: {
                        HStack { Toggle("", isOn: $button.isVisible); TextField("Button Title", text: $button.title) }
                    }
                    .contextMenu { Button("Delete") { deleteButton(button) } }
                }
            }
            .frame(height: 200)
            Button("Add New Button") { newButtonTitle = ""; showingAddButtonSheet = true }
        }
        .sheet(isPresented: $showingAddButtonSheet) { addButtonSheet }
        .sheet(isPresented: $showingAddItemSheet) { addItemSheet }
    }

    private func syncFromBindings() {
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

    private func updateMenuToggle(_ local: inout Bool, new: Bool, binding: Binding<Bool>) {
        local = new
        binding.wrappedValue = new
        UserDefaults.standard.synchronize()
        if !localCPUMBESelect && !localIPMBESelect && !localBatteryMBESelect && !localMemoryMBESelect && !localPortsMBESelect {
            localCPUMBESelect = true
            cpuMBESelectBinding.wrappedValue = true
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

