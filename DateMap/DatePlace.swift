import Foundation
import SwiftData

@Model
final class DatePlace {
    var name: String
    var order: Int
    var memo: String

    // 네이버 지도 연결 후 사용할 좌표
    var latitude: Double?
    var longitude: Double?

    var history: DateHistory?

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
