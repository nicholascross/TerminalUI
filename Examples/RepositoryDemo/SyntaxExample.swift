enum SyntaxExample: String, CaseIterable {
    case swift, python, json

    var title: String {
        switch self {
        case .swift: "Swift"
        case .python: "Python"
        case .json: "JSON"
        }
    }

    var source: String {
        switch self {
        case .swift:
            """
            struct Reading {
                let city: String
                let temperature: Double
            }

            // Keep only comfortable readings.
            func comfortable(_ readings: [Reading]) -> [String] {
                readings
                    .filter { $0.temperature >= 18 && $0.temperature <= 25 }
                    .map { "\\($0.city): \\($0.temperature)°C" }
            }

            let readings = [Reading(city: "Melbourne", temperature: 21.5)]
            print(comfortable(readings))
            """
        case .python:
            """
            from dataclasses import dataclass

            @dataclass
            class Reading:
                city: str
                temperature: float

            def comfortable(readings: list[Reading]) -> list[str]:
                # Keep only comfortable readings.
                return [
                    f"{item.city}: {item.temperature}°C"
                    for item in readings
                    if 18 <= item.temperature <= 25
                ]

            readings = [Reading("Melbourne", 21.5)]
            print(comfortable(readings))
            """
        case .json:
            """
            {
              "station": "Melbourne",
              "active": true,
              "readings": [
                { "time": "09:00", "temperature": 18.5 },
                { "time": "12:00", "temperature": 21.5 },
                { "time": "15:00", "temperature": 24.0 }
              ],
              "units": {
                "temperature": "Celsius",
                "wind": "km/h"
              },
              "lastError": null
            }
            """
        }
    }
}
