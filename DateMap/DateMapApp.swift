import SwiftUI
import SwiftData

@main
struct DateMapApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DateHistory.self,
            DatePlace.self,
            DatePhoto.self
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
        }
        .modelContainer(sharedModelContainer)
    }
}
