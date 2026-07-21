//
//  Wish.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//

import Foundation
import SwiftData

/// 위시를 묶어 보는 폴더. 위시가 없어도 폴더만 먼저 만들 수 있다.
@Model
final class WishFolder {
    var id: UUID
    var name: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

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

    /// 위시를 묶어 보는 폴더 이름. 비어 있으면 폴더 없음.
    var folder: String = ""

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
        visitedDate: Date? = nil,
        folder: String = ""
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
        self.folder = folder
    }
}
