import SwiftUI
import SwiftData

/// 기록을 숫자로 돌아보는 웹진 스타일의 데이트 리포트.
struct StatsView: View {
    @Query(sort: \DateHistory.date) private var histories: [DateHistory]
    @Query private var diaries: [Diary]
    @Query private var wishes: [Wish]

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    @AppStorage("relationshipStartDate")
    private var relationshipStartDateInterval = Date().timeIntervalSince1970

    @AppStorage("showRelationshipDay")
    private var showRelationshipDay = false

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - 기초 데이터

    private var records: [DateHistory] {
        histories.filter { $0.type == .record }
    }

    private var allPlaces: [DatePlace] {
        records.flatMap(\.places)
    }

    private var totalPhotoCount: Int {
        allPlaces.map(\.photos.count).reduce(0, +)
            + diaries.filter { $0.photoData != nil }.count
    }

    // MARK: - 통계 계산

    private struct RankedItem: Identifiable {
        let id = UUID()
        let label: String
        let emoji: String?
        let count: Int
    }

    private func topRanked(
        _ counts: [String: Int],
        limit: Int,
        emoji: ((String) -> String?)? = nil
    ) -> [RankedItem] {
        counts
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .prefix(limit)
            .map {
                RankedItem(
                    label: $0.key,
                    emoji: emoji?($0.key),
                    count: $0.value
                )
            }
    }

    private var districtRanking: [RankedItem] {
        var counts: [String: Int] = [:]

        for place in allPlaces {
            guard
                let code = MapDistrictStore.districtCode(for: place),
                let district = MapDistrictStore.district(withCode: code)
            else {
                continue
            }

            counts[district.name, default: 0] += 1
        }

        return topRanked(counts, limit: 5)
    }

    private var categoryRanking: [RankedItem] {
        var counts: [String: Int] = [:]

        for place in allPlaces {
            let category = PlaceCategoryNormalizer.categoryName(
                from: place.categoryName
            )

            guard !category.isEmpty else {
                continue
            }

            counts[category, default: 0] += 1
        }

        return topRanked(counts, limit: 5) { category in
            PlaceCategoryNormalizer.emoji(for: category)
        }
    }

    private var revisitRanking: [RankedItem] {
        var counts: [String: Int] = [:]

        for place in allPlaces {
            counts[place.name, default: 0] += 1
        }

        return topRanked(counts.filter { $0.value >= 2 }, limit: 5)
    }

    private func monthKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월"
    }

    /// 데이트를 가장 많이 한 달
    private var busiestDateMonth: (label: String, count: Int)? {
        var counts: [String: Int] = [:]

        for record in records {
            counts[monthKey(for: record.date), default: 0] += 1
        }

        return counts.max {
            $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
        }
        .map { ($0.key, $0.value) }
    }

    /// 장소를 가장 많이 다닌 달
    private var busiestPlaceMonth: (label: String, count: Int)? {
        var counts: [String: Int] = [:]

        for place in allPlaces {
            guard let date = place.history?.date else {
                continue
            }

            counts[monthKey(for: date), default: 0] += 1
        }

        return counts.max {
            $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
        }
        .map { ($0.key, $0.value) }
    }

    /// 요일별 데이트 횟수 (일요일부터)
    private var weekdayCounts: [Int] {
        var counts = Array(repeating: 0, count: 7)

        for record in records {
            let weekday = calendar.component(.weekday, from: record.date)
            counts[weekday - 1] += 1
        }

        return counts
    }

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    // MARK: 계절

    /// 봄·여름·가을·겨울 데이트 횟수
    private var seasonCounts: [(name: String, emoji: String, count: Int)] {
        var counts = [0, 0, 0, 0]

        for record in records {
            switch calendar.component(.month, from: record.date) {
            case 3...5: counts[0] += 1
            case 6...8: counts[1] += 1
            case 9...11: counts[2] += 1
            default: counts[3] += 1
            }
        }

        return [
            ("봄", "🌸", counts[0]),
            ("여름", "☀️", counts[1]),
            ("가을", "🍂", counts[2]),
            ("겨울", "❄️", counts[3])
        ]
    }

    // MARK: 템포

    private var uniqueRecordDays: [Date] {
        Array(
            Set(records.map { calendar.startOfDay(for: $0.date) })
        )
        .sorted()
    }

    /// 데이트 사이 평균 간격(일)
    private var averageIntervalDays: Int? {
        let days = uniqueRecordDays

        guard days.count >= 2, let first = days.first, let last = days.last else {
            return nil
        }

        let totalDays = calendar.dateComponents(
            [.day],
            from: first,
            to: last
        ).day ?? 0

        return totalDays / (days.count - 1)
    }

    /// 가장 오래 데이트가 없던 공백(일)
    private var longestGapDays: Int? {
        let days = uniqueRecordDays

        guard days.count >= 2 else {
            return nil
        }

        return zip(days, days.dropFirst())
            .map {
                calendar.dateComponents([.day], from: $0, to: $1).day ?? 0
            }
            .max()
    }

    /// 매달 빠짐없이 데이트한 최장 연속 개월 수
    private var monthlyStreak: Int {
        let monthIndexes = Set(
            records.map { record -> Int in
                let components = calendar.dateComponents(
                    [.year, .month],
                    from: record.date
                )
                return (components.year ?? 0) * 12 + (components.month ?? 0)
            }
        )
        .sorted()

        var best = monthIndexes.isEmpty ? 0 : 1
        var current = best

        for (previous, next) in zip(monthIndexes, monthIndexes.dropFirst()) {
            current = next == previous + 1 ? current + 1 : 1
            best = max(best, current)
        }

        return best
    }

    /// 주말/평일 데이트 횟수
    private var weekendWeekdaySplit: (weekend: Int, weekday: Int) {
        var weekend = 0
        var weekday = 0

        for record in records {
            let day = calendar.component(.weekday, from: record.date)

            if day == 1 || day == 7 {
                weekend += 1
            } else {
                weekday += 1
            }
        }

        return (weekend, weekday)
    }

    // MARK: 여정 (이동 거리)

    private static func distanceKilometers(
        latitude1: Double,
        longitude1: Double,
        latitude2: Double,
        longitude2: Double
    ) -> Double {
        let earthRadius = 6371.0
        let deltaLatitude = (latitude2 - latitude1) * .pi / 180
        let deltaLongitude = (longitude2 - longitude1) * .pi / 180
        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(latitude1 * .pi / 180) * cos(latitude2 * .pi / 180)
            * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)

        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// 데이트 안에서 장소 순서대로 이동한 직선거리 합(km)
    private func travelDistance(of record: DateHistory) -> Double {
        let coordinates = record.places
            .sorted { $0.order < $1.order }
            .compactMap { place -> (Double, Double)? in
                guard
                    let latitude = place.latitude,
                    let longitude = place.longitude
                else {
                    return nil
                }

                return (latitude, longitude)
            }

        guard coordinates.count >= 2 else {
            return 0
        }

        return zip(coordinates, coordinates.dropFirst())
            .map {
                Self.distanceKilometers(
                    latitude1: $0.0,
                    longitude1: $0.1,
                    latitude2: $1.0,
                    longitude2: $1.1
                )
            }
            .reduce(0, +)
    }

    private var totalTravelDistance: Double {
        records.map(travelDistance(of:)).reduce(0, +)
    }

    /// 가장 멀리 움직인 데이트
    private var longestJourney: (record: DateHistory, distance: Double)? {
        records
            .map { ($0, travelDistance(of: $0)) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }
    }

    // MARK: 영토

    private var placesWithCoordinates: [DatePlace] {
        allPlaces.filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// 동서남북 극점 장소
    private var extremePlaces: [(direction: String, place: DatePlace)] {
        let places = placesWithCoordinates

        guard
            let north = places.max(by: { ($0.latitude ?? 0) < ($1.latitude ?? 0) }),
            let south = places.min(by: { ($0.latitude ?? 0) < ($1.latitude ?? 0) }),
            let east = places.max(by: { ($0.longitude ?? 0) < ($1.longitude ?? 0) }),
            let west = places.min(by: { ($0.longitude ?? 0) < ($1.longitude ?? 0) })
        else {
            return []
        }

        return [
            ("최북단", north),
            ("최남단", south),
            ("최동단", east),
            ("최서단", west)
        ]
    }

    /// 방문한 행정구역 수 / 전체 행정구역 수
    private var districtConquest: (visited: Int, total: Int) {
        let visitedCodes = Set(
            allPlaces.compactMap {
                MapDistrictStore.districtCode(for: $0)
            }
        )

        return (visitedCodes.count, MapDistrictStore.districts().count)
    }

    // MARK: 일기 무드

    private var moodRanking: [RankedItem] {
        var counts: [String: Int] = [:]

        for diary in diaries where !diary.mood.isEmpty {
            counts[diary.mood, default: 0] += 1
        }

        return topRanked(counts, limit: 3)
    }

    private var weatherRanking: [RankedItem] {
        var counts: [String: Int] = [:]

        for diary in diaries where !diary.weather.isEmpty {
            counts[diary.weather, default: 0] += 1
        }

        return topRanked(counts, limit: 3)
    }

    // MARK: 수다

    private var totalCommentCount: Int {
        records.map(\.comments.count).reduce(0, +)
    }

    /// 댓글이 가장 많이 달린 데이트
    private var chattiestDate: DateHistory? {
        records
            .filter { !$0.comments.isEmpty }
            .max {
                $0.comments.count == $1.comments.count
                    ? $0.date < $1.date
                    : $0.comments.count < $1.comments.count
            }
    }

    /// 일기·메모·댓글로 남긴 총 글자 수
    private var totalWrittenCharacters: Int {
        let diaryCharacters = diaries
            .map { $0.title.count + $0.content.count }
            .reduce(0, +)
        let memoCharacters = allPlaces.map(\.memo.count).reduce(0, +)
        let commentCharacters = records
            .flatMap(\.comments)
            .map(\.content.count)
            .reduce(0, +)

        return diaryCharacters + memoCharacters + commentCharacters
    }

    // MARK: 위시의 시간

    private var visitedWishDurations: [(wish: Wish, days: Int)] {
        wishes.compactMap { wish in
            guard
                wish.isVisited,
                let visitedDate = wish.visitedDate
            else {
                return nil
            }

            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: wish.createdAt),
                to: calendar.startOfDay(for: visitedDate)
            ).day ?? 0

            return days >= 0 ? (wish, days) : nil
        }
    }

    private var averageWishDays: Int? {
        let durations = visitedWishDurations

        guard !durations.isEmpty else {
            return nil
        }

        return durations.map(\.days).reduce(0, +) / durations.count
    }

    /// 담아두고 가장 오래 묵힌 뒤 이룬 위시
    private var longestAgedWish: (wish: Wish, days: Int)? {
        visitedWishDurations.max { $0.days < $1.days }
    }

    /// 사진을 가장 많이 남긴 데이트
    private var mostPhotographedDate: (record: DateHistory, count: Int)? {
        records
            .map { record in
                (record, record.places.map(\.photos.count).reduce(0, +))
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }
    }

    /// 장소를 가장 많이 들른 데이트
    private var longestDate: DateHistory? {
        records.max {
            $0.places.count == $1.places.count
                ? $0.date < $1.date
                : $0.places.count < $1.places.count
        }
    }

    private var wishAchievementText: String? {
        guard !wishes.isEmpty else {
            return nil
        }

        let visited = wishes.filter(\.isVisited).count
        return "\(visited)/\(wishes.count)"
    }

    private var firstDate: DateHistory? {
        records.first
    }

    // MARK: - 본문

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroSection

                if records.isEmpty {
                    emptyCard
                } else {
                    monthSection
                    seasonSection
                    tempoSection
                    districtSection

                    if !extremePlaces.isEmpty {
                        territorySection
                    }

                    categorySection
                    weekdaySection

                    if totalTravelDistance > 0 {
                        journeySection
                    }

                    if !revisitRanking.isEmpty {
                        revisitSection
                    }

                    if !moodRanking.isEmpty || !weatherRanking.isEmpty {
                        moodSection
                    }

                    if totalCommentCount > 0 || totalWrittenCharacters > 0 {
                        talkSection
                    }

                    if averageWishDays != nil {
                        wishTimeSection
                    }

                    tmiSection
                }
            }
            .padding(16)
        }
        .background(selectedTheme.backgroundColor)
        .navigationTitle("데이트 리포트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(selectedTheme.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(
            selectedTheme.navigationColorScheme,
            for: .navigationBar
        )
        .dateLogBackChevron(selectedTheme)
        .tint(selectedTheme.primaryColor)
    }

    // MARK: - 섹션

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("우리의 발자국을\n숫자로 되돌아봤어요.")
                .font(.pretendard(size: 24, weight: .extraBold))
                .foregroundStyle(selectedTheme.onPrimaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                heroStat(value: "\(records.count)", unit: "번의 데이트")
                heroStat(value: "\(allPlaces.count)", unit: "곳의 장소")
                heroStat(value: "\(totalPhotoCount)", unit: "장의 사진")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selectedTheme.primaryColor)

                FabricTexture(
                    lineColor: selectedTheme.onPrimaryTextColor,
                    lineOpacity: 0.05
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                )

                StitchBorder(
                    cornerRadius: 22,
                    inset: 6,
                    threadColor: selectedTheme.onPrimaryTextColor.opacity(0.5)
                )
            }
        }
    }

    private func heroStat(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(selectedTheme.onPrimaryTextColor)

            Text(unit)
                .font(.pretendard(size: 12, weight: .semiBold))
                .foregroundStyle(selectedTheme.onPrimaryTextColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(selectedTheme.primaryColor)

            Text("아직 통계를 낼 기록이 없어요")
                .font(.pretendard(size: 16, weight: .bold))

            Text("데이트를 기록하면 이곳에 리포트가 채워집니다.")
                .font(.pretendard(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .dateLogCard(selectedTheme, cornerRadius: 18)
    }

    private var monthSection: some View {
        statsSection(overline: "MONTH", title: "가장 바빴던 달") {
            HStack(spacing: 10) {
                if let busiestDateMonth {
                    highlightCard(
                        title: "데이트가 가장 많던 달",
                        value: busiestDateMonth.label,
                        caption: "\(busiestDateMonth.count)번의 데이트"
                    )
                }

                if let busiestPlaceMonth {
                    highlightCard(
                        title: "발걸음이 가장 잦던 달",
                        value: busiestPlaceMonth.label,
                        caption: "\(busiestPlaceMonth.count)곳 방문"
                    )
                }
            }
        }
    }

    private var seasonSection: some View {
        let seasons = seasonCounts
        let maxCount = max(seasons.map(\.count).max() ?? 0, 1)

        return statsSection(overline: "SEASON", title: "계절의 온도") {
            HStack(spacing: 10) {
                ForEach(seasons, id: \.name) { season in
                    VStack(spacing: 5) {
                        Text(season.emoji)
                            .font(.system(size: 22))
                            .opacity(season.count > 0 ? 1 : 0.35)

                        Text("\(season.count)회")
                            .font(.pretendard(size: 14, weight: .extraBold))
                            .monospacedDigit()
                            .foregroundStyle(
                                season.count == maxCount && season.count > 0
                                    ? selectedTheme.primaryColor
                                    : .primary
                            )

                        Text(season.name)
                            .font(.pretendard(size: 11, weight: .semiBold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTheme.primaryColor.opacity(
                            season.count == maxCount && season.count > 0
                                ? 0.12
                                : 0.05
                        )
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                }
            }
        }
    }

    private var tempoSection: some View {
        statsSection(overline: "TEMPO", title: "우리의 템포") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if let averageIntervalDays {
                        highlightCard(
                            title: "평균 데이트 간격",
                            value: "\(averageIntervalDays)일",
                            caption: "데이트와 데이트 사이"
                        )
                    }

                    if let longestGapDays {
                        highlightCard(
                            title: "가장 길었던 공백",
                            value: "\(longestGapDays)일",
                            caption: "그래도 다시 만났죠"
                        )
                    }
                }

                if monthlyStreak >= 2 {
                    highlightCard(
                        title: "월간 개근 스트릭",
                        value: "\(monthlyStreak)개월 연속",
                        caption: "한 달도 빠짐없이 데이트한 기간"
                    )
                }
            }
        }
    }

    private var territorySection: some View {
        let conquest = districtConquest

        return statsSection(overline: "TERRITORY", title: "우리 영토의 끝") {
            VStack(spacing: 10) {
                ForEach(extremePlaces, id: \.direction) { item in
                    HStack(spacing: 10) {
                        Text(item.direction)
                            .font(.pretendard(size: 11, weight: .bold))
                            .foregroundStyle(selectedTheme.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTheme.primaryColor.opacity(0.10))
                            .clipShape(Capsule())

                        Text(item.place.name)
                            .font(.pretendard(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(item.place.categoryEmoji)
                            .font(.system(size: 14))
                    }
                }

                if conquest.visited > 0 {
                    HStack {
                        Text("동네 정복")
                            .font(.pretendard(size: 13, weight: .semiBold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(conquest.visited)")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(selectedTheme.primaryColor)
                        + Text(" / \(conquest.total)개 지역")
                            .font(.pretendard(size: 13, weight: .semiBold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var journeySection: some View {
        statsSection(overline: "JOURNEY", title: "우리가 움직인 거리") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", totalTravelDistance))
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(selectedTheme.primaryColor)

                    Text("km")
                        .font(.pretendard(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Text("데이트에서 장소 사이를 이동한 직선거리 합이에요.")
                    .font(.pretendard(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)

                if let longestJourney {
                    tmiRow(
                        icon: "figure.hiking",
                        title: "가장 멀리 움직인 날",
                        value: "\(longestJourney.record.title) · \(String(format: "%.1f", longestJourney.distance))km"
                    )
                }
            }
        }
    }

    private var moodSection: some View {
        statsSection(overline: "MOOD", title: "일기 속 우리") {
            HStack(alignment: .top, spacing: 10) {
                if !moodRanking.isEmpty {
                    emojiRankColumn(title: "자주 남긴 기분", items: moodRanking)
                }

                if !weatherRanking.isEmpty {
                    emojiRankColumn(title: "함께한 날씨", items: weatherRanking)
                }
            }
        }
    }

    private func emojiRankColumn(
        title: String,
        items: [RankedItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.pretendard(size: 12, weight: .semiBold))
                .foregroundStyle(.secondary)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 7) {
                    Text(item.label)
                        .font(.system(size: index == 0 ? 22 : 16))

                    Text("\(item.count)번")
                        .font(.pretendard(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(
                            index == 0 ? selectedTheme.primaryColor : .secondary
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(selectedTheme.primaryColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var talkSection: some View {
        statsSection(overline: "TALK", title: "우리가 남긴 이야기") {
            VStack(spacing: 10) {
                tmiRow(
                    icon: "text.bubble.fill",
                    title: "주고받은 댓글",
                    value: "\(totalCommentCount)개"
                )

                if let chattiestDate {
                    tmiRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "가장 수다스러웠던 데이트",
                        value: "\(chattiestDate.title) · \(chattiestDate.comments.count)개"
                    )
                }

                tmiRow(
                    icon: "pencil.line",
                    title: "함께 쓴 글자 수",
                    value: "\(totalWrittenCharacters.formatted())자"
                )
            }
        }
    }

    private var wishTimeSection: some View {
        statsSection(overline: "WISH", title: "위시가 이뤄지기까지") {
            VStack(spacing: 10) {
                if let averageWishDays {
                    tmiRow(
                        icon: "hourglass",
                        title: "평균 숙성 기간",
                        value: averageWishDays == 0 ? "당일 실행!" : "\(averageWishDays)일"
                    )
                }

                if let longestAgedWish, longestAgedWish.days > 0 {
                    tmiRow(
                        icon: "clock.badge.checkmark",
                        title: "가장 오래 기다린 위시",
                        value: "\(longestAgedWish.wish.name) · \(longestAgedWish.days)일"
                    )
                }
            }
        }
    }

    private var districtSection: some View {
        statsSection(overline: "PLACE", title: "우리가 가장 많이 간 동네") {
            if districtRanking.isEmpty {
                sectionEmptyText("좌표가 있는 장소가 쌓이면 동네 랭킹이 나와요.")
            } else {
                rankedBars(districtRanking, unit: "곳")
            }
        }
    }

    private var categorySection: some View {
        statsSection(overline: "TASTE", title: "우리가 사랑한 카테고리") {
            if categoryRanking.isEmpty {
                sectionEmptyText("장소에 카테고리를 붙이면 취향 랭킹이 나와요.")
            } else {
                rankedBars(categoryRanking, unit: "곳")
            }
        }
    }

    private var weekdaySection: some View {
        let counts = weekdayCounts
        let maxCount = max(counts.max() ?? 0, 1)

        let split = weekendWeekdaySplit

        return statsSection(overline: "RHYTHM", title: "우리의 데이트 요일") {
            VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text(counts[index] > 0 ? "\(counts[index])" : "")
                            .font(.pretendard(size: 10, weight: .bold))
                            .foregroundStyle(selectedTheme.primaryColor)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                counts[index] == maxCount && counts[index] > 0
                                    ? selectedTheme.primaryColor
                                    : selectedTheme.primaryColor.opacity(0.25)
                            )
                            .frame(
                                height: max(
                                    6,
                                    CGFloat(counts[index]) / CGFloat(maxCount) * 74
                                )
                            )

                        Text(weekdaySymbols[index])
                            .font(.pretendard(size: 11, weight: .semiBold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text(
                split.weekend >= split.weekday
                    ? "우리는 주말파! 주말 \(split.weekend)회 · 평일 \(split.weekday)회"
                    : "우리는 평일파! 평일 \(split.weekday)회 · 주말 \(split.weekend)회"
            )
            .font(.pretendard(size: 12, weight: .semiBold))
            .foregroundStyle(selectedTheme.primaryColor)
            }
        }
    }

    private var revisitSection: some View {
        statsSection(overline: "AGAIN", title: "또 가고 또 간 곳") {
            rankedBars(revisitRanking, unit: "번")
        }
    }

    private var tmiSection: some View {
        statsSection(overline: "TMI", title: "소소한 기록들") {
            VStack(spacing: 10) {
                if let firstDate {
                    tmiRow(
                        icon: "sparkles",
                        title: "첫 데이트",
                        value: "\(DateDisplayFormatter.string(from: firstDate.date)) \(firstDate.title)"
                    )
                }

                if let longestDate, longestDate.places.count > 0 {
                    tmiRow(
                        icon: "figure.walk",
                        title: "가장 부지런했던 데이트",
                        value: "\(longestDate.title) · \(longestDate.places.count)곳"
                    )
                }

                if let mostPhotographedDate {
                    tmiRow(
                        icon: "camera.fill",
                        title: "사진을 가장 많이 남긴 날",
                        value: "\(mostPhotographedDate.record.title) · \(mostPhotographedDate.count)장"
                    )
                }

                tmiRow(
                    icon: "book.closed.fill",
                    title: "함께 쓴 일기",
                    value: "\(diaries.count)편"
                )

                if let wishAchievementText {
                    tmiRow(
                        icon: "heart.text.square.fill",
                        title: "위시 달성",
                        value: wishAchievementText
                    )
                }

                if showRelationshipDay {
                    tmiRow(
                        icon: "calendar.badge.clock",
                        title: "함께한 날",
                        value: "\(relationshipDayCount)일째"
                    )
                }
            }
        }
    }

    private var relationshipDayCount: Int {
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

    // MARK: - 공통 컴포넌트

    private func statsSection(
        overline: String,
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(overline)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .kerning(1.6)
                    .foregroundStyle(selectedTheme.primaryColor)

                Text(title)
                    .font(.pretendard(size: 19, weight: .extraBold))
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dateLogCard(selectedTheme, cornerRadius: 20)
    }

    private func sectionEmptyText(_ text: String) -> some View {
        Text(text)
            .font(.pretendard(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightCard(
        title: String,
        value: String,
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.pretendard(size: 12, weight: .semiBold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.pretendard(size: 18, weight: .extraBold))
                .foregroundStyle(selectedTheme.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(caption)
                .font(.pretendard(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectedTheme.primaryColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rankedBars(
        _ items: [RankedItem],
        unit: String
    ) -> some View {
        let maxCount = max(items.map(\.count).max() ?? 0, 1)

        return VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(
                            index == 0
                                ? selectedTheme.primaryColor
                                : Color.secondary
                        )
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            if let emoji = item.emoji {
                                Text(emoji)
                                    .font(.system(size: 13))
                            }

                            Text(item.label)
                                .font(.pretendard(size: 14, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("\(item.count)\(unit)")
                                .font(.pretendard(size: 12, weight: .semiBold))
                                .foregroundStyle(selectedTheme.primaryColor)
                        }

                        GeometryReader { proxy in
                            Capsule()
                                .fill(
                                    selectedTheme.primaryColor.opacity(
                                        index == 0 ? 1 : 0.3
                                    )
                                )
                                .frame(
                                    width: max(
                                        proxy.size.width
                                            * CGFloat(item.count)
                                            / CGFloat(maxCount),
                                        10
                                    )
                                )
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    private func tmiRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selectedTheme.primaryColor)
                .frame(width: 30, height: 30)
                .background(selectedTheme.primaryColor.opacity(0.10))
                .clipShape(Circle())

            Text(title)
                .font(.pretendard(size: 14, weight: .semiBold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.pretendard(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(
        for: [
            DateHistory.self,
            DatePlace.self,
            DatePhoto.self,
            Diary.self,
            Wish.self
        ],
        inMemory: true
    )
}
