//
//  PlacePhotoPickerView.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import SwiftUI
import SwiftData

struct PlacePhotoPickerView: View {
    let history: DateHistory
    let onSelect: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    private var allPhotos: [DatePhoto] {
        history.places
            .flatMap { $0.photos }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allPhotos.isEmpty {
                    ContentUnavailableView(
                        "사진이 없습니다",
                        systemImage: "photo",
                        description: Text("이 데이트에 등록된 장소 사진이 없습니다.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {
                            ForEach(allPhotos) { photo in
                                if let imageData = photo.imageData,
                                   let image = UIImage(data: imageData) {
                                    Button {
                                        onSelect(imageData)
                                        dismiss()
                                    } label: {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 12,
                                                    style: .continuous
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("장소 사진 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}
