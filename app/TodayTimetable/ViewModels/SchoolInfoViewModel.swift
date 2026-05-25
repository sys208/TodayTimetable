import Foundation
import Observation

struct SchoolAIDiagnosis: Codable {
    let summary: String
    let strengths: [String]
    let improvements: [String]
    let studyTips: [String]
    let notes: [String]
}

@MainActor @Observable
final class SchoolInfoViewModel {
    var basicInfo: SchoolInfoService.BasicInfo?
    var stats: SchoolInfoService.SchoolStats?
    var genderStats: SchoolInfoService.GenderStats?
    var teacherStats: SchoolInfoService.TeacherStats?
    var clubs: [SchoolInfoService.ClubInfo] = []
    var uniforms: [SchoolInfoService.UniformInfo] = []
    var afterSchool: [SchoolInfoService.AfterSchoolInfo] = []
    var library: SchoolInfoService.LibraryInfo?
    var classDetails: [SchoolInfoService.ClassDetail] = []
    var classDays: [SchoolInfoService.ClassDays] = []
    var transferStats: SchoolInfoService.TransferStats?
    var aiDiagnosis: SchoolAIDiagnosis?
    var isLoadingAI = false
    var isLoading = false
    var loadingMessage = ""
    var errorMessage: String?
    var schulCode: String?
    var selectedYear: Int = Calendar.current.component(.year, from: Date())
    private var loadedSchoolCode: String?

    func loadAll(school: School) async {
        if loadedSchoolCode != nil && loadedSchoolCode != school.code {
            resetAll()
        }
        loadedSchoolCode = school.code

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await SchoolInfoService.shared.configureRegion(address: school.address, neisRegionCode: school.regionCode)

        // 정보공시 코드 찾기
        if schulCode == nil {
            let cached = UserDefaults.standard.string(forKey: "schulCode_\(school.code)")
            if let cached {
                schulCode = cached
            } else {
                schulCode = school.code
                loadingMessage = "학교 정보를 검색하는 중..."
                let region = school.address.components(separatedBy: " ").prefix(2).joined(separator: " ")
                let discovered = await SchoolInfoService.shared.findSchulCode(
                    schoolName: school.name,
                    schoolType: school.schoolType,
                    region: region
                )
                if let code = discovered {
                    schulCode = code
                    UserDefaults.standard.set(code, forKey: "schulCode_\(school.code)")
                }
            }
        }

        guard let code = schulCode else {
            loadingMessage = "학교 정보를 찾을 수 없습니다"
            errorMessage = "학교코드를 찾지 못해서 정보를 불러오지 못했어요."
            return
        }
        let type = school.schoolType
        var yr = selectedYear
        var currentCode = code

        loadingMessage = "기본정보 불러오는 중..."
        basicInfo = await SchoolInfoService.shared.getBasicInfo(schulCode: currentCode, schoolType: type, year: yr)
        if let basicInfo, !isMatchingSchoolName(basicInfo.name, school.name) {
            self.basicInfo = nil
            UserDefaults.standard.removeObject(forKey: "schulCode_\(school.code)")
        }
        if basicInfo == nil {
            // 학교 코드가 학교알리미와 바로 매칭되지 않는 경우, 검색 결과를 한 번 더 시도
            if let fallbackCode = await SchoolInfoService.shared.findSchulCode(
                schoolName: school.name,
                schoolType: school.schoolType,
                region: school.address.components(separatedBy: " ").prefix(2).joined(separator: " ")
               ),
               fallbackCode != code {
                currentCode = fallbackCode
                schulCode = fallbackCode
                UserDefaults.standard.set(fallbackCode, forKey: "schulCode_\(school.code)")
                basicInfo = await SchoolInfoService.shared.getBasicInfo(schulCode: fallbackCode, schoolType: type, year: yr)
                if let basicInfo, !isMatchingSchoolName(basicInfo.name, school.name) {
                    self.basicInfo = nil
                    UserDefaults.standard.removeObject(forKey: "schulCode_\(school.code)")
                }
            }
        }
        if basicInfo == nil {
            loadingMessage = "학교 기본정보를 찾지 못했어요."
        }

        loadingMessage = "학생 현황 불러오는 중..."
        stats = await SchoolInfoService.shared.getSchoolStats(schulCode: currentCode, schoolType: type, year: yr)

        // 데이터가 없으면 작년으로 자동 전환
        if stats == nil && yr == Calendar.current.component(.year, from: Date()) {
            yr = yr - 1
            selectedYear = yr
            stats = await SchoolInfoService.shared.getSchoolStats(schulCode: currentCode, schoolType: type, year: yr)
        }
        classDetails = await SchoolInfoService.shared.getClassDetails(schulCode: currentCode, schoolType: type, year: yr)

        loadingMessage = "교원 현황 불러오는 중..."
        genderStats = await SchoolInfoService.shared.getGenderStats(schulCode: currentCode, schoolType: type, year: yr)
        teacherStats = await SchoolInfoService.shared.getTeacherStats(schulCode: currentCode, schoolType: type, year: yr)

        loadingMessage = "상세 정보 불러오는 중..."
        clubs = await SchoolInfoService.shared.getClubs(schulCode: currentCode, schoolType: type, year: yr)
        library = await SchoolInfoService.shared.getLibrary(schulCode: currentCode, schoolType: type, year: yr)
        uniforms = await SchoolInfoService.shared.getUniformPrices(schulCode: currentCode, schoolType: type, year: yr)
        afterSchool = await SchoolInfoService.shared.getAfterSchool(schulCode: currentCode, schoolType: type, year: yr)
        classDays = await SchoolInfoService.shared.getClassDays(schulCode: currentCode, schoolType: type, year: yr)
        transferStats = await SchoolInfoService.shared.getTransferStats(schulCode: currentCode, schoolType: type, year: yr)

        if basicInfo == nil, stats == nil, genderStats == nil, teacherStats == nil, clubs.isEmpty,
           uniforms.isEmpty, afterSchool.isEmpty, library == nil, classDetails.isEmpty, classDays.isEmpty,
           transferStats == nil {
            errorMessage = "학교알리미 데이터가 아직 없거나 학교코드 매칭이 실패했어요."
        }
    }

    // MARK: - AI 학교 진단

    func runAIDiagnosis(school: School) async {
        guard let code = schulCode else { return }
        isLoadingAI = true
        aiDiagnosis = nil
        defer { isLoadingAI = false }

        let yr = selectedYear
        let report = await SchoolInfoService.shared.collectAllDataForAI(
            schulCode: code, schoolType: school.schoolType, year: yr
        )

        guard !report.isEmpty else {
            aiDiagnosis = SchoolAIDiagnosis(summary: "데이터를 수집할 수 없습니다.", strengths: [], improvements: [], studyTips: [], notes: [])
            return
        }

        let prompt = """
        다음은 학교알리미 공공데이터에서 가져온 학교 정보입니다.

        \(report)

        이 학교에 대해 분석해주세요.
        아래 JSON 형식으로만 답해주세요.
        {
          "summary": "학교 개요 한 줄 요약",
          "strengths": ["장점"],
          "improvements": ["개선점 또는 확인할 점"],
          "studyTips": ["이 학교 학생에게 추천하는 공부법"],
          "notes": ["참고할 만한 정보"]
        }

        한국어로, 중학생이 이해하기 쉽게 작성해주세요.
        """

        if let result = await AIService.shared.askGroqJSON(prompt: prompt, as: SchoolAIDiagnosis.self) {
            aiDiagnosis = result
        } else {
            aiDiagnosis = SchoolAIDiagnosis(summary: "AI 분석에 실패했습니다. 나중에 다시 시도해주세요.", strengths: [], improvements: [], studyTips: [], notes: [])
        }
    }

    private func resetAll() {
        basicInfo = nil; stats = nil; genderStats = nil; teacherStats = nil
        clubs = []; uniforms = []; afterSchool = []; library = nil
        classDetails = []; classDays = []; transferStats = nil
        schulCode = nil; aiDiagnosis = nil; errorMessage = nil
    }

    private func isMatchingSchoolName(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = lhs.replacingOccurrences(of: " ", with: "")
        let normalizedRHS = rhs.replacingOccurrences(of: " ", with: "")
        return normalizedLHS == normalizedRHS
    }
}
