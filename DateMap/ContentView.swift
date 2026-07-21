
import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import NMapsMap

enum AppTab: Hashable {
    case history
    case map
    case wish
    case more
}

enum MapTimeScope: String, CaseIterable, Identifiable {
    case all = "전체 보기"
    case date = "데이트별 보기"

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

    /// 장소 저장 시 연결할 원본 위시 ID (위시 선택으로 시작된 경우)
    @State private var selectedSourceWishID: UUID?

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    @State private var isShowingSavePlace = false
    @State private var isShowingPlaceSearch = false
    @State private var isShowingMapPlaceSearch = false
    @State private var isShowingMapPinPicker = false
    @State private var directPlaceName = ""
    @State private var selectedSearchResult: PlaceSearchResult?
    @State private var isShowingPlaceActionSheet = false
    @State private var selectedDistrictVisit: MapDistrictVisitSummary?
    @State private var selectedDistrictPage: MapDistrictVisitSummary?
    @State private var isShowingQuickDateAdd = false
    @State private var isShowingQuickDiaryAdd = false

    @State private var selectedHistory: DateHistory?
    @State private var isShowingHistorySelector = false
    @State private var mapTimeScope: MapTimeScope = .all
    @State private var mapDisplayMode: MapDisplayMode = .pins
    @State private var selectedMapMonth = Date()
    @State private var selectedMapYear = Date()
    @State private var selectedMapCategory: String?
    @State private var historyQuickAddTargetDate: Date?

    private var quickAddInitialDate: Date {
        Date()
    }

    private var allMapPlaces: [DatePlace] {
        histories
            .filter { $0.type == .record }
            .flatMap { history in
                history.places
            }
    }

    /// 지도 검색 대상 — 기록과 계획에 담긴 모든 장소
    private var searchableMapPlaces: [DatePlace] {
        histories.flatMap { $0.places }
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
        let scopedHistories: [DateHistory]

        switch mapTimeScope {
        case .date:
            scopedHistories = selectedHistory.map { [$0] } ?? []
        case .all:
            scopedHistories = histories.filter { $0.type == .record }
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

    private func districtPlaces(
        for summary: MapDistrictVisitSummary
    ) -> [DatePlace] {
        displayedPlaces
            .filter { place in
                MapDistrictStore.districtCode(for: place) == summary.code
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

    var body: some View {
        TabView(selection: $selectedTab) {
            HistoryView(quickAddTargetDate: $historyQuickAddTargetDate)
                .tabItem {
                    Label("기록", systemImage: "calendar")
                }
                .tag(AppTab.history)

            mapTabView
            .sheet(isPresented: $isShowingSavePlace) {
                if let coordinate = selectedCoordinate {
                    SavePinnedPlaceView(
                        coordinate: coordinate,
                        suggestedPlaceName: selectedPlaceName,
                        sourceWishID: selectedSourceWishID
                    ) {
                        selectedCoordinate = nil
                        selectedPlaceName = ""
                        selectedSourceWishID = nil
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
                        selectedSourceWishID = nil
                    },
                    onSelectWish: { wish in
                        selectedSavedPlace = nil
                        selectedPlaceName = wish.name
                        selectedSourceWishID = wish.id

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
                            selectedSourceWishID = nil
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
            .sheet(isPresented: $isShowingMapPlaceSearch) {
                MapPlaceSearchView(places: searchableMapPlaces) { place in
                    selectedCoordinate = nil
                    selectedDistrictVisit = nil
                    selectedSavedPlace = place
                }
            }
            .sheet(isPresented: $isShowingHistorySelector) {
                HistorySelectionSheet(
                    histories: histories.filter { $0.type == .record },
                    selectedHistory: $selectedHistory
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if selectedHistory == nil || selectedHistory?.type == .plan {
                    selectedHistory = histories.first { $0.type == .record }
                }
            }
            .onChange(of: selectedHistory) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
            }
            .onChange(of: mapTimeScope) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
            }
            .onChange(of: mapDisplayMode) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
            }
            .onChange(of: selectedMapCategory) {
                selectedCoordinate = nil
                selectedSavedPlace = nil
                selectedDistrictVisit = nil
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

            NavigationStack {
                MoreView()
            }
            .tabItem {
                Label("전체", systemImage: "line.3.horizontal")
            }
            .tag(AppTab.more)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(selectedTheme.primaryColor)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customBottomBar
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $isShowingQuickDateAdd) {
            AddDateHistoryView(initialDate: quickAddInitialDate)
        }
        .sheet(isPresented: $isShowingQuickDiaryAdd) {
            AddDiaryView(date: quickAddInitialDate)
        }
        .task {
            migrateHistoryMemosToComments()
        }
    }

    /// 예전 버전에서 데이트에 저장해둔 메모를 댓글로 옮긴다.
    private func migrateHistoryMemosToComments() {
        let migratableHistories = histories.filter { !$0.memo.isEmpty }

        guard !migratableHistories.isEmpty else {
            return
        }

        for history in migratableHistories {
            let comment = DateComment(content: history.memo)
            comment.history = history
            modelContext.insert(comment)
            history.memo = ""
        }

        do {
            try modelContext.save()
        } catch {
            print("메모를 댓글로 옮기지 못했습니다: \(error)")
        }
    }

    private var mapTabView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapView(
                    places: displayedPlaces,
                    showsHeatmap: mapDisplayMode == .heatmap,
                    showsMarkerOrder: mapDisplayMode == .pins && mapTimeScope == .date,
                    selectedCoordinate: $selectedCoordinate,
                    selectedSavedPlace: $selectedSavedPlace,
                    selectedPlaceName: $selectedPlaceName,
                    selectedDistrictVisit: $selectedDistrictVisit,
                    onDistrictBubbleTap: { summary in
                        selectedDistrictPage = summary
                    }
                )
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 10) {
                    HStack {
                        Spacer()
                        mapDisplayModeButton
                    }

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
            .toolbarBackground(selectedTheme.color, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                selectedTheme.navigationColorScheme,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedTab = .history
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selectedTheme.navigationTextColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("기록으로 돌아가기")
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingMapPlaceSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selectedTheme.navigationTextColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("내 장소 검색")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(item: $selectedDistrictPage) { summary in
                MapDistrictVisitListView(
                    summary: summary,
                    places: districtPlaces(for: summary)
                )
            }
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
                tab: .more,
                title: "전체",
                systemImage: "line.3.horizontal"
            )
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            // 구분선을 배경에 두어 + 버튼이 항상 선 위에 그려지게 하고,
            // 배경은 홈 인디케이터 영역까지 내려 아래로 콘텐츠가 비치지 않게 한다
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea(edges: .bottom)

                Divider()
            }
        }
    }

    private var quickAddButton: some View {
        Menu {
            Button {
                isShowingQuickDiaryAdd = true
            } label: {
                Label("일기 추가", systemImage: "book.closed.fill")
            }

            Button {
                isShowingQuickDateAdd = true
            } label: {
                Label("데이트 추가", systemImage: "heart.fill")
            }
        } label: {
            ZStack {
                // 완전 불투명한 흰 바탕을 깔아 뒤의 구분선이 비치지 않게 한다
                Circle()
                    .fill(Color.white)

                Circle()
                    .fill(selectedTheme.primaryColor)

                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            .compositingGroup()
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
                    .frame(height: 24)

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
                            .foregroundStyle(selectedTheme.navigationTextColor)
                            .lineLimit(1)

                        Text(
                            DateDisplayFormatter.string(
                                from: selectedHistory.date
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(
                            selectedTheme.navigationTextColor.opacity(0.72)
                        )
                        .lineLimit(1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("데이트 선택")
                            .font(.headline)
                            .foregroundStyle(selectedTheme.navigationTextColor)

                        Text("선택된 데이트가 없습니다")
                            .font(.caption)
                            .foregroundStyle(
                                selectedTheme.navigationTextColor.opacity(0.72)
                            )
                    }
                }

                Spacer()

                Text("\(displayedPlaces.count)곳")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedTheme.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTheme.primaryColor.opacity(0.12))
                    .clipShape(Capsule())

                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(
                        selectedTheme.navigationTextColor.opacity(0.72)
                    )
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(histories.isEmpty)
    }

    private var mapDisplayModeButtonIcon: String {
        mapDisplayMode == .pins ? "🗺️" : "📍"
    }

    private var mapDisplayModeButtonTitle: String {
        mapDisplayMode == .pins ? "히트맵" : "핀"
    }

    private var mapDisplayModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                mapDisplayMode = mapDisplayMode == .pins ? .heatmap : .pins
            }
        } label: {
            HStack(spacing: 7) {
                Text(mapDisplayModeButtonIcon)
                    .font(.system(size: 15))

                Text(mapDisplayModeButtonTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selectedTheme.primaryColor)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background {
                ZStack {
                    Capsule().fill(selectedTheme.cardBackgroundColor)

                    FabricTexture(
                        lineColor: selectedTheme.navigationTextColor,
                        lineOpacity: 0.05
                    )
                    .clipShape(Capsule())

                    Capsule()
                        .inset(by: 3.5)
                        .stroke(
                            selectedTheme.stitchColor,
                            style: StrokeStyle(
                                lineWidth: 1.4,
                                lineCap: .round,
                                dash: [5, 4.5]
                            )
                        )
                }
            }
            .shadow(
                color: selectedTheme.primaryColor.opacity(0.20),
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mapDisplayModeButtonTitle) 보기")
    }

    private var mapControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                mapScopeToggle

                mapCategoryMenu
            }

            if mapTimeScope == .date {
                historyPicker
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                // 헤더와 같은 흰 원단 위에 테마 색 실로 박음질한 카드
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(selectedTheme.cardBackgroundColor)

                FabricTexture(
                    lineColor: selectedTheme.navigationTextColor,
                    lineOpacity: 0.05
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )

                StitchBorder(
                    cornerRadius: 24,
                    inset: 7,
                    threadColor: selectedTheme.stitchColor
                )
            }
        }
        .shadow(
            color: selectedTheme.primaryColor.opacity(0.18),
            radius: 16,
            x: 0,
            y: 9
        )
    }

    private var mapScopeToggle: some View {
        HStack(spacing: 4) {
            ForEach(MapTimeScope.allCases) { scope in
                mapScopeButton(scope)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectedTheme.primaryColor.opacity(0.10))
        }
    }

    private func mapScopeButton(_ scope: MapTimeScope) -> some View {
        let isSelected = mapTimeScope == scope

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                mapTimeScope = scope
            }
        } label: {
            Text(scope.rawValue)
                .font(.pretendard(size: 13, weight: .semiBold))
                .foregroundStyle(
                    isSelected
                        ? .white
                        : selectedTheme.navigationTextColor.opacity(0.72)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(selectedTheme.primaryColor)
                            .shadow(
                                color: selectedTheme.primaryColor.opacity(0.32),
                                radius: 6,
                                x: 0,
                                y: 3
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var mapCategoryMenu: some View {
        Menu {
            Button {
                selectedMapCategory = nil
            } label: {
                HStack {
                    if selectedMapCategory == nil {
                        Image(systemName: "checkmark")
                    }

                    Text("전체")
                }
            }

            ForEach(mapCategories, id: \.self) { category in
                Button {
                    selectedMapCategory = category
                } label: {
                    Label {
                        HStack(spacing: 6) {
                            Text(category)

                            if selectedMapCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    } icon: {
                        Image(uiImage: mapCategoryDotImage(for: category))
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
                    .lineLimit(1)
            }
            .font(.pretendard(size: 13, weight: .semiBold))
            .foregroundStyle(selectedTheme.primaryColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(selectedTheme.primaryColor.opacity(0.10))
            .clipShape(Capsule())
        }
    }

    private func mapCategoryDot(_ category: String) -> some View {
        Circle()
            .fill(PlaceCategoryNormalizer.color(for: category))
            .frame(width: 10, height: 10)
    }

    private func mapCategoryDotImage(for category: String) -> UIImage {
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        let color = UIColor(PlaceCategoryNormalizer.color(for: category))

        return renderer.image { _ in
            let rect = CGRect(x: 3, y: 3, width: 12, height: 12)
            color.setFill()
            UIBezierPath(ovalIn: rect).fill()

            UIColor.white.withAlphaComponent(0.92).setStroke()
            let outline = UIBezierPath(ovalIn: rect.insetBy(dx: -1, dy: -1))
            outline.lineWidth = 1.5
            outline.stroke()
        }
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
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
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

                                Text(
                                    DateDisplayFormatter.string(
                                        from: history.date
                                    )
                                )
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
                    .listRowBackground(selectedTheme.cardBackgroundColor)
                }
            }
            .dateLogListBackground(selectedTheme)
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
        .dateLogCard(selectedTheme, cornerRadius: 20)
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
        .dateLogCard(selectedTheme, cornerRadius: 20)
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

}

private struct MapDistrictVisitListView: View {
    let summary: MapDistrictVisitSummary
    let places: [DatePlace]

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    var body: some View {
        List {
            if places.isEmpty {
                ContentUnavailableView(
                    "방문 장소가 없습니다",
                    systemImage: "mappin.slash",
                    description: Text("현재 지도 조건에서 이 지역의 방문 장소를 찾지 못했습니다.")
                )
            } else {
                ForEach(places) { place in
                    NavigationLink {
                        PlaceDetailView(place: place)
                    } label: {
                        HStack(spacing: 12) {
                            Text(place.categoryEmoji)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(selectedTheme.primaryColor.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 5) {
                                Text(place.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(dateText(for: place))
                                    .font(.caption)
                                    .foregroundStyle(selectedTheme.primaryColor)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(selectedTheme.cardBackgroundColor)
                }
            }
        }
        .dateLogListBackground(selectedTheme)
        .navigationTitle(summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .dateLogBackChevron(selectedTheme)
        .tint(selectedTheme.primaryColor)
    }

    private func dateText(for place: DatePlace) -> String {
        guard let date = place.history?.date else {
            return "날짜 없음"
        }

        return DateDisplayFormatter.string(from: date)
    }
}

private struct MoreView: View {
    @State private var isShowingAlbum = false
    @State private var isShowingSettings = false

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 10) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        moreRow(
                            title: "데이트 리포트",
                            subtitle: "우리의 기록을 숫자로 돌아보기",
                            systemImage: "chart.bar.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PlanListView()
                    } label: {
                        moreRow(
                            title: "계획",
                            subtitle: "다가올 데이트 계획을 한눈에",
                            systemImage: "calendar.badge.clock"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingAlbum = true
                    } label: {
                        moreRow(
                            title: "앨범",
                            subtitle: "함께 남긴 사진 모아보기",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingSettings = true
                    } label: {
                        moreRow(
                            title: "설정",
                            subtitle: "테마, 기념일, 알림 관리",
                            systemImage: "gearshape"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(selectedTheme.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                // 흰 헤더 위에 테마 색으로 틴트한 로고
                ZStack {
                    Image("DateLogLogoText")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(selectedTheme.primaryColor)
                    Image("DateLogLogoHeart")
                        .resizable()
                        .scaledToFit()
                }
                .frame(width: 94, height: 32)
                .accessibilityLabel("DateLog")
            }
        }
        .tint(selectedTheme.primaryColor)
        .sheet(isPresented: $isShowingAlbum) {
            AlbumView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    private func moreRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(selectedTheme.primaryColor)
                .frame(width: 46, height: 46)
                .background(selectedTheme.primaryColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.pretendard(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.pretendard(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dateLogCard(selectedTheme, cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PlanListView: View {
    @Query(sort: \DateHistory.date, order: .reverse)
    private var histories: [DateHistory]

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private var plans: [DateHistory] {
        histories.filter { $0.type == .plan }
    }

    var body: some View {
        List {
            if plans.isEmpty {
                ContentUnavailableView(
                    "저장된 계획이 없습니다",
                    systemImage: "calendar.badge.clock",
                    description: Text("데이트 계획으로 추가한 항목이 여기에 모입니다.")
                )
            } else {
                ForEach(plans) { plan in
                    NavigationLink {
                        DateHistoryDetailView(history: plan)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(plan.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(DateDisplayFormatter.string(from: plan.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let latestComment = plan.comments.max(
                                by: { $0.createdAt < $1.createdAt }
                            ) {
                                Text(latestComment.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(selectedTheme.cardBackgroundColor)
                }
            }
        }
        .dateLogListBackground(selectedTheme)
        .navigationTitle("계획")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .dateLogBackChevron(selectedTheme)
        .tint(selectedTheme.primaryColor)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("relationshipStartDate")
    private var relationshipStartDateInterval = Date().timeIntervalSince1970

    @AppStorage("showRelationshipDay")
    private var showRelationshipDay = false

    @AppStorage("showRelationshipDayInHistory")
    private var showRelationshipDayInHistory = true

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
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    @AppStorage("calendarWeekStartsOnMonday")
    private var calendarWeekStartsOnMonday = false

    @AppStorage("showPlansInHistory")
    private var showPlansInHistory = true

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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pretendard(size: 14, weight: .bold))
            .foregroundStyle(selectedTheme.primaryColor)
            .textCase(nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("만난 날 표시", isOn: $showRelationshipDay)

                    if showRelationshipDay {
                        DatePicker(
                            "처음 만난 날",
                            selection: relationshipStartDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))

                        Toggle(
                            "기록 탭 히스토리에 만난 날 표시",
                            isOn: $showRelationshipDayInHistory
                        )
                    }
                } header: {
                    sectionHeader("❤️ 커플")
                }
                .listRowBackground(selectedTheme.cardBackgroundColor)

                Section {
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
                } header: {
                    sectionHeader("🎂 생일")
                }
                .listRowBackground(selectedTheme.cardBackgroundColor)

                Section {
                    Toggle(
                        "기념일 알림",
                        isOn: $anniversaryNotificationsEnabled
                    )

                    if anniversaryNotificationsEnabled {
                        Text("100일, 200일, 300일, 1주년, 500일, 1000일 등 주요 기념일에 알림을 보내드립니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    sectionHeader("🔔 기념일 알림")
                }
                .listRowBackground(selectedTheme.cardBackgroundColor)

                Section {
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

                    Toggle(
                        "히스토리에 계획 표시",
                        isOn: $showPlansInHistory
                    )

                    Text(
                        showPlansInHistory
                            ? "데이트 계획이 히스토리에 회색 카드로 함께 표시됩니다."
                            : "데이트 계획이 히스토리에 표시되지 않습니다."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    sectionHeader("🗓️ 표시")
                }
                .listRowBackground(selectedTheme.cardBackgroundColor)

                Section {
                    Picker("테마", selection: $selectedThemeRawValue) {
                        ForEach(DateLogTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme.rawValue)
                        }
                    }

                    LabeledContent("언어", value: "한국어")
                } header: {
                    sectionHeader("🎨 앱")
                }
                .listRowBackground(selectedTheme.cardBackgroundColor)
            }
            .dateLogListBackground(selectedTheme)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(selectedTheme.color, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                selectedTheme.navigationColorScheme,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedTheme.navigationTextColor)
                    }
                    .accessibilityLabel("설정 닫기")
                }
            }
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
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
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

#Preview("설정") {
    SettingsView()
}
