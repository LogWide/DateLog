import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddDateHistoryView: View {
    private enum EntryMode: String, CaseIterable, Identifiable {
        case plan = "계획"
        case record = "기록"

        var id: String { rawValue }
    }
    let initialDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var entryMode: EntryMode = .record
    @State private var title = ""
    @State private var selectedDate: Date
    @State private var memo = ""
    @State private var selectedCoverImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(initialDate: Date = Date()) {
        self.initialDate = initialDate
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("작성 유형", selection: $entryMode) {
                        ForEach(EntryMode.allCases) { mode in
                            Text(mode.rawValue)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("기본 정보") {
                    TextField("데이트 제목", text: $title)

                    DatePicker(
                        "날짜",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("메모") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 140)
                }

                Section("대표사진") {
                    if selectedCoverImageData != nil {
                        Label("대표사진이 선택되었습니다.", systemImage: "photo.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("대표사진 없음", systemImage: "photo")
                            .foregroundStyle(.secondary)
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("새 사진 추가", systemImage: "camera")
                    }


                    if selectedCoverImageData != nil {
                        Button(role: .destructive) {
                            selectedCoverImageData = nil
                        } label: {
                            Label("대표사진 제거", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(
                entryMode == .plan
                ? "데이트 계획 추가"
                : "데이트 기록 추가"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveHistory()
                    }
                    .disabled(cleanTitle.isEmpty)
                }
            }
            .task(id: selectedPhotoItem) {
                guard let selectedPhotoItem else { return }

                if
                    let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
                    let image = UIImage(data: data),
                    let compressedData = image.jpegData(compressionQuality: 0.82)
                {
                    selectedCoverImageData = compressedData
                }
            }
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func saveHistory() {
        guard !cleanTitle.isEmpty else {
            return
        }

        let history = DateHistory(
            title: cleanTitle,
            date: selectedDate,
            memo: memo.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            coverImageData: selectedCoverImageData,
            type: entryMode == .plan ? .plan : .record
        )

        modelContext.insert(history)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("기록 저장 실패: \(error)")
        }
    }
}
