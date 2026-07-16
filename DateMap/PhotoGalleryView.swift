import SwiftUI
import SwiftData
import UIKit

struct PhotoGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let photos: [DatePhoto]
    let initialPhotoID: UUID

    @State private var selectedPhotoID: UUID
    @State private var photoPendingDeletion: DatePhoto?
    @State private var isShowingDeleteConfirmation = false

    init(
        photos: [DatePhoto],
        initialPhotoID: UUID
    ) {
        let sortedPhotos = photos.sorted {
            if $0.order == $1.order {
                return $0.createdAt < $1.createdAt
            }

            return $0.order < $1.order
        }

        self.photos = sortedPhotos
        self.initialPhotoID = initialPhotoID
        _selectedPhotoID = State(
            initialValue: initialPhotoID
        )
    }

    private var currentPhoto: DatePhoto? {
        photos.first {
            $0.id == selectedPhotoID
        }
    }

    private var currentIndex: Int? {
        photos.firstIndex {
            $0.id == selectedPhotoID
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if photos.isEmpty {
                    ContentUnavailableView(
                        "사진이 없습니다",
                        systemImage: "photo"
                    )
                    .foregroundStyle(.white)
                } else {
                    TabView(selection: $selectedPhotoID) {
                        ForEach(photos) { photo in
                            photoPage(photo)
                                .tag(photo.id)
                        }
                    }
                    .tabViewStyle(
                        .page(indexDisplayMode: .automatic)
                    )
                }
            }
            .navigationTitle(photoCounterText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button(
                        role: .destructive
                    ) {
                        photoPendingDeletion = currentPhoto
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(currentPhoto == nil)
                }
            }
            .confirmationDialog(
                "사진을 삭제하시겠습니까?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    "삭제",
                    role: .destructive
                ) {
                    deleteSelectedPhoto()
                }

                Button(
                    "취소",
                    role: .cancel
                ) {
                    photoPendingDeletion = nil
                }
            }
        }
    }

    private var photoCounterText: String {
        guard
            let currentIndex,
            !photos.isEmpty
        else {
            return ""
        }

        return "\(currentIndex + 1) / \(photos.count)"
    }

    private func photoPage(
        _ photo: DatePhoto
    ) -> some View {

        Group {
            if
                let data = photo.imageData,
                let uiImage = UIImage(data: data)
            {
                ZoomableImageView(image: uiImage)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "사진을 불러올 수 없습니다",
                    systemImage: "photo.badge.exclamationmark"
                )
                .foregroundStyle(.white)
            }
        }
    }
    private func deleteSelectedPhoto() {
        guard let photo = photoPendingDeletion else {
            return
        }

        let deletedIndex = photos.firstIndex {
            $0.id == photo.id
        }

        modelContext.delete(photo)

        do {
            try modelContext.save()
        } catch {
            print("사진 삭제 실패: \(error)")
            return
        }

        photoPendingDeletion = nil

        guard photos.count > 1 else {
            dismiss()
            return
        }

        let remainingPhotos = photos.filter {
            $0.id != photo.id
        }

        let nextIndex = min(
            deletedIndex ?? 0,
            remainingPhotos.count - 1
        )

        selectedPhotoID = remainingPhotos[nextIndex].id
    }
}
