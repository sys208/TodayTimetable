import Foundation
import Observation

@MainActor @Observable
final class OnboardingViewModel {
    var searchQuery = ""
    var searchResults: [NEISService.SchoolSearchResult] = []
    var selectedSchool: NEISService.SchoolSearchResult?
    var grade = 1
    var classNumber = "1"
    var isSearching = false
    var isLoadingClasses = false
    var errorMessage: String?

    // 컴시간 관련
    var comciganCode: Int = 0
    var periodTimesPreview: [PeriodTimeStore.PeriodTime] = []
    var classDurationMinutes = 45

    var grades: [Int] {
        guard let school = selectedSchool else { return [1, 2, 3] }
        if school.type == "초등학교" { return [1, 2, 3, 4, 5, 6] }
        return [1, 2, 3]
    }
    var availableClasses: [String] = (1...20).map { String($0) }

    private var searchTask: Task<Void, Never>?

    func searchSchool() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            errorMessage = nil

            do {
                let results = try await NEISService.shared.searchSchool(query: query)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }

            isSearching = false
        }
    }

    func selectSchool(_ school: NEISService.SchoolSearchResult) {
        selectedSchool = school
        grade = 1
        classNumber = "1"
        comciganCode = 0
        classDurationMinutes = PeriodTimeStore.defaultClassDuration(for: schoolType(for: school))
        loadClassList()

        // 컴시간 스위치가 켜져 있고 초등학교가 아니면 컴시간 코드 자동 매칭
        if APIConfig.isComciganEnabled && school.type != "초등학교" {
            Task { await matchComciganCode(school) }
        }
    }

    /// 학년 변경 시 반 목록 다시 로드 + 교시 시간 갱신
    func onGradeChanged() {
        classNumber = "1"
        loadClassList()
        fetchPeriodTimes()
    }

    /// 반 변경 시 교시 시간 갱신
    func onClassChanged() {
        fetchPeriodTimes()
    }

    func onClassDurationChanged() {
        PeriodTimeStore.shared.saveClassDuration(classDurationMinutes)
        fetchPeriodTimes()
    }

    // MARK: - 컴시간 매칭

    private func matchComciganCode(_ school: NEISService.SchoolSearchResult) async {
        let regionMap: [String: String] = [
            "B10": "서울", "C10": "부산", "D10": "대구", "E10": "인천",
            "F10": "광주", "G10": "대전", "H10": "울산", "I10": "세종",
            "J10": "경기", "K10": "강원", "M10": "충북", "N10": "충남",
            "P10": "전북", "Q10": "전남", "R10": "경북", "S10": "경남",
            "T10": "제주",
        ]
        let myRegion = regionMap[school.regionCode] ?? ""

        if let results = try? await NEISService.shared.searchComciganSchool(name: school.name) {
            let matched = results.first(where: { $0.region == myRegion }) ?? results.first
            if let matched {
                comciganCode = matched.code
                fetchPeriodTimes()
            }
        }
    }

    // MARK: - 교시 시간 가져오기 (컴시간)

    private func fetchPeriodTimes() {
        guard APIConfig.isComciganEnabled, comciganCode > 0 else {
            periodTimesPreview = []
            return
        }

        Task {
            do {
                let (_, classTimes) = try await NEISService.shared.getComciganTimetable(
                    comciganCode: comciganCode,
                    grade: grade,
                    classNumber: Int(classNumber) ?? 1,
                    classDurationMinutes: classDurationMinutes
                )

                periodTimesPreview = PeriodTimeStore.times(
                    from: classTimes,
                    classDurationMinutes: classDurationMinutes
                )

                // 바로 저장
                if !periodTimesPreview.isEmpty {
                    PeriodTimeStore.shared.saveClassDuration(classDurationMinutes)
                    PeriodTimeStore.shared.save(periodTimesPreview)
                }
            } catch {
                periodTimesPreview = []
            }
        }
    }

    // MARK: - 반 목록

    private func loadClassList() {
        guard let school = selectedSchool else { return }

        isLoadingClasses = true
        Task {
            do {
                let classes = try await NEISService.shared.getClassList(
                    regionCode: school.regionCode,
                    schoolCode: school.schoolCode,
                    schoolType: schoolType(for: school),
                    grade: grade
                )
                if !classes.isEmpty {
                    availableClasses = classes
                } else {
                    availableClasses = (1...10).map { String($0) }
                }
            } catch {
                availableClasses = (1...10).map { String($0) }
            }
            isLoadingClasses = false
        }
    }

    var schoolType: SchoolType {
        guard let type = selectedSchool?.type else { return .middle }
        return type == "고등학교" ? .high : type == "초등학교" ? .elementary : .middle
    }

    private func schoolType(for school: NEISService.SchoolSearchResult) -> SchoolType {
        school.type == "고등학교" ? .high : school.type == "초등학교" ? .elementary : .middle
    }
}
