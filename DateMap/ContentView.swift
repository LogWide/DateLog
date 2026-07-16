import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    @State private var selectedCoordinate: CoordinateData?
    @State private var selectedSavedPlace: DatePlace?
    @State private var selectedPlaceName = ""

    @State private var isShowingSavePlace = false
    @State private var isShowingPlaceSearch = false
    @State private var isShowingMapPinPicker = false
    @State private var directPlaceName = ""

    @State private var selectedHistory: DateHistory?
    private var displayedPlaces: [DatePlace] {
        selectedHistory?.places.sorted {
            $0.order < $1.order
        } ?? []
    }

    var body: some View {
        TabView {
            HistoryView()
                .tabItem {
                    Label("기록", systemImage: "calendar")
                }

            NavigationStack {
                ZStack(alignment: .bottom) {
                    MapView(
                        places: displayedPlaces,
                        selectedCoordinate: $selectedCoordinate,
                        selectedSavedPlace: $selectedSavedPlace,
                        selectedPlaceName: $selectedPlaceName
                    )
                    .ignoresSafeArea(edges: .top)

                    VStack(spacing: 12) {
                        historyPicker

                        if let place = selectedSavedPlace {
                            savedPlaceCard(place)
                        }

                        if let coordinate = selectedCoordinate {
                            selectedCoordinateCard(coordinate)
                        }
                    }
                    .padding()
                }
                .navigationTitle("지도")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingPlaceSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("장소 검색")
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
                    onDirectAdd: { directName in
                        selectedSavedPlace = nil
                        selectedPlaceName = directName
                        selectedCoordinate = nil
                    }
                )
            }
            .onAppear {
                if selectedHistory == nil {
                    selectedHistory = histories.first
                }
            }
            .tabItem {
                Label("지도", systemImage: "map")
            }
        }
    }

    private var historyPicker: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)

            if histories.isEmpty {
                Text("저장된 데이트가 없습니다")
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    "데이트",
                    selection: $selectedHistory
                ) {
                    Text("데이트 선택")
                        .tag(nil as DateHistory?)

                    ForEach(histories) { history in
                        Text(
                            "\(history.title) · \(history.date.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .tag(history as DateHistory?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedHistory) {
                    selectedCoordinate = nil
                    selectedSavedPlace = nil
                }
            }

            Spacer()

            Text("\(displayedPlaces.count)곳")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func selectedCoordinateCard(
        _ coordinate: CoordinateData
    ) -> some View {
        VStack(spacing: 8) {
            Text(
                selectedPlaceName.isEmpty
                    ? "새 위치"
                    : selectedPlaceName
            )
            .font(.headline)

            Text(
                String(
                    format: "%.6f, %.6f",
                    coordinate.latitude,
                    coordinate.longitude
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("선택 취소") {
                    selectedCoordinate = nil
                    selectedPlaceName = ""
                }
                .buttonStyle(.bordered)

                Button("이 위치 저장") {
                    isShowingSavePlace = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func savedPlaceCard(
        _ place: DatePlace
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(place.order + 1)번째 장소")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(place.name)
                        .font(.headline)
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

            if !place.memo.isEmpty {
                Text(place.memo)
                    .font(.subheadline)
            }

            if
                let latitude = place.latitude,
                let longitude = place.longitude
            {
                Text(
                    String(
                        format: "%.6f, %.6f",
                        latitude,
                        longitude
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    @State private var isShowingAddView = false

    var body: some View {
        NavigationStack {
            Group {
                if histories.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없습니다",
                        systemImage: "heart.text.clipboard",
                        description: Text("오른쪽 위 + 버튼으로 첫 데이트를 기록하세요.")
                    )
                } else {
                    List {
                        ForEach(histories) { history in
                            NavigationLink {
                                DateHistoryDetailView(history: history)
                            } label: {
                                HistoryRow(history: history)
                            }
                        }
                        .onDelete(perform: deleteHistories)
                    }
                }
            }
            .navigationTitle("DateLog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("데이트 추가")
                }
            }
            .sheet(isPresented: $isShowingAddView) {
                AddDateHistoryView()
            }
        }
    }

    private func deleteHistories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(histories[index])
        }

        do {
            try modelContext.save()
        } catch {
            print("기록 삭제 실패: \(error)")
        }
    }
}

// MARK: - 데이트 목록 행

private struct HistoryRow: View {
    let history: DateHistory

    private var sortedPlaces: [DatePlace] {
        history.places.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(history.title)
                .font(.headline)

            Text(
                history.date.formatted(
                    date: .long,
                    time: .omitted
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !sortedPlaces.isEmpty {
                Text(
                    sortedPlaces
                        .map(\.name)
                        .joined(separator: " → ")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            if !history.memo.isEmpty {
                Text(history.memo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 데이트 추가

private struct AddDateHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var selectedDate = Date()
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("데이트 제목", text: $title)

                    DatePicker(
                        "날짜",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                }

                Section("메모") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle("데이트 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveHistory()
                    }
                    .disabled(cleanTitle.isEmpty)
                }
            }
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveHistory() {
        guard !cleanTitle.isEmpty else {
            return
        }

        let history = DateHistory(
            title: cleanTitle,
            date: selectedDate,
            memo: memo.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )

        modelContext.insert(history)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("기록 저장 실패: \(error)")
        }
    }
}

// MARK: - 데이트 상세

private struct DateHistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let history: DateHistory

    @State private var isShowingAddPlace = false

    private var sortedPlaces: [DatePlace] {
        history.places.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            Section("날짜") {
                Text(
                    history.date.formatted(
                        date: .long,
                        time: .omitted
                    )
                )
            }

            Section {
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
                                    .background(.blue)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name)
                                        .foregroundStyle(.primary)

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

                                if let firstPhoto = place.photos
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
            } header: {
                HStack {
                    Text("장소")

                    Spacer()

                    Text("\(sortedPlaces.count)곳")
                }
            }

            Section("메모") {
                if history.memo.isEmpty {
                    Text("작성된 메모가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(history.memo)
                }
            }
        }
        .navigationTitle(history.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()

                Button {
                    isShowingAddPlace = true
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .accessibilityLabel("장소 추가")
            }
        }
        .sheet(isPresented: $isShowingAddPlace) {
            AddPlaceView(history: history)
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

    private func reorderPlaces() {
        let remainingPlaces = history.places
            .filter { !$0.isDeleted }
            .sorted { $0.order < $1.order }

        for (index, place) in remainingPlaces.enumerated() {
            place.order = index
        }
    }
}
private struct PlaceDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let place: DatePlace

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: DatePhoto?

    private var sortedPhotos: [DatePhoto] {
        place.photos.sorted {
            if $0.order == $1.order {
                return $0.createdAt < $1.createdAt
            }

            return $0.order < $1.order
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                placeInformationSection
                photoSection
            }
            .padding()
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Image(systemName: "photo.badge.plus")
                }
                .accessibilityLabel("사진 추가")
                .disabled(isImportingPhotos)
            }
        }
        .onChange(of: selectedPhotoItems) {
            guard !selectedPhotoItems.isEmpty else {
                return
            }

            Task {
                await importSelectedPhotos()
            }
        }
        .alert(
            "사진을 추가하지 못했습니다",
            isPresented: Binding(
                get: {
                    errorMessage != nil
                },
                set: { newValue in
                    if !newValue {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoGalleryView(
                photos: sortedPhotos,
                initialPhotoID: photo.id
            )
        }
    }

    private var placeInformationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("장소 정보")
                .font(.headline)

            if !place.memo.isEmpty {
                Text(place.memo)
                    .foregroundStyle(.secondary)
            }

            if
                let latitude = place.latitude,
                let longitude = place.longitude
            {
                Text(
                    String(
                        format: "%.6f, %.6f",
                        latitude,
                        longitude
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("사진")
                    .font(.headline)

                Spacer()

                if isImportingPhotos {
                    ProgressView()
                } else {
                    Text("\(sortedPhotos.count)장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if sortedPhotos.isEmpty {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)

                        Text("사진 추가")
                            .font(.headline)

                        Text("이 장소의 사진을 여러 장 선택할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(.quaternary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isImportingPhotos)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(sortedPhotos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            PhotoThumbnailView(photo: photo)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(
                                "사진 삭제",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                deletePhoto(photo)
                            }
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title2)

                            Text("추가")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(.quaternary)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isImportingPhotos)
                }
            }
        }
    }

    @MainActor
    private func importSelectedPhotos() async {
        guard !selectedPhotoItems.isEmpty else {
            return
        }

        isImportingPhotos = true
        errorMessage = nil

        defer {
            isImportingPhotos = false
            selectedPhotoItems = []
        }

        var nextOrder =
            (place.photos.map(\.order).max() ?? -1) + 1

        var importedCount = 0

        for item in selectedPhotoItems {
            do {
                guard
                    let originalData = try await item.loadTransferable(
                        type: Data.self
                    ),
                    let image = UIImage(data: originalData),
                    let compressedData = image.jpegData(
                        compressionQuality: 0.82
                    )
                else {
                    continue
                }

                let photo = DatePhoto(
                    imageData: compressedData,
                    order: nextOrder,
                    place: place
                )

                place.photos.append(photo)
                modelContext.insert(photo)

                nextOrder += 1
                importedCount += 1
            } catch {
                print("사진 가져오기 실패: \(error)")
            }
        }

        guard importedCount > 0 else {
            errorMessage = "선택한 사진을 불러오지 못했습니다."
            return
        }

        do {
            try modelContext.save()
            place.photos.sort {
                $0.order < $1.order
            }
        } catch {
            errorMessage = "사진 저장 중 오류가 발생했습니다."
            print("사진 저장 실패: \(error)")
        }
    }

    private func deletePhoto(
        _ photo: DatePhoto
    ) {
        modelContext.delete(photo)

        let remainingPhotos = place.photos
            .filter { $0 !== photo }
            .sorted { $0.order < $1.order }

        for (index, remainingPhoto) in remainingPhotos.enumerated() {
            remainingPhoto.order = index
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "사진을 삭제하지 못했습니다."
            print("사진 삭제 실패: \(error)")
        }
    }
}

private struct PhotoThumbnailView: View {
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
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - 장소 추가

private struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let history: DateHistory

    @State private var name = ""
    @State private var memo = ""

    @State private var latitude: Double?
    @State private var longitude: Double?

    @State private var searchResults: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var searchErrorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var isShowingMapPinPicker = false
    @State private var directPlaceName = ""

    @State private var shouldSkipNextSearch = false

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

                Section("메모") {
                    TextField(
                        "메모",
                        text: $memo,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                if
                    let latitude,
                    let longitude
                {
                    Section("선택된 위치") {
                        Text(
                            String(
                                format: "%.6f, %.6f",
                                latitude,
                                longitude
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    searchResults = []
                    searchErrorMessage = nil
                }
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

        searchResults = []
        searchErrorMessage = nil
    }

    private func savePlace() {
        guard
            !cleanName.isEmpty,
            let latitude,
            let longitude
        else {
            return
        }

        let nextOrder =
            (history.places.map(\.order).max() ?? -1) + 1

        let place = DatePlace(
            name: cleanName,
            order: nextOrder,
            memo: cleanMemo,
            latitude: latitude,
            longitude: longitude
        )

        place.history = history
        history.places.append(place)

        modelContext.insert(place)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("장소 저장 실패: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                DateHistory.self,
                DatePlace.self,
                DatePhoto.self
            ],
            inMemory: true
        )
}
