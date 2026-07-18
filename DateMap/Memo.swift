//
//  Memo.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//


import Foundation
import SwiftData

@Model
final class Memo {
    var date: Date
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date,
        content: String
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.content = content

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
