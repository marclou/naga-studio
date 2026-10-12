import Foundation
import IOKit

nonisolated struct DeviceStatus: Equatable, Sendable {
    var isConnected = false
    var name = "Naga V3 Pro"
    var transport: String?
    var batteryLevel: Int?

    var transportLabel: String? {
        guard let transport else { return nil }
        if transport.localizedCaseInsensitiveContains("bluetooth") { return "Bluetooth" }
        return transport == "USB" ? "USB" : transport
    }
}

nonisolated enum DeviceMonitor {
    static func scan() -> DeviceStatus {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator) == KERN_SUCCESS else {
            return DeviceStatus()
        }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            guard let product = property("Product", of: service) as? String, NagaDevice.matches(product) else { continue }
            return DeviceStatus(isConnected: true, name: product, transport: property("Transport", of: service) as? String)
        }
        return DeviceStatus()
    }

    private static func property(_ key: String, of service: io_service_t) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
