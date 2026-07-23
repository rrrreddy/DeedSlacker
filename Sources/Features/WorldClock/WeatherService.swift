import Foundation

struct WeatherSnapshot: Equatable {
    let temperatureCelsius: Double
    let symbolName: String
    let description: String

    var temperatureFahrenheit: Double { temperatureCelsius * 9 / 5 + 32 }
}

/// Fetches current weather from Open-Meteo — a free, keyless public API,
/// which is what makes this usable today. Apple's own WeatherKit would be
/// the more natural fit long-term, but it's gated behind the same paid
/// Apple Developer Program membership blocking CloudKit right now.
enum WeatherService {
    private static var cache: [String: (snapshot: WeatherSnapshot, fetchedAt: Date)] = [:]
    private static let cacheLifetime: TimeInterval = 15 * 60

    static func fetch(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        let cacheKey = "\(latitude),\(longitude)"
        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.snapshot
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let (symbol, description) = mapWeatherCode(response.current.weatherCode)
            let snapshot = WeatherSnapshot(
                temperatureCelsius: response.current.temperature2m,
                symbolName: symbol,
                description: description
            )
            cache[cacheKey] = (snapshot, Date())
            return snapshot
        } catch {
            return nil
        }
    }

    private static func mapWeatherCode(_ code: Int) -> (symbol: String, description: String) {
        switch code {
        case 0: return ("sun.max.fill", "Clear")
        case 1, 2: return ("cloud.sun.fill", "Partly Cloudy")
        case 3: return ("cloud.fill", "Overcast")
        case 45, 48: return ("cloud.fog.fill", "Foggy")
        case 51, 53, 55: return ("cloud.drizzle.fill", "Drizzle")
        case 56, 57: return ("cloud.sleet.fill", "Freezing Drizzle")
        case 61, 63, 65: return ("cloud.rain.fill", "Rain")
        case 66, 67: return ("cloud.sleet.fill", "Freezing Rain")
        case 71, 73, 75, 77: return ("cloud.snow.fill", "Snow")
        case 80, 81, 82: return ("cloud.heavyrain.fill", "Showers")
        case 85, 86: return ("cloud.snow.fill", "Snow Showers")
        case 95, 96, 99: return ("cloud.bolt.rain.fill", "Thunderstorm")
        default: return ("cloud.fill", "—")
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }
    let current: Current
}
