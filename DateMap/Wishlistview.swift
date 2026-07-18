//
//  Wishlistview.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wish.createdAt, order: .reverse) private var wishes: [Wish]

    @State private var isShowingPlaceSearch = false

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.pink.rawValue

    private var activeWishes: [Wish] {
        wishes.filter { !$0.isVisited }
    }

    private var visitedWishes: [Wish] {
        wishes.filter { $0.isVisited }
    }

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .pink
    }

    var body: some View {
        Group {
            if wishes.isEmpty {
                ContentUnavailableView(
                    "위시리스트가 비어 있습니다",
                    systemImage: "heart.text.square",
                    description: Text("가고 싶은 장소를 하나씩 담아보세요.")
                )
            } else {
                List {
                    if !activeWishes.isEmpty {
                        Section("위시리스트") {
                            ForEach(activeWishes) { wish in
                                wishRow(wish)
                            }
                            .onDelete(perform: deleteActiveWishes)
                        }
                    }

                    if !visitedWishes.isEmpty {
                        Section("방문 완료") {
                            ForEach(visitedWishes) { wish in
                                wishRow(wish)
                            }
                            .onDelete(perform: deleteVisitedWishes)
                        }
                    }
                }
            }
        }
        .navigationTitle("위시리스트")
        .tint(selectedTheme.primaryColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingPlaceSearch = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("위시 추가")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(selectedTheme.primaryColor)
                }
            }
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

    private func wishRow(_ wish: Wish) -> some View {
        NavigationLink {
            WishDetailView(wish: wish)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(wish.name)
                        .font(.headline)

                    Spacer()

                    if wish.isVisited {
                        Label("방문 완료", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(selectedTheme.primaryColor)
                    }
                }

                if !wish.address.isEmpty {
                    Text(wish.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !wish.memo.isEmpty {
                    Text(wish.memo)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func deleteActiveWishes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(activeWishes[index])
        }
    }

    private func deleteVisitedWishes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visitedWishes[index])
        }
    }
}

private struct AddWishSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var address = ""
    @State private var category = ""
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("장소") {
                    TextField("장소 이름", text: $name)
                    TextField("주소", text: $address)
                    TextField("카테고리", text: $category)
                }

                Section("메모") {
                    TextField("가고 싶은 이유나 메모", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("위시 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveWish()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveWish() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let wish = Wish(
            name: trimmedName,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(wish)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WishlistView()
    }
    .modelContainer(for: Wish.self, inMemory: true)
}
