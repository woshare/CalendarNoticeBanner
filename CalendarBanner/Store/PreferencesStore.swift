import Foundation

final class PreferencesStore: ObservableObject {
    private let defaults = UserDefaults.standard

    // macOS 内置系统铃声列表
    static let alertSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink"
    ]

    func reset() {
        Keys.all.forEach { defaults.removeObject(forKey: $0) }
    }

    var reminderMinutes: [Int] {
        get {
            let saved = defaults.array(forKey: Keys.reminderMinutes) as? [Int]
            return saved ?? [15, 5]
        }
        set {
            defaults.set(newValue, forKey: Keys.reminderMinutes)
            objectWillChange.send()
        }
    }

    var bannerDuration: Double {
        get { defaults.double(forKey: Keys.bannerDuration).nonZero ?? 300.0 }
        set { defaults.set(newValue, forKey: Keys.bannerDuration); objectWillChange.send() }
    }

    var verticalPosition: Double {
        get { defaults.double(forKey: Keys.verticalPosition).nonZero ?? 0.72 }
        set { defaults.set(newValue, forKey: Keys.verticalPosition); objectWillChange.send() }
    }

    var showTime: Bool {
        get { defaults.object(forKey: Keys.showTime) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showTime); objectWillChange.send() }
    }

    var showCountdown: Bool {
        get { defaults.object(forKey: Keys.showCountdown) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showCountdown); objectWillChange.send() }
    }

    var showLocation: Bool {
        get { defaults.object(forKey: Keys.showLocation) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showLocation); objectWillChange.send() }
    }

    var showURL: Bool {
        get { defaults.object(forKey: Keys.showURL) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showURL); objectWillChange.send() }
    }

    var showAttendeeCount: Bool {
        get { defaults.object(forKey: Keys.showAttendeeCount) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showAttendeeCount); objectWillChange.send() }
    }

    // 铃声名称，默认 Glass
    var alertSound: String {
        get { defaults.string(forKey: Keys.alertSound) ?? "Glass" }
        set { defaults.set(newValue, forKey: Keys.alertSound); objectWillChange.send() }
    }

    // 音量 0.0~1.0，0 表示关闭，默认 0.8
    var alertVolume: Double {
        get {
            guard defaults.object(forKey: Keys.alertVolume) != nil else { return 0.8 }
            return defaults.double(forKey: Keys.alertVolume)
        }
        set { defaults.set(newValue, forKey: Keys.alertVolume); objectWillChange.send() }
    }

    private enum Keys {
        static let reminderMinutes   = "com.meetbell.reminderMinutes"
        static let bannerDuration    = "com.meetbell.bannerDuration"
        static let verticalPosition  = "com.meetbell.verticalPosition"
        static let showTime          = "com.meetbell.showTime"
        static let showCountdown     = "com.meetbell.showCountdown"
        static let showLocation      = "com.meetbell.showLocation"
        static let showURL           = "com.meetbell.showURL"
        static let showAttendeeCount = "com.meetbell.showAttendeeCount"
        static let alertSound        = "com.meetbell.alertSound"
        static let alertVolume       = "com.meetbell.alertVolume"

        static let all = [reminderMinutes, bannerDuration, verticalPosition,
                          showTime, showCountdown, showLocation, showURL, showAttendeeCount,
                          alertSound, alertVolume]
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
