import Foundation
import SwiftData

@Model
final class DateHistory {
    var title: String
    var date: Date
    var memo: String
    var createdAt: Date

    @Relationship(
        deleteRule: .cascade,
        inverse: \DatePlace.history
    )
    var places: [DatePlace] = []

    init(
        title: String,
        date: Date,
        memo: String
    ) {
        self.title = title
        self.date = date
        self.memo = memo
        self.createdAt = Date()
    }
}
