
import Foundation
import SwiftData

enum DateHistoryType: String, Codable, CaseIterable {
    case plan
    case record

    var displayName: String {
        switch self {
        case .plan:
            return "계획"
        case .record:
            return "기록"
        }
    }

    var systemImage: String {
        switch self {
        case .plan:
            return "calendar.badge.clock"
        case .record:
            return "heart.fill"
        }
    }
}

@Model
final class DateHistory {
    var title: String
    var date: Date
    var memo: String
    @Attribute(.externalStorage)
    var coverImageData: Data?
    var typeRawValue: String = DateHistoryType.record.rawValue
    var createdAt: Date

    var type: DateHistoryType {
        get {
            DateHistoryType(rawValue: typeRawValue) ?? .record
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }

    @Relationship(
        deleteRule: .cascade,
        inverse: \DatePlace.history
    )
    var places: [DatePlace] = []

    @Relationship(
        deleteRule: .cascade,
        inverse: \DateComment.history
    )
    var comments: [DateComment] = []

    init(
        title: String,
        date: Date,
        memo: String,
        coverImageData: Data? = nil,
        type: DateHistoryType = .record
    ) {
        self.title = title
        self.date = date
        self.memo = memo
        self.coverImageData = coverImageData
        self.typeRawValue = type.rawValue
        self.createdAt = Date()
    }
}
