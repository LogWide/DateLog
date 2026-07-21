import SwiftUI
import SwiftData
import PhotosUI

struct AddDiaryView: View {
    let date: Date
    let diary: Diary?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var content: String
    @State private var mood: String
    @State private var weather: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    init(date: Date, diary: Diary? = nil) {
        self.date = date
        self.diary = diary
        _title = State(initialValue: diary?.title ?? "")
        _content = State(initialValue: diary?.content ?? "")
        _mood = State(initialValue: diary?.mood ?? "🙂")
        _weather = State(initialValue: diary?.weather ?? "☀️")
        _photoData = State(initialValue: diary?.photoData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(date, format: .dateTime.year().month().day().weekday(.wide))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("제목 (선택사항)", text: $title)
                        .font(.title3.weight(.semibold))
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("오늘의 기분")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 10) {
                            ForEach(["😀", "🥰", "🙂", "😐", "😢", "😡", "😴"], id: \.self) { emoji in
                                Button {
                                    mood = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .frame(width: 44, height: 44)
                                        .background(mood == emoji ? Color.accentColor.opacity(0.18) : Color.clear)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("날씨")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 10) {
                            ForEach(["☀️", "🌤️", "☁️", "🌧️", "⛈️", "🌨️", "🌫️"], id: \.self) { emoji in
                                Button {
                                    weather = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 44, height: 44)
                                        .background(weather == emoji ? Color.accentColor.opacity(0.18) : Color.clear)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("사진")
                            .font(.subheadline.weight(.semibold))

                        if let photoData,
                           let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .clipped()
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(photoData == nil ? "사진 추가" : "사진 변경", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    TextEditor(text: $content)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 260)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )
                }
                .padding(16)
            }
            .background(selectedTheme.backgroundColor)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
                }
            }
            .navigationTitle(diary == nil ? "일기 추가" : "일기 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveDiary()
                    }
                    .disabled(trimmedContent.isEmpty)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDiary() {
        if let diary {
            diary.title = trimmedTitle
            diary.content = trimmedContent
            diary.mood = mood
            diary.weather = weather
            diary.photoData = photoData
            diary.updatedAt = Date()
        } else {
            let newDiary = Diary(
                date: date,
                title: trimmedTitle,
                content: trimmedContent,
                mood: mood,
                weather: weather,
                photoData: photoData
            )

            modelContext.insert(newDiary)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("일기 저장 실패: \(error)")
        }
    }
}
