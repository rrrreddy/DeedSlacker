import Foundation

/// A curated IANA-identifier → coordinate lookup for weather fetching.
/// `TimeZone` itself carries no location data, so this fills that gap for
/// the ~60 most commonly tracked cities. Anything not in this table simply
/// won't show weather — it still works fully as a clock.
enum CityCoordinates {
    static let table: [String: (latitude: Double, longitude: Double)] = [
        "America/New_York": (40.7128, -74.0060),
        "America/Chicago": (41.8781, -87.6298),
        "America/Denver": (39.7392, -104.9903),
        "America/Phoenix": (33.4484, -112.0740),
        "America/Los_Angeles": (34.0522, -118.2437),
        "America/Anchorage": (61.2181, -149.9003),
        "Pacific/Honolulu": (21.3069, -157.8583),
        "America/Toronto": (43.6532, -79.3832),
        "America/Vancouver": (49.2827, -123.1207),
        "America/Mexico_City": (19.4326, -99.1332),
        "America/Sao_Paulo": (-23.5505, -46.6333),
        "America/Argentina/Buenos_Aires": (-34.6037, -58.3816),
        "America/Bogota": (4.7110, -74.0721),
        "Europe/London": (51.5072, -0.1276),
        "Europe/Dublin": (53.3498, -6.2603),
        "Europe/Paris": (48.8566, 2.3522),
        "Europe/Berlin": (52.5200, 13.4050),
        "Europe/Madrid": (40.4168, -3.7038),
        "Europe/Rome": (41.9028, 12.4964),
        "Europe/Amsterdam": (52.3676, 4.9041),
        "Europe/Zurich": (47.3769, 8.5417),
        "Europe/Stockholm": (59.3293, 18.0686),
        "Europe/Moscow": (55.7558, 37.6173),
        "Europe/Istanbul": (41.0082, 28.9784),
        "Europe/Athens": (37.9838, 23.7275),
        "Africa/Cairo": (30.0444, 31.2357),
        "Africa/Johannesburg": (-26.2041, 28.0473),
        "Africa/Lagos": (6.5244, 3.3792),
        "Africa/Nairobi": (-1.2921, 36.8219),
        "Asia/Dubai": (25.2048, 55.2708),
        "Asia/Riyadh": (24.7136, 46.6753),
        "Asia/Jerusalem": (31.7683, 35.2137),
        "Asia/Karachi": (24.8607, 67.0011),
        "Asia/Kolkata": (28.6139, 77.2090),
        "Asia/Dhaka": (23.8103, 90.4125),
        "Asia/Bangkok": (13.7563, 100.5018),
        "Asia/Jakarta": (-6.2088, 106.8456),
        "Asia/Singapore": (1.3521, 103.8198),
        "Asia/Kuala_Lumpur": (3.1390, 101.6869),
        "Asia/Manila": (14.5995, 120.9842),
        "Asia/Hong_Kong": (22.3193, 114.1694),
        "Asia/Shanghai": (31.2304, 121.4737),
        "Asia/Seoul": (37.5665, 126.9780),
        "Asia/Tokyo": (35.6762, 139.6503),
        "Australia/Perth": (-31.9505, 115.8605),
        "Australia/Adelaide": (-34.9285, 138.6007),
        "Australia/Sydney": (-33.8688, 151.2093),
        "Australia/Melbourne": (-37.8136, 144.9631),
        "Australia/Brisbane": (-27.4698, 153.0251),
        "Pacific/Auckland": (-36.8485, 174.7633),
        "Pacific/Fiji": (-18.1416, 178.4419)
    ]

    static func coordinates(forIdentifier identifier: String) -> (latitude: Double, longitude: Double)? {
        table[identifier]
    }
}
