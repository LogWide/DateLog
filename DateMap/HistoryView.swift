//
//  HistoryView.swift
//  DateMap
//
//  Created by 김기중 on 7/16/26.
//

import SwiftUI
import SwiftData


enum HistoryGrouping: String, CaseIterable, Identifiable {
    case day = "일"
    case week = "주"
    case month = "월"
    case year = "연"

    var id: Self { self }
}



private struct HistoryGroup: Identifiable {
    let id: Date
    let title: String
    let histories: [DateHistory]
}

private struct TimelineDayGroup: Identifiable {
    let id: Date
    let histories: [DateHistory]
    let diaries: [Diary]

    var isEmpty: Bool {
        histories.isEmpty && diaries.isEmpty
    }
}

private struct UpcomingAnniversary {
    let label: String
    let remainingDays: Int
    let periodStart: Date
    let periodEnd: Date
}

private enum KoreanHolidayCalendar {
    static func isHoliday(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let targetDate = calendar.startOfDay(for: date)

        return holidays(for: year).contains(targetDate)
    }

    private static func holidays(for year: Int) -> Set<Date> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        var holidays: Set<Date> = []
        var substituteTargets: Set<Date> = []

        let solarHolidays: [(month: Int, day: Int, hasSubstitute: Bool)] = [
            (1, 1, false),
            (3, 1, true),
            (5, 5, true),
            (6, 6, false),
            (8, 15, true),
            (10, 3, true),
            (10, 9, true),
            (12, 25, true)
        ]

        for holiday in solarHolidays {
            guard let date = calendar.date(
                from: DateComponents(
                    year: year,
                    month: holiday.month,
                    day: holiday.day
                )
            ) else {
                continue
            }

            let day = calendar.startOfDay(for: date)
            holidays.insert(day)

            if holiday.hasSubstitute && isWeekend(day, calendar: calendar) {
                substituteTargets.insert(day)
            }
        }

        let lunarRanges = [
            (month: 1, day: 1, offsets: [-1, 0, 1], hasSubstitute: true),
            (month: 4, day: 8, offsets: [0], hasSubstitute: true),
            (month: 8, day: 15, offsets: [-1, 0, 1], hasSubstitute: true)
        ]

        for lunarHoliday in lunarRanges {
            for baseDate in lunarDates(
                year: year,
                month: lunarHoliday.month,
                day: lunarHoliday.day
            ) {
                for offset in lunarHoliday.offsets {
                    guard let holidayDate = calendar.date(
                        byAdding: .day,
                        value: offset,
                        to: baseDate
                    ) else {
                        continue
                    }

                    let day = calendar.startOfDay(for: holidayDate)
                    holidays.insert(day)

                    if lunarHoliday.hasSubstitute &&
                        isWeekend(day, calendar: calendar) {
                        substituteTargets.insert(day)
                    }
                }
            }
        }

        for target in substituteTargets.sorted() {
            guard let substituteDate = nextWeekdayHoliday(
                after: target,
                existingHolidays: holidays,
                calendar: calendar
            ) else {
                continue
            }

            holidays.insert(substituteDate)
        }

        return holidays
    }

    private static func lunarDates(
        year: Int,
        month: Int,
        day: Int
    ) -> [Date] {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = Locale(identifier: "ko_KR")
        var lunar = Calendar(identifier: .chinese)
        lunar.locale = Locale(identifier: "ko_KR")

        guard
            let startDate = gregorian.date(
                from: DateComponents(year: year, month: 1, day: 1)
            ),
            let endDate = gregorian.date(
                from: DateComponents(year: year + 1, month: 1, day: 1)
            )
        else {
            return []
        }

        var dates: [Date] = []
        var currentDate = startDate

        while currentDate < endDate {
            let components = lunar.dateComponents(
                [.month, .day, .isLeapMonth],
                from: currentDate
            )

            if components.month == month &&
                components.day == day &&
                components.isLeapMonth != true {
                dates.append(gregorian.startOfDay(for: currentDate))
            }

            currentDate = gregorian.date(
                byAdding: .day,
                value: 1,
                to: currentDate
            ) ?? endDate
        }

        return dates
    }

    private static func isWeekend(
        _ date: Date,
        calendar: Calendar
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private static func nextWeekdayHoliday(
        after date: Date,
        existingHolidays: Set<Date>,
        calendar: Calendar
    ) -> Date? {
        var candidate = calendar.date(
            byAdding: .day,
            value: 1,
            to: date
        )

        while let date = candidate {
            let day = calendar.startOfDay(for: date)

            if !isWeekend(day, calendar: calendar) &&
                !existingHolidays.contains(day) {
                return day
            }

            candidate = calendar.date(
                byAdding: .day,
                value: 1,
                to: day
            )
        }

        return nil
    }
}


struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding private var quickAddTargetDate: Date?

    init(quickAddTargetDate: Binding<Date?> = .constant(nil)) {
        _quickAddTargetDate = quickAddTargetDate
    }

    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    @Query(sort: \Diary.createdAt)
    private var allDiaries: [Diary]

    @State private var isShowingAddView = false
    @State private var isShowingAddDiary = false
    @State private var isShowingAlbum = false
    @State private var isShowingAnniversaryAlbum = false
    @State private var isShowingPeriodPicker = false
    @State private var isShowingSettings = false
    @State private var selectedWeekDate: Date?
    @State private var selectedMonthDate: Date?

    /// 세션 동안 기념일 배너를 숨겼는지 (앱 재시작 시 초기화)
    @State private var isAnniversaryBannerDismissed = false

    /// 타임라인에서 눌러 열어본 일기
    @State private var editingTimelineDiary: Diary?
    @State private var selectedCalendarDateForNavigation: Date?
    @State private var grouping: HistoryGrouping = .day
    @State private var weekSwipeDirection = 1
    @State private var monthSwipeDirection = 1
    @State private var monthPageSelection = 0
    @State private var monthPageAnchor: Date = {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()
    @State private var selectedWeekStart = Date()
    @State private var selectedMonth: Date = {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()
    @State private var selectedYear: Date = {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year], from: Date())
        return calendar.date(from: components) ?? Date()
    }()

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private let anniversaryPreviewDays = 7

    @AppStorage("calendarWeekStartsOnMonday")
    private var calendarWeekStartsOnMonday = false

    private var historyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = calendarWeekStartsOnMonday ? 2 : 1
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    @AppStorage("relationshipStartDate")
    private var relationshipStartDateInterval = Date().timeIntervalSince1970

    @AppStorage("showRelationshipDay")
    private var showRelationshipDay = false

    @AppStorage("showRelationshipDayInHistory")
    private var showRelationshipDayInHistory = true

    @AppStorage("myBirthday")
    private var myBirthdayInterval = Date().timeIntervalSince1970

    @AppStorage("showMyBirthday")
    private var showMyBirthday = false

    @AppStorage("partnerBirthday")
    private var partnerBirthdayInterval = Date().timeIntervalSince1970

    @AppStorage("showPartnerBirthday")
    private var showPartnerBirthday = false

    @AppStorage("showPlansInHistory")
    private var showPlansInHistory = true

    private var welcomeMessage: String {
        let messages = [
            "우리 둘만의 DateLog.",
            "우리 둘만의 이야기.",
            "둘만의 순간을 기록하세요.",
            "우리의 시간을 기록하는 공간."
        ]

        let twentyMinuteSlot = Int(Date().timeIntervalSince1970 / (20 * 60))

        return messages[twentyMinuteSlot % messages.count]
    }

    private var displayHistories: [DateHistory] {
        histories.filter {
            $0.type == .record || (showPlansInHistory && $0.type == .plan)
        }
    }

    private var relationshipDayCount: Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(
            for: Date(timeIntervalSince1970: relationshipStartDateInterval)
        )
        let today = calendar.startOfDay(for: Date())

        let days = calendar.dateComponents(
            [.day],
            from: startDate,
            to: today
        ).day ?? 0

        return max(days + 1, 1)
    }

    private var groupedHistories: [HistoryGroup] {
        let calendar = historyCalendar
        let filteredHistories: [DateHistory]

        if grouping == .week {
            filteredHistories = displayHistories.filter { history in
                groupingDate(
                    for: history.date,
                    grouping: .week,
                    calendar: calendar
                ) == selectedWeekStart
            }
        } else if grouping == .month {
            filteredHistories = displayHistories.filter { history in
                groupingDate(
                    for: history.date,
                    grouping: .month,
                    calendar: calendar
                ) == selectedMonth
            }
        } else if grouping == .year {
            filteredHistories = displayHistories.filter { history in
                groupingDate(
                    for: history.date,
                    grouping: .year,
                    calendar: calendar
                ) == selectedYear
            }
        } else {
            filteredHistories = displayHistories
        }

        let effectiveGrouping: HistoryGrouping

        switch grouping {
        case .day, .week, .month, .year:
            effectiveGrouping = .day
        }

        let grouped = Dictionary(grouping: filteredHistories) { history in
            groupingDate(
                for: history.date,
                grouping: effectiveGrouping,
                calendar: calendar
            )
        }

        return grouped
            .map { date, histories in
                HistoryGroup(
                    id: date,
                    title: groupTitle(
                        for: date,
                        grouping: effectiveGrouping,
                        calendar: calendar
                    ),
                    histories: histories.sorted {
                        $0.date > $1.date
                    }
                )
            }
            .sorted {
                $0.id > $1.id
            }
    }

    private var timelineDayGroups: [TimelineDayGroup] {
        let calendar = historyCalendar
        let dates = Set(
            displayHistories.map { calendar.startOfDay(for: $0.date) } +
            allDiaries.map { calendar.startOfDay(for: $0.date) }
        )

        return dates
            .map { date in
                TimelineDayGroup(
                    id: date,
                    histories: displayHistories
                        .filter { calendar.isDate($0.date, inSameDayAs: date) }
                        .sorted { $0.date > $1.date },
                    diaries: allDiaries
                        .filter { calendar.isDate($0.date, inSameDayAs: date) }
                        .sorted { $0.createdAt > $1.createdAt }
                )
            }
            .filter { !$0.isEmpty }
            .sorted { $0.id > $1.id }
    }

    private var defaultTimelineDate: Date? {
        let today = historyCalendar.startOfDay(for: Date())

        if timelineDayGroups.contains(where: {
            historyCalendar.isDate($0.id, inSameDayAs: today)
        }) {
            return today
        }

        return timelineDayGroups
            .map(\.id)
            .filter { $0 <= today }
            .max()
    }

    private var periodTimelineDayGroups: [TimelineDayGroup] {
        switch grouping {
        case .day:
            return timelineDayGroups
        case .week:
            return timelineDayGroups.filter {
                groupingDate(
                    for: $0.id,
                    grouping: .week,
                    calendar: historyCalendar
                ) == selectedWeekStart
            }
        case .month:
            return timelineDayGroups.filter {
                groupingDate(
                    for: $0.id,
                    grouping: .month,
                    calendar: historyCalendar
                ) == selectedMonth
            }
        case .year:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                relationshipHeader

                if let upcomingAnniversary, !isAnniversaryBannerDismissed {
                    anniversaryBanner(upcomingAnniversary)
                }

                switch grouping {
                case .week:
                    VStack(spacing: 0) {
                        weekSelectorBar
                        weekCalendarStrip
                    }

                case .month:
                    VStack(spacing: 0) {
                        monthSelectorBar
                        monthCalendarGrid
                    }

                case .year:
                    ScrollView {
                        VStack(spacing: 0) {
                        yearSelectorBar
                        yearSummaryGrid
                    }
                    }
                    .background(selectedTheme.backgroundColor)

                default:
                    EmptyView()
                }

                Group {
                    if displayHistories.isEmpty && allDiaries.isEmpty {
                        ContentUnavailableView(
                            "아직 기록이 없습니다",
                            systemImage: "heart.text.clipboard",
                            description: Text(
                                "오른쪽 위 + 버튼으로 첫 기록을 추가하세요."
                            )
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if groupedHistories.isEmpty && !(grouping == .week && !periodTimelineDayGroups.isEmpty) {
                        if grouping == .month {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(selectedTheme.backgroundColor)
                        } else if grouping == .year {
                            EmptyView()
                        } else {
                            ContentUnavailableView(
                                emptyPeriodTitle,
                                systemImage: "calendar.badge.exclamationmark",
                                description: Text("다른 기간으로 이동하거나 새로운 데이트를 추가해보세요.")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else if grouping == .month {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(selectedTheme.backgroundColor)
                    } else if grouping == .year {
                        EmptyView()
                    } else if grouping == .day {
                        timelineListView(
                            groups: timelineDayGroups,
                            scrollsToDefaultDate: true
                        )
                    } else if grouping == .week {
                        timelineListView(
                            groups: periodTimelineDayGroups,
                            scrollsToDefaultDate: false
                        )
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 24) {
                                    ForEach(groupedHistories) { group in
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(
                                                daySectionTitle(
                                                    for: group.id,
                                                    fallback: group.title
                                                )
                                            )
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)

                                            VStack(spacing: 12) {
                                                ForEach(group.histories) { history in
                                                    NavigationLink {
                                                        DateHistoryDetailView(history: history)
                                                    } label: {
                                                        HistoryRow(history: history)
                                                            .padding(16)
                                                            .frame(
                                                                maxWidth: .infinity,
                                                                alignment: .leading
                                                            )
                                                            .background(selectedTheme.cardBackgroundColor)
                                                            .clipShape(
                                                                RoundedRectangle(
                                                                    cornerRadius: 20,
                                                                    style: .continuous
                                                                )
                                                            )
                                                            .overlay {
                                                                RoundedRectangle(
                                                                    cornerRadius: 20,
                                                                    style: .continuous
                                                                )
                                                                .stroke(
                                                                    selectedTheme.primaryColor.opacity(0.10),
                                                                    lineWidth: 1
                                                                )
                                                            }
                                                            .shadow(
                                                                color: .black.opacity(0.05),
                                                                radius: 12,
                                                                x: 0,
                                                                y: 5
                                                            )
                                                    }
                                                    .buttonStyle(.plain)
                                                    .contextMenu {
                                                        Button(
                                                            "데이트 삭제",
                                                            systemImage: "trash",
                                                            role: .destructive
                                                        ) {
                                                            deleteHistory(history)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .id(group.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 18)
                                .padding(.bottom, 28)
                            }
                            .background(selectedTheme.backgroundColor)
                            .id(grouping == .week ? selectedWeekStart : Date.distantPast)
                            .transition(
                                grouping == .week
                                    ? .asymmetric(
                                        insertion: .move(
                                            edge: weekSwipeDirection > 0
                                                ? .trailing
                                                : .leading
                                        ).combined(with: .opacity),
                                        removal: .move(
                                            edge: weekSwipeDirection > 0
                                                ? .leading
                                                : .trailing
                                        ).combined(with: .opacity)
                                    )
                                    : .identity
                            )
                            .onChange(of: selectedWeekDate) { _, newDate in
                                guard grouping == .week, let newDate else {
                                    return
                                }

                                scrollToHistoryDate(newDate, using: proxy)
                            }
                            .onChange(of: selectedMonthDate) { _, newDate in
                                guard grouping == .month, let newDate else {
                                    return
                                }

                                scrollToHistoryDate(newDate, using: proxy)
                            }
                        }
                    }
                }

                groupingPicker
            }
            .background(selectedTheme.backgroundColor)
            .contentShape(Rectangle())
            .simultaneousGesture(periodSwipeGesture)
            .onAppear {
                updateQuickAddTargetDate()

                selectedWeekStart = groupingDate(
                    for: selectedWeekDate ?? Date(),
                    grouping: .week,
                    calendar: historyCalendar
                )

                monthPageAnchor = groupingDate(
                    for: selectedMonth,
                    grouping: .month,
                    calendar: historyCalendar
                )
                monthPageSelection = 0
            }
            .onChange(of: calendarWeekStartsOnMonday) { _, _ in
                selectedWeekStart = groupingDate(
                    for: selectedWeekDate ?? selectedWeekStart,
                    grouping: .week,
                    calendar: historyCalendar
                )
                updateQuickAddTargetDate()
            }
            .onChange(of: grouping) {
                updateQuickAddTargetDate()
            }
            .onChange(of: selectedWeekDate) {
                updateQuickAddTargetDate()
            }
            .onChange(of: selectedMonthDate) {
                updateQuickAddTargetDate()
            }
            .onChange(of: selectedMonth) {
                updateQuickAddTargetDate()
            }
            .onChange(of: selectedYear) {
                updateQuickAddTargetDate()
            }
            .toolbarBackground(selectedTheme.primaryColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                selectedTheme.onPrimaryColorScheme,
                for: .navigationBar
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // 헤더가 히어로와 같은 테마 색이므로 텍스트 획은 onPrimary 색으로,
                    // 하트는 원본 핑크를 유지한다
                    ZStack {
                        Image("DateLogLogoText")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(selectedTheme.onPrimaryTextColor)
                        Image("DateLogLogoHeart")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: 94, height: 32)
                    .accessibilityLabel("DateLog")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingAlbum = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(selectedTheme.onPrimaryTextColor)
                    }
                    .accessibilityLabel("앨범")

                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(selectedTheme.onPrimaryTextColor)
                    }
                    .accessibilityLabel("설정")
                }
            }
            .sheet(isPresented: $isShowingAlbum) {
                AlbumView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isShowingAnniversaryAlbum) {
                if let upcomingAnniversary {
                    anniversaryHistorySheet(upcomingAnniversary)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $isShowingAddView) {
                AddDateHistoryView(initialDate: addTargetDate)
            }
            .sheet(isPresented: $isShowingAddDiary) {
                AddDiaryView(date: addTargetDate)
            }
            .sheet(item: $editingTimelineDiary) { diary in
                AddDiaryView(date: diary.date, diary: diary)
            }
            .sheet(isPresented: $isShowingPeriodPicker) {
                periodPickerSheet
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
            }
            .navigationDestination(item: $selectedCalendarDateForNavigation) { date in
                DayView(
                    date: date,
                    histories: displayHistories.filter {
                        historyCalendar.isDate($0.date, inSameDayAs: date)
                    }
                )
            }
        }
    }


    private var groupingPicker: some View {
        Picker("보기 방식", selection: $grouping) {
            Text("전체").tag(HistoryGrouping.day)
            Text("주별").tag(HistoryGrouping.week)
            Text("월별").tag(HistoryGrouping.month)
            Text("연도별").tag(HistoryGrouping.year)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 42)
        .frame(maxWidth: .infinity)
    }

    private var addTargetDate: Date {
        switch grouping {
        case .week:
            return selectedWeekDate ?? selectedWeekStart
        case .month:
            return selectedMonthDate ?? selectedMonth
        case .year:
            return selectedMonthDate ?? selectedYear
        case .day:
            return Date()
        }
    }

    private func prepareDateHistoryAddDate() {
        if grouping == .week, selectedWeekDate == nil {
            selectedWeekDate = selectedWeekStart
        } else if (grouping == .month || grouping == .year), selectedMonthDate == nil {
            selectedMonthDate = selectedMonth
        }

        updateQuickAddTargetDate()
    }

    private func updateQuickAddTargetDate() {
        quickAddTargetDate = addTargetDate
    }

    private var weekSelectorBar: some View {
        Button {
            isShowingPeriodPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(weekTitle)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTheme.primaryColor.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    private var weekCalendarStrip: some View {
        let dates = (0..<7).compactMap { offset in
            historyCalendar.date(
                byAdding: .day,
                value: offset,
                to: selectedWeekStart
            )
        }

        return HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                let isToday = historyCalendar.isDateInToday(date)
                let isSelected = selectedWeekDate.map {
                    historyCalendar.isDate($0, inSameDayAs: date)
                } ?? false
                let anniversaryLabel = relationshipAnniversaryLabel(for: date)
                let birthdayLabel = birthdayLabel(for: date)
                let eventLabel = anniversaryLabel ?? birthdayLabel

                let dateCount = displayHistories.filter {
                    $0.type == .record &&
                    historyCalendar.isDate($0.date, inSameDayAs: date)
                }.count
                let planCount = displayHistories.filter {
                    $0.type == .plan &&
                    historyCalendar.isDate($0.date, inSameDayAs: date)
                }.count
                let diaryCount = allDiaries.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }.count

                Button {
                    let selectedDate = historyCalendar.startOfDay(for: date)

                    if isSelected {
                        selectedCalendarDateForNavigation = selectedDate
                    } else {
                        selectedWeekDate = selectedDate
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(shortWeekdayText(for: date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(calendarDayColor(for: date).opacity(0.78))

                        Text("\(historyCalendar.component(.day, from: date))")
                            .font(.subheadline.weight(isToday || isSelected ? .bold : .medium))
                            .foregroundStyle(
                                isSelected || isToday
                                    ? Color.white
                                    : calendarDayColor(for: date)
                            )
                            .frame(width: 34, height: 34)
                            .background {
                                if isSelected {
                                    Circle()
                                        .fill(selectedTheme.primaryColor)
                                } else if isToday {
                                    Circle()
                                        .fill(selectedTheme.primaryColor.opacity(0.55))
                                }
                            }

                        calendarEventDots(
                            dateCount: dateCount,
                            planCount: planCount,
                            diaryCount: diaryCount
                        )
                        .frame(height: 6)

                        if let eventLabel {
                            Text(eventLabel)
                                .font(.pretendard(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    anniversaryLabel != nil
                                        ? selectedTheme.primaryColor
                                        : selectedTheme.secondaryColor
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 5,
                                        style: .continuous
                                    )
                                )
                        } else {
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
        .onAppear {
            if selectedWeekDate == nil {
                selectedWeekDate = historyCalendar.isDate(
                    Date(),
                    equalTo: selectedWeekStart,
                    toGranularity: .weekOfYear
                )
                    ? historyCalendar.startOfDay(for: Date())
                    : selectedWeekStart
            }
        }
        .onChange(of: selectedWeekStart) { _, newWeekStart in
            selectedWeekDate = newWeekStart
        }
    }

    private var upcomingAnniversary: UpcomingAnniversary? {
        guard showRelationshipDay else {
            return nil
        }

        let calendar = historyCalendar
        let startDate = calendar.startOfDay(
            for: Date(timeIntervalSince1970: relationshipStartDateInterval)
        )
        let today = calendar.startOfDay(for: Date())

        for offset in 0...anniversaryPreviewDays {
            guard let targetDate = calendar.date(
                byAdding: .day,
                value: offset,
                to: today
            ) else {
                continue
            }

            guard let periodEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: targetDate
            )?.addingTimeInterval(-1) else {
                continue
            }

            let years = calendar.dateComponents(
                [.year],
                from: startDate,
                to: targetDate
            ).year ?? 0

            if years >= 1, isSameMonthAndDay(targetDate, startDate) {
                let periodStart = calendar.date(
                    byAdding: .year,
                    value: years - 1,
                    to: startDate
                ) ?? startDate

                return UpcomingAnniversary(
                    label: "\(years)주년",
                    remainingDays: offset,
                    periodStart: periodStart,
                    periodEnd: periodEnd
                )
            }

            guard let days = calendar.dateComponents(
                [.day],
                from: startDate,
                to: targetDate
            ).day else {
                continue
            }

            let relationshipDay = days + 1

            if relationshipDay >= 100, relationshipDay % 100 == 0 {
                let periodStart = calendar.date(
                    byAdding: .day,
                    value: -100,
                    to: targetDate
                ) ?? startDate

                return UpcomingAnniversary(
                    label: "\(relationshipDay)일",
                    remainingDays: offset,
                    periodStart: max(periodStart, startDate),
                    periodEnd: periodEnd
                )
            }
        }

        return nil
    }

    private func anniversaryBanner(
        _ anniversary: UpcomingAnniversary
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    anniversary.remainingDays == 0
                        ? "오늘은 \(anniversary.label)이에요."
                        : "\(anniversary.label)이 \(anniversary.remainingDays)일 남았어요."
                )
                .font(.pretendard(size: 15, weight: .bold))
                .foregroundStyle(.primary)

                Text("소중한 순간들을 되돌아보세요.")
                    .font(.pretendard(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                isShowingAnniversaryAlbum = true
            } label: {
                Text("추억 돌아보기")
                    .font(.pretendard(size: 13, weight: .semiBold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(selectedTheme.primaryColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(selectedTheme.primaryColor.opacity(0.10))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay(alignment: .topTrailing) {
            // 세션 동안만 배너를 숨긴다. 앱을 다시 켜면 다시 보인다.
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isAnniversaryBannerDismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("기념일 배너 닫기")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func anniversaryHistorySheet(
        _ anniversary: UpcomingAnniversary
    ) -> some View {
        let groups = anniversaryTimelineDayGroups(for: anniversary)

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    anniversaryAlbumHeader(anniversary)

                    if groups.isEmpty {
                        ContentUnavailableView(
                            "돌아볼 기록이 없습니다",
                            systemImage: "heart.text.clipboard",
                            description: Text("이 기간에 남긴 데이트나 일기가 없습니다.")
                        )
                        .padding(.top, 46)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                timelineDayGroupView(
                                    group,
                                    showsMonth: shouldShowAnniversaryTimelineMonth(
                                        in: groups,
                                        at: index
                                    ),
                                    showsSeparator: index > 0
                                )
                            }
                        }
                        .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(selectedTheme.backgroundColor)
            .navigationTitle("\(anniversary.label) 추억")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        isShowingAnniversaryAlbum = false
                    }
                }
            }
        }
    }

    private func anniversaryAlbumHeader(
        _ anniversary: UpcomingAnniversary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))

                Text(
                    anniversary.remainingDays == 0
                        ? "오늘은 우리의 \(anniversary.label)"
                        : "\(anniversary.label)까지 \(anniversary.remainingDays)일"
                )
                .font(.pretendard(size: 12, weight: .semiBold))
            }
            .foregroundStyle(selectedTheme.primaryColor.opacity(0.85))

            Text("지난 \(anniversary.label)의 추억을\n함께 돌아보아요")
                .font(.pretendard(size: 23, weight: .extraBold))
                .foregroundStyle(.primary)
                .lineSpacing(4)

            Text(
                "\(DateDisplayFormatter.string(from: anniversary.periodStart)) - \(DateDisplayFormatter.string(from: anniversary.periodEnd))의 기록이 담겨 있어요."
            )
            .font(.pretendard(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(selectedTheme.primaryColor.opacity(0.07))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .padding(.top, 14)
    }

    private func anniversaryTimelineDayGroups(
        for anniversary: UpcomingAnniversary
    ) -> [TimelineDayGroup] {
        let calendar = historyCalendar
        let dateRange = anniversary.periodStart...anniversary.periodEnd
        let periodHistories = displayHistories.filter { dateRange.contains($0.date) }
        let periodDiaries = allDiaries.filter { dateRange.contains($0.date) }
        let dates = Set(
            periodHistories.map { calendar.startOfDay(for: $0.date) } +
            periodDiaries.map { calendar.startOfDay(for: $0.date) }
        )

        return dates
            .map { date in
                TimelineDayGroup(
                    id: date,
                    histories: periodHistories
                        .filter { calendar.isDate($0.date, inSameDayAs: date) }
                        .sorted { $0.date > $1.date },
                    diaries: periodDiaries
                        .filter { calendar.isDate($0.date, inSameDayAs: date) }
                        .sorted { $0.createdAt > $1.createdAt }
                )
            }
            .filter { !$0.isEmpty }
            .sorted { $0.id > $1.id }
    }

    private func shouldShowAnniversaryTimelineMonth(
        in groups: [TimelineDayGroup],
        at index: Int
    ) -> Bool {
        guard groups.indices.contains(index) else {
            return false
        }

        if index == 0 {
            return true
        }

        return !historyCalendar.isDate(
            groups[index].id,
            equalTo: groups[index - 1].id,
            toGranularity: .month
        )
    }

    private func relationshipAnniversaryLabel(for date: Date) -> String? {
        guard showRelationshipDay else {
            return nil
        }

        let calendar = historyCalendar
        let startDate = calendar.startOfDay(
            for: Date(timeIntervalSince1970: relationshipStartDateInterval)
        )
        let targetDate = calendar.startOfDay(for: date)

        guard let difference = calendar.dateComponents(
            [.day],
            from: startDate,
            to: targetDate
        ).day else {
            return nil
        }

        let relationshipDay = difference + 1

        guard relationshipDay >= 1 else {
            return nil
        }

        if relationshipDay == 1 {
            return "1일"
        }

        let years = calendar.dateComponents(
            [.year],
            from: startDate,
            to: targetDate
        ).year ?? 0

        if years >= 1, isSameMonthAndDay(targetDate, startDate) {
            return "\(years)주년"
        }

        if relationshipDay % 100 == 0 {
            return "\(relationshipDay)일"
        }

        return nil
    }

    private func birthdayLabel(for date: Date) -> String? {
        if
            showMyBirthday,
            isSameMonthAndDay(
                date,
                Date(timeIntervalSince1970: myBirthdayInterval)
            )
        {
            return "내 생일"
        }

        if
            showPartnerBirthday,
            isSameMonthAndDay(
                date,
                Date(timeIntervalSince1970: partnerBirthdayInterval)
            )
        {
            return "상대 생일"
        }

        return nil
    }

    private func isSameMonthAndDay(
        _ firstDate: Date,
        _ secondDate: Date
    ) -> Bool {
        let firstComponents = historyCalendar.dateComponents(
            [.month, .day],
            from: firstDate
        )
        let secondComponents = historyCalendar.dateComponents(
            [.month, .day],
            from: secondDate
        )

        return firstComponents.month == secondComponents.month &&
            firstComponents.day == secondComponents.day
    }

    private func shortWeekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    /// 캘린더 이벤트 점 고정 색 — 테마와 무관하게 데이트는 분홍, 일기는 머스터드
    private static let dateDotColor = Color(
        red: 0.93,
        green: 0.32,
        blue: 0.58
    )
    private static let diaryDotColor = Color(
        red: 0.85,
        green: 0.63,
        blue: 0.15
    )

    /// 날짜 아래 이벤트 점. 최대 4개까지만 보여주고 넘치면 점 크기의 +를 덧붙인다.
    private func calendarEventDots(
        dateCount: Int,
        planCount: Int,
        diaryCount: Int
    ) -> some View {
        let dotColors =
            Array(repeating: Self.dateDotColor, count: dateCount)
            + Array(repeating: Color.gray.opacity(0.55), count: planCount)
            + Array(repeating: Self.diaryDotColor, count: diaryCount)

        return HStack(spacing: 3) {
            ForEach(
                Array(dotColors.prefix(4).enumerated()),
                id: \.offset
            ) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }

            if dotColors.count > 4 {
                Image(systemName: "plus")
                    .font(.system(size: 5, weight: .black))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func calendarDayColor(for date: Date) -> Color {
        if KoreanHolidayCalendar.isHoliday(date) {
            return .red
        }

        switch historyCalendar.component(.weekday, from: date) {
        case 1:
            return .red
        case 7:
            return .blue
        default:
            return .primary
        }
    }

    private var weekTitle: String {
        let calendar = historyCalendar

        let representativeDate = calendar.date(
            byAdding: .day,
            value: 3,
            to: selectedWeekStart
        ) ?? selectedWeekStart

        let year = calendar.component(.year, from: representativeDate)
        let month = calendar.component(.month, from: representativeDate)

        let monthComponents = calendar.dateComponents(
            [.year, .month],
            from: representativeDate
        )

        guard
            let monthStart = calendar.date(from: monthComponents)
        else {
            return "\(year)년 \(month)월"
        }

        let firstWeekStart = groupingDate(
            for: monthStart,
            grouping: .week,
            calendar: calendar
        )

        let weekOffset = calendar.dateComponents(
            [.weekOfYear],
            from: firstWeekStart,
            to: selectedWeekStart
        ).weekOfYear ?? 0

        return "\(year)년 \(month)월 \(weekOffset + 1)주"
    }
    
    private var monthSelectorBar: some View {
        Button {
            isShowingPeriodPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(monthTitle)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTheme.primaryColor.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Button {
                let today = Date()
                selectedMonth = groupingDate(
                    for: today,
                    grouping: .month,
                    calendar: historyCalendar
                )
                selectedMonthDate = historyCalendar.startOfDay(for: today)
            } label: {
                Text("오늘")
                    .font(.pretendard(size: 13, weight: .semiBold))
                    .foregroundStyle(selectedTheme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(selectedTheme.primaryColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 6)
        }
    }

    private var monthCalendarGrid: some View {
        TabView(selection: $monthPageSelection) {
            ForEach(-240...240, id: \.self) { offset in
                if let month = historyCalendar.date(
                    byAdding: .month,
                    value: offset,
                    to: monthPageAnchor
                ) {
                    monthCalendarPage(for: month)
                        .tag(offset)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: monthCalendarHeight(for: selectedMonth))
        .onAppear {
            monthPageAnchor = groupingDate(
                for: selectedMonth,
                grouping: .month,
                calendar: historyCalendar
            )
            monthPageSelection = 0

            if selectedMonthDate == nil {
                selectedMonthDate = historyCalendar.isDate(
                    Date(),
                    equalTo: selectedMonth,
                    toGranularity: .month
                )
                    ? historyCalendar.startOfDay(for: Date())
                    : selectedMonth
            }
        }
        .onChange(of: monthPageSelection) { _, newOffset in
            guard let newMonth = historyCalendar.date(
                byAdding: .month,
                value: newOffset,
                to: monthPageAnchor
            ) else {
                return
            }

            selectedMonth = groupingDate(
                for: newMonth,
                grouping: .month,
                calendar: historyCalendar
            )
            selectedMonthDate = defaultMonthSelectedDate(for: selectedMonth)
        }
        .onChange(of: selectedMonth) { oldMonth, newMonth in
            selectedMonthDate = defaultMonthSelectedDate(for: newMonth)

            guard !historyCalendar.isDate(
                oldMonth,
                equalTo: newMonth,
                toGranularity: .month
            ) else {
                return
            }

            let offset = historyCalendar.dateComponents(
                [.month],
                from: monthPageAnchor,
                to: newMonth
            ).month ?? 0

            if (-240...240).contains(offset), monthPageSelection != offset {
                monthPageSelection = offset
            }
        }
    }

    private func defaultMonthSelectedDate(for month: Date) -> Date {
        historyCalendar.isDate(
            Date(),
            equalTo: month,
            toGranularity: .month
        )
            ? historyCalendar.startOfDay(for: Date())
            : month
    }

    private func monthCalendarHeight(for month: Date) -> CGFloat {
        let rowCount = max(monthGridDates(for: month).count / 7, 5)
        return CGFloat(rowCount * 49 + 34)
    }

    private func monthCalendarPage(for month: Date) -> some View {
        let weekdaySymbols = calendarWeekStartsOnMonday
            ? ["월", "화", "수", "목", "금", "토", "일"]
            : ["일", "월", "화", "수", "목", "금", "토"]
        let dates = monthGridDates(for: month)

        return VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(monthWeekdayHeaderColor(for: index))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 0),
                    count: 7
                ),
                spacing: 8
            ) {
                ForEach(dates, id: \.self) { date in
                    let isCurrentMonth = historyCalendar.isDate(
                        date,
                        equalTo: month,
                        toGranularity: .month
                    )
                    let isSelected = selectedMonthDate.map {
                        historyCalendar.isDate($0, inSameDayAs: date)
                    } ?? false
                    let dateCount = displayHistories.filter {
                        $0.type == .record &&
                        historyCalendar.isDate($0.date, inSameDayAs: date)
                    }.count
                    let planCount = displayHistories.filter {
                        $0.type == .plan &&
                        historyCalendar.isDate($0.date, inSameDayAs: date)
                    }.count
                    let diaryCount = allDiaries.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: date)
                    }.count
                    let weekday = historyCalendar.component(.weekday, from: date)
                    let anniversaryLabel = relationshipAnniversaryLabel(for: date)
                    let birthdayLabel = birthdayLabel(for: date)
                    let isAnniversary = anniversaryLabel != nil && isCurrentMonth
                    let isBirthday = birthdayLabel != nil && isCurrentMonth

                    Button {
                        guard isCurrentMonth else {
                            return
                        }

                        // 선택 단계 없이 바로 해당 날짜 페이지로 이동한다
                        let selectedDate = historyCalendar.startOfDay(for: date)
                        selectedMonthDate = selectedDate
                        selectedCalendarDateForNavigation = selectedDate
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(historyCalendar.component(.day, from: date))")
                                .font(
                                    .subheadline.weight(
                                        isAnniversary || isBirthday ? .bold : .medium
                                    )
                                )
                                .foregroundStyle(
                                    isAnniversary
                                        ? selectedTheme.primaryColor
                                        : isBirthday
                                            ? selectedTheme.secondaryColor
                                            : monthDayColor(
                                                date: date,
                                                weekday: weekday,
                                                isCurrentMonth: isCurrentMonth,
                                                isSelected: false
                                            )
                                )
                                .frame(width: 34, height: 30)
                                .overlay(alignment: .top) {
                                    if isAnniversary {
                                        Text("❤️")
                                            .font(.system(size: 7))
                                            .offset(y: -4)
                                    } else if isBirthday {
                                        Text("🎂")
                                            .font(.system(size: 7))
                                            .offset(y: -4)
                                    }
                                }

                            calendarEventDots(
                                dateCount: dateCount,
                                planCount: planCount,
                                diaryCount: diaryCount
                            )
                            .frame(height: 6, alignment: .top)
                            .offset(y: -3)

                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isCurrentMonth)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    private func monthGridDates(for month: Date) -> [Date] {
        guard
            let monthInterval = historyCalendar.dateInterval(
                of: .month,
                for: month
            ),
            let firstGridDate = historyCalendar.dateInterval(
                of: .weekOfYear,
                for: monthInterval.start
            )?.start,
            let lastMonthDate = historyCalendar.date(
                byAdding: .day,
                value: -1,
                to: monthInterval.end
            ),
            let lastGridWeek = historyCalendar.dateInterval(
                of: .weekOfYear,
                for: lastMonthDate
            )
        else {
            return []
        }

        let lastGridDate = lastGridWeek.end
        var dates: [Date] = []
        var currentDate = firstGridDate

        while currentDate < lastGridDate {
            dates.append(currentDate)
            currentDate = historyCalendar.date(
                byAdding: .day,
                value: 1,
                to: currentDate
            ) ?? lastGridDate
        }

        return dates
    }

    private func monthWeekdayHeaderColor(for index: Int) -> Color {
        if calendarWeekStartsOnMonday {
            if index == 5 {
                return .blue
            }

            if index == 6 {
                return .red
            }
        } else {
            if index == 0 {
                return .red
            }

            if index == 6 {
                return .blue
            }
        }

        return .secondary
    }

    private func monthDayColor(
        date: Date,
        weekday: Int,
        isCurrentMonth: Bool,
        isSelected: Bool
    ) -> Color {
        if isSelected {
            return .white
        }

        if !isCurrentMonth {
            return .secondary.opacity(0.35)
        }

        if KoreanHolidayCalendar.isHoliday(date) {
            return .red
        }

        switch weekday {
        case 1:
            return .red
        case 7:
            return .blue
        default:
            return .primary
        }
    }
    
    private var yearSelectorBar: some View {
        Button {
            isShowingPeriodPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(yearTitle)
                    .font(.pretendard(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTheme.primaryColor.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .buttonStyle(.plain)
    }

    // Year paging grid using TabView, similar to monthCalendarGrid
    @State private var yearPageSelection: Int = 0
    private let baseYearAnchor: Date = {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year], from: Date())
        return calendar.date(from: components) ?? Date()
    }()

    private var yearSummaryGrid: some View {
        TabView(selection: $yearPageSelection) {
            ForEach(-100...100, id: \.self) { offset in
                if let year = historyCalendar.date(
                    byAdding: .year,
                    value: offset,
                    to: baseYearAnchor
                ) {
                    yearSummaryPage(for: year)
                        .tag(offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 6 * 102 + 20) // 6 rows of cards, estimate height
        .onAppear {
            // No resetting of anchor or page selection on every appearance
            let offset = historyCalendar.dateComponents(
                [.year],
                from: baseYearAnchor,
                to: groupingDate(
                    for: selectedYear,
                    grouping: .year,
                    calendar: historyCalendar
                )
            ).year ?? 0
            if (-100...100).contains(offset), yearPageSelection != offset {
                yearPageSelection = offset
            }
        }
        .onChange(of: yearPageSelection) { _, newOffset in
            guard let newYear = historyCalendar.date(
                byAdding: .year,
                value: newOffset,
                to: baseYearAnchor
            ) else {
                return
            }
            let grouped = groupingDate(
                for: newYear,
                grouping: .year,
                calendar: historyCalendar
            )
            if !historyCalendar.isDate(selectedYear, equalTo: grouped, toGranularity: .year) {
                selectedYear = grouped
            }
        }
        .onChange(of: selectedYear) { oldYear, newYear in
            guard !historyCalendar.isDate(
                oldYear,
                equalTo: newYear,
                toGranularity: .year
            ) else {
                return
            }
            let offset = historyCalendar.dateComponents(
                [.year],
                from: baseYearAnchor,
                to: groupingDate(
                    for: newYear,
                    grouping: .year,
                    calendar: historyCalendar
                )
            ).year ?? 0
            if (-100...100).contains(offset), yearPageSelection != offset {
                yearPageSelection = offset
            }
        }
    }

    // Renders one year page as a 2-column x 6-row grid of month cards (reuse existing card UI)
    private func yearSummaryPage(for year: Date) -> some View {
        let calendar = historyCalendar
        let yearComponents = calendar.dateComponents([.year], from: year)
        let months = (1...12).compactMap { month in
            var components = yearComponents
            components.month = month
            components.day = 1
            return calendar.date(from: components)
        }
        let monthFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.calendar = calendar
            formatter.dateFormat = "M월"
            return formatter
        }()
        let monthlyHistoryCounts = months.map { monthDate in
            displayHistories.filter {
                $0.type == .record &&
                calendar.isDate(
                    $0.date,
                    equalTo: monthDate,
                    toGranularity: .month
                )
            }.count
        }
        let maximumHistoryCount = monthlyHistoryCounts.max() ?? 0

        // 2 columns, 6 rows: (1월/2월), (3월/4월), ...
        let monthPairs = stride(from: 0, to: 12, by: 2).map { idx -> [Date] in
            Array(months[idx..<min(idx+2, 12)])
        }

        return VStack(spacing: 12) {
            ForEach(Array(monthPairs.enumerated()), id: \.offset) { rowIdx, pair in
                HStack(spacing: 12) {
                    ForEach(pair, id: \.self) { monthDate in
                        let index = months.firstIndex(of: monthDate) ?? 0
                        let monthHistories = displayHistories.filter {
                            $0.type == .record &&
                            calendar.isDate(
                                $0.date,
                                equalTo: monthDate,
                                toGranularity: .month
                            )
                        }
                        let dateCount = monthHistories.count
                        let photoCount = monthHistories.reduce(0) { sum, history in
                            sum + history.places.reduce(0) {
                                $0 + $1.photos.count
                            }
                        }
                        let diaryCount = allDiaries.filter {
                            Calendar.current.isDate($0.date, equalTo: monthDate, toGranularity: .month)
                        }.count
                        let hasHistory = dateCount > 0
                        let isTopMonth = maximumHistoryCount > 0 && dateCount == maximumHistoryCount

                        Button {
                            selectedMonth = monthDate
                            selectedMonthDate = monthDate
                            grouping = .month
                        } label: {
                            VStack(spacing: 10) {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Spacer()
                                        Text(monthFormatter.string(from: monthDate))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(
                                                hasHistory
                                                    ? Color.primary
                                                    : Color.secondary.opacity(0.55)
                                            )
                                        if isTopMonth {
                                            Text("👑")
                                                .font(.caption)
                                        }
                                        Spacer()
                                    }
                                }
                                HStack(spacing: 10) {
                                    Label {
                                        Text("\(dateCount)")
                                    } icon: {
                                        Text("❤️")
                                    }

                                    Label {
                                        Text("\(diaryCount)")
                                    } icon: {
                                        Text("📒")
                                    }

                                    Label {
                                        Text("\(photoCount)")
                                    } icon: {
                                        Text("📷")
                                    }
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(
                                    hasHistory
                                        ? Color.secondary
                                        : Color.secondary.opacity(0.38)
                                )
                                .labelStyle(.titleAndIcon)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(14)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 90,
                                alignment: .center
                            )
                            .background(
                                hasHistory
                                    ? selectedTheme.cardBackgroundColor
                                    : selectedTheme.cardBackgroundColor.opacity(0.55)
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                                .stroke(
                                    selectedTheme.primaryColor.opacity(
                                        hasHistory ? 0.10 : 0.05
                                    ),
                                    lineWidth: 1
                                )
                            }
                            .shadow(
                                color: .black.opacity(hasHistory ? 0.05 : 0.02),
                                radius: 8,
                                x: 0,
                                y: 3
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(index + 1)월, 데이트 \(dateCount)개, 일기 \(diaryCount)개, 사진 \(photoCount)장"
                        )
                    }
                    // If last row is single, fill space
                    if pair.count == 1 {
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private var yearTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년"
        return formatter.string(from: selectedYear)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: selectedMonth)
    }

    private var emptyPeriodTitle: String {
        switch grouping {
        case .week:
            return "이 주에는 기록이 없습니다"
        case .month:
            return "이 달에는 기록이 없습니다"
        case .year:
            return "이 연도에는 기록이 없습니다"
        case .day:
            return "표시할 기록이 없습니다"
        }
    }

    private var periodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if grouping == .month {
                    HStack(spacing: 16) {
                        Picker("연도", selection: selectedMonthYearBinding) {
                            ForEach(2020...2040, id: \.self) { year in
                                Text(verbatim: "\(year)년").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        Picker("월", selection: selectedMonthMonthBinding) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)월").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                } else if grouping == .year {
                    Picker("연도", selection: selectedYearBinding) {
                        ForEach(2020...2040, id: \.self) { year in
                            Text(verbatim: "\(year)년").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                } else {
                    DatePicker(
                        "기간 선택",
                        selection: periodSelectionBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .padding(.horizontal, 16)
                }
                Spacer(minLength: 0)
            }
            .navigationTitle(periodPickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        isShowingPeriodPicker = false
                    }
                }
            }
        }
    }

    private var periodPickerTitle: String {
        switch grouping {
        case .week:
            return "주 선택"
        case .month:
            return "월 선택"
        case .year:
            return "연도 선택"
        case .day:
            return "날짜 선택"
        }
    }

    private var periodSelectionBinding: Binding<Date> {
        Binding(
            get: {
                switch grouping {
                case .week:
                    return selectedWeekStart
                case .month:
                    return selectedMonth
                case .year:
                    return selectedYear
                case .day:
                    return Date()
                }
            },
            set: { newDate in
                switch grouping {
                case .week:
                    selectedWeekStart = groupingDate(
                        for: newDate,
                        grouping: .week,
                        calendar: historyCalendar
                    )
                case .month:
                    selectedMonth = groupingDate(
                        for: newDate,
                        grouping: .month,
                        calendar: historyCalendar
                    )
                case .year:
                    selectedYear = groupingDate(
                        for: newDate,
                        grouping: .year,
                        calendar: historyCalendar
                    )
                case .day:
                    break
                }
            }
        )
    }

    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard grouping == .week else {
                    return
                }

                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard
                    abs(horizontalDistance) > abs(verticalDistance),
                    abs(horizontalDistance) > 55
                else {
                    return
                }

                withAnimation(.easeOut(duration: 0.22)) {
                    let direction = horizontalDistance < 0 ? 1 : -1
                    weekSwipeDirection = direction
                    moveSelectedPeriod(by: direction)
                }
            }
    }

    private func scrollToHistoryDate(
        _ date: Date,
        using proxy: ScrollViewProxy
    ) {
        let targetDate = historyCalendar.startOfDay(for: date)

        guard groupedHistories.contains(where: {
            historyCalendar.isDate($0.id, inSameDayAs: targetDate)
        }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            proxy.scrollTo(targetDate, anchor: .top)
        }
    }

    private func scrollToTimelineDate(
        _ date: Date,
        in groups: [TimelineDayGroup],
        using proxy: ScrollViewProxy
    ) {
        let targetDate = historyCalendar.startOfDay(for: date)

        guard let resolvedDate = timelineScrollTarget(for: targetDate, in: groups) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            proxy.scrollTo(resolvedDate, anchor: .top)
        }
    }

    private func timelineScrollTarget(
        for targetDate: Date,
        in groups: [TimelineDayGroup]
    ) -> Date? {
        let groupDates = groups.map { historyCalendar.startOfDay(for: $0.id) }

        if groupDates.contains(where: {
            historyCalendar.isDate($0, inSameDayAs: targetDate)
        }) {
            return targetDate
        }

        if let previousDate = groupDates.filter({ $0 < targetDate }).max() {
            return previousDate
        }

        return groupDates.min()
    }

    private func moveSelectedPeriod(by value: Int) {
        switch grouping {
        case .week:
            withAnimation(.easeInOut(duration: 0.30)) {
                weekSwipeDirection = value
                selectedWeekStart = historyCalendar.date(
                    byAdding: .weekOfYear,
                    value: value,
                    to: selectedWeekStart
                ) ?? selectedWeekStart
            }
        case .month:
            let newMonth = historyCalendar.date(
                byAdding: .month,
                value: value,
                to: selectedMonth
            ) ?? selectedMonth

            selectedMonth = newMonth
        case .year:
            withAnimation(.easeInOut(duration: 0.30)) {
                selectedYear = historyCalendar.date(
                    byAdding: .year,
                    value: value,
                    to: selectedYear
                ) ?? selectedYear
            }
        case .day:
            break
        }
    }

    private func timelineListView(
        groups: [TimelineDayGroup],
        scrollsToDefaultDate: Bool
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        timelineDayGroupView(
                            group,
                            showsMonth: shouldShowTimelineMonth(in: groups, at: index),
                            showsSeparator: index > 0
                        )
                        .id(group.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(selectedTheme.backgroundColor)
            .id(grouping == .week ? selectedWeekStart : Date.distantPast)
            .transition(
                grouping == .week
                    ? .asymmetric(
                        insertion: .move(
                            edge: weekSwipeDirection > 0
                                ? .trailing
                                : .leading
                        ).combined(with: .opacity),
                        removal: .move(
                            edge: weekSwipeDirection > 0
                                ? .leading
                                : .trailing
                        ).combined(with: .opacity)
                    )
                    : .identity
            )
            .onAppear {
                guard scrollsToDefaultDate, let defaultTimelineDate else {
                    return
                }

                DispatchQueue.main.async {
                    proxy.scrollTo(defaultTimelineDate, anchor: .top)
                }
            }
            .onChange(of: selectedWeekDate) { _, newDate in
                guard grouping == .week, let newDate else {
                    return
                }

                scrollToTimelineDate(newDate, in: groups, using: proxy)
            }
        }
    }

    private func timelineDayGroupView(
        _ group: TimelineDayGroup,
        showsMonth: Bool,
        showsSeparator: Bool
    ) -> some View {
        VStack(spacing: 16) {
            if showsSeparator {
                Rectangle()
                    .fill(Color.primary.opacity(0.045))
                    .frame(height: 1)
                    .padding(.leading, 82)
                    .padding(.vertical, 4)
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 4) {
                    // 월 칩이 박스 위에 얹히므로 모든 행에 같은 여백을 준다
                    timelineDateBox(for: group.id, showsMonth: showsMonth)
                        .padding(.top, 9)

                    Rectangle()
                        .fill(selectedTheme.primaryColor.opacity(0.11))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: timelineDateColumnWidth, alignment: .center)

                VStack(spacing: 8) {
                    ForEach(group.histories) { history in
                        NavigationLink {
                            DateHistoryDetailView(history: history)
                        } label: {
                            timelineHistoryCard(history)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(
                                "데이트 삭제",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                deleteHistory(history)
                            }
                        }
                    }

                    ForEach(group.diaries) { diary in
                        timelineDiaryCard(diary)
                    }
                }
                .padding(.bottom, 22)
            }
        }
    }

    private func shouldShowTimelineMonth(
        in groups: [TimelineDayGroup],
        at index: Int
    ) -> Bool {
        guard groups.indices.contains(index) else {
            return false
        }

        if index == 0 {
            return true
        }

        return !historyCalendar.isDate(
            groups[index].id,
            equalTo: groups[index - 1].id,
            toGranularity: .month
        )
    }

    private var showsRelationshipTimelineLabel: Bool {
        showRelationshipDay && showRelationshipDayInHistory
    }

    private var timelineDateColumnWidth: CGFloat {
        58
    }

    /// 위 칸은 배경색 바탕에 포인트색 날짜, 아래 칸은 포인트색 바탕에 만난 날 일수.
    /// 달이 바뀌는 날에는 월 칩이 박스 위에 얹혀 위치 통일성을 지킨다.
    private func timelineDateBox(
        for date: Date,
        showsMonth: Bool
    ) -> some View {
        VStack(spacing: 0) {
            Text(timelineDayText(for: date))
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(selectedTheme.primaryOnBackgroundTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 46)
                .padding(.vertical, 8)
                .background(selectedTheme.backgroundColor)

            if let relationshipLabel = relationshipTimelineLabel(for: date) {
                Text(relationshipLabel)
                    .font(.pretendard(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(selectedTheme.backgroundOnPrimaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 46)
                    .padding(.vertical, 5)
                    .background(selectedTheme.primaryColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(selectedTheme.primaryColor.opacity(0.55), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            if showsMonth {
                Text(timelineMonthText(for: date))
                    .font(.pretendard(size: 9, weight: .bold))
                    .foregroundStyle(selectedTheme.backgroundOnPrimaryTextColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(selectedTheme.primaryColor))
                    .offset(y: -9)
            }
        }
    }

    private func relationshipTimelineLabel(for date: Date) -> String? {
        guard showsRelationshipTimelineLabel else {
            return nil
        }

        let startDate = historyCalendar.startOfDay(
            for: Date(timeIntervalSince1970: relationshipStartDateInterval)
        )
        let targetDate = historyCalendar.startOfDay(for: date)

        guard
            let days = historyCalendar.dateComponents(
                [.day],
                from: startDate,
                to: targetDate
            ).day,
            days >= 0
        else {
            return nil
        }

        return "+\(days + 1)"
    }

    private func timelineHistoryCard(
        _ history: DateHistory
    ) -> some View {
        let isPlan = history.type == .plan

        if !isPlan,
            let imageData = history.coverImageData,
            let uiImage = UIImage(data: imageData)
        {
            let usesLightText = usesLightText(on: uiImage)
            let textColor: Color = usesLightText ? .white : selectedTheme.primaryColor

            return AnyView(
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 148)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .saturation(isPlan ? 0.35 : 1)

                    LinearGradient(
                        colors: [
                            .black.opacity(0),
                            .black.opacity(usesLightText ? 0.54 : 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        Text(history.title)
                            .font(.pretendard(size: 20, weight: .extraBold))
                            .foregroundStyle(textColor)
                            .lineLimit(2)

                        historyMetaRow(history)
                            .foregroundStyle(textColor.opacity(0.88))
                    }
                    .padding(16)
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
                .overlay(alignment: .topTrailing) {
                    if isPlan {
                        planBadge
                    }
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: isPlan ? "calendar.badge.clock" : "heart.fill")
                        .foregroundStyle(
                            isPlan ? Color.gray : selectedTheme.primaryColor
                        )

                    Text(history.title)
                        .font(.pretendard(size: 17, weight: .bold))
                        .foregroundStyle(isPlan ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }

                if let latestComment = history.comments.max(
                    by: { $0.createdAt < $1.createdAt }
                ) {
                    Text(latestComment.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                historyMetaRow(history)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isPlan
                    ? Color(uiColor: .systemGray6)
                    : selectedTheme.cardBackgroundColor
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    isPlan
                        ? Color.gray.opacity(0.28)
                        : selectedTheme.primaryColor.opacity(0.10),
                    lineWidth: 1
                )
            }
            .overlay(alignment: .topTrailing) {
                if isPlan {
                    planBadge
                }
            }
        )
    }

    private var planBadge: some View {
        Text("계획")
            .font(.pretendard(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.gray)
            .clipShape(Capsule())
            .padding(10)
    }

    private func historyMetaRow(
        _ history: DateHistory
    ) -> some View {
        HStack(spacing: 10) {
            Label(
                "장소 \(history.places.count)곳",
                systemImage: "mappin.and.ellipse"
            )
        }
        .font(.caption.weight(.semibold))
    }

    private func timelineDiaryCard(
        _ diary: Diary
    ) -> some View {
        Button {
            editingTimelineDiary = diary
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(diary.mood)
                    Text(diary.weather)

                    Text(diary.title.isEmpty ? "일기" : diary.title)
                        .font(.pretendard(size: 16, weight: .bold))
                        .lineLimit(1)
                }

                Text(diary.content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.13))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func usesLightText(on image: UIImage) -> Bool {
        guard
            let cgImage = image.cgImage,
            let data = cgImage.dataProvider?.data,
            let bytes = CFDataGetBytePtr(data)
        else {
            return true
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        let startY = Int(Double(height) * 0.62)
        let stepX = max(width / 12, 1)
        let stepY = max((height - startY) / 8, 1)
        var luminanceTotal = 0.0
        var sampleCount = 0

        for y in stride(from: startY, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = Double(bytes[offset]) / 255.0
                let green = Double(bytes[offset + min(1, bytesPerPixel - 1)]) / 255.0
                let blue = Double(bytes[offset + min(2, bytesPerPixel - 1)]) / 255.0
                luminanceTotal += 0.299 * red + 0.587 * green + 0.114 * blue
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else {
            return true
        }

        return luminanceTotal / Double(sampleCount) <= 0.58
    }

    private func timelineMonthText(for date: Date) -> String {
        "\(historyCalendar.component(.month, from: date))월"
    }

    private func timelineDayText(for date: Date) -> String {
        "\(historyCalendar.component(.day, from: date))"
    }

    private var relationshipHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showRelationshipDay {
                Text("오늘, 우리가 함께한")
                    .font(.subheadline)
                    .foregroundStyle(
                        selectedTheme.onPrimaryTextColor.opacity(0.78)
                    )

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(relationshipDayCount)")
                        .font(
                            .system(
                                size: 46,
                                weight: .semibold,
                                design: .serif
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(selectedTheme.onPrimaryTextColor)

                    Text("일째")
                        .font(.headline)
                        .foregroundStyle(
                            selectedTheme.onPrimaryTextColor.opacity(0.82)
                        )
                }
            } else {
                Text(welcomeMessage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(selectedTheme.onPrimaryTextColor)

                Text("데이트 계획과 추억을 하나씩 남겨보세요.")
                    .font(.subheadline)
                    .foregroundStyle(
                        selectedTheme.onPrimaryTextColor.opacity(0.76)
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.trailing, 158)
        .padding(.bottom, 20)
        .background(selectedTheme.primaryColor)
        .overlay(alignment: .bottomTrailing) {
            Image("relationshipHeaderCouple")
                .resizable()
                .renderingMode(.template)
                .scaledToFill()
                .foregroundStyle(
                    selectedTheme == .cream
                        ? selectedTheme.secondaryColor
                        : .white
                )
                .frame(width: 222, height: 158, alignment: .top)
                .clipped()
                .offset(x: 6, y: 27)
                .allowsHitTesting(false)
        }
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 26,
                bottomTrailingRadius: 26
            )
        )
        .clipped()
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func daySectionTitle(
        for date: Date,
        fallback: String
    ) -> String {
        guard grouping == .week || grouping == .month || grouping == .year else {
            return fallback
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = historyCalendar
        formatter.dateFormat = "yyyy.M.d"
        return formatter.string(from: date)
    }

    private func groupingMenuTitle(
        _ grouping: HistoryGrouping
    ) -> String {
        switch grouping {
        case .day:
            return "전체보기"
        case .week:
            return "주별"
        case .month:
            return "월별"
        case .year:
            return "연도별"
        }
    }

    private func deleteHistory(
        _ history: DateHistory
    ) {
        modelContext.delete(history)

        do {
            try modelContext.save()
        } catch {
            print("기록 삭제 실패: \(error)")
        }
    }

    private func deleteHistories(
        _ offsets: IndexSet,
        from groupedHistories: [DateHistory]
    ) {
        for index in offsets {
            modelContext.delete(groupedHistories[index])
        }

        do {
            try modelContext.save()
        } catch {
            print("기록 삭제 실패: \(error)")
        }
    }

    private func groupingDate(
        for date: Date,
        grouping: HistoryGrouping,
        calendar: Calendar
    ) -> Date {
        switch grouping {
        case .day:
            return calendar.startOfDay(for: date)

        case .week:
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: date
            )
            return calendar.date(from: components) ?? date

        case .month:
            let components = calendar.dateComponents(
                [.year, .month],
                from: date
            )
            return calendar.date(from: components) ?? date

        case .year:
            let components = calendar.dateComponents(
                [.year],
                from: date
            )
            return calendar.date(from: components) ?? date
        }
    }

    private func groupTitle(
        for date: Date,
        grouping: HistoryGrouping,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar

        switch grouping {
        case .day:
            formatter.dateFormat = "yyyy.M.d"
            return formatter.string(from: date)

        case .week:
            guard
                let endDate = calendar.date(
                    byAdding: .day,
                    value: 6,
                    to: date
                )
            else {
                return DateDisplayFormatter.string(from: date)
            }

            let startText = DateDisplayFormatter.string(from: date)
            let endText = DateDisplayFormatter.string(from: endDate)

            return "\(startText) - \(endText)"

        case .month:
            formatter.dateFormat = "yyyy년 M월"
            return formatter.string(from: date)

        case .year:
            formatter.dateFormat = "yyyy년"
            return formatter.string(from: date)
        }
    }

    // MARK: - Custom Month/Year Picker Bindings
    private var selectedMonthYearBinding: Binding<Int> {
        Binding<Int>(
            get: {
                Calendar(identifier: .gregorian).component(.year, from: selectedMonth)
            },
            set: { newYear in
                let cal = Calendar(identifier: .gregorian)
                var comps = cal.dateComponents([.year, .month], from: selectedMonth)
                comps.year = newYear
                comps.day = 1
                if let newDate = cal.date(from: comps) {
                    selectedMonth = newDate
                }
            }
        )
    }

    private var selectedMonthMonthBinding: Binding<Int> {
        Binding<Int>(
            get: {
                Calendar(identifier: .gregorian).component(.month, from: selectedMonth)
            },
            set: { newMonth in
                let cal = Calendar(identifier: .gregorian)
                var comps = cal.dateComponents([.year, .month], from: selectedMonth)
                comps.month = newMonth
                comps.day = 1
                if let newDate = cal.date(from: comps) {
                    selectedMonth = newDate
                }
            }
        )
    }

    private var selectedYearBinding: Binding<Int> {
        Binding<Int>(
            get: {
                Calendar(identifier: .gregorian).component(.year, from: selectedYear)
            },
            set: { newYear in
                let cal = Calendar(identifier: .gregorian)
                var comps = cal.dateComponents([.year], from: selectedYear)
                comps.year = newYear
                if let newDate = cal.date(from: comps) {
                    selectedYear = newDate
                }
            }
        )
    }
}


private struct HistoryRow: View {
    let history: DateHistory

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private var sortedPlaces: [DatePlace] {
        history.places.sorted {
            $0.order < $1.order
        }
    }

    private var photoCount: Int {
        sortedPlaces.reduce(0) { count, place in
            count + place.photos.count
        }
    }


    private var placeRouteText: String {
        sortedPlaces
            .map(\.name)
            .joined(separator: " → ")
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(selectedTheme.secondaryColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 12) {
                if history.type == .record,
                    let imageData = history.coverImageData,
                    let uiImage = UIImage(data: imageData)
                {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                }

                HStack(alignment: .top, spacing: 12) {
                    Text(history.title)
                        .font(
                            .system(
                                size: 20,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }

                if !sortedPlaces.isEmpty {
                    Label {
                        Text(placeRouteText)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(selectedTheme.secondaryColor)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(
                        "\(sortedPlaces.count)곳",
                        systemImage: "location.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTheme.secondaryColor.opacity(0.10))
                    .clipShape(Capsule())

                    if photoCount > 0 {
                        Label(
                            "\(photoCount)장",
                            systemImage: "photo.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTheme.primaryColor.opacity(0.10))
                        .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
