import AVFAudio
import UIKit

protocol MicrophonePermission: AnyObject {
    func request() async -> Bool
}

final class SystemMicrophonePermission: MicrophonePermission {
    func request() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

final class FakeMicrophonePermission: MicrophonePermission {
    var granted: Bool
    private(set) var requests = 0
    init(granted: Bool) { self.granted = granted }
    func request() async -> Bool {
        requests += 1
        return granted
    }
}

struct BatteryState: Equatable {
    /// 0...1, or nil when unknown (e.g. in the simulator).
    var level: Double?
    var charging: Bool
}

protocol BatteryReading: AnyObject {
    func read() -> BatteryState
}

final class DeviceBattery: BatteryReading {
    func read() -> BatteryState {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel < 0 ? nil : Double(device.batteryLevel)
        let charging = device.batteryState == .charging || device.batteryState == .full
        return BatteryState(level: level, charging: charging)
    }
}

final class FakeBattery: BatteryReading {
    var state: BatteryState
    init(state: BatteryState = BatteryState(level: 1, charging: true)) { self.state = state }
    func read() -> BatteryState { state }
}
