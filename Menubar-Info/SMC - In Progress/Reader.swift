//
//  Reader.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 01/06/2025.
//

//import Foundation
//import IOKit
//
//class SMCReader {
//    private let kSMCFamily = "AppleSMC"
//    private let kSMCUserClientOpen: UInt32 = 2
//    private let kSMCUserClientClose: UInt32 = 3
//    private let kSMCReadKey: UInt32 = 5
//    private let kSMCGetKeyInfo: UInt32 = 9
//    
//    private var conn: io_connect_t = 0
//    public var isConnected = false
//    
//    init() {
//        isConnected = open()
//        if !isConnected {
//            tryRootAccess()
//        }
//    }
//    
//    deinit {
//        close()
//    }
//    
//    private func tryRootAccess() {
//        let task = Process()
//        task.launchPath = "/usr/bin/osascript"
//        task.arguments = [
//            "-e",
//            "do shell script \"whoami\" with administrator privileges"
//        ]
//        
//        do {
//            try task.run()
//            isConnected = open()
//        } catch {
//            print("Failed to get root access: \(error)")
//        }
//    }
//    
//    private func open() -> Bool {
//        let service = IOServiceGetMatchingService(kIOMainPortDefault,
//                                                IOServiceMatching(kSMCFamily))
//        guard service != 0 else {
//            print("Error: Failed to find AppleSMC service")
//            return false
//        }
//        
//        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
//        IOObjectRelease(service)
//        
//        guard result == KERN_SUCCESS else {
//            print("Error: Failed to open SMC connection: \(result)")
//            return false
//        }
//        
//        return true
//    }
//    
//    private func close() {
//        if conn != 0 {
//            IOServiceClose(conn)
//            conn = 0
//        }
//        isConnected = false
//    }
//    
//    func readKey(_ key: String) -> (value: Double, type: String)? {
//        guard isConnected else { return nil }
//        
//        let keyCode = stringToUInt32(key)
//        var input = SMCKeyData_t()
//        var output = SMCKeyData_t()
//        
//        input.key = keyCode
//        input.data8 = UInt8(kSMCGetKeyInfo)
//        
//        let inputSize = MemoryLayout<SMCKeyData_t>.size
//        var outputSize = MemoryLayout<SMCKeyData_t>.size
//        
//        let result = IOConnectCallStructMethod(conn,
//                                             kSMCGetKeyInfo,
//                                             &input,
//                                             inputSize,
//                                             &output,
//                                             &outputSize)
//        
//        guard result == kIOReturnSuccess else {
//            print("Failed to get key info for \(key): \(result)")
//            return nil
//        }
//        
//        input.keyInfo.dataSize = output.keyInfo.dataSize
//        input.data8 = UInt8(kSMCReadKey)
//        
//        let readResult = IOConnectCallStructMethod(conn,
//                                                  kSMCReadKey,
//                                                  &input,
//                                                  inputSize,
//                                                  &output,
//                                                  &outputSize)
//        
//        guard readResult == kIOReturnSuccess else {
//            print("Failed to read key \(key): \(readResult)")
//            return nil
//        }
//        
//        let type = String(bytes: output.keyInfo.dataType.map { UInt8($0) },
//                         encoding: .ascii) ?? "UNKN"
//        
//        let value: Double
//        switch type {
//        case "sp78":
//            let sp78Value = output.bytes.withUnsafeBytes { $0.load(as: Int16.self) }
//            value = Double(sp78Value) / 256.0
//        case "flt ":
//            value = output.bytes.withUnsafeBytes { $0.load(as: Float32.self) }.doubleValue
//        case "ui8 ", "ui16", "ui32":
//            if output.keyInfo.dataSize == 1 {
//                value = Double(output.bytes.withUnsafeBytes { $0.load(as: UInt8.self) })
//            } else if output.keyInfo.dataSize == 2 {
//                value = Double(output.bytes.withUnsafeBytes { $0.load(as: UInt16.self) })
//            } else {
//                value = Double(output.bytes.withUnsafeBytes { $0.load(as: UInt32.self) })
//            }
//        default:
//            print("Unsupported data type \(type) for key \(key)")
//            return nil
//        }
//        
//        return (value, type)
//    }
//    
//    private func stringToUInt32(_ string: String) -> UInt32 {
//        guard string.count == 4 else { return 0 }
//        var result: UInt32 = 0
//        for char in string.utf16 {
//            result = result << 8 + UInt32(char)
//        }
//        return result
//    }
//}
//
//private struct SMCKeyData_t {
//    var key: UInt32 = 0
//    var vers = SMCVers_t()
//    var pLimitData = SMCPLimitData_t()
//    var keyInfo = SMCKeyInfo_t()
//    var result: UInt8 = 0
//    var status: UInt8 = 0
//    var data8: UInt8 = 0
//    var data32: UInt32 = 0
//    var bytes: [UInt8] = Array(repeating: 0, count: 32)
//}
//
//private struct SMCVers_t {
//    var major: UInt8 = 0
//    var minor: UInt8 = 0
//    var build: UInt8 = 0
//    var reserved: UInt8 = 0
//    var release: UInt16 = 0
//}
//
//private struct SMCPLimitData_t {
//    var version: UInt16 = 0
//    var length: UInt16 = 0
//    var cpuPLimit: UInt32 = 0
//    var gpuPLimit: UInt32 = 0
//    var memPLimit: UInt32 = 0
//}
//
//private struct SMCKeyInfo_t {
//    var dataSize: UInt32 = 0
//    var dataType: [UInt8] = Array(repeating: 0, count: 5)
//    var dataAttributes: UInt8 = 0
//}
//
//extension Float32 {
//    var doubleValue: Double { Double(self) }
//}
//
//enum SensorType: String {
//    case integer = "int"
//    case float = "flt"
//    case hidden = "hid"
//    case ioFloat = "ioft"
//    case boolean = "bool"
//    case unknown
//    
//    init(rawValue: String) {
//        switch rawValue.lowercased() {
//        case "int": self = .integer
//        case "flt": self = .float
//        case "hid": self = .hidden
//        case "ioft": self = .ioFloat
//        case "bool": self = .boolean
//        default: self = .unknown
//        }
//    }
//}
//
//struct SensorData: Identifiable {
//    let id = UUID()
//    let description: String
//    let key: String
//    let value: String
//    let type: SensorType
//}
//
//struct SensorCategory: Identifiable {
//    let id = UUID()
//    let name: String
//    var sensors: [SensorData]
//}
