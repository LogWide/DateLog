
import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import NMapsMap

enum AppTab: Hashable {
    case history
    case map
    case wish
    case settings
}

enum MapTimeScope: String, CaseIterable, Identifiable {
    case date = "데이트"
    case month = "월별"
    case year = "연도별"

    var id: Self { self }
}

enum MapDisplayMode: String, CaseIterable, Identifiable {
    case pins = "핀"
    case heatmap = "히트맵"

    var id: Self { self }
}


enum DateDisplayFormatter {
    static let koreanDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy. M. d."
        return formatter
    }()

    static func string(from date: Date) -> String {
        koreanDate.string(from: date)
    }
}


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    @State private var selectedTab: AppTab = .history
    @State private var selectedCoordinate: CoordinateData?
    @State private var selectedSavedPlace: DatePlace?
    @State private var selectedPlaceName = ""

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
    }

    @State private var isShowingSavePlace = false
    @State private var isShowingPlaceSearch = false
    @State private var isShowingMapPinPicker = false
    @State private var directPlaceName = ""
    @State private var selectedSearchResult: PlaceSearchResult?
    @State private var isShowingPlaceActionSheet = false
    @State private var selectedDistrictVisit: MapDistrictVisitSummary?
    @State private var isShowingDistrictPlaces = false
    @State private var isShowingQuickDateAdd = false
    @State private var isShowingQuickDiaryAdd = false
    @State private var isShowingQuickMemoAdd = false

    @State private var selectedHistory: DateHistory?
    @State private var isShowingHistorySelector = false
    @State private var mapTimeScope: MapTimeScope = .date
    @State private var mapDisplayMode: MapDisplayMode = .pins
    @State private var selectedMapMonth = Date()
    @State private var selectedMapYear = Date()
    @State private var selectedMapCategory: String?

    private var allMapPlaces: [DatePlace] {
        histories.flatMap { history in
            history.places
        }
    }

    private var mapCategories: [String] {
        Array(
                Set(
                    allMapPlaces
                        .map {
                            PlaceCategoryNormalizer.categoryName(
                                from: $0.categoryName
                            )
                        }
                        .filter { !$0.isEmpty }
                )
        )
        .sorted()
    }

    private var scopedMapPlaces: [DatePlace] {
        let calendar = Calendar(identifier: .gregorian)
        let scopedHistories: [DateHistory]

        if mapDisplayMode == .heatmap {
            let places = allMapPlaces.sorted { first, second in
                (first.history?.date ?? .distantPast) <
                    (second.history?.date ?? .distantPast)
            }

            guard let selectedMapCategory else {
                return places
            }

            return places.filter {
                PlaceCategoryNormalizer.categoryName(
                    from: $0.categoryName
                ) == selectedMapCategory
            }
        }

        switch mapTimeScope {
        case .date:
            scopedHistories = selectedHistory.map { [$0] } ?? []
        case .month:
            scopedHistories = histories.filter {
                calendar.isDate(
                    $0.date,
                    equalTo: selectedMapMonth,
                    toGranularity: .month
                )
            }
        case .year:
            scopedHistories = histories.filter {
                calendar.isDate(
                    $0.date,
                    equalTo: selectedMapYear,
                    toGranularity: .year
                )
            }
        }

        let places = scopedHistories
            .flatMap { $0.places }
            .sorted { first, second in
                if first.history?.date == second.history?.date {
                    return first.order < second.order
                }

                return (first.history?.date ?? .distantPast) <
                    (second.history?.date ?? .distantPast)
            }

        guard let selectedMapCategory else {
            return places
        }

        return places.filter {
            PlaceCategoryNormalizer.categoryName(
                from: $0.categoryName
            ) == selectedMapCategory
        }
    }

    private var displayedPlaces: [DatePlace] {
        scopedMapPlaces
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HistoryView()
                .tabItem {
                    Label("기록", systemImage: "calendar")
                }
                .tag(AppTab.history)

            NavigationStack {
                ZStack(alignment: .bottom) {
                    MapView(
                        places: displayedPlaces,
                        showsHeatmap: mapDisplayMode == .heatmap,
                        showsMarkerOrder: mapTimeScope == .date,
                        selectedCoordinate: $selectedCoordinate,
                        selectedSavedPlace: $selectedSavedPlace,
                        selectedPlaceName: $selectedPlaceName,
                        selectedDistrictVisit: $selectedDistrictVisit
                    )
                    .ignoresSafeArea(edges: .top)

                    if let districtVisit = selectedDistrictVisit {
                        VStack {
                            districtVisitCard(districtVisit)
                                .padding(.horizontal, 18)
                                .padding(.top, 12)

                            Spacer()
                        }
                    }

                    VStack(spacing: 12) {
                        mapControls

                        if let place = selectedSavedPlace {
                            savedPlaceCard(place)
                        }

                        if let coordinate = selectedCoordinate {
                            selectedCoordinateCard(coordinate)
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
                .navigationTitle("지도")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedTab = .history
                        } label: {
                            Label("기록", systemImage: "chevron.left")
                        }
                        .accessibilityLabel("기록으로 돌아가기")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingPlaceSearch = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("장소 추가")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedTheme.primaryColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("장소 추가")
                    }
                }
            }
            .sheet(isPresented: $isShowingSavePlace) {
                if let coordinate = selectedCoordinate {
                    SavePinnedPlaceView(
                        coordinate: coordinate,
                        suggestedPlaceName: selectedPlaceName
                    ) {
                        selectedCoordinate = nil
                        selectedPlaceName = ""
                    }
                }
            }
            .sheet(isPresented: $isShowingPlaceSearch) {
                PlaceSearchView(
                    onSelect: { result in
                        selectedSearchResult = result
                        isShowingPlaceSearch = false
                        isShowingPlaceActionSheet = true
                    },
                    onDirectAdd: { directName in
                        selectedSavedPlace = nil
                        selectedPlaceName = directName
                        selectedCoordinate = nil
                    },
                    onSelectWish: { wish in
                        selectedSavedPlace = nil
                        selectedPlaceName = wish.name

                        if wish.latitude != 0 || wish.longitude != 0 {
                            selectedCoordinate = CoordinateData(
                                latitude: wish.latitude,
                                longitude: wish.longitude
                            )
                        } else {
                            selectedCoordinate = nil
                        }

                        wish.isVisited = true
                        wish.visitedDate = selectedHistory?.date ?? Date()
                        isShowingPlaceSearch = false
                    },
                    showsWishSuggestions: true
                )
            }
            .sheet(isPresented: $isShowingPlaceActionSheet) {
                if let result = selectedSearchResult {
                    PlaceActionSheet(
                        placeName: result.cleanTitle,
                        onAddDate: {
                            guard
                                let latitude = result.latitude,
                                let longitude = result.longitude
                            else {
                                return
                            }

                            selectedSavedPlace = nil
                            selectedPlaceName = result.cleanTitle
                            selectedCoordinate = CoordinateData(
                                latitude: latitude,
                                longitude: longitude
                            )
                        },
                        onAddWish: {
                            let wish = Wish(
                                name: result.cleanTitle,
                                address: result.address,
                                latitude: result.latitude ?? 0,
                                longitude: result.longitude ?? 0,
                                category: PlaceCategoryNormalizer.categoryName(
                                    from: result.category
                                ),
                                memo: ""
                            )

                            modelContext.insert(wish)

                            selectedSearchResult = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $isShowingHistorySelector) {
                HistorySelectionSheet(
                    histories: histories,
                    selectedHistory: $selectedHistory
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if selectedHistory == nil {
                    selectedHistory = histories.first
                }
            }
            .onChange(of: selectedHistory) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
                isShowingDistrictPlaces = false
            }
            .onChange(of: mapTimeScope) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
                isShowingDistrictPlaces = false
            }
            .onChange(of: mapDisplayMode) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
                isShowingDistrictPlaces = false
            }
            .onChange(of: selectedMapCategory) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
                isShowingDistrictPlaces = false
            }
            .onChange(of: selectedDistrictVisit) {
                isShowingDistrictPlaces = false
            }
            .onChange(of: mapCategories) { _, categories in
                guard
                    let selectedMapCategory,
                    !categories.contains(selectedMapCategory)
                else {
                    return
                }

                self.selectedMapCategory = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
                isShowingDistrictPlaces = false
            }
            .tabItem {
                Label("지도", systemImage: "map")
            }
            .tag(AppTab.map)

            NavigationStack {
                WishlistView()
            }
            .tabItem {
                Label("위시", systemImage: "heart.text.square")
            }
            .tag(AppTab.wish)

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(selectedTheme.primaryColor)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customBottomBar
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $isShowingQuickDateAdd) {
            AddDateHistoryView(initialDate: Date())
        }
        .sheet(isPresented: $isShowingQuickDiaryAdd) {
            AddDiaryView(date: Date())
        }
        .sheet(isPresented: $isShowingQuickMemoAdd) {
            AddMemoView(date: Date())
        }
    }
    private var customBottomBar: some View {
        HStack(alignment: .top, spacing: 0) {
            customTabButton(
                tab: .history,
                title: "기록",
                systemImage: "calendar"
            )

            customTabButton(
                tab: .map,
                title: "지도",
                systemImage: "map"
            )

            quickAddButton
                .frame(maxWidth: .infinity)
                .offset(y: -20)

            customTabButton(
                tab: .wish,
                title: "위시",
                systemImage: "heart.text.square"
            )

            customTabButton(
                tab: .settings,
                title: "설정",
                systemImage: "gearshape"
            )
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var quickAddButton: some View {
        Menu {
            Button {
                isShowingQuickDateAdd = true
            } label: {
                Label("데이트 추가", systemImage: "heart.fill")
            }

            Button {
                isShowingQuickDiaryAdd = true
            } label: {
                Label("일기 추가", systemImage: "book.closed.fill")
            }

            Button {
                isShowingQuickMemoAdd = true
            } label: {
                Label("메모 추가", systemImage: "note.text")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(selectedTheme.primaryColor)
                    .frame(width: 58, height: 58)

                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            .background(
                Circle()
                    .fill(selectedTheme.primaryColor)
            )
            .clipShape(Circle())
                .shadow(
                    color: selectedTheme.primaryColor.opacity(0.36),
                    radius: 12,
                    x: 0,
                    y: 7
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("기록 추가")
    }

    private func customTabButton(
        tab: AppTab,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))

                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(
                selectedTab == tab
                    ? selectedTheme.primaryColor
                    : Color.secondary
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var historyPicker: some View {
        Button {
            guard !histories.isEmpty else {
                return
            }

            isShowingHistorySelector = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(selectedTheme.primaryColor)

                if let selectedHistory {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedHistory.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(
                            DateDisplayFormatter.string(
                                from: selectedHistory.date
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("데이트 선택")
                            .font(.headline)

                        Text("선택된 데이트가 없습니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(displayedPlaces.count)곳")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTheme.primaryColor.opacity(0.12))
                    .clipShape(Capsule())

                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(histories.isEmpty)
    }

    private var mapControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Picker("표현", selection: $mapDisplayMode) {
                    ForEach(MapDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Menu {
                    Button {
                        selectedMapCategory = nil
                    } label: {
                        HStack {
                            if selectedMapCategory == nil {
                                Image(systemName: "checkmark")
                            }

                            Text("전체 카테고리")
                        }
                    }

                    ForEach(mapCategories, id: \.self) { category in
                        Button {
                            selectedMapCategory = category
                        } label: {
                            HStack {
                                if selectedMapCategory == category {
                                    Image(systemName: "checkmark")
                                }

                                mapCategoryDot(category)
                                Text(category)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        if let selectedMapCategory {
                            mapCategoryDot(selectedMapCategory)
                        } else {
                            Image(systemName: "tag.fill")
                        }

                        Text(selectedMapCategory ?? "전체")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedTheme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTheme.primaryColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .disabled(mapCategories.isEmpty)
            }

            if mapDisplayMode == .heatmap {
                Label(
                    "전체 기록 기준",
                    systemImage: "map.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedTheme.primaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                Picker("지도 기간", selection: $mapTimeScope) {
                    ForEach(MapTimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                switch mapTimeScope {
                case .date:
                    historyPicker
                case .month:
                    mapPeriodStepper(
                        title: mapMonthTitle,
                        previousAction: {
                            moveMapMonth(by: -1)
                        },
                        nextAction: {
                            moveMapMonth(by: 1)
                        }
                    )
                case .year:
                    mapPeriodStepper(
                        title: mapYearTitle,
                        previousAction: {
                            moveMapYear(by: -1)
                        },
                        nextAction: {
                            moveMapYear(by: 1)
                        }
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func mapCategoryDot(_ category: String) -> some View {
        Circle()
            .fill(PlaceCategoryNormalizer.color(for: category))
            .frame(width: 8, height: 8)
    }

    private func mapPeriodStepper(
        title: String,
        previousAction: @escaping () -> Void,
        nextAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: previousAction) {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedTheme.primaryColor)

            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button(action: nextAction) {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedTheme.primaryColor)
        }
        .padding(.vertical, 4)
    }

    private var mapMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: selectedMapMonth)
    }

    private var mapYearTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년"
        return formatter.string(from: selectedMapYear)
    }

    private func moveMapMonth(by value: Int) {
        selectedMapMonth = Calendar(identifier: .gregorian).date(
            byAdding: .month,
            value: value,
            to: selectedMapMonth
        ) ?? selectedMapMonth
    }

    private func moveMapYear(by value: Int) {
        selectedMapYear = Calendar(identifier: .gregorian).date(
            byAdding: .year,
            value: value,
            to: selectedMapYear
        ) ?? selectedMapYear
    }
// MARK: - 데이트 선택 시트

private struct HistorySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
    }

    let histories: [DateHistory]
    @Binding var selectedHistory: DateHistory?

    var body: some View {
        NavigationStack {
            List {
                ForEach(histories) { history in
                    Button {
                        selectedHistory = history
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(history.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Label(
                                        history.type.displayName,
                                        systemImage: history.type.systemImage
                                    )

                                    Text(
                                        DateDisplayFormatter.string(
                                            from: history.date
                                        )
                                    )
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }

                            Spacer()

                            if selectedHistory?.id == history.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(selectedTheme.primaryColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("데이트 선택")
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


    private func selectedCoordinateCard(
        _ coordinate: CoordinateData
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(selectedTheme.primaryColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        selectedPlaceName.isEmpty
                            ? "새 위치"
                            : selectedPlaceName
                    )
                    .font(.headline)

                    Text("지도에서 선택한 위치")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }


            HStack(spacing: 12) {
                Button("선택 취소") {
                    selectedCoordinate = nil
                    selectedPlaceName = ""
                }
                .buttonStyle(.bordered)
                .tint(selectedTheme.primaryColor)

                Button("이 위치 저장") {
                    isShowingSavePlace = true
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedTheme.primaryColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
    private func savedPlaceCard(
        _ place: DatePlace
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selectedTheme.primaryColor.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Text(place.categoryEmoji)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(mapPlaceSubtitle(for: place))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    selectedSavedPlace = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !place.address.isEmpty {
                Label(place.address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !place.memo.isEmpty {
                Text(place.memo)
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func mapPlaceSubtitle(for place: DatePlace) -> String {
        if mapTimeScope == .date {
            return "\(place.order + 1)번째 장소 · \(PlaceCategoryNormalizer.categoryName(from: place.categoryName))"
        }

        guard let date = place.history?.date else {
            return PlaceCategoryNormalizer.categoryName(
                from: place.categoryName
            )
        }

        return "\(DateDisplayFormatter.string(from: date)) 방문 · \(PlaceCategoryNormalizer.categoryName(from: place.categoryName))"
    }

    private func districtVisitCard(
        _ summary: MapDistrictVisitSummary
    ) -> some View {
        let districtPlaces = districtPlaces(for: summary)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundStyle(selectedTheme.primaryColor)
                    .frame(width: 42, height: 42)
                    .background(selectedTheme.primaryColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.name)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)

                    (
                        Text("총 ")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        + Text("\(summary.visitCount)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selectedTheme.primaryColor)
                        + Text("회 방문")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    )
                }

                Spacer()

                Button {
                    selectedDistrictVisit = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isShowingDistrictPlaces {
                Divider()

                if districtPlaces.isEmpty {
                    Text("표시할 장소가 없습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(districtPlaces) { place in
                            NavigationLink {
                                PlaceDetailView(place: place)
                            } label: {
                                districtPlaceRow(place)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
        .onTapGesture {
            isShowingDistrictPlaces.toggle()
        }
    }

    private func districtPlaceRow(_ place: DatePlace) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(PlaceCategoryNormalizer.color(for: place.categoryName))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(mapPlaceSubtitle(for: place))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private func districtPlaces(
        for summary: MapDistrictVisitSummary
    ) -> [DatePlace] {
        guard let district = MapDistrictStore.districts().first(where: {
            $0.code == summary.code
        }) else {
            return []
        }

        return displayedPlaces
            .filter {
                place($0, isIn: district)
            }
            .sorted { first, second in
                let firstDate = first.history?.date ?? .distantPast
                let secondDate = second.history?.date ?? .distantPast

                if firstDate == secondDate {
                    return first.order < second.order
                }

                return firstDate > secondDate
            }
    }

    private func place(
        _ place: DatePlace,
        isIn district: MapDistrict
    ) -> Bool {
        if
            let latitude = place.latitude,
            let longitude = place.longitude,
            districtContains(
                coordinate: NMGLatLng(lat: latitude, lng: longitude),
                district: district
            )
        {
            return true
        }

        return place.address.contains(district.name) ||
            place.name.contains(district.name)
    }

    private func districtContains(
        coordinate: NMGLatLng,
        district: MapDistrict
    ) -> Bool {
        district.polygons.contains {
            polygonContains(coordinate: coordinate, polygon: $0)
        }
    }

    private func polygonContains(
        coordinate: NMGLatLng,
        polygon: [NMGLatLng]
    ) -> Bool {
        guard polygon.count >= 3 else {
            return false
        }

        var isInside = false
        var previousIndex = polygon.count - 1

        for currentIndex in polygon.indices {
            let current = polygon[currentIndex]
            let previous = polygon[previousIndex]
            let crossesLatitude = (current.lat > coordinate.lat) !=
                (previous.lat > coordinate.lat)

            if crossesLatitude {
                let intersectionLongitude =
                    (previous.lng - current.lng) *
                    (coordinate.lat - current.lat) /
                    (previous.lat - current.lat) +
                    current.lng

                if coordinate.lng < intersectionLongitude {
                    isInside.toggle()
                }
            }

            previousIndex = currentIndex
        }

        return isInside
    }
}

private struct SettingsView: View {
    @AppStorage("relationshipStartDate")
    private var relationshipStartDateInterval = Date().timeIntervalSince1970

    @AppStorage("showRelationshipDay")
    private var showRelationshipDay = false

    @AppStorage("myBirthday")
    private var myBirthdayInterval = Date().timeIntervalSince1970

    @AppStorage("showMyBirthday")
    private var showMyBirthday = false

    @AppStorage("partnerBirthday")
    private var partnerBirthdayInterval = Date().timeIntervalSince1970

    @AppStorage("showPartnerBirthday")
    private var showPartnerBirthday = false

    @AppStorage("anniversaryNotificationsEnabled")
    private var anniversaryNotificationsEnabled = false

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
    }

    @AppStorage("calendarWeekStartsOnMonday")
    private var calendarWeekStartsOnMonday = false

    private var relationshipStartDate: Binding<Date> {
        Binding(
            get: {
                Date(timeIntervalSince1970: relationshipStartDateInterval)
            },
            set: { newValue in
                relationshipStartDateInterval = newValue.timeIntervalSince1970
            }
        )
    }

    private var myBirthday: Binding<Date> {
        Binding(
            get: {
                Date(timeIntervalSince1970: myBirthdayInterval)
            },
            set: { newValue in
                myBirthdayInterval = newValue.timeIntervalSince1970
            }
        )
    }

    private var partnerBirthday: Binding<Date> {
        Binding(
            get: {
                Date(timeIntervalSince1970: partnerBirthdayInterval)
            },
            set: { newValue in
                partnerBirthdayInterval = newValue.timeIntervalSince1970
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("❤️ 커플") {
                    Toggle("만난 날 표시", isOn: $showRelationshipDay)

                    if showRelationshipDay {
                        DatePicker(
                            "처음 만난 날",
                            selection: relationshipStartDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                Section("🎂 생일") {
                    Toggle("내 생일 표시", isOn: $showMyBirthday)

                    if showMyBirthday {
                        DatePicker(
                            "내 생일",
                            selection: myBirthday,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }

                    Toggle("상대 생일 표시", isOn: $showPartnerBirthday)

                    if showPartnerBirthday {
                        DatePicker(
                            "상대 생일",
                            selection: partnerBirthday,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                Section("🔔 기념일 알림") {
                    Toggle(
                        "기념일 알림",
                        isOn: $anniversaryNotificationsEnabled
                    )

                    if anniversaryNotificationsEnabled {
                        Text("100일, 200일, 300일, 1주년, 500일, 1000일 등 주요 기념일에 알림을 보내드립니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("표시") {
                    LabeledContent("날짜 형식", value: "2026. 1. 1.")
                    LabeledContent("시간 형식", value: "24시간")

                    Toggle(
                        "한 주를 월요일부터 시작",
                        isOn: $calendarWeekStartsOnMonday
                    )

                    Text(
                        calendarWeekStartsOnMonday
                            ? "달력이 월요일부터 일요일 순서로 표시됩니다."
                            : "달력이 일요일부터 토요일 순서로 표시됩니다."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("앱") {
                    Picker("테마", selection: $selectedThemeRawValue) {
                        ForEach(DateLogTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme.rawValue)
                        }
                    }

                    LabeledContent("언어", value: "한국어")
                }
            }
            .navigationTitle("설정")
            .tint(selectedTheme.primaryColor)
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: DatePhoto

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)

            if
                let data = photo.imageData,
                let uiImage = UIImage(data: data)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.title2)

                    Text("이미지를 불러올 수 없음")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(height: 110)
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }
}

private struct PhotoViewerView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
    }

    let photo: DatePhoto

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if
                    let data = photo.imageData,
                    let uiImage = UIImage(data: data)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView(
                        "사진을 불러올 수 없습니다",
                        systemImage: "photo.badge.exclamationmark"
                    )
                    .foregroundStyle(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .tint(selectedTheme.primaryColor)
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - 장소 추가


#Preview {
    ContentView()
        .modelContainer(
            for: [
                DateHistory.self,
                DatePlace.self,
                DatePhoto.self,
                Wish.self
            ],
            inMemory: true
        )
}
