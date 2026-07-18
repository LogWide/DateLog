//
//  PlaceActionSheet.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import Foundation

//
//  PlaceActionSheet.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import SwiftUI

struct PlaceActionSheet: View {
    let placeName: String
    let onAddDate: () -> Void
    let onAddWish: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        onAddDate()
                    } label: {
                        Label("데이트에 추가", systemImage: "calendar.badge.plus")
                    }

                    Button {
                        dismiss()
                        onAddWish()
                    } label: {
                        Label("위시에 저장", systemImage: "heart")
                    }
                } header: {
                    Text(placeName)
                }
            }
            .navigationTitle("장소 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PlaceActionSheet(
        placeName: "성수 카페",
        onAddDate: {},
        onAddWish: {}
    )
}
