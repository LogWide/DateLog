//
//  AddPlaceView.swift
//  DateMap
//
//  Created by 김기중 on 7/16/26.
//


import SwiftUI
import SwiftData

private struct SavedPlaceCategory: Codable, Hashable, Identifiable {
    var name: String
    var emoji: String

    var id: String {
        "\(emoji)-\(name)"
    }
}

struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wish.createdAt, order: .reverse)
    private var wishes: [Wish]

    let history: DateHistory

    @State private var name = ""
    @State private var memo = ""

    @State private var categoryName = "식당"
    @State private var categoryEmoji = "🍽️"

    @State private var isShowingCustomCategory = false
    @State private var customCategoryName = ""
    @State private var customCategoryEmoji = "✨"
    @State private var savedCustomCategories: [SavedPlaceCategory] = []
    @State private var isShowingCategoryManager = false

    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var selectedAddress = ""

    @State private var searchResults: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var searchErrorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var isShowingMapPinPicker = false
    @State private var isShowingWishPicker = false
    @State private var directPlaceName = ""
    @State private var selectedWish: Wish?

    @State private var shouldSkipNextSearch = false

    private var availableWishes: [Wish] {
        wishes.filter { !$0.isVisited }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("장소") {
                    TextField(
                        "장소 이름을 입력하세요",
                        text: $name
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _, newValue in
                        handleNameChange(newValue)
                    }

                    Button {
                        isShowingWishPicker = true
                    } label: {
                        Label(
                            "위시리스트에서 가져오기",
                            systemImage: "plus.circle"
                        )
                    }
                    .disabled(availableWishes.isEmpty)

                    if !cleanName.isEmpty {
                        Button {
                            searchTask?.cancel()
                            directPlaceName = cleanName
                            isShowingMapPinPicker = true
                        } label: {
                            Label {
                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    Text(
                                        "‘\(cleanName)’으로 직접 추가"
                                    )
                                    .foregroundStyle(.primary)

                                    Text(
                                        "지도에서 위치를 직접 선택합니다."
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(
                                    systemName: "mappin.and.ellipse"
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if isSearching {
                        HStack {
                            Spacer()

                            ProgressView("검색 중...")

                            Spacer()
                        }
                    }

                    ForEach(searchResults) { result in
                        Button {
                            selectSearchResult(result)
                        } label: {
                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {
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
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }

                    if let searchErrorMessage {
                        Text(searchErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("카테고리") {
                    Picker("기본 카테고리", selection: $categoryName) {
                        Text("🍽️ 식당").tag("식당")
                        Text("☕ 카페").tag("카페")
                        Text("🍺 술").tag("술")
                        Text("🎬 영화").tag("영화")
                        Text("🛍️ 쇼핑").tag("쇼핑")
                        Text("🌳 산책").tag("산책")
                        Text("🏨 숙소").tag("숙소")
                        Text("🚗 드라이브").tag("드라이브")

                        ForEach(savedCustomCategories) { category in
                            Text("\(category.emoji) \(category.name)")
                                .tag(category.name)
                        }

                        Text("⭐ 직접 입력").tag("__custom__")
                    }
                    .onChange(of: categoryName) { _, newValue in
                        isShowingCustomCategory = (newValue == "__custom__")
                        if !isShowingCustomCategory {
                            categoryEmoji = emoji(for: newValue)
                        }
                    }

                    if !savedCustomCategories.isEmpty {
                        Button {
                            isShowingCategoryManager = true
                        } label: {
                            Label(
                                "사용자 카테고리 관리",
                                systemImage: "slider.horizontal.3"
                            )
                        }
                    }

                    if isShowingCustomCategory {
                        TextField("이모지", text: $customCategoryEmoji)
                        TextField("카테고리명", text: $customCategoryName)
                    }
                }

                Section("메모") {
                    TextField(
                        "메모",
                        text: $memo,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                if latitude != nil && longitude != nil {
                    Section("선택된 위치") {
                        if !selectedAddress.isEmpty {
                            Text(selectedAddress)
                                .font(.subheadline)
                        } else {
                            Text("지도에서 위치를 선택했습니다.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("장소 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("취소") {
                        searchTask?.cancel()
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("저장") {
                        savePlace()
                    }
                    .disabled(
                        cleanName.isEmpty ||
                        latitude == nil ||
                        longitude == nil
                    )
                }
            }
            .sheet(
                isPresented: $isShowingMapPinPicker
            ) {
                MapPinPickerView(
                    placeName: directPlaceName
                ) { coordinate in
                    shouldSkipNextSearch = true
                    name = directPlaceName
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                    selectedAddress = ""
                    searchResults = []
                    searchErrorMessage = nil
                }
            }
            .sheet(isPresented: $isShowingWishPicker) {
                WishPlaceSelectionView(wishes: availableWishes) { wish in
                    selectWish(wish)
                    isShowingWishPicker = false
                }
            }
            .sheet(isPresented: $isShowingCategoryManager) {
                SavedCategoryManagerView(
                    categories: $savedCustomCategories
                ) {
                    persistCustomCategories()
                }
            }
            .onAppear {
                loadCustomCategories()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private var cleanName: String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var cleanMemo: String {
        memo.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func handleNameChange(
        _ newValue: String
    ) {
        searchTask?.cancel()

        if shouldSkipNextSearch {
            shouldSkipNextSearch = false
            return
        }

        latitude = nil
        longitude = nil
        selectedAddress = ""
        searchErrorMessage = nil

        let trimmedName = newValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedName.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(
                for: .milliseconds(400)
            )

            guard !Task.isCancelled else {
                return
            }

            await searchPlaces(
                query: trimmedName
            )
        }
    }

    @MainActor
    private func searchPlaces(
        query: String
    ) async {
        isSearching = true
        searchErrorMessage = nil

        defer {
            isSearching = false
        }

        do {
            let results = try await PlaceSearchService.search(
                query: query
            )

            guard !Task.isCancelled else {
                return
            }

            searchResults = results

            if results.isEmpty {
                searchErrorMessage = "검색 결과가 없습니다."
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }

            searchResults = []
            searchErrorMessage =
                error.localizedDescription
        }
    }

    private func selectSearchResult(
        _ result: PlaceSearchResult
    ) {
        guard
            let resultLatitude = result.latitude,
            let resultLongitude = result.longitude
        else {
            return
        }

        searchTask?.cancel()
        shouldSkipNextSearch = true

        name = result.cleanTitle
        latitude = resultLatitude
        longitude = resultLongitude
        selectedAddress = result.displayAddress

        searchResults = []
        searchErrorMessage = nil
    }

    private func selectWish(_ wish: Wish) {
        searchTask?.cancel()
        shouldSkipNextSearch = true

        selectedWish = wish
        name = wish.name
        memo = wish.memo
        selectedAddress = wish.address
        searchResults = []
        searchErrorMessage = nil

        if !wish.category.isEmpty {
            categoryName = PlaceCategoryNormalizer.categoryName(
                from: wish.category
            )
            categoryEmoji = PlaceCategoryNormalizer.emoji(for: categoryName)
            isShowingCustomCategory = false
        }

        if wish.latitude != 0 || wish.longitude != 0 {
            latitude = wish.latitude
            longitude = wish.longitude
        } else {
            latitude = nil
            longitude = nil
        }
    }

    private func emoji(for category: String) -> String {
        let normalizedCategory = PlaceCategoryNormalizer.categoryName(
            from: category
        )

        switch normalizedCategory {
        case "식당": return "🍽️"
        case "카페": return "☕"
        case "술": return "🍺"
        case "영화": return "🎬"
        case "쇼핑": return "🛍️"
        case "산책": return "🌳"
        case "숙소": return "🏨"
        case "드라이브": return "🚗"
        default:
            return savedCustomCategories.first {
                $0.name == normalizedCategory
            }?.emoji ?? PlaceCategoryNormalizer.emoji(for: normalizedCategory)
        }
    }

    private func loadCustomCategories() {
        guard
            let data = UserDefaults.standard.data(
                forKey: "savedPlaceCategories"
            ),
            let categories = try? JSONDecoder().decode(
                [SavedPlaceCategory].self,
                from: data
            )
        else {
            return
        }

        savedCustomCategories = categories
    }

    private func persistCustomCategories() {
        savedCustomCategories = savedCustomCategories
            .map { category in
                SavedPlaceCategory(
                    name: category.name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    emoji: category.emoji.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )
            }
            .filter {
                !$0.name.isEmpty && !$0.emoji.isEmpty
            }

        guard let data = try? JSONEncoder().encode(
            savedCustomCategories
        ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: "savedPlaceCategories"
        )
    }

    private func saveCustomCategoryIfNeeded() {
        let cleanCategoryName = customCategoryName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let cleanCategoryEmoji = customCategoryEmoji.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !cleanCategoryName.isEmpty,
            !cleanCategoryEmoji.isEmpty
        else {
            return
        }

        let newCategory = SavedPlaceCategory(
            name: cleanCategoryName,
            emoji: cleanCategoryEmoji
        )

        if !savedCustomCategories.contains(newCategory) {
            savedCustomCategories.append(newCategory)
            savedCustomCategories.sort {
                $0.name < $1.name
            }
        }

        persistCustomCategories()
    }

    private func savePlace() {
        if isShowingCustomCategory {
            saveCustomCategoryIfNeeded()
        }
        guard
            !cleanName.isEmpty,
            let latitude,
            let longitude
        else {
            return
        }

        let nextOrder =
            (history.places.map(\.order).max() ?? -1) + 1

        let normalizedCategoryName = isShowingCustomCategory
            ? customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            : PlaceCategoryNormalizer.categoryName(from: categoryName)

        let place = DatePlace(
            name: cleanName,
            order: nextOrder,
            memo: cleanMemo,
            latitude: latitude,
            longitude: longitude,
            address: selectedAddress,
            categoryName: normalizedCategoryName,
            categoryEmoji: isShowingCustomCategory
                ? customCategoryEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
                : PlaceCategoryNormalizer.emoji(for: normalizedCategoryName)
        )

        place.history = history
        history.places.append(place)
        selectedWish?.isVisited = true
        selectedWish?.visitedDate = history.date

        modelContext.insert(place)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("장소 저장 실패: \(error)")
        }
    }
}

private struct WishPlaceSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let wishes: [Wish]
    let onSelect: (Wish) -> Void

    var body: some View {
        NavigationStack {
            List {
                if wishes.isEmpty {
                    ContentUnavailableView(
                        "가져올 위시가 없습니다",
                        systemImage: "heart.text.square"
                    )
                } else {
                    ForEach(wishes) { wish in
                        Button {
                            onSelect(wish)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(wish.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if !wish.address.isEmpty {
                                    Text(wish.address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                if !wish.memo.isEmpty {
                                    Text(wish.memo)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("위시리스트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SavedCategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var categories: [SavedPlaceCategory]
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach($categories) { $category in
                    HStack(spacing: 12) {
                        TextField("이모지", text: $category.emoji)
                            .frame(width: 56)
                            .multilineTextAlignment(.center)

                        TextField("카테고리명", text: $category.name)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    categories.remove(atOffsets: offsets)
                }
            }
            .navigationTitle("사용자 카테고리 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}
