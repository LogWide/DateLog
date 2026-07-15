import SwiftUI

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (PlaceSearchResult) -> Void

    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 본인의 Cloudflare Worker 주소
    private let workerBaseURL =
        "https://datelog-place-search.k2mkj.workers.dev"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if isLoading {
                    Spacer()

                    ProgressView("검색 중...")
                    Spacer()
                } else if let errorMessage {
                    Spacer()

                    ContentUnavailableView(
                        "검색할 수 없습니다",
                        systemImage: "exclamationmark.magnifyingglass",
                        description: Text(errorMessage)
                    )

                    Spacer()
                } else if results.isEmpty {
                    Spacer()

                    ContentUnavailableView(
                        "장소 검색",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "카페, 식당, 공원 등의 이름을 검색하세요."
                        )
                    )

                    Spacer()
                } else {
                    List(results) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            PlaceSearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("장소 검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "예: 서울숲, 스타벅스 성수",
                text: $query
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit {
                Task {
                    await searchPlaces()
                }
            }

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button("검색") {
                Task {
                    await searchPlaces()
                }
            }
            .disabled(cleanQuery.isEmpty || isLoading)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var cleanQuery: String {
        query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    @MainActor
    private func searchPlaces() async {
        guard !cleanQuery.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        guard
            var components = URLComponents(
                string: "\(workerBaseURL)/search"
            )
        else {
            errorMessage = "검색 주소를 만들 수 없습니다."
            return
        }

        components.queryItems = [
            URLQueryItem(
                name: "query",
                value: cleanQuery
            )
        ]

        guard let url = components.url else {
            errorMessage = "검색 주소가 올바르지 않습니다."
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(
                from: url
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "서버 응답을 확인할 수 없습니다."
                return
            }

            guard 200...299 ~= httpResponse.statusCode else {
                errorMessage =
                    "검색 서버 오류가 발생했습니다. 코드: \(httpResponse.statusCode)"
                return
            }

            let decoded = try JSONDecoder().decode(
                PlaceSearchResponse.self,
                from: data
            )

            results = decoded.items

            if decoded.items.isEmpty {
                errorMessage = "검색 결과가 없습니다."
            }
        } catch {
            errorMessage = "검색 중 오류가 발생했습니다.\n\(error.localizedDescription)"
        }
    }
}

private struct PlaceSearchResultRow: View {
    let result: PlaceSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.cleanTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            if !result.category.isEmpty {
                Text(result.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.displayAddress)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }
}

// MARK: - 네이버 검색 응답

struct PlaceSearchResponse: Decodable {
    let items: [PlaceSearchResult]
}

struct PlaceSearchResult: Decodable, Identifiable {
    let title: String
    let category: String
    let address: String
    let roadAddress: String
    let mapx: String
    let mapy: String

    var id: String {
        "\(mapx)-\(mapy)-\(title)"
    }

    var cleanTitle: String {
        title.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
    }

    var displayAddress: String {
        if !roadAddress.isEmpty {
            return roadAddress
        }

        return address
    }

    var longitude: Double? {
        guard let value = Double(mapx) else {
            return nil
        }

        return value / 10_000_000
    }

    var latitude: Double? {
        guard let value = Double(mapy) else {
            return nil
        }

        return value / 10_000_000
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case category
        case address
        case roadAddress
        case mapx
        case mapy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        title = try container.decodeIfPresent(
            String.self,
            forKey: .title
        ) ?? ""

        category = try container.decodeIfPresent(
            String.self,
            forKey: .category
        ) ?? ""

        address = try container.decodeIfPresent(
            String.self,
            forKey: .address
        ) ?? ""

        roadAddress = try container.decodeIfPresent(
            String.self,
            forKey: .roadAddress
        ) ?? ""

        mapx = Self.decodeStringOrInteger(
            from: container,
            key: .mapx
        )

        mapy = Self.decodeStringOrInteger(
            from: container,
            key: .mapy
        )
    }

    private static func decodeStringOrInteger(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String {
        if let stringValue = try? container.decode(
            String.self,
            forKey: key
        ) {
            return stringValue
        }

        if let integerValue = try? container.decode(
            Int.self,
            forKey: key
        ) {
            return String(integerValue)
        }

        return ""
    }
}
