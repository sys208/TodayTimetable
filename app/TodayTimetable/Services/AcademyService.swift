import CoreLocation
import FirebaseFunctions
import Foundation

actor AcademyService {
    static let shared = AcademyService()

    private let functions = Functions.functions(region: "asia-northeast3")
    private let geocoder = CLGeocoder()
    private var coordinateCache: [String: CLLocationCoordinate2D] = [:]

    func searchAcademies(
        educationOfficeCode: String,
        administrativeZone: String?,
        query: String,
        page: Int = 1,
        pageSize: Int = 100
    ) async throws -> [Academy] {
        let result = try await functions.httpsCallable("searchAcademies").call([
            "educationOfficeCode": educationOfficeCode,
            "administrativeZone": administrativeZone ?? "",
            "query": query,
            "page": page,
            "pageSize": pageSize,
        ] as [String: Any])

        guard let data = result.data as? [String: Any],
              let rows = data["academies"] as? [[String: Any]]
        else { return [] }

        return rows.map(Self.parseAcademy)
    }

    func geocode(_ academies: [Academy], limit: Int = 100) async -> [Academy] {
        var result: [Academy] = []
        result.reserveCapacity(academies.count)

        for academy in academies {
            guard result.count < limit else {
                result.append(academy)
                continue
            }

            var academy = academy
            let address = academy.roadAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            if !address.isEmpty {
                if let cached = coordinateCache[address] {
                    academy.latitude = cached.latitude
                    academy.longitude = cached.longitude
                } else if let coordinate = try? await geocodeAddress(address) {
                    coordinateCache[address] = coordinate
                    academy.latitude = coordinate.latitude
                    academy.longitude = coordinate.longitude
                    try? await saveCoordinate(academyNumber: academy.id, coordinate: coordinate)
                }
            }
            result.append(academy)
        }

        return result
    }

    func nearestAcademies(
        _ academies: [Academy],
        from coordinate: CLLocationCoordinate2D?,
        limit: Int = 100
    ) -> [Academy] {
        guard let coordinate else { return Array(academies.prefix(limit)) }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return academies
            .sorted { lhs, rhs in
                distance(from: origin, to: lhs) < distance(from: origin, to: rhs)
            }
            .prefix(limit)
            .map { $0 }
    }

    func administrativeZone(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return try? await reverseGeocodeZone(location)
    }

    func saveCoordinate(academyNumber: String, coordinate: CLLocationCoordinate2D) async throws {
        _ = try await functions.httpsCallable("saveAcademyCoordinate").call([
            "academyNumber": academyNumber,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
        ])
    }

    func toggleSaved(academy: Academy, saved: Bool) async throws {
        _ = try await functions.httpsCallable("toggleSavedAcademy").call([
            "userId": AcademyUserID.current,
            "academyNumber": academy.id,
            "saved": saved,
        ] as [String: Any])
    }

    func vote(tag: String, for academy: Academy) async throws -> [String: Int] {
        let result = try await functions.httpsCallable("voteAcademyTag").call([
            "userId": AcademyUserID.current,
            "academyNumber": academy.id,
            "tag": tag,
        ])

        guard let data = result.data as? [String: Any],
              let tags = data["tags"] as? [String: Any]
        else { return [:] }

        return tags.reduce(into: [:]) { result, item in
            if let value = item.value as? Int {
                result[item.key] = value
            } else if let value = item.value as? NSNumber {
                result[item.key] = value.intValue
            }
        }
    }

    func saveSchedule(_ schedule: AcademySchedule) async throws {
        _ = try await functions.httpsCallable("saveAcademySchedule").call([
            "userId": AcademyUserID.current,
            "schedule": [
                "id": schedule.id.uuidString,
                "academyNumber": schedule.academyNumber,
                "academyName": schedule.academyName,
                "weekday": schedule.weekday,
                "startTime": schedule.startTime.timeIntervalSince1970,
                "endTime": schedule.endTime.timeIntervalSince1970,
                "memo": schedule.memo,
            ],
        ] as [String: Any])
    }

    func getUserData() async throws -> (savedIDs: Set<String>, schedules: [AcademySchedule]) {
        let result = try await functions.httpsCallable("getUserAcademyData").call([
            "userId": AcademyUserID.current,
        ])
        guard let data = result.data as? [String: Any] else { return ([], []) }

        let savedIDs = Set(data["savedAcademyIDs"] as? [String] ?? [])
        let schedules = (data["schedules"] as? [[String: Any]] ?? []).compactMap(Self.parseSchedule)
        return (savedIDs, schedules)
    }

    private func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D? {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    private func reverseGeocodeZone(_ location: CLLocation) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let place = placemarks?.first
                continuation.resume(returning: place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea)
            }
        }
    }

    private func distance(from origin: CLLocation, to academy: Academy) -> CLLocationDistance {
        guard let coordinate = academy.coordinate else { return .greatestFiniteMagnitude }
        return origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private static func parseAcademy(_ row: [String: Any]) -> Academy {
        Academy(
            educationOfficeCode: string(row["educationOfficeCode"], row["ATPT_OFCDC_SC_CODE"]),
            educationOfficeName: string(row["educationOfficeName"], row["ATPT_OFCDC_SC_NM"]),
            administrativeZoneName: string(row["administrativeZoneName"], row["ADMST_ZONE_NM"]),
            academyInstituteTypeName: string(row["academyInstituteTypeName"], row["ACA_INSTI_SC_NM"]),
            academyNumber: string(row["academyNumber"], row["ACA_ASNUM"]),
            name: string(row["name"], row["ACA_NM"]),
            establishedDate: string(row["establishedDate"], row["ESTBL_YMD"]),
            registeredDate: string(row["registeredDate"], row["REG_YMD"]),
            registrationStatusName: string(row["registrationStatusName"], row["REG_STTUS_NM"]),
            closureBeginDate: string(row["closureBeginDate"], row["CAA_BEGIN_YMD"]),
            closureEndDate: string(row["closureEndDate"], row["CAA_END_YMD"]),
            totalCapacity: int(row["totalCapacity"], row["TOFOR_SMTOT"]),
            temporaryCapacity: int(row["temporaryCapacity"], row["DTM_RCPTN_ABLTY_NMPR_SMTOT"]),
            fieldName: string(row["fieldName"], row["REALM_SC_NM"]),
            teachingOrderName: string(row["teachingOrderName"], row["LE_ORD_NM"]),
            courseListName: string(row["courseListName"], row["LE_CRSE_LIST_NM"]),
            courseName: string(row["courseName"], row["LE_CRSE_NM"]),
            tuitionContent: string(row["tuitionContent"], row["PSNBY_THCC_CNTNT"]),
            tuitionPublic: string(row["tuitionPublic"], row["THCC_OTHBC_YN"]),
            dormitoryAcademy: string(row["dormitoryAcademy"], row["BRHS_ACA_YN"]),
            roadAddress: string(row["roadAddress"], row["FA_RDNMA"]),
            roadDetailAddress: string(row["roadDetailAddress"], row["FA_RDNDA"]),
            roadPostalCode: string(row["roadPostalCode"], row["FA_RDNZC"]),
            phoneNumber: string(row["phoneNumber"], row["FA_TELNO"]),
            updatedAt: string(row["updatedAt"], row["LOAD_DTM"]),
            latitude: double(row["latitude"]),
            longitude: double(row["longitude"])
        )
    }

    private static func parseSchedule(_ row: [String: Any]) -> AcademySchedule? {
        guard let academyNumber = stringValue(row["academyNumber"]),
              let academyName = stringValue(row["academyName"])
        else { return nil }

        let id = stringValue(row["id"]).flatMap(UUID.init(uuidString:)) ?? UUID()
        let weekday = int(row["weekday"])
        let startTime = date(row["startTime"])
        let endTime = date(row["endTime"])
        return AcademySchedule(
            id: id,
            academyNumber: academyNumber,
            academyName: academyName,
            weekday: weekday,
            startTime: startTime,
            endTime: endTime,
            memo: string(row["memo"])
        )
    }

    private static func string(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func string(_ values: Any?...) -> String {
        for value in values {
            let text = string(value)
            if !text.isEmpty { return text }
        }
        return ""
    }

    private static func int(_ value: Any?) -> Int {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        return Int(string(value).replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private static func int(_ values: Any?...) -> Int {
        for value in values {
            let number = int(value)
            if number != 0 { return number }
        }
        return 0
    }

    private static func double(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func date(_ value: Any?) -> Date {
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        if let double = value as? Double { return Date(timeIntervalSince1970: double) }
        if let string = value as? String, let double = Double(string) { return Date(timeIntervalSince1970: double) }
        return Date()
    }

    private static func stringValue(_ value: Any?) -> String? {
        let value = string(value)
        return value.isEmpty ? nil : value
    }
}

enum AcademyStore {
    private static let savedKey = "savedAcademyIDs"
    private static let tagKey = "academyTagVotes"
    private static let scheduleKey = "academySchedules"

    static let reviewTags = ["설명 잘함", "시험대비 좋음", "숙제 많음", "질문 잘 받아줌", "분위기 조용함", "내신형", "선행형", "예체능 특화"]

    static func savedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: savedKey) ?? [])
    }

    static func isSaved(_ academy: Academy) -> Bool {
        savedIDs().contains(academy.id)
    }

    static func toggleSaved(_ academy: Academy) {
        var ids = savedIDs()
        let shouldSave: Bool
        if ids.contains(academy.id) {
            ids.remove(academy.id)
            shouldSave = false
        } else {
            ids.insert(academy.id)
            shouldSave = true
        }
        UserDefaults.standard.set(Array(ids), forKey: savedKey)
        Task {
            try? await AcademyService.shared.toggleSaved(academy: academy, saved: shouldSave)
        }
    }

    static func tagVotes(for academy: Academy) -> [String: Int] {
        let all = allTagVotes()
        return all[academy.id] ?? [:]
    }

    static func vote(tag: String, for academy: Academy) {
        var all = allTagVotes()
        var votes = all[academy.id] ?? [:]
        votes[tag, default: 0] += 1
        all[academy.id] = votes
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: tagKey)
        }
        Task {
            if let serverVotes = try? await AcademyService.shared.vote(tag: tag, for: academy) {
                var all = allTagVotes()
                all[academy.id] = serverVotes
                if let data = try? JSONEncoder().encode(all) {
                    UserDefaults.standard.set(data, forKey: tagKey)
                }
            }
        }
    }

    static func schedules() -> [AcademySchedule] {
        guard let data = UserDefaults.standard.data(forKey: scheduleKey),
              let decoded = try? JSONDecoder().decode([AcademySchedule].self, from: data)
        else { return [] }
        return decoded
    }

    static func addSchedule(_ schedule: AcademySchedule) {
        var schedules = schedules()
        schedules.append(schedule)
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: scheduleKey)
        }
        Task {
            try? await AcademyService.shared.saveSchedule(schedule)
        }
    }

    static func schedules(for academy: Academy) -> [AcademySchedule] {
        schedules().filter { $0.academyNumber == academy.id }
    }

    private static func allTagVotes() -> [String: [String: Int]] {
        guard let data = UserDefaults.standard.data(forKey: tagKey),
              let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data)
        else { return [:] }
        return decoded
    }

    static func syncFromFirestore() async {
        guard let data = try? await AcademyService.shared.getUserData() else { return }
        UserDefaults.standard.set(Array(data.savedIDs), forKey: savedKey)
        if let encoded = try? JSONEncoder().encode(data.schedules) {
            UserDefaults.standard.set(encoded, forKey: scheduleKey)
        }
    }
}

enum AcademyUserID {
    private static let key = "academyUserId"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}
