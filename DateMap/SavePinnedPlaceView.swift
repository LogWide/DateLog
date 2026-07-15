import SwiftUI
import SwiftData

struct SavePinnedPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    let coordinate: CoordinateData
    let suggestedPlaceName: String
    let onSaved: () -> Void

    @State private var placeName = ""
    @State private var memo = ""
    @State private var selectedHistory: DateHistory?

    @State private var isShowingNewDateForm = false
    @State private var newDateTitle = ""
    @State private var newDate = Date()
    @State private var newDateMemo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("장소") {
                    TextField("장소 이름", text: $placeName)

                    TextField(
                        "메모",
                        text: $memo,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                Section("추가할 데이트") {
                    if histories.isEmpty {
                        Text("저장된 데이트가 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(
                            "데이트 선택",
                            selection: $selectedHistory
                        ) {
                            Text("선택하세요")
                                .tag(nil as DateHistory?)

                            ForEach(histories) { history in
                                Text(
                                    "\(history.title) · \(history.date.formatted(date: .abbreviated, time: .omitted))"
                                )
                                .tag(history as DateHistory?)
                            }
                        }
                    }

                    Button {
                        isShowingNewDateForm.toggle()
                    } label: {
                        Label(
                            isShowingNewDateForm
                                ? "새 데이트 접기"
                                : "새 데이트 만들기",
                            systemImage: isShowingNewDateForm
                                ? "chevron.up"
                                : "plus.circle"
                        )
                    }

                    if isShowingNewDateForm {
                        TextField(
                            "데이트 제목",
                            text: $newDateTitle
                        )

                        DatePicker(
                            "날짜",
                            selection: $newDate,
                            displayedComponents: .date
                        )

                        TextField(
                            "데이트 메모",
                            text: $newDateMemo,
                            axis: .vertical
                        )
                        .lineLimit(2...4)

                        Button("새 데이트 생성") {
                            createHistory()
                        }
                        .disabled(cleanNewDateTitle.isEmpty)
                    }
                }

                Section("선택 좌표") {
                    Text(
                        String(
                            format: "%.6f, %.6f",
                            coordinate.latitude,
                            coordinate.longitude
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("장소 저장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        savePlace()
                    }
                    .disabled(
                        cleanPlaceName.isEmpty ||
                        selectedHistory == nil
                    )
                }
            }
            .onAppear {
                if placeName.isEmpty {
                    placeName = suggestedPlaceName
                }
                if selectedHistory == nil {
                    selectedHistory = histories.first
                }

                if histories.isEmpty {
                    isShowingNewDateForm = true
                }
            }
        }
    }

    private var cleanPlaceName: String {
        placeName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var cleanNewDateTitle: String {
        newDateTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func createHistory() {
        guard !cleanNewDateTitle.isEmpty else {
            return
        }

        let history = DateHistory(
            title: cleanNewDateTitle,
            date: newDate,
            memo: newDateMemo.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )

        modelContext.insert(history)

        do {
            try modelContext.save()

            selectedHistory = history
            isShowingNewDateForm = false

            newDateTitle = ""
            newDate = Date()
            newDateMemo = ""
        } catch {
            print("새 데이트 생성 실패: \(error)")
        }
    }

    private func savePlace() {
        guard
            let history = selectedHistory,
            !cleanPlaceName.isEmpty
        else {
            return
        }

        let nextOrder =
            (history.places.map(\.order).max() ?? -1) + 1

        let place = DatePlace(
            name: cleanPlaceName,
            order: nextOrder,
            memo: memo.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        place.history = history
        history.places.append(place)

        modelContext.insert(place)

        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            print("핀 장소 저장 실패: \(error)")
        }
    }
}
