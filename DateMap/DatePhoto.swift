import Foundation
import SwiftData

@Model
final class DatePhoto {
    var id: UUID
    var createdAt: Date
    var order: Int

    @Attribute(.externalStorage)
    var imageData: Data?

    var place: DatePlace?

    init(
        imageData: Data,
        order: Int,
        place: DatePlace? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.order = order
        self.imageData = imageData
        self.place = place
    }
}
