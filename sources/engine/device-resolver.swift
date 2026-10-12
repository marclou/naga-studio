import CoreGraphics
import Darwin
import Foundation
import IOKit
import Synchronization

nonisolated enum NagaDevice {
    static func matches(_ product: String) -> Bool {
        product.localizedCaseInsensitiveContains("naga")
    }
}

nonisolated enum EventOrigin: Sendable {
    case naga
    case otherDevice
    /// macOS delivers some hardware events without their device, such as the Naga's middle click.
    case unattributed(pid: Int64)
}

/// Tells which physical device produced an event, so settings only apply to the Naga.
nonisolated final class DeviceResolver: Sendable {
    private typealias CopyHIDEvent = @convention(c) (CGEvent) -> Unmanaged<CFTypeRef>?
    private typealias SenderID = @convention(c) (CFTypeRef) -> UInt64

    private let copyHIDEvent: CopyHIDEvent?
    private let senderID: SenderID?
    private let senderCache = Mutex<[UInt64: Bool]>([:])
    private let processCache = Mutex<[Int64: Bool]>([:])

    init() {
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        copyHIDEvent = dlsym(handle, "CGEventCopyIOHIDEvent").map { unsafeBitCast($0, to: CopyHIDEvent.self) }
        senderID = dlsym(handle, "IOHIDEventGetSenderID").map { unsafeBitCast($0, to: SenderID.self) }
    }

    var isAvailable: Bool { copyHIDEvent != nil && senderID != nil }

    func origin(of event: CGEvent) -> EventOrigin {
        guard let copyHIDEvent, let senderID, let hidEvent = copyHIDEvent(event)?.takeRetainedValue() else {
            return .unattributed(pid: event.getIntegerValueField(.eventSourceUnixProcessID))
        }
        let id = senderID(hidEvent)
        guard id != 0 else { return .unattributed(pid: event.getIntegerValueField(.eventSourceUnixProcessID)) }
        if let isKnownNaga = senderCache.withLock({ $0[id] }) { return isKnownNaga ? .naga : .otherDevice }
        let isNaga = Self.registryEntryIsNaga(id)
        senderCache.withLock { $0[id] = isNaga }
        return isNaga ? .naga : .otherDevice
    }

    /// Events posted by apps carry the app's process ID; hardware events carry 0 or a system daemon's.
    func isSystemProcess(_ pid: Int64) -> Bool {
        guard pid > 0 else { return true }
        if let isKnownSystem = processCache.withLock({ $0[pid] }) { return isKnownSystem }
        var path = [CChar](repeating: 0, count: 4096)
        let length = Int(proc_pidpath(Int32(pid), &path, UInt32(path.count)))
        let isSystem = length > 0
            && !String(decoding: path.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self).contains(".app/")
        processCache.withLock { $0[pid] = isSystem }
        return isSystem
    }

    private static func registryEntryIsNaga(_ id: UInt64) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(id))
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }
        let options = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        let product = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "Product" as CFString, kCFAllocatorDefault, options) as? String
        return product.map(NagaDevice.matches) ?? false
    }
}
