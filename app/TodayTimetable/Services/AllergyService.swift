import Foundation

/// 알레르기 정보 관리
final class AllergyService: Sendable {
    static let shared = AllergyService()

    /// 알레르기 유형 (NEIS 표준 번호)
    static let allergyTypes: [(id: Int, name: String, emoji: String)] = [
        (1, "난류", "🥚"),
        (2, "우유", "🥛"),
        (3, "메밀", "🌾"),
        (4, "땅콩", "🥜"),
        (5, "대두", "🫘"),
        (6, "밀", "🌾"),
        (7, "고등어", "🐟"),
        (8, "게", "🦀"),
        (9, "새우", "🦐"),
        (10, "돼지고기", "🐷"),
        (11, "복숭아", "🍑"),
        (12, "토마토", "🍅"),
        (13, "아황산류", "⚗️"),
        (14, "호두", "🌰"),
        (15, "닭고기", "🐔"),
        (16, "쇠고기", "🐄"),
        (17, "오징어", "🦑"),
        (18, "조개류", "🐚"),
        (19, "잣", "🌲"),
    ]

    /// 사용자가 선택한 알레르기 번호 목록
    var selectedAllergies: Set<Int> {
        get {
            Set(UserDefaults.standard.array(forKey: "selectedAllergies") as? [Int] ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "selectedAllergies")
        }
    }

    /// NEIS 메뉴 텍스트에서 알레르기 번호 추출
    /// 예: "돈육고추장불고기 (5.6.10.13)" → [5, 6, 10, 13]
    static func extractAllergyNumbers(from menuItem: String) -> [Int] {
        guard let range = menuItem.range(of: "\\(([\\d.]+)\\)", options: .regularExpression) else {
            return []
        }
        let numbersStr = menuItem[range]
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        return numbersStr.split(separator: ".").compactMap { Int($0) }
    }

    /// 해당 메뉴가 사용자 알레르기에 해당하는지 확인
    func hasAllergy(menuItem: String) -> Bool {
        let numbers = Self.extractAllergyNumbers(from: menuItem)
        return !numbers.isEmpty && !selectedAllergies.isDisjoint(with: numbers)
    }
}
