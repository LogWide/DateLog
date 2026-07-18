import SwiftUI
import SwiftData

struct AddMemoView: View {
    let date: Date
    let memo: Memo?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var content: String

    init(date: Date, memo: Memo? = nil) {
        self.date = date
        self.memo = memo
        _content = State(initialValue: memo?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(date, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $content)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
            }
            .padding(16)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(memo == nil ? "메모 추가" : "메모 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveMemo()
                    }
                    .disabled(trimmedContent.isEmpty)
                }
            }
        }
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveMemo() {
        if let memo {
            memo.content = trimmedContent
            memo.updatedAt = Date()
        } else {
            let newMemo = Memo(
                date: date,
                content: trimmedContent
            )

            modelContext.insert(newMemo)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("메모 저장 실패: \(error)")
        }
    }
}
