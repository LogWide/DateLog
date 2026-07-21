//
//  Wishlistview.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import SwiftUI
import SwiftData

struct WishlistView: View {
    private enum WishViewMode {
        case all
        case folders
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wish.createdAt, order: .reverse) private var wishes: [Wish]
    @Query(sort: \WishFolder.createdAt) private var folders: [WishFolder]

    @State private var isShowingPlaceSearch = false

    /// 전체 위시 보기 / 폴더별 보기
    @State private var viewMode: WishViewMode = .all
    @State private var isShowingAddFolderAlert = false
    @State private var newFolderName = ""

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var activeWishes: [Wish] {
        wishes.filter { !$0.isVisited }
    }

    private var visitedWishes: [Wish] {
        wishes.filter { $0.isVisited }
    }

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerExtension

                VStack(alignment: .leading, spacing: 20) {
                    if viewMode == .folders {
                        folderListSection
                    } else if wishes.isEmpty {
                        emptyState
                    } else {
                        if !activeWishes.isEmpty {
                            WishSectionView(
                                title: "가보고 싶은 곳",
                                subtitle: "다음 데이트 후보",
                                wishes: activeWishes
                            )
                        }

                        if !visitedWishes.isEmpty {
                            WishSectionView(
                                title: "다녀온 곳",
                                subtitle: "위시리스트에서 추억으로 이동한 장소",
                                wishes: visitedWishes
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(selectedTheme.backgroundColor)
        .navigationTitle("위시리스트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .tint(selectedTheme.primaryColor)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewMode = .all
                    } label: {
                        if viewMode == .all {
                            Label("전체 위시 보기", systemImage: "checkmark")
                        } else {
                            Text("전체 위시 보기")
                        }
                    }

                    Button {
                        viewMode = .folders
                    } label: {
                        if viewMode == .folders {
                            Label("폴더별 보기", systemImage: "checkmark")
                        } else {
                            Text("폴더별 보기")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(selectedTheme.navigationTextColor)
                }
                .accessibilityLabel("보기 방식")

                Menu {
                    Button {
                        isShowingPlaceSearch = true
                    } label: {
                        Label("위시 추가", systemImage: "mappin.and.ellipse")
                    }

                    Button {
                        isShowingAddFolderAlert = true
                    } label: {
                        Label("폴더 추가", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(selectedTheme.navigationTextColor)
                }
                .accessibilityLabel("추가")
            }
        }
        .alert("폴더 추가", isPresented: $isShowingAddFolderAlert) {
            TextField("폴더 이름", text: $newFolderName)

            Button("추가") {
                addFolder()
            }

            Button("취소", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("위시를 묶어 볼 폴더를 만듭니다.")
        }
        .navigationDestination(for: WishFolder.self) { folder in
            WishFolderDetailView(folder: folder)
        }
        .sheet(isPresented: $isShowingPlaceSearch) {
            PlaceSearchView(
                onSelect: { result in
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
                    isShowingPlaceSearch = false
                },
                onDirectAdd: { placeName in
                    let trimmedName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }

                    let wish = Wish(
                        name: trimmedName,
                        address: "",
                        category: "",
                        memo: ""
                    )

                    modelContext.insert(wish)
                    isShowingPlaceSearch = false
                }
            )
        }
    }

    /// 흰 헤더가 아래로 길게 이어진 것처럼 보이는 설명 영역.
    /// 타이틀과는 옅은 점선으로 구분한다.
    private var headerExtension: some View {
        VStack(alignment: .leading, spacing: 13) {
            HorizontalDashLine()
                .stroke(
                    selectedTheme.primaryColor.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: 1,
                        lineCap: .round,
                        dash: [4, 5]
                    )
                )
                .frame(height: 1)

            Text("가고 싶은 곳을 모아두고,\n다녀오면 자연스럽게 기록으로 넘겨보세요.")
                .font(.pretendard(size: 16, weight: .semiBold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectedTheme.color)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(selectedTheme.primaryColor)

            VStack(spacing: 5) {
                Text("아직 담아둔 장소가 없습니다")
                    .font(.pretendard(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text("생각나는 장소를 추가해두면 데이트 계획을 세울 때 바로 꺼내볼 수 있어요.")
                    .font(.pretendard(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                isShowingPlaceSearch = true
            } label: {
                Label("장소 추가", systemImage: "plus")
                    .font(.pretendard(size: 15, weight: .semiBold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedTheme.primaryColor)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .dateLogCard(selectedTheme, cornerRadius: 18)
    }

    // MARK: - 폴더별 보기

    private var folderListSection: some View {
        VStack(spacing: 10) {
            if folders.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(selectedTheme.primaryColor)

                    Text("아직 폴더가 없습니다")
                        .font(.pretendard(size: 16, weight: .bold))

                    Text("오른쪽 위 + 메뉴에서 폴더를 추가해보세요.")
                        .font(.pretendard(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .dateLogCard(selectedTheme, cornerRadius: 18)
            } else {
                ForEach(folders) { folder in
                    NavigationLink(value: folder) {
                        folderRow(folder)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteFolder(folder)
                        } label: {
                            Label("폴더 삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func folderRow(_ folder: WishFolder) -> some View {
        let folderWishes = wishes.filter { $0.folder == folder.name }
        let visitedCount = folderWishes.filter(\.isVisited).count

        return HStack(spacing: 13) {
            Image(systemName: "folder.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedTheme.primaryColor)
                .frame(width: 44, height: 44)
                .background(selectedTheme.primaryColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text(folder.name)
                .font(.pretendard(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("위시 달성 \(visitedCount)/\(folderWishes.count)")
                .font(.pretendard(size: 12, weight: .semiBold))
                .foregroundStyle(selectedTheme.primaryColor)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dateLogCard(selectedTheme, cornerRadius: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""

        guard
            !name.isEmpty,
            !folders.contains(where: { $0.name == name })
        else {
            return
        }

        modelContext.insert(WishFolder(name: name))
    }

    private func deleteFolder(_ folder: WishFolder) {
        // 폴더에 담겨 있던 위시는 폴더 없음 상태로 돌린다
        for wish in wishes where wish.folder == folder.name {
            wish.folder = ""
        }

        modelContext.delete(folder)
    }
}

// MARK: - 폴더 상세

private struct WishFolderDetailView: View {
    let folder: WishFolder

    @Query(sort: \Wish.createdAt, order: .reverse) private var wishes: [Wish]

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private var folderWishes: [Wish] {
        wishes.filter { $0.folder == folder.name }
    }

    private var activeWishes: [Wish] {
        folderWishes.filter { !$0.isVisited }
    }

    private var visitedWishes: [Wish] {
        folderWishes.filter { $0.isVisited }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if folderWishes.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(selectedTheme.primaryColor)

                        Text("폴더가 비어 있습니다")
                            .font(.pretendard(size: 16, weight: .bold))

                        Text("위시 상세 화면에서 이 폴더를 선택하면 여기에 모입니다.")
                            .font(.pretendard(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .dateLogCard(selectedTheme, cornerRadius: 18)
                } else {
                    if !activeWishes.isEmpty {
                        WishSectionView(
                            title: "가보고 싶은 곳",
                            subtitle: "다음 데이트 후보",
                            wishes: activeWishes
                        )
                    }

                    if !visitedWishes.isEmpty {
                        WishSectionView(
                            title: "다녀온 곳",
                            subtitle: "위시리스트에서 추억으로 이동한 장소",
                            wishes: visitedWishes
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(selectedTheme.backgroundColor)
        .navigationTitle(folder.name)
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

// MARK: - 위시 섹션 / 행

private struct WishSectionView: View {
    let title: String
    let subtitle: String
    let wishes: [Wish]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.pretendard(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.pretendard(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(wishes) { wish in
                    WishRowCard(wish: wish)
                }
            }
        }
    }
}

private struct WishRowCard: View {
    let wish: Wish

    @Environment(\.modelContext) private var modelContext

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    var body: some View {
        NavigationLink {
            WishDetailView(wish: wish)
        } label: {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(wish.isVisited ? Color.green.opacity(0.12) : selectedTheme.primaryColor.opacity(0.12))

                    Image(systemName: wish.isVisited ? "checkmark.circle.fill" : "mappin")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(wish.isVisited ? .green : selectedTheme.primaryColor)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(wish.name)
                            .font(.pretendard(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        if wish.isVisited {
                            if let visitedDate = wish.visitedDate {
                                Text(shortDateText(visitedDate))
                                    .font(.pretendard(size: 11, weight: .bold))
                                    .foregroundStyle(.green)
                            }

                            statusBadge("완료", color: .green)
                        }
                    }

                    if !wish.address.isEmpty {
                        Label(wish.address, systemImage: "location")
                            .font(.pretendard(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if !wish.category.isEmpty || !wish.memo.isEmpty {
                        HStack(spacing: 8) {
                            if !wish.category.isEmpty {
                                Text(wish.category)
                                    .font(.pretendard(size: 12, weight: .semiBold))
                                    .foregroundStyle(selectedTheme.primaryColor)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(selectedTheme.primaryColor.opacity(0.10))
                                    .clipShape(Capsule())
                            }

                            if !wish.memo.isEmpty {
                                Text(wish.memo)
                                    .font(.pretendard(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dateLogCard(selectedTheme, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(wish)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    /// 방문일을 "7/20" 형태로 짧게 표시한다.
    private func shortDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func statusBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.pretendard(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        WishlistView()
    }
    .modelContainer(
        for: [Wish.self, WishFolder.self],
        inMemory: true
    )
}
