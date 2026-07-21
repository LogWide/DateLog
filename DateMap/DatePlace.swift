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

    /// 위시에서 방문 완료/계획 추가로 만들어진 장소라면 원본 위시의 ID
    var sourceWishID: UUID?

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
        categoryEmoji: String = "📍",
        sourceWishID: UUID? = nil
    ) {
        self.name = name
        self.order = order
        self.memo = memo
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.categoryName = categoryName
        self.categoryEmoji = categoryEmoji
        self.sourceWishID = sourceWishID
    }
}
