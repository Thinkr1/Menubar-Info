//
//  SensorDataManager.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 01/06/2025.
//

//import Foundation
//import Combine
//
//class SensorDataManager: ObservableObject {
//    @Published var categories: [SensorCategory] = []
//    @Published var isLoading = false
//    @Published var lastUpdated = Date()
//    @Published var errorMessage: String?
//    
//    private let smcReader = SMCReader()
//    private var timer: Timer?
//    
//    private let knownKeys: [String: [(key: String, description: String, unit: String?)]] = [
//        "Battery": [
//            ("BNum", "Battery Count", nil),
//            ("BSIn", "Battery Info", nil),
//            ("BATP", "Battery Power", nil)
//        ],
//        "Current": [
//            ("IPBR", "Charger BMON", "A"),
//            ("ibuck5", "PMU2 ibuck5", "A"),
//            ("ibuck8", "PMU2 ibuck8", "A"),
//            ("ildo4", "PMU2 ildo4", "A"),
//            ("ibuck0", "PMU ibuck0", "A"),
//            ("ibuck1", "PMU ibuck1", "A"),
//            ("ibuck2", "PMU ibuck2", "A"),
//            ("ibuck4", "PMU ibuck4", "A"),
//            ("ibuck7", "PMU ibuck7", "A"),
//            ("ibuck9", "PMU ibuck9", "A"),
//            ("ibuck11", "PMU ibuck11", "A"),
//            ("ildo2", "PMU ildo2", "A"),
//            ("ildo7", "PMU ildo7", "A"),
//            ("ildo8", "PMU ildo8", "A"),
//            ("ildo9", "PMU ildo9", "A")
//        ],
//        "Fans": [
//            ("FNum", "Fan Count", nil)
//        ],
//        "Power": [
//            ("PPBR", "Battery", "W"),
//            ("PHPC", "Heatpipe", "W"),
//            ("PSTR", "System Total", "W")
//        ],
//        "Temperature": [
//            ("Ts1P", "Actuator", "°C"),
//            ("TW0P", "Airport", "°C"),
//            ("TB1T", "Battery 1", "°C"),
//            ("TB2T", "Battery 2", "°C"),
//            ("Te05", "CPU Efficiency Core 1", "°C"),
//            ("Tp01", "CPU Performance Core 1", "°C"),
//            ("Tp05", "CPU Performance Core 2", "°C"),
//            ("Tp09", "CPU Performance Core 3", "°C"),
//            ("Tp0D", "CPU Performance Core 4", "°C"),
//            ("Tp0b", "CPU Performance Core 6", "°C"),
//            ("Tp0f", "CPU Performance Core 7", "°C"),
//            ("Tp0j", "CPU Performance Core 8", "°C"),
//            ("TH0x", "Drive 0 OOBv3 Max", "°C"),
//            ("Tg0f", "GPU 1", "°C"),
//            ("TG0H", "GPU Heatsink 1", "°C"),
//            ("Th0H", "Heatpipe 1", "°C"),
//            ("Ts0S", "Memory Proximity", "°C"),
//            ("temp", "NAND CH0 temp", "°C"),
//            ("tcal", "PMU2 tcal", "°C"),
//            ("tdev1", "PMU2 tdev1", "°C"),
//            ("tdev2", "PMU2 tdev2", "°C"),
//            ("tdev3", "PMU2 tdev3", "°C"),
//            ("tdev4", "PMU2 tdev4", "°C"),
//            ("tdev5", "PMU2 tdev5", "°C"),
//            ("tdev6", "PMU2 tdev6", "°C"),
//            ("tdev7", "PMU2 tdev7", "°C"),
//            ("tdev8", "PMU2 tdev8", "°C"),
//            ("tdie1", "PMU2 tdie1", "°C"),
//            ("tdie2", "PMU2 tdie2", "°C"),
//            ("tdie3", "PMU2 tdie3", "°C"),
//            ("tdie4", "PMU2 tdie4", "°C"),
//            ("tdie5", "PMU2 tdie5", "°C"),
//            ("tdie6", "PMU2 tdie6", "°C"),
//            ("tdie7", "PMU2 tdie7", "°C"),
//            ("tdie8", "PMU2 tdie8", "°C"),
//            ("Ts0P", "Palm Rest", "°C"),
//            ("Tp0C", "Power Supply 1 Alt", "°C"),
//            ("battery", "gas gauge battery", "°C")
//        ],
//        "Voltage": [
//            ("VP0R", "12V Rail", "V"),
//            ("VD0R", "DC In", "V"),
//            ("vbuck5", "PMU2 vbuck5", "V"),
//            ("vbuck6", "PMU2 vbuck6", "V"),
//            ("vbuck8", "PMU2 vbuck8", "V"),
//            ("vbuck10", "PMU2 vbuck10", "V"),
//            ("vbuck12", "PMU2 vbuck12", "V"),
//            ("vbuck14", "PMU2 vbuck14", "V"),
//            ("vldo4", "PMU2 vldo4", "V"),
//            ("vbuck0", "PMU vbuck0", "V"),
//            ("vbuck1", "PMU vbuck1", "V"),
//            ("vbuck2", "PMU vbuck2", "V"),
//            ("vbuck3", "PMU vbuck3", "V"),
//            ("vbuck4", "PMU vbuck4", "V"),
//            ("vbuck7", "PMU vbuck7", "V"),
//            ("vbuck9", "PMU vbuck9", "V"),
//            ("vbuck11", "PMU vbuck11", "V"),
//            ("vbuck13", "PMU vbuck13", "V"),
//            ("vldo2", "PMU vldo2", "V"),
//            ("vldo7", "PMU vldo7", "V"),
//            ("vldo8", "PMU vldo8", "V"),
//            ("vldo9", "PMU vldo9", "V")
//        ]
//    ]
//    
//    func startMonitoring(refreshInterval: TimeInterval = 5.0) {
//        stopMonitoring()
//        fetchData()
//        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
//            self?.fetchData()
//        }
//    }
//    
//    func stopMonitoring() {
//        timer?.invalidate()
//        timer = nil
//    }
//    
//    func fetchData() {
//        if !smcReader.isConnected {
//            DispatchQueue.main.async {
//                self.errorMessage = "SMC Access Denied - Check entitlements"
//                self.isLoading = false
//            }
//            return
//        }
//        DispatchQueue.global(qos: .userInitiated).async {
//            var newCategories: [SensorCategory] = []
//            
//            for (categoryName, keys) in self.knownKeys {
//                var sensors: [SensorData] = []
//                
//                for keyInfo in keys {
//                    if let (value, type) = self.smcReader.readKey(keyInfo.key) {
//                        let formattedValue: String
//                        if let unit = keyInfo.unit {
//                            formattedValue = String(format: "%.2f \(unit)", value)
//                        } else {
//                            formattedValue = String(format: "%.0f", value)
//                        }
//                        
//                        let sensorType: SensorType
//                        switch type {
//                        case "ui8 ", "ui16", "ui32", "si8 ", "si16", "si32":
//                            sensorType = .integer
//                        case "flt ", "sp78", "sp5a", "fp2e":
//                            sensorType = .float
//                        case "{flag":
//                            sensorType = .boolean
//                        default:
//                            sensorType = type.contains("hid") ? .hidden : .unknown
//                        }
//                        
//                        let sensor = SensorData(
//                            description: keyInfo.description,
//                            key: keyInfo.key,
//                            value: formattedValue,
//                            type: sensorType
//                        )
//                        sensors.append(sensor)
//                    }
//                }
//                
//                if !sensors.isEmpty {
//                    newCategories.append(SensorCategory(
//                        name: categoryName,
//                        sensors: sensors
//                    ))
//                }
//            }
//            
//            DispatchQueue.main.async {
//                self.categories = newCategories
//                self.lastUpdated = Date()
//                self.isLoading = false
//                self.errorMessage = nil
//            }
//        }
//    }
//}
