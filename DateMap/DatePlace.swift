import Foundation
import SwiftData

@Model
final class DatePlace {
    var name: String
    var order: Int
    var memo: String

    var latitude: Double?
    var longitude: Double?
    var address: String = ""
    var categoryName: String = "기타"
    var categoryEmoji: String = "📍"

    var history: DateHistory?

    @Relationship(
        deleteRule: .cascade,
        inverse: \DatePhoto.place
    )
    var photos: [DatePhoto] = []

    init(
        name: String,
        order: Int,
        memo: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String = "",
        categoryName: String = "기타",
        categoryEmoji: String = "📍"
    ) {
        self.name = name
        self.order = order
        self.memo = memo
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.categoryName = categoryName
        self.categoryEmoji = categoryEmoji
    }
}
