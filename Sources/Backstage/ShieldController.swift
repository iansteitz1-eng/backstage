// ShieldController — dictation shield. While engaged, EVERY programmatic activation is
// bounced (not just jailed apps); user-initiated activations always pass.
// Modes: off · on (manual) · auto (mic-in-use via CoreAudio DeviceIsRunningSomewhere).
// Auto ships OFF by default: boxes with a warm-mic pipeline (like the M4 it was born on)
// read the input device as running at idle, which would pin the shield on.
import CoreAudio
import Foundation

final class ShieldController {
    enum Mode: String { case off, on, auto }
    var mode: Mode = .off {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "shieldMode") }
    }

    init() {
        if let s = UserDefaults.standard.string(forKey: "shieldMode"), let m = Mode(rawValue: s) {
            mode = m
        }
    }

    var engaged: Bool {
        switch mode {
        case .off: return false
        case .on: return true
        case .auto: return Self.micInUse()
        }
    }

    static func micInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz, &deviceID) == noErr else { return false }
        var running: UInt32 = 0
        var addr2 = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                               mScope: kAudioObjectPropertyScopeGlobal,
                                               mElement: kAudioObjectPropertyElementMain)
        var sz2 = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr2, 0, nil, &sz2, &running) == noErr else { return false }
        return running != 0
    }
}
