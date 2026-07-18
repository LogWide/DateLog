
//
//  RouteService.swift
//  DateMap
//
//  Created by 김기중 on 7/16/26.
//


import Foundation

struct RouteCoordinate: Hashable {
    let latitude: Double
    let longitude: Double
}

struct DrivingRouteSummary: Decodable {
    let distance: Int
    let duration: Int
    let tollFare: Int
    let fuelPrice: Int
    let path: [[Double]]

    var distanceKilometers: Double {
        Double(distance) / 1_000
    }

    var durationMinutes: Int {
        Int((Double(duration) / 60_000).rounded())
    }

    var routeCoordinates: [RouteCoordinate] {
        path.compactMap { coordinate in
            guard coordinate.count >= 2 else {
                return nil
            }

            return RouteCoordinate(
                latitude: coordinate[1],
                longitude: coordinate[0]
            )
        }
    }
}

enum RouteService {
    private static let workerBaseURL =
        "https://datelog-place-search.k2mkj.workers.dev"

    static func route(
        startLatitude: Double,
        startLongitude: Double,
        goalLatitude: Double,
        goalLongitude: Double
    ) async throws -> DrivingRouteSummary {
        guard
            var components = URLComponents(
                string: "\(workerBaseURL)/route"
            )
        else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(
                name: "start",
                value: "\(startLongitude),\(startLatitude)"
            ),
            URLQueryItem(
                name: "goal",
                value: "\(goalLongitude),\(goalLatitude)"
            )
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(
            DrivingRouteSummary.self,
            from: data
        )
    }
}
