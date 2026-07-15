import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    @State private var selectedCoordinate: CoordinateData?
    @State private var selectedSavedPlace: DatePlace?
    @State private var selectedPlaceName = ""

    @State private var isShowingSavePlace = false
    @State private var isShowingPlaceSearch = false

    @State private var selectedHistory: DateHistory?
    private var displayedPlaces: [DatePlace] {
        selectedHistory?.places.sorted {
            $0.order < $1.order
        } ?? []
    }

    var body: some View {
        TabView {
            HistoryView()
                .tabItem {
                    Label("기록", systemImage: "calendar")
                }

            NavigationStack {
                ZStack(alignment: .bottom) {
                    MapView(
                        places: displayedPlaces,
                        selectedCoordinate: $selectedCoordinate,
                        selectedSavedPlace: $selectedSavedPlace,
                        selectedPlaceName: $selectedPlaceName
                    )
                    .ignoresSafeArea(edges: .top)

                    VStack(spacing: 12) {
                        historyPicker

                        if let place = selectedSavedPlace {
                            savedPlaceCard(place)
                        }

                        if let coordinate = selectedCoordinate {
                            selectedCoordinateCard(coordinate)
                        }
                    }
                    .padding()
                }
                .navigationTitle("지도")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingPlaceSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("장소 검색")
                    }
                }
            }
            .sheet(isPresented: $isShowingSavePlace) {
                if let coordinate = selectedCoordinate {
                    SavePinnedPlaceView(
                        coordinate: coordinate,
                        suggestedPlaceName: selectedPlaceName
                    ) {
                        selectedCoordinate = nil
                        selectedPlaceName = ""
                    }
                }
            }
            .sheet(isPresented: $isShowingPlaceSearch) {
                PlaceSearchView { result in
                    guard
                        let latitude = result.latitude,
                        let longitude = result.longitude
                    else {
                        return
                    }

                    selectedSavedPlace = nil
                    selectedPlaceName = result.cleanTitle

                    selectedCoordinate = CoordinateData(
                        latitude: latitude,
                        longitude: longitude
                    )
                }
            }
            .onAppear {
                if selectedHistory == nil {
                    selectedHistory = histories.first
                }
            }
            .tabItem {
                Label("지도", systemImage: "map")
            }
        }
    }

    private var historyPicker: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)

            if histories.isEmpty {
                Text("저장된 데이트가 없습니다")
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    "데이트",
                    selection: $selectedHistory
                ) {
                    Text("데이트 선택")
                        .tag(nil as DateHistory?)

                    ForEach(histories) { history in
                        Text(
                            "\(history.title) · \(history.date.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .tag(history as DateHistory?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedHistory) {
                    selectedCoordinate = nil
                    selectedSavedPlace = nil
                }
            }

            Spacer()

            Text("\(displayedPlaces.count)곳")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func selectedCoordinateCard(
        _ coordinate: CoordinateData
    ) -> some View {
        VStack(spacing: 8) {
            Text(
                selectedPlaceName.isEmpty
                    ? "새 위치"
                    : selectedPlaceName
            )
            .font(.headline)

            Text(
                String(
                    format: "%.6f, %.6f",
                    coordinate.latitude,
                    coordinate.longitude
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("선택 취소") {
                    selectedCoordinate = nil
                    selectedPlaceName = ""
                }
                .buttonStyle(.bordered)

                Button("이 위치 저장") {
                    isShowingSavePlace = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func savedPlaceCard(
        _ place: DatePlace
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(place.order + 1)번째 장소")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(place.name)
                        .font(.headline)
                }

                Spacer()

                Button {
                    selectedSavedPlace = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !place.memo.isEmpty {
                Text(place.memo)
                    .font(.subheadline)
            }

            if
                let latitude = place.latitude,
                let longitude = place.longitude
            {
                Text(
                    String(
                        format: "%.6f, %.6f",
                        latitude,
                        longitude
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: \DateHistory.date,
        order: .reverse
    )
    private var histories: [DateHistory]

    @State private var isShowingAddView = false

    var body: some View {
        NavigationStack {
            Group {
                if histories.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없습니다",
                        systemImage: "heart.text.clipboard",
                        description: Text("오른쪽 위 + 버튼으로 첫 데이트를 기록하세요.")
                    )
                } else {
                    List {
                        ForEach(histories) { history in
                            NavigationLink {
                                DateHistoryDetailView(history: history)
                            } label: {
                                HistoryRow(history: history)
                            }
                        }
                        .onDelete(perform: deleteHistories)
                    }
                }
            }
            .navigationTitle("DateLog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("데이트 추가")
                }
            }
            .sheet(isPresented: $isShowingAddView) {
                AddDateHistoryView()
            }
        }
    }

    private func deleteHistories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(histories[index])
        }

        do {
            try modelContext.save()
        } catch {
            print("기록 삭제 실패: \(error)")
        }
    }
}

// MARK: - 데이트 목록 행

private struct HistoryRow: View {
    let history: DateHistory

    private var sortedPlaces: [DatePlace] {
        history.places.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(history.title)
                .font(.headline)

            Text(
                history.date.formatted(
                    date: .long,
                    time: .omitted
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !sortedPlaces.isEmpty {
                Text(
                    sortedPlaces
                        .map(\.name)
                        .joined(separator: " → ")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            if !history.memo.isEmpty {
                Text(history.memo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 데이트 추가

private struct AddDateHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var selectedDate = Date()
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("데이트 제목", text: $title)

                    DatePicker(
                        "날짜",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                }

                Section("메모") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle("데이트 추가")
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
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
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
            )
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

// MARK: - 데이트 상세

private struct DateHistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let history: DateHistory

    @State private var isShowingAddPlace = false

    private var sortedPlaces: [DatePlace] {
        history.places.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            Section("날짜") {
                Text(
                    history.date.formatted(
                        date: .long,
                        time: .omitted
                    )
                )
            }

            Section {
                if sortedPlaces.isEmpty {
                    Text("아직 추가된 장소가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlaces) { place in
                        HStack(spacing: 12) {
                            Text("\(place.order + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(.blue)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)

                                if !place.memo.isEmpty {
                                    Text(place.memo)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .onDelete(perform: deletePlaces)
                    .onMove(perform: movePlaces)
                }
            } header: {
                HStack {
                    Text("장소")

                    Spacer()

                    Text("\(sortedPlaces.count)곳")
                }
            }

            Section("메모") {
                if history.memo.isEmpty {
                    Text("작성된 메모가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(history.memo)
                }
            }
        }
        .navigationTitle(history.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()

                Button {
                    isShowingAddPlace = true
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .accessibilityLabel("장소 추가")
            }
        }
        .sheet(isPresented: $isShowingAddPlace) {
            AddPlaceView(history: history)
        }
    }

    private func deletePlaces(at offsets: IndexSet) {
        let placesToDelete = offsets.map { sortedPlaces[$0] }

        for place in placesToDelete {
            modelContext.delete(place)
        }

        reorderPlaces()

        do {
            try modelContext.save()
        } catch {
            print("장소 삭제 실패: \(error)")
        }
    }
    private func movePlaces(
        from source: IndexSet,
        to destination: Int
    ) {
        var reorderedPlaces = sortedPlaces

        reorderedPlaces.move(
            fromOffsets: source,
            toOffset: destination
        )

        for (index, place) in reorderedPlaces.enumerated() {
            place.order = index
        }

        do {
            try modelContext.save()
        } catch {
            print("장소 순서 저장 실패: \(error)")
        }
    }

    private func reorderPlaces() {
        let remainingPlaces = history.places
            .filter { !$0.isDeleted }
            .sorted { $0.order < $1.order }

        for (index, place) in remainingPlaces.enumerated() {
            place.order = index
        }
    }
}

// MARK: - 장소 추가

private struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let history: DateHistory

    @State private var name = ""
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("장소 정보") {
                    TextField(
                        "장소 이름",
                        text: $name
                    )

                    TextField(
                        "간단한 메모",
                        text: $memo,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }
            .navigationTitle("장소 추가")
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
                    .disabled(cleanName.isEmpty)
                }
            }
        }
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func savePlace() {
        guard !cleanName.isEmpty else {
            return
        }

        let nextOrder =
            (history.places.map(\.order).max() ?? -1) + 1

        let place = DatePlace(
            name: cleanName,
            order: nextOrder,
            memo: memo.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )

        place.history = history
        history.places.append(place)

        modelContext.insert(place)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("장소 저장 실패: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                DateHistory.self,
                DatePlace.self
            ],
            inMemory: true
        )
}
