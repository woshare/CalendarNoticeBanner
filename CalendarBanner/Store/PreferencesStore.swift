import Foundation

final class PreferencesStore: ObservableObject {
    private let defaults = UserDefaults.standard

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
        get { defaults.double(forKey: Keys.bannerDuration).nonZero ?? 5.0 }
        set { defaults.set(newValue, forKey: Keys.bannerDuration); objectWillChange.send() }
    }

    var verticalPosition: Double {
        get { defaults.double(forKey: Keys.verticalPosition).nonZero ?? 0.35 }
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

    private enum Keys {
        static let reminderMinutes   = "com.calendarbanner.reminderMinutes"
        static let bannerDuration    = "com.calendarbanner.bannerDuration"
        static let verticalPosition  = "com.calendarbanner.verticalPosition"
        static let showTime          = "com.calendarbanner.showTime"
        static let showCountdown     = "com.calendarbanner.showCountdown"
        static let showLocation      = "com.calendarbanner.showLocation"
        static let showURL           = "com.calendarbanner.showURL"
        static let showAttendeeCount = "com.calendarbanner.showAttendeeCount"

        static let all = [reminderMinutes, bannerDuration, verticalPosition,
                          showTime, showCountdown, showLocation, showURL, showAttendeeCount]
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
