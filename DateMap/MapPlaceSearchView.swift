import SwiftUI

/// 지도 탭의 검색 — 외부 검색이 아니라 내가 기록·계획한 장소 안에서만 찾는다.
/// 한 글자 입력할 때마다 바로 결과가 갱신된다.
struct MapPlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss

    /// 기록과 계획에 담긴 모든 장소
    let places: [DatePlace]
    let onSelect: (DatePlace) -> Void

    @State private var query = ""

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredPlaces: [DatePlace] {
        let sorted = places.sorted {
            ($0.history?.date ?? .distantPast) >
                ($1.history?.date ?? .distantPast)
        }

        guard !cleanQuery.isEmpty else {
            return sorted
        }

        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(cleanQuery) ||
                $0.address.localizedCaseInsensitiveContains(cleanQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if filteredPlaces.isEmpty {
                    Spacer()

                    ContentUnavailableView(
                        cleanQuery.isEmpty
                            ? "저장된 장소가 없습니다"
                            : "일치하는 장소가 없습니다",
                        systemImage: "mappin.slash",
                        description: Text(
                            cleanQuery.isEmpty
                                ? "데이트 기록이나 계획에 장소를 추가하면 여기에서 찾을 수 있어요."
                                : "다녀왔거나 계획에 담아둔 장소 중에서만 검색됩니다."
                        )
                    )

                    Spacer()
                } else {
                    List {
                        ForEach(filteredPlaces) { place in
                            Button {
                                onSelect(place)
                                dismiss()
                            } label: {
                                placeRow(place)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedTheme.cardBackgroundColor)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(selectedTheme.backgroundColor)
            .navigationTitle("내 장소 검색")
            .navigationBarTitleDisplayMode(.inline)
            .tint(selectedTheme.primaryColor)
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
                "방문했거나 계획한 장소 이름",
                text: $query
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private func placeRow(_ place: DatePlace) -> some View {
        HStack(spacing: 12) {
            Text(place.categoryEmoji)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(selectedTheme.primaryColor.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.pretendard(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let history = place.history {
                        if history.type == .plan {
                            Text(DateDisplayFormatter.string(from: history.date))
                                .font(.pretendard(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)

                            Text("계획")
                                .font(.pretendard(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.16))
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 6,
                                        style: .continuous
                                    )
                                )
                        } else {
                            Text(
                                "\(DateDisplayFormatter.string(from: history.date)) 방문"
                            )
                            .font(.pretendard(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
