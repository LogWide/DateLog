//
//  Wish.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import Foundation
import SwiftData

@Model
final class Wish {
    var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var category: String
    var memo: String
    var createdAt: Date
    var isVisited: Bool
    var visitedDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        category: String = "",
        memo: String = "",
        createdAt: Date = Date(),
        isVisited: Bool = false,
        visitedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.memo = memo
        self.createdAt = createdAt
        self.isVisited = isVisited
        self.visitedDate = visitedDate
    }
}
