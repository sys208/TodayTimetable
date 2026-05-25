import Foundation
import HealthKit

/// 건강앱 칼로리 연동 서비스
final class HealthService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = HealthService()

    private let store = HKHealthStore()

    /// HealthKit 사용 가능 여부
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // 읽기/쓰기할 데이터 타입
    private let dietaryEnergy = HKQuantityType(.dietaryEnergyConsumed)    // 섭취 칼로리
    private let activeEnergy = HKQuantityType(.activeEnergyBurned)        // 활동 칼로리
    private let basalEnergy = HKQuantityType(.basalEnergyBurned)          // 기초 대사

    // MARK: - 권한 요청

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [activeEnergy, basalEnergy, dietaryEnergy]
        let writeTypes: Set<HKSampleType> = [dietaryEnergy]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 급식 칼로리 쓰기

    /// 급식 칼로리를 건강앱에 추가
    func saveMealCalories(calories: Double, mealType: String, date: Date = Date()) async -> Bool {
        guard isAvailable else { return false }

        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(
            type: dietaryEnergy,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [
                HKMetadataKeyFoodType: mealType,
                "Source": "오늘시간표",
            ]
        )

        do {
            try await store.save(sample)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 오늘 칼로리 읽기

    struct CalorieSummary {
        let consumed: Double    // 섭취 칼로리 (급식)
        let active: Double      // 활동 칼로리
        let basal: Double       // 기초 대사
        var total: Double { active + basal }  // 총 소비 칼로리
        var balance: Double { consumed - total }  // 칼로리 잔여
    }

    func getTodayCalories() async -> CalorieSummary {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        let consumed = await sumQuantity(type: dietaryEnergy, predicate: predicate)
        let active = await sumQuantity(type: activeEnergy, predicate: predicate)
        let basal = await sumQuantity(type: basalEnergy, predicate: predicate)

        return CalorieSummary(consumed: consumed, active: active, basal: basal)
    }

    private func sumQuantity(type: HKQuantityType, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
