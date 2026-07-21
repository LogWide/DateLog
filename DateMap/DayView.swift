//
//  DayView.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import SwiftUI
import SwiftData

struct DayView: View {
    let date: Date
    let histories: [DateHistory]

    @Environment(\.modelContext) private var modelContext

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    @AppStorage("relationshipStartDate")
    private var relationshipStartDateInterval = Date().timeIntervalSince1970

    @AppStorage("showRelationshipDay")
    private var showRelationshipDay = false

    @AppStorage("myBirthday")
    private var myBirthdayInterval = Date().timeIntervalSince1970

    @AppStorage("showMyBirthday")
    private var showMyBirthday = false

    @AppStorage("partnerBirthday")
    private var partnerBirthdayInterval = Date().timeIntervalSince1970

    @AppStorage("showPartnerBirthday")
    private var showPartnerBirthday = false

    @Query(sort: \DateHistory.date) private var allHistories: [DateHistory]
    @Query(sort: \Diary.createdAt) private var allDiaries: [Diary]

    @State private var showingAddDateHistory = false
    @State private var showingAddDiary = false
    @State private var selectedDiary: Diary?
    @State private var diaryPendingDeletion: Diary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dateHeader

                daySection(
                    title: "데이트",
                    systemImage: "heart.fill"
                ) {
                    VStack(spacing: 12) {
                        ForEach(Array(histories.enumerated()), id: \.offset) { index, history in
                            dateHistoryCard(history: history, index: index)
                        }

                        emptySectionButton(
                            title: "데이트 추가",
                            systemImage: "plus.circle"
                        ) {
                            showingAddDateHistory = true
                        }
                    }
                }

                daySection(
                    title: "일기",
                    systemImage: "book.closed.fill"
                ) {
                    VStack(spacing: 12) {
                        ForEach(diariesForSelectedDate) { diary in
                            diaryCard(diary: diary)
                        }

                        emptySectionButton(
                            title: "일기 추가",
                            systemImage: "square.and.pencil"
                        ) {
                            showingAddDiary = true
                        }
                    }
                }

            }
            .padding(16)
        }
        .background(selectedTheme.backgroundColor)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .dateLogBackChevron(selectedTheme)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddDateHistory = true
                    } label: {
                        Label("데이트 추가", systemImage: "heart.fill")
                    }

                    Button {
                        showingAddDiary = true
                    } label: {
                        Label("일기 추가", systemImage: "book.closed.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddDateHistory) {
            AddDateHistoryView(initialDate: date)
        }
        .sheet(isPresented: $showingAddDiary) {
            AddDiaryView(date: date)
        }
        .sheet(item: $selectedDiary) { diary in
            AddDiaryView(date: diary.date, diary: diary)
        }
        .alert(
            "일기를 삭제할까요?",
            isPresented: Binding(
                get: { diaryPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        diaryPendingDeletion = nil
                    }
                }
            ),
            presenting: diaryPendingDeletion
        ) { diary in
            Button("삭제", role: .destructive) {
                deleteDiary(diary)
            }

            Button("취소", role: .cancel) {
                diaryPendingDeletion = nil
            }
        } message: { _ in
            Text("삭제한 일기는 복구할 수 없습니다.")
        }
    }

    private var diariesForSelectedDate: [Diary] {
        allDiaries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private var dateHeader: some View {
        VStack(spacing: 10) {
            Text(displayDateText)
                .font(.pretendard(size: 23, weight: .extraBold))
                .foregroundStyle(.primary)

            if let relationshipDayText {
                HStack(spacing: 7) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)

                    Text(relationshipDayText)
                        .font(.pretendard(size: 15, weight: .semiBold))
                        .foregroundStyle(.secondary)
                }
            }

            if let birthdayText {
                HStack(spacing: 7) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.pink)

                    Text(birthdayText)
                        .font(.pretendard(size: 14, weight: .semiBold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.vertical, 12)
    }

    private func daySection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())

            content()
        }
    }

    private func dateHistoryCard(
        history: DateHistory,
        index: Int
    ) -> some View {
        NavigationLink {
            DateHistoryDetailView(history: history)
        } label: {
            HStack(spacing: 14) {
                Group {
                    if history.type == .record,
                       let imageData = history.coverImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                            .fill(.pink.opacity(0.12))

                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundStyle(.pink)
                        }
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(history.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let latestComment = history.comments.max(
                        by: { $0.createdAt < $1.createdAt }
                    ) {
                        Text(latestComment.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Label(
                            history.type.displayName,
                            systemImage: history.type.systemImage
                        )

                        Label(
                            "장소 \(history.places.count)곳",
                            systemImage: "mappin.and.ellipse"
                        )

                        if !history.comments.isEmpty {
                            Label(
                                "댓글 \(history.comments.count)개",
                                systemImage: "text.bubble"
                            )
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func diaryCard(diary: Diary) -> some View {
        Button {
            selectedDiary = diary
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                if let photoData = diary.photoData,
                   let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(diary.mood)
                            .font(.title3)

                        Text(diary.weather)
                            .font(.title3)

                        if !diary.title.isEmpty {
                            Text(diary.title)
                                .font(.headline)
                                .lineLimit(1)
                        }
                    }

                    Text(diary.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)

                    HStack(spacing: 6) {
                        Text(diary.createdAt, format: .dateTime.year().month().day().hour().minute())

                        if diary.updatedAt > diary.createdAt {
                            Text("수정됨")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                selectedDiary = diary
            } label: {
                Label("수정", systemImage: "pencil")
            }

            Button(role: .destructive) {
                diaryPendingDeletion = diary
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func deleteDiary(_ diary: Diary) {
        modelContext.delete(diary)

        do {
            try modelContext.save()
            diaryPendingDeletion = nil
        } catch {
            print("일기 삭제 실패: \(error)")
        }
    }

    private func emptySectionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)

                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var navigationTitle: String {
        formattedDate("M월 d일의 데이트")
    }

    private var displayDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.M.d.EEE"
        return formatter.string(from: date)
    }

    private var relationshipDayText: String? {
        guard showRelationshipDay else {
            return nil
        }

        let firstDate = Date(
            timeIntervalSince1970: relationshipStartDateInterval
        )

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: firstDate)
        let selected = calendar.startOfDay(for: date)

        guard let days = calendar.dateComponents(
            [.day],
            from: start,
            to: selected
        ).day,
        days >= 0 else {
            return nil
        }

        return "+ \(days + 1)"
    }

    private var birthdayText: String? {
        if
            showMyBirthday,
            isSameMonthAndDay(
                date,
                Date(timeIntervalSince1970: myBirthdayInterval)
            )
        {
            return "오늘은 내 생일이에요"
        }

        if
            showPartnerBirthday,
            isSameMonthAndDay(
                date,
                Date(timeIntervalSince1970: partnerBirthdayInterval)
            )
        {
            return "오늘은 상대방의 생일이에요"
        }

        return nil
    }

    private func isSameMonthAndDay(
        _ firstDate: Date,
        _ secondDate: Date
    ) -> Bool {
        let calendar = Calendar.current
        let firstComponents = calendar.dateComponents(
            [.month, .day],
            from: firstDate
        )
        let secondComponents = calendar.dateComponents(
            [.month, .day],
            from: secondDate
        )

        return firstComponents.month == secondComponents.month &&
            firstComponents.day == secondComponents.day
    }

    private func formattedDate(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

}
