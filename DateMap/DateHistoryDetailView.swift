import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct DateHistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Environment(\.dismiss) private var dismiss

    let history: DateHistory

    @State private var isShowingAddPlace = false
    @State private var isShowingCoverOptions = false
    @State private var isShowingPhotoLibrary = false
    @State private var selectedCoverPhotoItem: PhotosPickerItem?
    @State private var isShowingPlacePhotoPicker = false
    @State private var showingDeleteAlert = false
    @State private var usesManualPlaceOrder = true
    @State private var isRecommendingRoute = false
    @State private var routeRecommendationMessage: String?
    @State private var pendingRecommendedPlaces: [DatePlace]?
    @State private var newCommentText = ""

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private var sortedPlaces: [DatePlace] {
        history.places.sorted { $0.order < $1.order }
    }

    private var isEditingPlaces: Bool {
        editMode?.wrappedValue.isEditing == true
    }


    var body: some View {
        List {
            Section("기본 정보") {
                if history.type == .plan || isEditingPlaces {
                    Picker("데이트 유형", selection: Binding(
                        get: { history.type },
                        set: { newType in
                            history.type = newType
                            saveHistoryChanges()
                        }
                    )) {
                        ForEach(DateHistoryType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                DatePicker(
                    "데이트 날짜",
                    selection: Binding(
                        get: {
                            history.date
                        },
                        set: { newDate in
                            history.date = newDate
                            saveHistoryChanges()
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ko_KR"))
            }

            if history.type == .record {
                Section("대표사진") {
                    if let imageData = history.coverImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                            )
                    } else {
                        ContentUnavailableView(
                            "대표사진 없음",
                            systemImage: "photo",
                            description: Text("대표사진를 아직 선택하지 않았습니다.")
                        )
                    }

                    Button {
                        isShowingCoverOptions = true
                    } label: {
                        Label(
                            history.coverImageData == nil
                                ? "대표사진 선택"
                                : "대표사진 변경",
                            systemImage: "photo.badge.plus"
                        )
                    }
                }
            }

            Section {
                if history.type == .plan {
                    Toggle("순서 지정", isOn: $usesManualPlaceOrder)

                    Button {
                        recommendPlanOrder()
                    } label: {
                        Label("AI 순서 추천", systemImage: "sparkles")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(isRecommendingRoute || routablePlaces.count < 2)

                    if let routeRecommendationMessage {
                        Text(routeRecommendationMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if sortedPlaces.isEmpty {
                    Text("아직 추가된 장소가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlaces) { place in
                        NavigationLink {
                            PlaceDetailView(place: place)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(place.order + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        Color(
                                            red: 0.93,
                                            green: 0.32,
                                            blue: 0.58
                                        )
                                    )
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name)
                                        .foregroundStyle(.primary)

                                    Text(
                                        "\(PlaceCategoryNormalizer.emoji(for: place.categoryName)) \(PlaceCategoryNormalizer.categoryName(from: place.categoryName))"
                                    )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if !place.address.isEmpty {
                                        Text(place.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    if !place.memo.isEmpty {
                                        Text(place.memo)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if !place.photos.isEmpty {
                                        Label(
                                            "\(place.photos.count)장",
                                            systemImage: "photo.on.rectangle"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if !isEditingPlaces,
                                   let firstPhoto = place.photos
                                    .sorted(by: { $0.order < $1.order })
                                    .first
                                {
                                    PhotoThumbnailView(photo: firstPhoto)
                                        .frame(width: 64, height: 64)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deletePlaces)
                    .onMove(perform: movePlaces)
                }

                Button {
                    isShowingAddPlace = true
                } label: {
                    Label("장소 추가하기", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
            } header: {
                HStack {
                    Text("장소")

                    Spacer()

                    Text("\(sortedPlaces.count)곳")
                }
            }

            Section("댓글") {
                if sortedComments.isEmpty {
                    Text("아직 댓글이 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedComments) { comment in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(comment.content)

                            Text(
                                comment.createdAt,
                                format: .dateTime.year().month().day().hour().minute()
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button(
                                "댓글 삭제",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                deleteComment(comment)
                            }
                        }
                    }
                    .onDelete(perform: deleteComments)
                }

                HStack(spacing: 10) {
                    TextField(
                        "댓글을 입력하세요",
                        text: $newCommentText,
                        axis: .vertical
                    )

                    Button("등록") {
                        addComment()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(trimmedNewComment.isEmpty)
                }
            }
        }
        .dateLogListBackground(selectedTheme)
        .navigationTitle(history.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .dateLogBackChevron(selectedTheme)
        .tint(selectedTheme.primaryColor)
        .overlay {
            if isRecommendingRoute {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()

                    VStack(spacing: 18) {
                        ProgressView()
                            .tint(selectedTheme.primaryColor)
                            .scaleEffect(1.3)

                        Text("AI가 데이트 코스를\n분석하고 있어요")
                            .font(.pretendard(size: 21, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditingPlaces ? "완료" : "편집") {
                    withAnimation {
                        editMode?.wrappedValue = isEditingPlaces
                            ? .inactive
                            : .active
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $isShowingAddPlace) {
            AddPlaceView(history: history)
        }
        .sheet(isPresented: $isShowingPlacePhotoPicker) {
            PlacePhotoPickerView(history: history) { imageData in
                guard history.type == .record else { return }

                history.coverImageData = imageData
                saveHistoryChanges()
            }
        }
        .confirmationDialog(
            "대표사진 변경",
            isPresented: $isShowingCoverOptions,
            titleVisibility: .visible
        ) {
            Button("사진 보관함에서 선택") {
                isShowingPhotoLibrary = true
            }

            Button("장소 사진에서 선택") {
                isShowingPlacePhotoPicker = true
            }

            if history.coverImageData != nil {
                Button("대표사진 제거", role: .destructive) {
                    history.coverImageData = nil
                    saveHistoryChanges()
                }
            }

            Button("취소", role: .cancel) {}
        }
        .alert(
            "AI 추천 코스",
            isPresented: Binding(
                get: { pendingRecommendedPlaces != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingRecommendedPlaces = nil
                    }
                }
            ),
            presenting: pendingRecommendedPlaces
        ) { recommendedPlaces in
            Button("이 순서로 변경") {
                applyRecommendedOrder(recommendedPlaces)
            }

            Button("그대로 두기", role: .cancel) {
                pendingRecommendedPlaces = nil
            }
        } message: { recommendedPlaces in
            Text(
                "AI가 추천하는 코스예요.\n\n\(recommendedPlaces.map(\.name).joined(separator: " → "))\n\n이 순서로 바꿀까요?"
            )
        }
        .alert(
            "이 데이트를 삭제할까요?",
            isPresented: $showingDeleteAlert
        ) {
            Button("삭제", role: .destructive) {
                deleteHistory()
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("데이트와 장소 정보가 모두 삭제되며 복구할 수 없습니다.")
        }
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $selectedCoverPhotoItem,
            matching: .images
        )
        .task(id: selectedCoverPhotoItem) {
            guard history.type == .record else {
                selectedCoverPhotoItem = nil
                return
            }

            guard let selectedCoverPhotoItem else { return }

            if
                let imageData = try? await selectedCoverPhotoItem
                    .loadTransferable(type: Data.self),
                let image = UIImage(data: imageData),
                let compressedData = image.jpegData(compressionQuality: 0.82)
            {
                history.coverImageData = compressedData
                saveHistoryChanges()
            }
        }
    }

    private var routablePlaces: [DatePlace] {
        sortedPlaces.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var sortedComments: [DateComment] {
        history.comments.sorted { $0.createdAt < $1.createdAt }
    }

    private var trimmedNewComment: String {
        newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addComment() {
        let content = trimmedNewComment

        guard !content.isEmpty else {
            return
        }

        let comment = DateComment(content: content)
        comment.history = history
        modelContext.insert(comment)
        newCommentText = ""
        saveHistoryChanges()
    }

    private func deleteComment(_ comment: DateComment) {
        modelContext.delete(comment)
        saveHistoryChanges()
    }

    private func deleteComments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedComments[index])
        }

        saveHistoryChanges()
    }

    private func recommendPlanOrder() {
        guard history.type == .plan else {
            return
        }

        let places = routablePlaces

        guard places.count >= 2 else {
            routeRecommendationMessage = "좌표가 있는 장소가 2곳 이상 필요합니다."
            return
        }

        isRecommendingRoute = true
        routeRecommendationMessage = nil

        Task { @MainActor in
            let recommendedPlaces = await recommendedPlanRoute(from: places)

            isRecommendingRoute = false

            if recommendedPlaces.map(\.persistentModelID) ==
                routablePlaces.map(\.persistentModelID) {
                routeRecommendationMessage = "지금 순서가 AI 추천 순서와 같아요."
            } else {
                pendingRecommendedPlaces = recommendedPlaces
            }
        }
    }

    private func applyRecommendedOrder(
        _ recommendedPlaces: [DatePlace]
    ) {
        for (index, place) in recommendedPlaces.enumerated() {
            place.order = index
        }

        var nextOrder = recommendedPlaces.count
        for place in sortedPlaces where !recommendedPlaces.contains(where: { $0 === place }) {
            place.order = nextOrder
            nextOrder += 1
        }

        saveHistoryChanges()
        usesManualPlaceOrder = false
        pendingRecommendedPlaces = nil
        routeRecommendationMessage = "추천 순서로 정리했습니다."
    }

    private func recommendedPlanRoute(
        from places: [DatePlace]
    ) async -> [DatePlace] {
        var bestRoute = places
        var bestCost = Double.greatestFiniteMagnitude

        for startPlace in places {
            var route = [startPlace]
            var remainingPlaces = places.filter { $0 !== startPlace }
            var totalCost: Double = 0

            while let currentPlace = route.last, !remainingPlaces.isEmpty {
                var bestCandidate: DatePlace?
                var bestCandidateCost = Double.greatestFiniteMagnitude

                for candidate in remainingPlaces {
                    let cost = await routeCost(
                        from: currentPlace,
                        to: candidate
                    )

                    if cost < bestCandidateCost {
                        bestCandidate = candidate
                        bestCandidateCost = cost
                    }
                }

                guard let bestCandidate else {
                    break
                }

                route.append(bestCandidate)
                totalCost += bestCandidateCost
                remainingPlaces.removeAll { $0 === bestCandidate }
            }

            if totalCost < bestCost {
                bestRoute = route
                bestCost = totalCost
            }
        }

        return bestRoute
    }

    private func routeCost(
        from startPlace: DatePlace,
        to goalPlace: DatePlace
    ) async -> Double {
        guard
            let startLatitude = startPlace.latitude,
            let startLongitude = startPlace.longitude,
            let goalLatitude = goalPlace.latitude,
            let goalLongitude = goalPlace.longitude
        else {
            return Double.greatestFiniteMagnitude
        }

        let baseDistance: Double

        do {
            let route = try await RouteService.route(
                startLatitude: startLatitude,
                startLongitude: startLongitude,
                goalLatitude: goalLatitude,
                goalLongitude: goalLongitude
            )
            baseDistance = Double(route.distance)
        } catch {
            baseDistance = haversineDistance(
                startLatitude: startLatitude,
                startLongitude: startLongitude,
                goalLatitude: goalLatitude,
                goalLongitude: goalLongitude
            )
        }

        return baseDistance + consecutiveDiningPenalty(
            from: startPlace,
            to: goalPlace
        )
    }

    private func consecutiveDiningPenalty(
        from startPlace: DatePlace,
        to goalPlace: DatePlace
    ) -> Double {
        let diningCategories: Set<String> = ["식당", "카페"]
        let startCategory = PlaceCategoryNormalizer.categoryName(
            from: startPlace.categoryName
        )
        let goalCategory = PlaceCategoryNormalizer.categoryName(
            from: goalPlace.categoryName
        )

        return diningCategories.contains(startCategory) &&
            diningCategories.contains(goalCategory)
            ? 50_000
            : 0
    }

    private func haversineDistance(
        startLatitude: Double,
        startLongitude: Double,
        goalLatitude: Double,
        goalLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let startLatitudeRadians = startLatitude * .pi / 180
        let goalLatitudeRadians = goalLatitude * .pi / 180
        let latitudeDelta = (goalLatitude - startLatitude) * .pi / 180
        let longitudeDelta = (goalLongitude - startLongitude) * .pi / 180

        let haversine = sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
            cos(startLatitudeRadians) * cos(goalLatitudeRadians) *
            sin(longitudeDelta / 2) * sin(longitudeDelta / 2)

        return earthRadius * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }

    private func saveHistoryChanges() {
        do {
            try modelContext.save()
        } catch {
            print("데이트 수정 저장 실패: \(error)")
        }
    }

    private func deletePlaces(at offsets: IndexSet) {
        let placesToDelete = offsets.map { sortedPlaces[$0] }

        for place in placesToDelete {
            modelContext.delete(place)
        }

        reorderPlaces()

        do {
            try modelContext.save()
        } catch {
            print("장소 삭제 실패: \(error)")
        }
    }
    private func movePlaces(
        from source: IndexSet,
        to destination: Int
    ) {
        var reorderedPlaces = sortedPlaces

        reorderedPlaces.move(
            fromOffsets: source,
            toOffset: destination
        )

        for (index, place) in reorderedPlaces.enumerated() {
            place.order = index
        }

        do {
            try modelContext.save()
        } catch {
            print("장소 순서 저장 실패: \(error)")
        }
    }

    private func deleteHistory() {
        modelContext.delete(history)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("데이트 삭제 실패: \(error)")
        }
    }

    private func reorderPlaces() {
        let remainingPlaces = history.places
            .filter { !$0.isDeleted }
            .sorted { $0.order < $1.order }

        for (index, place) in remainingPlaces.enumerated() {
            place.order = index
        }
    }
}
