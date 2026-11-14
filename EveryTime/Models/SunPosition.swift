import Foundation

/// Where the sun is overhead, and which side of the day/night line a place is on (NOAA low-precision formulas).
struct SunPosition: Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(at date: Date) {
        let seconds = date.timeIntervalSince1970
        let d = seconds / 86400 - 10957.5
        let g = (357.529 + 0.98560028 * d) * .pi / 180
        let q = 280.459 + 0.98564736 * d
        let l = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)) * .pi / 180
        let e = (23.439 - 0.00000036 * d) * .pi / 180
        let ra = atan2(cos(e) * sin(l), cos(l)) * 180 / .pi
        let equationOfTime = remainder(q - ra, 360) * 4
        let utcMinutes = seconds.truncatingRemainder(dividingBy: 86400) / 60
        latitude = asin(sin(e) * sin(l)) * 180 / .pi
        longitude = remainder(-(utcMinutes + equationOfTime - 720) / 4, 360)
    }

    /// Sine of the sun's height above the horizon: above 0 is day.
    func height(latitude lat: Double, longitude lon: Double) -> Double {
        let r = Double.pi / 180
        return sin(lat * r) * sin(latitude * r) + cos(lat * r) * cos(latitude * r) * cos((lon - longitude) * r)
    }

    /// Latitude of the day/night line at `lon`.
    func terminator(longitude lon: Double) -> Double {
        let r = Double.pi / 180
        let declination = (abs(latitude) < 0.1 ? 0.1 : latitude) * r
        return atan(-cos((lon - longitude) * r) / tan(declination)) / r
    }
}
