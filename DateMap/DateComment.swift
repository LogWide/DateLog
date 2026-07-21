//
//  DateComment.swift
//  DateMap
//

import Foundation
import SwiftData

@Model
final class DateComment {
    var content: String
    var createdAt: Date
    var history: DateHistory?

    init(content: String) {
        self.content = content
        self.createdAt = Date()
    }
}
