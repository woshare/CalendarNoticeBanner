import Foundation

// (month, day) inclusive range — spans within a single year only
private struct HolidayWindow {
    let skin: BannerSkinID
    let startMonth: Int; let startDay: Int
    let endMonth: Int;   let endDay: Int

    func contains(month: Int, day: Int) -> Bool {
        let value = month * 100 + day
        return value >= startMonth * 100 + startDay
            && value <= endMonth * 100 + endDay
    }
}

private let holidayWindows: [HolidayWindow] = [
    HolidayWindow(skin: .springFestival,  startMonth: 1, startDay: 20, endMonth: 2, endDay: 10),
    HolidayWindow(skin: .lanternFestival, startMonth: 2, startDay: 11, endMonth: 2, endDay: 17),
    HolidayWindow(skin: .qingming,        startMonth: 4, startDay: 3,  endMonth: 4, endDay: 6),
    HolidayWindow(skin: .dragonBoatFest,  startMonth: 5, startDay: 28, endMonth: 6, endDay: 10),
    HolidayWindow(skin: .midAutumn,       startMonth: 9, startDay: 10, endMonth: 9, endDay: 30),
    HolidayWindow(skin: .christmas,       startMonth: 12, startDay: 20, endMonth: 12, endDay: 26),
]

enum BannerSkinID: String, CaseIterable, Codable {
    case auto            = "auto"
    case dragonBoat      = "dragon_boat"
    case minimal         = "minimal"
    case random          = "random"
    case springFestival  = "spring_festival"
    case lanternFestival = "lantern_festival"
    case qingming        = "qingming"
    case dragonBoatFest  = "dragon_boat_fest"
    case midAutumn       = "mid_autumn"
    case christmas       = "christmas"

    var displayName: String {
        switch self {
        case .auto:            return "🗓 自动（按节日）"
        case .dragonBoat:      return "🐉 龙舟（默认）"
        case .minimal:         return "✨ 简约"
        case .random:          return "🎲 随机"
        case .springFestival:  return "🧧 春节"
        case .lanternFestival: return "🏮 元宵"
        case .qingming:        return "🌿 清明"
        case .dragonBoatFest:  return "🐲 端午"
        case .midAutumn:       return "🌕 中秋"
        case .christmas:       return "🎄 圣诞"
        }
    }

    static var selectableCases: [BannerSkinID] {
        [.auto, .dragonBoat, .minimal, .random,
         .springFestival, .lanternFestival, .qingming,
         .dragonBoatFest, .midAutumn, .christmas]
    }

    func resolved(on date: Date = Date()) -> BannerSkinID {
        switch self {
        case .auto:
            return BannerSkinID.matchHoliday(for: date) ?? .dragonBoat
        case .random:
            let pool = BannerSkinID.allCases.filter { $0 != .random && $0 != .auto }
            return pool.randomElement() ?? .dragonBoat
        default:
            return self
        }
    }

    static func matchHoliday(for date: Date) -> BannerSkinID? {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)
        return holidayWindows.first { $0.contains(month: month, day: day) }?.skin
    }
}
