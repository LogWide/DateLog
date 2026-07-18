import SwiftUI
import SwiftData
import UserNotifications

@main
struct DateMapApp: App {

    init() {
        DateLogTypography.configureAppearance()

        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if let error {
                    print("알림 권한 요청 실패: \(error)")
                }

                print("알림 권한: \(granted)")
            }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DateHistory.self,
            DatePlace.self,
            DatePhoto.self,
            Diary.self,
            Memo.self,
            Wish.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .font(.pretendard(size: 16))
        }
        .modelContainer(sharedModelContainer)
    }
}
