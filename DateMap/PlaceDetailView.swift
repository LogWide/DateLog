import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PlaceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    let place: DatePlace

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: DatePhoto?

    private let builtInCategories: [(name: String, emoji: String)] = [
        ("식당", "🍽️"),
        ("카페", "☕"),
        ("술", "🍺"),
        ("영화", "🎬"),
        ("쇼핑", "🛍️"),
        ("산책", "🌳"),
        ("숙소", "🏨"),
        ("드라이브", "🚗"),
        ("기타", "📍")
    ]

    private var categoryOptions: [(name: String, emoji: String)] {
        let normalizedCategory = PlaceCategoryNormalizer.categoryName(
            from: place.categoryName
        )

        if builtInCategories.contains(where: { $0.name == normalizedCategory }) {
            return builtInCategories
        }

        return [
            (
                normalizedCategory,
                PlaceCategoryNormalizer.emoji(for: normalizedCategory)
            )
        ] + builtInCategories
    }

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
    }

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
        VStack(alignment: .leading, spacing: 14) {
            Text("장소 정보")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("장소명")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "장소명",
                    text: Binding(
                        get: {
                            place.name
                        },
                        set: { newValue in
                            place.name = newValue
                            savePlaceChanges()
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 14) {
                Text("카테고리")
                    .font(.headline)
                    .foregroundStyle(selectedTheme.primaryColor)

                Spacer()

                Picker(
                    "카테고리",
                    selection: Binding(
                        get: {
                            PlaceCategoryNormalizer.categoryName(
                                from: place.categoryName
                            )
                        },
                        set: { newCategory in
                            let normalizedCategory = PlaceCategoryNormalizer.categoryName(
                                from: newCategory
                            )
                            place.categoryName = normalizedCategory
                            place.categoryEmoji = PlaceCategoryNormalizer.emoji(
                                for: normalizedCategory
                            )
                            savePlaceChanges()
                        }
                    )
                ) {
                    ForEach(categoryOptions, id: \.name) { category in
                        Text("\(category.emoji) \(category.name)")
                            .tag(category.name)
                    }
                }
                .pickerStyle(.menu)
                .font(.body.weight(.semibold))
                .tint(selectedTheme.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTheme.primaryColor.opacity(0.12))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("메모")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "메모",
                    text: Binding(
                        get: {
                            place.memo
                        },
                        set: { newValue in
                            place.memo = newValue
                            savePlaceChanges()
                        }
                    ),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            }

            if !place.address.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("주소")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(place.address)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            openInNaverMap()
                        } label: {
                            Label(
                                "네이버 지도",
                                systemImage: "map"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(
                            Color(
                                red: 0.18,
                                green: 0.74,
                                blue: 0.42
                            )
                        )

                        Button {
                            openInAppleMaps()
                        } label: {
                            Label(
                                "Apple 지도",
                                systemImage: "apple.logo"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
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

    private func openInNaverMap() {
        let encodedName = place.name.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? place.name

        guard
            let latitude = place.latitude,
            let longitude = place.longitude
        else {
            openNaverMapWebSearch(encodedName: encodedName)
            return
        }

        let appName = Bundle.main.bundleIdentifier ?? "DateMap"

        guard let appURL = URL(
            string:
                "nmap://place?lat=\(latitude)&lng=\(longitude)&name=\(encodedName)&appname=\(appName)"
        ) else {
            openNaverMapWebSearch(encodedName: encodedName)
            return
        }

        UIApplication.shared.open(
            appURL,
            options: [:]
        ) { success in
            if !success {
                openNaverMapWebSearch(encodedName: encodedName)
            }
        }
    }

    private func openNaverMapWebSearch(
        encodedName: String
    ) {
        guard let webURL = URL(
            string: "https://map.naver.com/p/search/\(encodedName)"
        ) else {
            return
        }

        UIApplication.shared.open(webURL)
    }

    private func openInAppleMaps() {
        var components = URLComponents(
            string: "https://maps.apple.com/"
        )

        var queryItems = [
            URLQueryItem(name: "q", value: place.name)
        ]

        if
            let latitude = place.latitude,
            let longitude = place.longitude
        {
            queryItems.append(
                URLQueryItem(
                    name: "ll",
                    value: "\(latitude),\(longitude)"
                )
            )
        } else if !place.address.isEmpty {
            queryItems.append(
                URLQueryItem(
                    name: "address",
                    value: place.address
                )
            )
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            return
        }

        UIApplication.shared.open(url)
    }

    private func savePlaceChanges() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "장소 정보를 저장하지 못했습니다."
            print("장소 수정 저장 실패: \(error)")
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
