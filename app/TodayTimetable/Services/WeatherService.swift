import CoreLocation
import Foundation

/// 기상청 단기예보 API 기반 날씨 서비스 (WeatherKit 대체)
actor WeatherService {
    static let shared = WeatherService()

    struct WeatherData: Sendable {
        let temperature: Double
        let highTemperature: Double
        let lowTemperature: Double
        let conditionSymbol: String    // SF Symbol
        let conditionDescription: String
    }

    private var cachedWeather: WeatherData?
    private var lastFetchDate: Date?
    private let cacheDuration: TimeInterval = 1800 // 30분

    // 기상청 API 키 (data.go.kr)
    private let apiKey = "" // TODO: 기상청 API 키 입력

    func getCurrentWeather(location: CLLocation) async throws -> WeatherData {
        if let cached = cachedWeather,
           let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            return cached
        }

        // 기상청 API 키 없으면 OpenMeteo 무료 API 사용 (키 불필요!)
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,apparent_temperature,weather_code&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max&timezone=Asia/Seoul&forecast_days=1") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let daily = json["daily"] as? [String: Any]
        else { throw URLError(.cannotParseResponse) }

        let temp = (current["temperature_2m"] as? Double) ?? 0
        let apparentTemp = (current["apparent_temperature"] as? Double) ?? temp
        let weatherCode = (current["weather_code"] as? Int) ?? 0
        let maxTemps = (daily["temperature_2m_max"] as? [Double]) ?? []
        let minTemps = (daily["temperature_2m_min"] as? [Double]) ?? []
        // 실제 기온과 체감 기온 중 높은 값 사용 (네이버 날씨와 유사하게)
        let displayTemp = max(temp, apparentTemp)

        let (symbol, desc) = weatherCodeToInfo(weatherCode)

        let weatherData = WeatherData(
            temperature: displayTemp,
            highTemperature: maxTemps.first ?? temp,
            lowTemperature: minTemps.first ?? temp,
            conditionSymbol: symbol,
            conditionDescription: desc
        )

        cachedWeather = weatherData
        lastFetchDate = Date()
        return weatherData
    }

    /// 오늘 비/눈 오는지 확인 (hourly forecast)
    func willRainToday(location: CLLocation) async -> Bool {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&hourly=weather_code&timezone=Asia/Seoul&forecast_days=1") else { return false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hourly = json["hourly"] as? [String: Any],
                  let codes = hourly["weather_code"] as? [Int]
            else { return false }

            // 7시~19시 (등하교 시간대) 중 비/눈 코드가 있는지
            let schoolHours = Array(codes.dropFirst(7).prefix(12))
            let rainCodes = Set([51, 53, 55, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99])
            return schoolHours.contains(where: { rainCodes.contains($0) })
        } catch {
            return false
        }
    }

    private func weatherCodeToInfo(_ code: Int) -> (String, String) {
        switch code {
        case 0: return ("sun.max.fill", "맑음")
        case 1: return ("sun.max.fill", "대체로 맑음")
        case 2: return ("cloud.sun.fill", "구름 조금")
        case 3: return ("cloud.fill", "흐림")
        case 45, 48: return ("cloud.fog.fill", "안개")
        case 51, 53, 55: return ("cloud.drizzle.fill", "이슬비")
        case 61, 63, 65: return ("cloud.rain.fill", "비")
        case 66, 67: return ("cloud.sleet.fill", "진눈깨비")
        case 71, 73, 75: return ("cloud.snow.fill", "눈")
        case 77: return ("cloud.snow.fill", "싸락눈")
        case 80, 81, 82: return ("cloud.heavyrain.fill", "소나기")
        case 85, 86: return ("cloud.snow.fill", "폭설")
        case 95: return ("cloud.bolt.fill", "천둥번개")
        case 96, 99: return ("cloud.bolt.rain.fill", "우박")
        default: return ("sun.max.fill", "맑음")
        }
    }
}
