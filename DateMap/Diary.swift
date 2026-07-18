//
//  Diary.swift
//  DateMap
//
//  Created by 김기중 on 7/17/26.
//


import Foundation
import SwiftData

@Model
final class Diary {
    var date: Date
    var title: String
    var content: String
    var mood: String
    var weather: String
    @Attribute(.externalStorage)
    var photoData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date,
        title: String = "",
        content: String = "",
        mood: String = "🙂",
        weather: String = "☀️",
        photoData: Data? = nil
    ) {
        self.date = date
        self.title = title
        self.content = content
        self.mood = mood
        self.weather = weather
        self.photoData = photoData
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
