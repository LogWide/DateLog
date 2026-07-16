//
//  PlaceSearchService.swift
//  DateMap
//
//  Created by 김기중 on 7/16/26.
//

import Foundation

enum PlaceSearchService {
    private static let workerBaseURL =
        "https://datelog-place-search.k2mkj.workers.dev"

    static func search(
        query: String
    ) async throws -> [PlaceSearchResult] {
        let cleanQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanQuery.isEmpty else {
            return []
        }

        guard
            var components = URLComponents(
                string: "\(workerBaseURL)/search"
            )
        else {
            throw PlaceSearchError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(
                name: "query",
                value: cleanQuery
            )
        ]

        guard let url = components.url else {
            throw PlaceSearchError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaceSearchError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw PlaceSearchError.serverError(
                statusCode: httpResponse.statusCode
            )
        }

        let decoded = try JSONDecoder().decode(
            PlaceSearchResponse.self,
            from: data
        )

        return decoded.items
    }
}

enum PlaceSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "검색 주소를 만들 수 없습니다."

        case .invalidResponse:
            return "검색 서버 응답을 확인할 수 없습니다."

        case .serverError(let statusCode):
            return "검색 서버 오류가 발생했습니다. 코드: \(statusCode)"
        }
    }
}
