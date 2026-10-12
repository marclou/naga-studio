import CoreBluetooth
import os

/// Reads the Naga's battery over Razer's vendor Bluetooth service. The standard battery service on Naga mice
/// is stuck at 100%, so the level comes from vendor key `05 81 00 01`, which answers with a 0–255 byte.
/// Protocol reference: https://github.com/gh123man/open-snek/blob/main/docs/protocol/BLE_PROTOCOL.md
nonisolated final class BatteryMonitor: NSObject, @unchecked Sendable {
    private struct Exchange {
        let id: UInt8
        let onPayload: ([UInt8]) -> Void
        var length: Int?
        var payload: [UInt8] = []
        var inlinePayload: [UInt8] = []
    }

    // Touched only from refresh() and CoreBluetooth callbacks, which both run on the main queue.
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var isNotifying = false
    private var requestID: UInt8 = 0x30
    private var exchange: Exchange?
    private let onLevel: @MainActor (Int?) -> Void

    nonisolated(unsafe) private static let vendorService = CBUUID(string: "52401523-F97C-7F90-0E7F-6C6F4E36DB1C")
    nonisolated(unsafe) private static let vendorWrite = CBUUID(string: "52401524-F97C-7F90-0E7F-6C6F4E36DB1C")
    nonisolated(unsafe) private static let vendorNotify = CBUUID(string: "52401525-F97C-7F90-0E7F-6C6F4E36DB1C")
    nonisolated(unsafe) private static let batteryService = CBUUID(string: "180F")
    private static let batteryKey: [UInt8] = [0x05, 0x81, 0x00, 0x01]
    private static let successStatus: UInt8 = 0x02
    private static let logger = Logger(subsystem: "com.marclou.naga-studio", category: "battery")

    init(onLevel: @escaping @MainActor (Int?) -> Void) {
        self.onLevel = onLevel
    }

    @MainActor func refresh() {
        guard let central else {
            central = CBCentralManager(delegate: self, queue: .main)
            return
        }
        guard central.state == .poweredOn else { return }
        if let peripheral, peripheral.state == .connected, isNotifying {
            requestBattery(from: peripheral)
        } else {
            attach(using: central)
        }
    }

    private func attach(using central: CBCentralManager) {
        guard let naga = central.retrieveConnectedPeripherals(withServices: [Self.vendorService, Self.batteryService])
            .first(where: { NagaDevice.matches($0.name ?? "") }) else { return }
        peripheral = naga
        naga.delegate = self
        central.connect(naga)
    }

    private func requestBattery(from peripheral: CBPeripheral) {
        send(Self.batteryKey, to: peripheral) { [weak self] payload in
            guard let self, let raw = payload.first else { return }
            let level = Int((Double(raw) * 100 / 255).rounded())
            Self.logger.notice("Naga battery \(level, privacy: .public)% (raw \(raw, privacy: .public))")
            MainActor.assumeIsolated { onLevel(level) }
        }
    }

    private func send(_ key: [UInt8], to peripheral: CBPeripheral, onPayload: @escaping ([UInt8]) -> Void) {
        guard let writeCharacteristic, exchange == nil else { return }
        requestID &+= 1
        let id = requestID
        exchange = Exchange(id: id, onPayload: onPayload)
        peripheral.writeValue(Data([id, 0x00, 0x00, 0x00] + key), for: writeCharacteristic, type: .withResponse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.exchange?.id == id { self?.exchange = nil }
        }
    }

    private func receive(_ frame: [UInt8]) {
        guard var current = exchange else { return }
        if current.length == nil {
            guard frame.count >= 8, frame[0] == current.id else { return }
            guard frame[7] == Self.successStatus else {
                Self.logger.error("Vendor request failed with status \(frame[7], privacy: .public)")
                exchange = nil
                return
            }
            current.length = Int(frame[1])
            current.inlinePayload = Array(frame.dropFirst(8))
            exchange = current
            // Payload normally follows in its own frame; long headers may carry it inline instead.
            let id = current.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, let pending = exchange, pending.id == id, pending.payload.isEmpty else { return }
                finish(pending, with: pending.inlinePayload)
            }
        } else {
            current.payload += frame
            exchange = current
            finish(current, with: current.payload)
        }
    }

    private func finish(_ completed: Exchange, with payload: [UInt8]) {
        guard let length = completed.length, length > 0, payload.count >= length else { return }
        exchange = nil
        completed.onPayload(Array(payload.prefix(length)))
    }
}

nonisolated extension BatteryMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { attach(using: central) }
        if central.state == .unauthorized { Self.logger.error("Bluetooth access denied") }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.vendorService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        writeCharacteristic = nil
        isNotifying = false
        exchange = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.vendorService }) else {
            Self.logger.error("Razer vendor service not found")
            return
        }
        peripheral.discoverCharacteristics([Self.vendorWrite, Self.vendorNotify], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.vendorWrite { writeCharacteristic = characteristic }
            if characteristic.uuid == Self.vendorNotify { peripheral.setNotifyValue(true, for: characteristic) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard characteristic.uuid == Self.vendorNotify, characteristic.isNotifying else { return }
        isNotifying = true
        requestBattery(from: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard characteristic.uuid == Self.vendorNotify, let value = characteristic.value else { return }
        receive([UInt8](value))
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error { Self.logger.error("Vendor request write failed: \(error.localizedDescription, privacy: .public)") }
    }
}
