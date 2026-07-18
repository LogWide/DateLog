import SwiftUI
import SwiftData
import UIKit

private enum AlbumPhotoSource: Identifiable, Hashable {
    case placePhoto(UUID)
    case diary(UUID)

    var id: String {
        switch self {
        case .placePhoto(let id):
            return "place-\(id.uuidString)"
        case .diary(let id):
            return "diary-\(id.uuidString)"
        }
    }
}

private struct AlbumPhotoItem: Identifiable, Hashable {
    let source: AlbumPhotoSource
    let imageData: Data
    let date: Date
    let title: String
    let subtitle: String
    let history: DateHistory?
    let diary: Diary?

    var id: String {
        source.id
    }
}

struct AlbumView: View {
    @Query(sort: \DatePhoto.createdAt, order: .reverse)
    private var placePhotos: [DatePhoto]

    @Query(sort: \Diary.createdAt, order: .reverse)
    private var diaries: [Diary]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: AlbumPhotoItem?

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    private var albumItems: [AlbumPhotoItem] {
        let placeItems = placePhotos.compactMap { photo -> AlbumPhotoItem? in
            guard let imageData = photo.imageData else {
                return nil
            }

            let place = photo.place
            let history = place?.history

            return AlbumPhotoItem(
                source: .placePhoto(photo.id),
                imageData: imageData,
                date: photo.createdAt,
                title: history?.title ?? place?.name ?? "장소 사진",
                subtitle: place?.name ?? "장소 정보 없음",
                history: history,
                diary: nil
            )
        }

        let diaryItems = diaries.compactMap { diary -> AlbumPhotoItem? in
            guard let imageData = diary.photoData else {
                return nil
            }

            return AlbumPhotoItem(
                source: .diary(diary.persistentModelID.hashValue.uuidValue),
                imageData: imageData,
                date: diary.createdAt,
                title: diary.title.isEmpty ? "일기" : diary.title,
                subtitle: "일기 사진",
                history: nil,
                diary: diary
            )
        }

        return (placeItems + diaryItems).sorted {
            $0.date > $1.date
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if albumItems.isEmpty {
                    ContentUnavailableView(
                        "앨범이 비어 있습니다",
                        systemImage: "photo.on.rectangle",
                        description: Text("데이트 장소나 일기에 사진을 추가하면 여기에 모입니다.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(albumItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    albumThumbnail(item)
                                }
                                .buttonStyle(AlbumThumbnailButtonStyle())
                                .contentShape(Rectangle())
                                .clipped()
                            }
                        }
                        .padding(3)
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle("앨범")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $selectedItem) { item in
                AlbumPhotoDetailView(item: item)
            }
        }
    }

    private func albumThumbnail(
        _ item: AlbumPhotoItem
    ) -> some View {
        Group {
            if let image = UIImage(data: item.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.16)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private struct AlbumThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct AlbumPhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsInfo = false
    @State private var selectedDiary: Diary?

    let item: AlbumPhotoItem

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)

                    if let image = UIImage(data: item.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, showsInfo ? 260 : 0)
                            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showsInfo)
                    } else {
                        ContentUnavailableView(
                            "사진을 불러올 수 없습니다",
                            systemImage: "photo.badge.exclamationmark"
                        )
                        .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)
                }
                .overlay(alignment: .bottomLeading) {
                    if !showsInfo {
                        Text(DateDisplayFormatter.string(from: item.date))
                            .font(.pretendard(size: 13, weight: .light))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard showsInfo else {
                        return
                    }

                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showsInfo = false
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                if value.translation.height < -42 {
                                    showsInfo = true
                                } else if value.translation.height > 42 {
                                    showsInfo = false
                                }
                            }
                        }
                )

                if showsInfo {
                    infoPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("닫기")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showsInfo.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("사진 정보")
                }
            }
            .sheet(item: $selectedDiary) { diary in
                AddDiaryView(date: diary.date, diary: diary)
            }
        }
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

            Text(DateDisplayFormatter.string(from: item.date))
                .font(.pretendard(size: 24, weight: .extraBold))
                .foregroundStyle(.primary)

            Text(item.title)
                .font(.pretendard(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Label(item.subtitle, systemImage: item.diary == nil ? "mappin.and.ellipse" : "book.closed.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("올린 날 \(DateDisplayFormatter.string(from: item.date))", systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let history = item.history {
                NavigationLink {
                    DateHistoryDetailView(history: history)
                } label: {
                    Text("\(history.title) 데이트에서 보기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if let diary = item.diary {
                Button {
                    selectedDiary = diary
                } label: {
                    Text("\(diary.title.isEmpty ? "일기" : diary.title) 일기로 이동하기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 310, alignment: .top)
        .background(.regularMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                topTrailingRadius: 26
            )
        )
    }
}

private extension Int {
    var uuidValue: UUID {
        let hex = String(format: "%032x", abs(self))
        let first = String(hex.prefix(8))
        let second = String(hex.dropFirst(8).prefix(4))
        let third = String(hex.dropFirst(12).prefix(4))
        let fourth = String(hex.dropFirst(16).prefix(4))
        let fifth = String(hex.dropFirst(20).prefix(12))
        return UUID(uuidString: "\(first)-\(second)-\(third)-\(fourth)-\(fifth)") ?? UUID()
    }
}
