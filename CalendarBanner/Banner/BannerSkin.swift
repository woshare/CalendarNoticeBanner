import Foundation

enum BannerSkinID: String, CaseIterable, Codable {
    case dragonBoat = "dragon_boat"
    case minimal    = "minimal"
    case random     = "random"

    var displayName: String {
        switch self {
        case .dragonBoat: return "🐉 龙舟（默认）"
        case .minimal:    return "✨ 简约"
        case .random:     return "🎲 随机"
        }
    }

    static var selectableCases: [BannerSkinID] {
        allCases
    }

    func resolved() -> BannerSkinID {
        guard self == .random else { return self }
        return allCases.filter { $0 != .random }.randomElement() ?? .dragonBoat
    }
}
