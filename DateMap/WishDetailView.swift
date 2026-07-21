//
//  WishDetailView.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import SwiftUI
import SwiftData

struct WishDetailView: View {
    @Bindable var wish: Wish

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishFolder.createdAt) private var folders: [WishFolder]

    @State private var isAddingFolder = false
    @State private var newFolderName = ""

    @State private var isShowingAddToDatePrompt = false
    @State private var isShowingHistoryPicker = false
    @State private var isShowingPlanPicker = false

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    var body: some View {
        Form {
            Section("장소") {
                Text(wish.name)
                    .font(.headline)

                if !wish.address.isEmpty {
                    Text(wish.address)
                        .foregroundStyle(.secondary)
                }
            }

            Section("폴더") {
                ForEach(folders) { folder in
                    Button {
                        // 같은 폴더를 다시 누르면 선택 해제된다
                        wish.folder = wish.folder == folder.name ? "" : folder.name
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: "folder")
                                .foregroundStyle(.primary)

                            Spacer()

                            if wish.folder == folder.name {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedTheme.primaryColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if isAddingFolder {
                    HStack(spacing: 10) {
                        TextField("새 폴더 이름", text: $newFolderName)

                        Button {
                            addFolder()
                        } label: {
                            Text("추가")
                                .font(.pretendard(size: 14, weight: .bold))
                                .foregroundStyle(selectedTheme.primaryColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            newFolderName
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )
                    }
                } else {
                    Button {
                        isAddingFolder = true
                    } label: {
                        Label("폴더 추가", systemImage: "plus")
                            .foregroundStyle(selectedTheme.primaryColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("메모") {
                TextEditor(text: $wish.memo)
                    .frame(minHeight: 120)
            }

            Section("방문") {
                if wish.isVisited {
                    HStack {
                        Label("방문 완료", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        Spacer()

                        if let visitedDate = wish.visitedDate {
                            Text(DateDisplayFormatter.string(from: visitedDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // 방문 완료는 한번 표시하면 되돌릴 수 없다.
                    // 되돌리려면 데이트에 추가된 장소를 삭제해야 한다.
                    Button {
                        wish.isVisited = true
                        wish.visitedDate = Date()
                        isShowingAddToDatePrompt = true
                    } label: {
                        Label("방문 완료로 표시", systemImage: "checkmark.circle")
                            .foregroundStyle(selectedTheme.primaryColor)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isShowingPlanPicker = true
                } label: {
                    Label("데이트 계획에 추가", systemImage: "calendar.badge.plus")
                        .foregroundStyle(selectedTheme.primaryColor)
                }
                .buttonStyle(.plain)
            }
        }
        .alert(
            "데이트 기록에 추가할까요?",
            isPresented: $isShowingAddToDatePrompt
        ) {
            Button("예") {
                isShowingHistoryPicker = true
            }

            Button("아니오", role: .cancel) {}
        } message: {
            Text("이 장소를 다녀온 데이트 기록에 함께 담을 수 있어요.")
        }
        .sheet(isPresented: $isShowingHistoryPicker) {
            WishHistoryPickerView(historyType: .record) { history in
                addWishPlace(to: history)
                wish.visitedDate = history.date
            }
        }
        .sheet(isPresented: $isShowingPlanPicker) {
            WishHistoryPickerView(historyType: .plan) { plan in
                addWishPlace(to: plan)
            }
        }
        .dateLogListBackground(selectedTheme)
        .navigationTitle("위시")
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

    /// 새 폴더를 만들고 곧바로 이 위시에 지정한다.
    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            return
        }

        if !folders.contains(where: { $0.name == name }) {
            modelContext.insert(WishFolder(name: name))
        }

        wish.folder = name
        newFolderName = ""
        isAddingFolder = false
    }

    /// 선택한 데이트 기록/계획에 이 위시를 장소로 추가한다.
    private func addWishPlace(to history: DateHistory) {
        let nextOrder = (history.places.map(\.order).max() ?? -1) + 1
        let categoryName = PlaceCategoryNormalizer.categoryName(
            from: wish.category
        )
        let hasCoordinate = wish.latitude != 0 || wish.longitude != 0

        let place = DatePlace(
            name: wish.name,
            order: nextOrder,
            memo: wish.memo,
            latitude: hasCoordinate ? wish.latitude : nil,
            longitude: hasCoordinate ? wish.longitude : nil,
            address: wish.address,
            categoryName: categoryName,
            categoryEmoji: PlaceCategoryNormalizer.emoji(for: categoryName),
            sourceWishID: wish.id
        )
        place.history = history

        modelContext.insert(place)
    }
}

/// 위시를 담을 데이트 기록/계획을 고르는 시트.
/// 저장된 항목이 없으면 오른쪽 위 "새로 만들기"로 바로 만들 수 있다.
private struct WishHistoryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \DateHistory.date, order: .reverse)
    private var histories: [DateHistory]

    let historyType: DateHistoryType
    let onSelect: (DateHistory) -> Void

    @State private var isShowingNewDate = false

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private var records: [DateHistory] {
        histories.filter { $0.type == historyType }
    }

    private var typeTitle: String {
        historyType == .plan ? "계획" : "데이트"
    }

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    ContentUnavailableView(
                        "저장된 \(typeTitle)이 없습니다",
                        systemImage: "calendar.badge.plus",
                        description: Text("오른쪽 위 ‘새로 만들기’로 \(typeTitle)을 먼저 만들어보세요.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(records) { history in
                        Button {
                            onSelect(history)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(history.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(DateDisplayFormatter.string(from: history.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedTheme.cardBackgroundColor)
                    }
                }
            }
            .dateLogListBackground(selectedTheme)
            .navigationTitle("\(typeTitle) 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("새로 만들기") {
                        isShowingNewDate = true
                    }
                }
            }
            .sheet(isPresented: $isShowingNewDate) {
                AddDateHistoryView(startsAsPlan: historyType == .plan)
            }
            .tint(selectedTheme.primaryColor)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Wish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let wish = Wish(name: "성수 카페")
    container.mainContext.insert(wish)

    return NavigationStack {
        WishDetailView(wish: wish)
    }
    .modelContainer(container)
}
