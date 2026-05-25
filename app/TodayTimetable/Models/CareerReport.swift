import Foundation
import SwiftData

/// AI 진로 리포트 전용 모델
@Model
final class CareerReport {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var interestArea: String
    var favoriteSubjects: String
    var target: String
    var studyStyle: String

    // AI 생성 결과
    var title: String
    var summary: String
    var recommendedJobs: [CareerItem]
    var recommendedMajors: [CareerItem]
    var recommendedUniversities: [CareerItem]
    var schoolStrategy: [String]
    var performanceTips: [String]
    var weeklyPlan: [WeekPlan]
    var warnings: [String]
    var publicDataSummary: String

    init(
        interestArea: String = "",
        favoriteSubjects: String = "",
        target: String = "",
        studyStyle: String = "",
        title: String = "",
        summary: String = "",
        recommendedJobs: [CareerItem] = [],
        recommendedMajors: [CareerItem] = [],
        recommendedUniversities: [CareerItem] = [],
        schoolStrategy: [String] = [],
        performanceTips: [String] = [],
        weeklyPlan: [WeekPlan] = [],
        warnings: [String] = [],
        publicDataSummary: String = ""
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.interestArea = interestArea
        self.favoriteSubjects = favoriteSubjects
        self.target = target
        self.studyStyle = studyStyle
        self.title = title
        self.summary = summary
        self.recommendedJobs = recommendedJobs
        self.recommendedMajors = recommendedMajors
        self.recommendedUniversities = recommendedUniversities
        self.schoolStrategy = schoolStrategy
        self.performanceTips = performanceTips
        self.weeklyPlan = weeklyPlan
        self.warnings = warnings
        self.publicDataSummary = publicDataSummary
    }
}

struct CareerItem: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let reason: String
    let detail: String
}

struct WeekPlan: Codable, Identifiable, Hashable {
    var id: Int { week }
    let week: Int
    let tasks: [String]
}

/// AI JSON 응답 디코딩용 (모든 필드 optional — Groq 응답이 불완전할 수 있음)
struct CareerReportJSON: Codable {
    let title: String?
    let summary: String?
    let recommendedJobs: [CareerItemJSON]?
    let recommendedMajors: [CareerItemJSON]?
    let recommendedUniversities: [CareerItemJSON]?
    let schoolStrategy: [String]?
    let performanceTips: [String]?
    let weeklyPlan: [WeekPlanJSON]?
    let warnings: [String]?
}

struct CareerItemJSON: Codable {
    let name: String?
    let reason: String?
    let detail: String?

    var toModel: CareerItem {
        CareerItem(name: name ?? "", reason: reason ?? "", detail: detail ?? "")
    }
}

struct WeekPlanJSON: Codable {
    let week: Int?
    let tasks: [String]?

    var toModel: WeekPlan {
        WeekPlan(week: week ?? 0, tasks: tasks ?? [])
    }
}
