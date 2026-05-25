import Foundation
import SwiftData
import SwiftUI

@Model
final class Subject {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String       // 색상 Hex 코드
    var teacher: String?
    var classroom: String?

    init(name: String, colorHex: String = Subject.randomColorHex(), teacher: String? = nil, classroom: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.teacher = teacher
        self.classroom = classroom
    }

    var color: Color {
        Color(hex: colorHex)
    }

    /// 과목별 기본 색상 팔레트
    private static let palette = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
        "#BB8FCE", "#85C1E9", "#F0B27A", "#82E0AA",
    ]

    static func randomColorHex() -> String {
        palette.randomElement() ?? "#4ECDC4"
    }
}
