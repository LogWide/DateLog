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

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
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
                Label(
                    history.type.displayName,
                    systemImage: history.type.systemImage
                )

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
        .tint(selectedTheme.primaryColor)
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
            "이 \(history.type.displayName)을 삭제할까요?",
            isPresented: $showingDeleteAlert
        ) {
            Button("삭제", role: .destructive) {
                deleteHistory()
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("\(history.type.displayName)과 장소 정보가 모두 삭제되며 복구할 수 없습니다.")
        }
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $selectedCoverPhotoItem,
            matching: .images
        )
        .task(id: selectedCoverPhotoItem) {
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
