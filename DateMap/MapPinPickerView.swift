//
//  MapPinPickerView.swift
//  DateMap
//
//  Created by 김기중 on 7/16/26.
//

import SwiftUI

struct MapPinPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let placeName: String
    let onConfirm: (CoordinateData) -> Void

    @State private var selectedCoordinate: CoordinateData?
    @State private var selectedSavedPlace: DatePlace?
    @State private var selectedPlaceName: String

    init(
        placeName: String,
        onConfirm: @escaping (CoordinateData) -> Void
    ) {
        self.placeName = placeName
        self.onConfirm = onConfirm
        _selectedPlaceName = State(initialValue: placeName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapView(
                    places: [],
                    selectedCoordinate: $selectedCoordinate,
                    selectedSavedPlace: $selectedSavedPlace,
                    selectedPlaceName: $selectedPlaceName
                )
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        if selectedCoordinate == nil {
                            Text("지도에서 위치를 눌러 핀을 지정하세요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("이 위치로 저장할까요?")
                                .font(.headline)
                        }

                        Button {
                            guard let selectedCoordinate else {
                                return
                            }

                            onConfirm(selectedCoordinate)
                            dismiss()
                        } label: {
                            Text("이 위치 선택")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedCoordinate == nil)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding()
                }
            }
            .navigationTitle(placeName)
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
