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

            Section("메모") {
                TextEditor(text: $wish.memo)
                    .frame(minHeight: 120)
            }

            Section("방문") {
                Toggle("방문 완료", isOn: $wish.isVisited)
                    .onChange(of: wish.isVisited) { _, newValue in
                        wish.visitedDate = newValue ? Date() : nil
                    }
            }
        }
        .navigationTitle("위시")
        .navigationBarTitleDisplayMode(.inline)
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
