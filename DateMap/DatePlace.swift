import Foundation
import SwiftData

@Model
final class DatePlace {
    var name: String
    var order: Int
    var memo: String

    var latitude: Double?
    var longitude: Double?

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
        longitude: Double? = nil
    ) {
        self.name = name
        self.order = order
        self.memo = memo
        self.latitude = latitude
        self.longitude = longitude
    }
}
